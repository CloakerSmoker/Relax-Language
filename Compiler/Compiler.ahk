﻿class Compiler {
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
	
	CompileProgram(Program, ModuleName := "") {
		this.FunctionIndex := 0 ; A unique number to keep different functions from reusing label names
		
		this.CodeGen := new X64CodeGen()
		this.Globals := Program.Globals
		this.Name := ModuleName
		
		if (this.Features & this.DisableGlobals) {
			if (this.Globals.Count()) {
				K := ""
				V := ""
				
				this.Globals._NewEnum().Next(K, V)
				
				StatementError("Global variables are disabled by the DisableGlobals flag.", "global " V " " K)
			}
		}
		
		this.Program := Program
		this.CurrentForLoop := False
		
		this.Modules := {}
		this.ModuleFunctions := {}
		this.ModuleGlobals := {}
		
		this.FunctionOffsets := FunctionOffsets := {}
		
		Log({})
		this.FlattenModuleList(Program)
		Log({})
		
		FunctionOffset := 0
		
		for FunctionName, FunctionDefine in Program.Functions {
			FunctionOffsets[FunctionName] := FunctionOffset
			
			if !(this.ModuleFunctions.HasKey(FunctionName)) {
				Log("Compiling function '" FunctionName "' into index " FunctionOffset " inside assembled code")
				this.CompileDefine(FunctionName, FunctionDefine) ; Compile a function starting from FunctionOffset
			}
			
			FunctionOffset := this.CodeGen.Index() ; And store the new offset for the next function
			
			if (FunctionOffsets[FunctionName] = FunctionOffset) {
				FunctionOffsets.Delete(FunctionName)
			}
		}
		
		if (this.Name) {
			FunctionOffsets["SetGlobals"] := this.CodeGen.Index()
			
			for GlobalName, GlobalInfo in this.Globals {
				Initializer := GlobalInfo.Initializer
				Expression := Initializer.Expression
				
				if (Initializer.Type != ASTNodeTypes.None) {
					if (Expression.Type = ASTNodeTypes.Binary && Expression.Operator.Type = Tokens.COLON_EQUAL) {
						Expression.Left.Value := GlobalName
					}
					
					this.Compile(GlobalInfo.Initializer)
				}
			}
			
			this.CodeGen.Return()
		}
		else {
			; If we're not compiling a standalone module, then actually gather the implementation for the modules used
			
			for ModuleName, ModuleInfo in this.Modules {
				ModuleOffset := this.CodeGen.Index()
				
				Log("Copying pre-compiled module " ModuleName " into offset " ModuleOffset " of compiled code")
				
				for LabelName, LabelOffset in ModuleInfo.Offsets {
					this.CodeGen.Labels[LabelName] := ModuleOffset + LabelOffset
				}
				
				this.CodeGen.Bytes.Push(ModuleInfo.Bytes*)
			}
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
			ModuleAST := ModuleInfo.AST
			
			for FunctionName, FunctionDefine in ModuleAST.Functions {
				EncodedName := this.EncodeModuleName(ModuleName, FunctionName)
				
				this.Program.Functions[EncodedName] := FunctionDefine
				this.ModuleFunctions[EncodedName] := FunctionDefine
			}
			
			for GlobalName, GlobalInfo in ModuleAST.Globals {
				this.Program.Globals[this.EncodeModuleName(ModuleName, GlobalName)] := GlobalInfo
				this.ModuleGlobals[GlobalName] := GlobalInfo
			}
			
			
			this.FlattenModuleList(ModuleAST)
			
			this.Modules[ModuleName] := ModuleInfo
		}
	}

	static PushSavedRegisters := [RCX, RDX, RSI, RDI, R8, R9, R10, R11, R12, R13, R14, R15]
	static PopSavedRegisters := [R15, R14, R13, R12, R11, R10, R9, R8, RDI, RSI, RDX, RCX]
	
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
			return this.GetVariable(TargetToken)
		}
		
		ResultRegister := this.PushRegisterStack()
		
		Switch (TargetToken.Type) {
			Case Tokens.INTEGER: {
				IntegerValue := TargetToken.Value
				
				if (IntegerValue <= 0x7F) {
					this.CodeGen.XOR_R64_R64(ResultRegister, ResultRegister)
					this.CodeGen.Move_R64_I8(ResultRegister, I8(IntegerValue))
				}
				else if (IntegerValue <= 0x7FFF) {
					this.CodeGen.XOR_R64_R64(ResultRegister, ResultRegister)
					this.CodeGen.Move_R64_I16(ResultRegister, I16(IntegerValue))
				}
				else if (IntegerValue <= 0x7FFFFFFF) {
					this.CodeGen.Move_R64_I32(ResultRegister, I32(IntegerValue))
				}
				else {
					this.CodeGen.Move_R64_I64(ResultRegister, I64(IntegerValue))
				}
				
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
	
	Cast(TypeOne, TypeTwo, StackLess := False) {
		; Parameter should be on the register stack, or in RAX
		; RAX is the only register used for casts
		; StackLess param is for when the operand is already in RAX, otherwise RAX is loaded with the first thing on the stack
		
		Base := ObjGetBase(this)
		Path := this.Typing.CastPath(TypeOne, TypeTwo)
		
		if (TypeOne.Name = TypeTwo.Name || Path.Count() = 0) {
			return
		}	
		
		if !(StackLess) {
			this.CodeGen.Move(RAX, this.TopOfRegisterStack())
		}
		
		for k, Pair in Path {
			Name := "Cast_" Pair[1].Name "_" Pair[2].Name
		
			if (Base.HasKey(Name)) {
				Base[Name].Call(this)
			}
			else {
				Throw, Exception("Invalid cast: " Name)
			}
		}
		
		if !(StackLess) {
			this.CodeGen.Move(this.TopOfRegisterStack(), RAX)
		}
	}
	
	Cast_I8_I16() {
		this.CodeGen.CBWE()
	}
	Cast_I16_I32() {
		this.CodeGen.CWDE()
	}
	Cast_I32_I64() {
		this.CodeGen.CDQE()
	}
	Cast_I64_I8() {
		this.Cast(this.Typing.GetType("i8"), this.Typing.GetType("i64"), True)
	}
	Cast_I64_Void() {
	}
	Cast_Void_I64() {
	}
	Cast_I64_F64() {
		this.CodeGen.Push(RAX), this.StackDepth++
		this.CodeGen.FILD_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(RAX), this.StackDepth--
	}
	Cast_F64_I64() {
		this.CodeGen.Push(RAX), this.StackDepth++
		this.CodeGen.FISTP_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(RAX), this.StackDepth--
	}
	Cast_I32_F32() {
	}
	Cast_F32_I32() {
	}
}