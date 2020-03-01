	StackStrings(DefineAST, StringStartingOffsets) {
		if (DefineAST.Strings.Count() = 0) {
			return
		}
		
		this.CodeGen.Move(RBX, RSP)
		
		for k, String in DefineAST.Strings {
			HighAddressOffset := StringStartingOffsets[String.Value]
			
			this.CodeGen.SmallMove(RAX, HighAddressOffset)
			HighAddressSIB := SIB(1, RAX, R15)
			
			this.CodeGen.Lea_R64_SIB(RSP, HighAddressSIB)
			
			Characters := StrSplit(String.Value)
			
			CharacterCountRemainder := Mod(Characters.Count(), 8) ; Gets how many characters the string is over a 8 byte boundry
			
			if (CharacterCountRemainder = 0) {
				; If the string straddles the 8 byte boundry, push an extra character and update how many characters it is over the boundry by
				Characters.Push("") ; Otherwise, the string wouldn't be null-terminated
				CharacterCountRemainder := 1
			}
			
			loop, % 8 - CharacterCountRemainder {
				; For each byte left until the string reaches an 8 byte boundry, push an extra null character on it for padding
				Characters.Push("")
			}
			
			loop {
				CharacterChunk := 0 ; An int64 which holds the current 8 characters being turned into a single movabs
				
				loop 8 {
					; Since we are actually working with big-endian, the number we push will be reversed, so we want 
					;  to have all the terminating null characters (at the end of the string) on the left of the 
					;   first chunk, so by moving the first character we pop all the way left, we align the string
					;    correctly with the start at a low address, which counts up higher until the null characters
					;     are reached
					
					ReversedIndex := 8 - A_Index
					ShiftBy := ReversedIndex * 8
					
					CharacterChunk |= Asc(Characters.Pop()) << ShiftBy
				}
				
				this.CodeGen.Push(I64(CharacterChunk))
			} until (Characters.Count() = 0)
		}
		
		this.CodeGen.Move(RSP, RBX)
	}
	
	AddLocalAndCalculateSize(VariableIndex, TypeName, Name) {
		this.AddVariable(VariableIndex, Name)
		Type := this.Typing.AddVariable(TypeName, Name)
		
		return VariableIndex + 8
	}
	
	CompileDefine(Name, DefineAST) {
		if (DefineAST.Type != ASTNodeTypes.Define) {
			return
		}
		
		
		this.FunctionIndex++
		this.Variables := {}
		
		this.Function := DefineAST
		this.Locals := DefineAST.Locals
		
		this.RegisterStackIndex := 0
		this.StackDepth := 0
		this.HasReturn := False
		
		VariableIndex := 0
		MultiByteInitialValueSpace := 0
		
		for k, ParamPair in DefineAST.Params {
			VariableIndex := this.AddLocalAndCalculateSize(VariableIndex, ParamPair[1].Value, ParamPair[2].Value)
		}
		for LocalName, LocalInfo in DefineAST.Locals {
			VariableIndex := this.AddLocalAndCalculateSize(VariableIndex, LocalInfo.Type, LocalName)
		}
		
		StringStartingOffsets := {}

		for k, String in DefineAST.Strings {
			this.AddVariable(VariableIndex + (MultiByteInitialValueSpace * 8), "__String__" String.Value)
			this.Typing.AddVariable("i8*", "__String__" String.Value)
			
			MultiByteInitialValueSpace += Ceil((StrLen(String.Value) + 1) / 8)
			
			StringStartingOffsets[String.Value] := VariableIndex + (MultiByteInitialValueSpace * 8)
		}
		
		RequiredStackSpace := VariableIndex + (MultiByteInitialValueSpace * 8)
		
		if (Mod(RequiredStackSpace, 16) != 0) {
			RoundedStackSpace := RequiredStackSpace + (16 - Mod(RequiredStackSpace, 16))
		}
		else {
			RoundedStackSpace := RequiredStackSpace
		}
		
		RoundedStackSpace := Floor(RoundedStackSpace / 8) + 1
		
		;MsgBox, % Name " Flat:" RequiredStackSpace ", Round" RoundedStackSpace
		
		if (Mod(RequiredStackSpace, 2) != 1) {
			RequiredStackSpace++
			; Store a single extra fake local to align the stack (Saved RBP breaks alignment, so any odd number of locals will align the stack again, this just forces an odd number)
		}
		
		Log("Function '" Name "' uses " RequiredStackSpace " bytes of stack, with " this.Locals.Count() " locals, " DefineAST.Params.Count() " parameters, and " DefineAST.Strings.Count() " strings")
		
		this.CodeGen.Label("__Define__" Name)
		
		this.PushA()
			if (RequiredStackSpace != 0) {
				this.CodeGen.SmallSub(RSP, RoundedStackSpace * 8), this.StackDepth += RoundedStackSpace
				
				this.CodeGen.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			this.CodeGen.SmallMove(RSI, 0)
			this.CodeGen.SmallMove(RDI, 1)
			
			this.StackStrings(DefineAST, StringStartingOffsets)
			
			this.FunctionParameters(DefineAST.Params)
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
			if (Name = "__RunTime__SetGlobals") {
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
			}
			
			if !(this.HasReturn) {
				Log("Function '" Name "' had no return, inserting one")
				this.CodeGen.SmallMove(RAX, 0)
			}
			
			this.CodeGen.Label("__Return" this.FunctionIndex)
			
			if (RequiredStackSpace != 0) {
				this.CodeGen.SmallAdd(RSP, RoundedStackSpace * 8), this.StackDepth -= RoundedStackSpace
			}
		this.PopA()
		
		if (this.StackDepth != 0) {
			Log("Code generation error in '" Name "'")
			MsgBox, % "Unbalenced stack ops in " Name ", " this.StackDepth
		}
		
		this.CodeGen.Return()
	}
	
	FunctionParameters(Pairs) {
		static IntFirstFour := [RCX, RDX, R8, R9]
		static XMMFirstFour := [XMM0, XMM1, XMM2, XMM3]
		
		; x64 calling convention has the first four params in RCX(|XMM0), RDX(|XMM1), R8(|XMM2), R9(|XMM3)
		;  and the rest dumped onto the stack before the shadow space, and the return address/saved RBP
		;   so, FunctionEntryRBP aka FunctionEntryRSP + 2 (saved return address + saved RBP) + 4 = Start of stack params.
		;  However, variadic functions are still sort of ???
		
		; Because of these rules, after parameter 4, we need to use RBP as a base, and (ParamNumber - 4) + 2 + 4 as an offset into the stack for the parameter's value
		
		this.CodeGen.Move(RAX, RSI)
		IndexSIB := SIB(8, RAX, R15)
		
		for k, Pair in Pairs {
			TypeName := Pair[1].Value
			Type := this.Typing.GetType(TypeName)
			NameToken := Pair[2]
			Name := NameToken.Value

			TrueIndex := k - 1
			
			;this.AddVariable(TrueIndex, Name)
			;this.Typing.AddVariable(TypeName, Name)
			
			if (A_Index <= 4) {
				if (TypeName = "f64" || TypeName = "f32") {
					this.CodeGen.Move_SIB_XMM(IndexSIB, XMMFirstFour[TrueIndex + 1])
				}
				else {
					this.CodeGen.Move_SIB_R64(IndexSIB, IntFirstFour[TrueIndex + 1])
				}
			}
			
			if (A_Index = 5) {
				; When A_Index is 5 (aka the first stack-passed param)
				;  Store RBP into RCX, so we can use RBP in the SIB for getting a parameter out of the stack
				
				this.CodeGen.Move(RCX, RBP)
				this.CodeGen.SmallMove(RDX, 6)
			}
			
			if (A_Index > 4) {
				this.CodeGen.Move_R64_SIB(RBX, SIB(8, RDX, RCX)) ; Then fetch the passed value
				
				this.CodeGen.Move_SIB_R64(IndexSIB, RBX) ; And store it into our variable space
				
				if (Pairs.Count() > A_Index) {
					this.CodeGen.Inc_R64(RDX)
				}
			}
		
			if (Type.Family = "Custom") {
				if (Type.RoundedSize > 8) {
					new Error("Compile")
						.LongText("Parameter type size is larger than 8 bytes, and must be passed by pointer.")
						.ShortText("Can't be passed by value")
						.Token(Pair[2])
					.Throw()
				}
			}
			
			if (A_Index != Pairs.Count()) {
				this.CodeGen.Inc_R64(RAX)
			}
		}
	}
	
	CompileCall(Expression) {
		if (Expression.Target.Value = "__HCF") {
			this.CodeGen.Move_R64_RI64(this.PushRegisterStack(), RSI)
			return this.Typing.GetType("i8")
		}
		
		
		if (this.Typing.IsValidType(Expression.Target.Value) && Expression.Params.Expressions.Count() = 1) {
			OperandType := this.Compile(Expression.Params.Expressions[1])
			ResultType := this.Typing.GetType(Expression.Target.Value)
			
			try {
				this.Cast(OperandType, ResultType)
			}
			
			return ResultType
		}
		else if (Expression.Target.Type = ASTNodeTypes.Binary) {
			if (this.Features & this.DisableModules) {
				new Error("Compile")
					.LongText("Calling functions from modules is disabled by the DisableModules flag.")
					.ShortText("Can't be called")
					.Token(Expression)
					.Source(this.Source)
				.Throw()
			}
			
			ModuleExpression := Expression.Target
			
			if (ModuleExpression.Operator.Type = Tokens.COLON) {
				ModuleName := ModuleExpression.Left.Value
				ModuleFunctionName := ModuleExpression.Right.Value
				
				TrueName := this.EncodeModuleName(ModuleName, ModuleFunctionName)
				
				if (this.Name) {
					; If compiling a stand alone module, use a less intensive module finding method which avoids circular requirements
					TargetModule := Module.Find(ModuleName, True)
					FunctionNode := TargetModule.AST.Functions[ModuleFunctionName]
				}
				else {
					FunctionNode := this.Program.Functions[TrueName]
				}
				
				if !(IsObject(FunctionNode)) {
					new Error("Module")
						.LongText("Module or member not found.")
						.Token(Expression)
						.Source(this.Source)
					.Throw()
				}
				
				Expression.Target.Value := TrueName
			}
		}
		else {
			FunctionNode := this.Program.Functions[Expression.Target.Value]
		}
		
		if (FunctionNode) {
			;static ParamRegisters := [R9, R8, RDX, RCX]
			static ParamRegisters := [RCX, RDX, R8, R9]
			
			OldIndex := this.RegisterStackIndex ; Store the register stack index before calling, so we know what to save, and what to restore
			
			loop, % OldIndex {
				; Store whatever part of the register stack we're using, just in case the function we call doesn't 
				;  save all registers
				this.CodeGen.Push(this.RegisterStack[A_Index]), this.StackDepth++
			}
			
			this.RegisterStackIndex := 0
			
			loop, 4 {
				this.PushRegisterStack() ; Reserve RCX, RDX, R8, R9 on the register stack
			}
			
			Params := Expression.Params.Expressions
			
			if (Params.Count() > FunctionNode.Params.Count()) {
				new Error("Compile")
					.LongText("Too many parameters passed to function.")
					.ShortText("Takes " FunctionNode.Params.Count() " parameters.")
					.Token(Expression.Target)
					.Source(this.Source)
				.Throw()
			}
			else if (Params.Count() < FunctionNode.Params.Count()) {
				new Error("Compile")
					.LongText("Not enough parameters passed to function.")
					.ShortText("Takes " FunctionNode.Params.Count() " parameters.")
					.Token(Expression.Target)
					.Source(this.Source)
				.Throw()
			}
			
			StackParamCount := Max(Params.Count() - 4, 0)
			Straddling := False
			
			if (this.RegisterStackIndex = this.RegisterStack.Count()) {
				; If we are straddling a page of the register stack, push a dummy value just to make sure 
				;  the repeated .PopRegisterStack calls in the for loop don't spam pushing/popping the whole stack
				this.PushRegisterStack()
				Straddling := True ; Remember for later so we can remove the dummy
			}
			
			loop, % Abs(Min(0, Params.Count() - 4)) {
				this.CodeGen.Move(ParamRegisters[A_Index - 1 + 4])
			}
			
			loop, % Params.Count() {
				ReversedIndex := Params.Count() - (A_Index - 1)
				ParamValue := Params[ReversedIndex]
				; Push all parameters onto the stack in reverse order, the top 4 will be popped below to save the register stack
				
				ParamType := this.Compile(ParamValue)
				RequiredType := this.Typing.GetType(FunctionNode.Params[ReversedIndex][1].Value)
				
				if (RequiredType.Family = "Custom") {
					if (RequiredType.Size > 8) {
						new Error("Compile")
							.LongText("Parameter type size is larger than 8 bytes, and must be passed by pointer.")
							.ShortText("Can't be passed by value")
							.Token(ParamValue)
						.Throw()
					}
					
					TargetRegister := this.TopOfRegisterStack()
					this.CodeGen.Move_R64_RI64(TargetRegister, TargetRegister)
					
					;Name := "Move_R64_RI" (RequiredType.RoundedSize * 8)
					
					;this.CodeGen[Name].Call(this.CodeGen, this.TopOfRegisterStack(), this.TopOfRegisterStack())
				}
				
				try {
					this.Cast(ParamType, RequiredType) ; Ensure the passed parameter is of the correct type
					
					if (ReversedIndex <= 4) {
						this.CodeGen.Move(ParamRegisters[ReversedIndex], this.PopRegisterStack())
					}
					else {
						this.CodeGen.Push(this.PopRegisterStack()), this.StackDepth++
					}
				}
				catch {
					new Error("Compile")
						.LongText("Should be " RequiredType.Name ", not " ParamType.Name ".")
						.Token(ParamValue)
						.Source(this.Source)
					.Throw()
				}
			}
			
			loop, % 4 {
				;this.CodeGen.Pop(ParamRegisters[A_Index]), this.StackDepth--
			}
			
			ShadowSpaceSize := 4
			
			if (Mod(this.StackDepth, 2) != 1) {
				; Break stack alignment if needed, since 0x20 is even, and the push return addr will align the stack
				ShadowSpaceSize += 1
			}
			
			this.CodeGen.SmallSub(RSP, ShadowSpaceSize * 8), this.StackDepth += ShadowSpaceSize ; Allocate shadow space (below the stack parameters)
			
			if (FunctionNode.Type = ASTNodeTypes.DllImport) {
				this.CodeGen.DllCall(FunctionNode.DllName, FunctionNode.FunctionName)
			}
			else if (FunctionNode.Type = ASTNodeTypes.Define) {
				this.CodeGen.Call_Label("__Define__" Expression.Target.Value)
			}
			
			this.CodeGen.SmallAdd(RSP, (StackParamCount * 8) + (ShadowSpaceSize * 8))
			this.StackDepth -= StackParamCount, this.StackDepth -= ShadowSpaceSize ; Free shadow space + any stack params/dummy space
			
			this.RegisterStackIndex := OldIndex
			
			if (Straddling) {
				this.PopRegisterStack()
			}
			
			loop, % OldIndex {
				ReversedIndex := OldIndex - A_Index + 1
				this.CodeGen.Pop(this.RegisterStack[ReversedIndex]), this.StackDepth--
			}
			
			this.RegisterStackIndex := OldIndex
			
			this.CodeGen.Move(this.PushRegisterStack(), RAX) ; Push the return value
			
			return this.Typing.GetType(FunctionNode.ReturnType.Value) ; Give back the function's return type
		}
		
		new Error("Compile")
			.LongText("Function '" Expression.Target.Stringify() "' is not callable.")
			.Token(Expression.Target)
			.Source(this.Source)
		.Throw()
	}