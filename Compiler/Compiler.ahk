class Compiler {
	; Note: This class is split into the various scripts in \Compiler\Components\, since it was too long to debug
	;  and very hard to navigate
	
	; How it works:
	;  Programs:
	;   A program is passed, and each function inside of that program is compiled
	;  Functions:
	;   For each parameter + local, stack space is allocated
	;   For each line in the body, compile the line
	;  Lines:
	;   Expression Statements:
	;    Compile the line's expression, but with a Pop at the end to clear the expression's return value
	;
	;  Expressions:
	;   Expressions are compiled by compiling both operands, and then compiling the equal instruction for the 
	;    - Operator. Each compiled expression is expected to push it's resulting value back onto the stack
	;    - so the next expression/construct up in the AST can use the return value
	;
	;   The operands of an operator can be tokens (numerical literals), identifiers, or other expressions
	;    Tokens:
	;     If the token is a number, it is just pushed onto the stack, otherwise it is an error
	;    Identifiers:
	;     The identifier is ensured to be a variable name, and then the variable contents are read off of the stack
	;      - By using R15 as a base for all variables, so a constant index can be used to read any given variable
	;    Expressions:
	;     The expressions are simply compiled, which will be a recursive process until a child expression has two 
	;      - Non-Expression operands
	;   Types:
	;    Each expression related CompileXXXX method will return the type of it's output value, in order for type checking to 
	;     - Work
	;   Assignments:
	;	 Assignments are handled seperately, since they function differently. An assignment is compiled by compiling the right
	;     - side value first, and then popping the resulting value from the right side expression into the memory
	;     - where the left-side variable lives
	;
	;  DllImports:
	;   DllImports are just functions with extra steps, all of the same pre-processing happens with a function call, but 
	;    - instead of linking against an offset to a second local function, the calls are linked to a const(ish) pointer
	;    - to the given function, gathered by `GetProcAddress`
	
	; Note 2: When I say "Pushed" or "Pop" or any combo of the two, I am not actually talking about the x86 stack
	;  Instead, I'm talking out RCX-R14, which are used as a fake stack, this is so I can use stack-like behavior to
	;   help with evaluation, but get the speed of using registers. When the register stack needs another register past
	;    R14, the entire register stack is saved, and it starts back from RCX
	
	static DisableDllCall := 1
	static DisableModules := 2
	static DisableGlobals := 4
	static DisableStrings := 8
	
	static UseStackStrings := 16
	static TargetPE := 32

	__New(CodeLexer, CodeParser, Flags) {
		this.Lexer := CodeLexer
		this.Source := CodeLexer.CodeString
		this.Parser := CodeParser
		this.Typing := CodeParser.Typing
		this.Features := Flags.Features
		
		this.RegisterStackIndex := 0
	}
	Compile(Something) {
		if (Something.__Class = "Token") {
			return this.CompileToken(Something)
		}
	
		return this["Compile" ASTNodeTypes[Something.Type]].Call(this, Something)
	}
	CompileNone() {
		return
	}
	
	static RegisterStack := [RCX, RDX, R8, R9, R10, R11, R12, R13]
	static RegisterStackReversed := [R13, R12, R11, R10, R9, R8, RDX, RCX]
	
	PopAllRegisterStack() {
		Log("Register stack empty, popping saved register stack")
		
		for k, Register in this.RegisterStackReversed {
			this.CodeGen.Pop(Register), this.StackDepth--
		}
	}
	PushAllRegisterStack() {
		Log("Register stack full, saving register stack")
		
		for k, Register in this.RegisterStack {
			this.CodeGen.Push(Register), this.StackDepth++
		}
	}
	
	TopOfRegisterStack() {
		return this.RegisterStack[this.RegisterStackIndex]
	}
	PopRegisterStack() {
		if (this.RegisterStackIndex = 0) {
			this.PopAllRegisterStack()
			this.RegisterStackIndex := this.RegisterStack.Count()
		}
		
		return this.RegisterStack[this.RegisterStackIndex--]
	}
	PushRegisterStack() {
		if (this.RegisterStackIndex >= this.RegisterStack.Count()) {
			this.PushAllRegisterStack()
			this.RegisterStackIndex := 0
		}
		
		return this.RegisterStack[++this.RegisterStackIndex]
	}
	
	#Include %A_LineFile%\..\Components\CompileFunctions.ahk
	; Compiles function definitions, and function calls
	
	#Include %A_LineFile%\..\Components\CompileStatements.ahk
	; Compiles control flow statements, plus expression statements
	
	#Include %A_LineFile%\..\Components\CompileVariables.ahk
	; Compiles variable behavior, and handles getting/setting/getting the address of a variable
	
	#Include %A_LineFile%\..\Components\CompileExpressions.ahk
	; Compiles all expressions but function calls
	
	AddStructTypes(Program) {
		this.CustomTypes := {}
		
		for k, StructNode in Program.CustomTypes {
			Offsets := {}
			Size := 0
			Types := {}
			
			for k, TypePair in StructNode.Types {
				try {
					Type := this.Typing.GetType(TypePair[1].Value)
				}
				catch {
					new Error("Type")
						.LongText("Unknown type")
						.Token(TypePair[1])
					.Throw()
				}
				
				TypeSize := Floor(Type.Precision / 8)
				Name := TypePair[2].Value
				
				if (Mod(Size, TypeSize)) {
					Size += (TypeSize - Mod(Size, TypeSize))
				}
				
				Offsets[Name] := Size
				Size += TypeSize
				Types[Name] := Type
			}
			
			if (Mod(Size, 8) != 0) {
				RoundedSize := Size + (8 - Mod(Size, 8))
			}
			else {
				RoundedSize := Size
			}
			
			;MsgBox, % StructName ": " Size "`n" RoundedSize
			
			Info := {"Size": Size, "Offsets": Offsets, "RoundedSize": RoundedSize, "Types": Types}
			
			StructName := StructNode.NameToken.Value
			this.CustomTypes[StructName] := Info
			this.Typing.AddCustomType(StructName, Info)
		}
	}
	
	CompileProgram(Program, ModuleName := "") {
		this.FunctionIndex := 0 ; A unique number to keep different functions from reusing label names
		
		this.CodeGen := new X64CodeGen()
		this.Globals := Program.Globals
		this.Name := ModuleName
		
		this.AddStructTypes(Program)
		
		this.Program := Program
		this.CurrentForLoop := False
		
		this.Modules := {}
		this.ModuleFunctions := {}
		this.ModuleGlobals := {}
		
		this.FunctionOffsets := FunctionOffsets := {}
		
		this.FlattenModuleList(Program)
		
		FunctionOffset := 0
		
		for FunctionName, FunctionDefine in Program.Functions {
			FunctionOffsets[FunctionName] := FunctionOffset
			
			Log("Compiling function '" FunctionName "' into index " FunctionOffset " inside assembled code")
			this.CompileDefine(FunctionName, FunctionDefine) ; Compile a function starting from FunctionOffset
			
			FunctionOffset := this.CodeGen.Index() ; And store the new offset for the next function
			
			if (FunctionOffsets[FunctionName] = FunctionOffset) {
				FunctionOffsets.Delete(FunctionName)
			}
		}
		
		this.Exports := {}
		
		Log("Program has " Program.Exports.Count() " exported functions")
		
		for k, ExportName in Program.Exports {
			Log("Registering exported function '" ExportName "' at offset " this.FunctionOffsets[ExportName])
			this.Exports[ExportName] := this.FunctionOffsets[ExportName]
		}
		
		return this
	}
	
	EncodeModuleName(ModuleName, Name) {
		if (ModuleName = this.Name) {
			return Name
		}
		else {
			return "__" ModuleName "__" Name
		}
	}
	
	FlattenModuleList(ForProgram) {
		for k, ModuleName in ForProgram.Modules {
			if (this.Modules.HasKey(ModuleName)) {
				Continue
			}
			
			ModuleInfo := Module.Find(ModuleName)
			this.Modules[ModuleName] := ModuleInfo ; Add the module to the list of already found modules
			ModuleAST := ModuleInfo.AST
			
			; Merge namespaces, prefixing each module function/global
			
			for FunctionName, FunctionDefine in ModuleAST.Functions {
				EncodedName := this.EncodeModuleName(ModuleName, FunctionName)
				
				this.Program.Functions[EncodedName] := FunctionDefine
				this.ModuleFunctions[EncodedName] := FunctionDefine
			}
			
			for GlobalName, GlobalInfo in ModuleAST.Globals {
				this.Program.Globals[this.EncodeModuleName(ModuleName, GlobalName)] := GlobalInfo
				this.ModuleGlobals[GlobalName] := GlobalInfo
			}
			
			; Recursively get the list of modules
			this.FlattenModuleList(ModuleAST)
		}
	}

	static PushSavedRegisters := [RSI, RDI, R12, R13, R14, R15]
	static PopSavedRegisters := [R15, R14, R13, R12, RDI, RSI]
	
	PushA() {
		this.CodeGen.Push(RBP), this.StackDepth++
		this.CodeGen.Move(RBP, RSP)
		
		for k, RegisterToPush in this.PushSavedRegisters {
			this.CodeGen.Push(RegisterToPush), this.StackDepth++
		}
	}
	PopA() {
		for k, RegisterToPop in this.PopSavedRegisters {
			this.CodeGen.Pop(RegisterToPop), this.StackDepth--
		}

		this.CodeGen.Pop(RBP), this.StackDepth--
	}
	
	CompileToken(TargetToken) {
		if (TargetToken.Type = Tokens.IDENTIFIER) {
			static PredefinedNames := {"false": RSI, "true": RDI}
			
			if (PredefinedNames.HasKey(TargetToken.Value)) {
				this.CodeGen.Move(this.PushRegisterStack(), PredefinedNames[TargetToken.Value])
				return this.Typing.GetType("i8")
			}
		
			
			return this.GetVariable(TargetToken)
		}
		
		ResultRegister := this.PushRegisterStack()
		
		Switch (TargetToken.Type) {
			Case Tokens.INTEGER: {
				IntegerValue := TargetToken.Value
				
				this.CodeGen.SmallMove(ResultRegister, IntegerValue)
				
				return this.Typing.GetType(this.CodeGen.NumberSizeOf(IntegerValue, False))
			}
			Case Tokens.DOUBLE: {
				this.CodeGen.Move_R64_I64(ResultRegister, I64(FloatToBinaryInt(TargetToken.Value)))
				
				return this.Typing.GetType("f64")
			}
			Case Tokens.STRING: {
				this.CodeGen.Lea_R64_SIB(ResultRegister, this.GetVariableSIB({"Value": "__String__" TargetToken.Value}))
				
				return this.Typing.GetType("i8*")
			}
			Default: {
				new Error("Compile")
					.LongText("This token can not be compiled.")
					.ShortText("Is not implemented in the compiler.")
					.Token(TargetToken)
					.Source(this.Source)
				.Throw()
			}
		}
	}
	
	;========================
	; Cast methods
	
	Cast(TypeOne, TypeTwo) {
		Base := ObjGetBase(this)
		
		try {
			; Try since with custom types, this might throw (even if T1.Name and T2.Name are equal)
			Path := this.Typing.CastPath(TypeOne, TypeTwo)
			; The other throw will still be reached for real bad casts though
		}
		
		if (TypeOne.Name = TypeTwo.Name || Path.Count() = 0) {
			return
		}
		
		TargetRegister := this.TopOfRegisterStack()
		
		if (TypeOne.Family = "Decimal" && TypeTwo.Family = "Integer") {
			return this.Cast_F64_I64(TargetRegister)
		}
		else if (TypeOne.Family = "Integer" && TypeTwo.Family = "Decimal") {
			return this.Cast_I64_F64(TargetRegister)
		}
		else if (TypeOne.Family = "Integer" && TypeTwo.Family = "Integer") {
			StartingTypeName := TypeOne.Name
			
			if (StartingTypeName = "Void") {
				StartingTypeName := "I64"
			}
			
			return this.CodeGen["MoveSX_R64_" TypeOne.Name].Call(this, TargetRegister, TargetRegister)
		}
		else if ((TypeOne.Pointer && TypeTwo.Family = "Integer") || (TypeTwo.Pointer && TypeOne.Family = "Integer")) {
			return
		}
		
		Throw, Exception("Invalid cast")
	}
	
	Cast_I64_F64(TargetRegister) {
		this.CodeGen.Push(TargetRegister), this.StackDepth++
		this.CodeGen.FILD_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(TargetRegister), this.StackDepth--
	}
	Cast_F64_I64(TargetRegister) {
		this.CodeGen.Push(TargetRegister), this.StackDepth++
		this.CodeGen.FISTP_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(TargetRegister), this.StackDepth--
	}
}