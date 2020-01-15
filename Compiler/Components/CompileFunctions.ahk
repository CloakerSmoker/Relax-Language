	CompileDefine(DefineAST) {
		this.FunctionIndex++
		this.Variables := {}
		
		this.Function := DefineAST
		this.Locals := DefineAST.Locals
		
		this.RegisterStackIndex := 0
		this.StackDepth := 0
		this.HasReturn := False
		
		ParamSizes := DefineAST.Params.Count()
		
		for LocalName, LocalType in DefineAST.Locals {
			this.AddVariable(ParamSizes++, LocalName)
			this.Typing.AddVariable(LocalType[1], LocalName)
		}
		
		if (Mod(ParamSizes, 2) != 1) {
			ParamSizes++
			; Store a single extra fake local to align the stack (Saved RBP breaks alignment, so any odd number of locals will align the stack again, this just forces an odd number)
		}
		
		this.CodeGen.Label("__Define__" DefineAST.Name.Value)
		
		this.PushA()
			if (ParamSizes != 0) {
				if (ParamSizes <= 3) {
					Loop, % ParamSizes {
						this.CodeGen.Push(RBX), this.StackDepth++
					}
				}
				else {
					this.CodeGen.SmallSub(RSP, ParamSizes * 8), this.StackDepth += ParamSizes
				}
				
				this.CodeGen.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			this.CodeGen.SmallMove(RSI, 0)
			this.CodeGen.SmallMove(RDI, 1)
			
			this.FunctionParameters(DefineAST.Params)
			
			for k, LocalDefault in DefineAST.Locals {
				if (LocalDefault[2].Type != ASTNodeTypes.None) {
					this.Compile(LocalDefault[2])
				}
			}
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
			if !(this.HasReturn) {
				this.CodeGen.SmallMove(RAX, 0)
			}
			
			this.CodeGen.Label("__Return" this.FunctionIndex)
			
			if (ParamSizes != 0) {
				if (ParamSizes <= 3) {
					Loop, % ParamSizes {
						this.CodeGen.Pop(RBX), this.StackDepth--
					}
				}
				else {
					this.CodeGen.SmallAdd(RSP, ParamSizes * 8), this.StackDepth -= ParamSizes
				}
			}
		this.PopA()
		
		if (this.StackDepth != 0) {
			Throw, Exception("Unbalenced stack ops in " DefineAST.Name.Value ", " this.StackDepth)
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
		
		for k, Pair in Pairs {
			Type := Pair[1].Value
			Name := Pair[2].Value

			TrueIndex := k - 1
			
			this.AddVariable(TrueIndex, Name)
			this.Typing.AddVariable(Type, Name)
			
			if (TrueIndex = 0) {
				IndexRegister := RSI
			}
			else if (TrueIndex = 1) {
				IndexRegister := RDI
			}
			else {
				this.CodeGen.SmallMove(R14, TrueIndex)
				IndexRegister := R14
			}
			
			IndexSIB := SIB(8, IndexRegister, R15)

			if (Type = "Double" || Type = "Float") {
				this.CodeGen.Move_SIB_XMM(IndexSIB, XMMFirstFour[TrueIndex + 1])
			}
			else {
				this.CodeGen.Move_SIB_R64(IndexSIB, IntFirstFour[TrueIndex + 1])
			}
			
			if (A_Index = 4) {
				Break
			}
		}
		
		if (Pairs.Count() > 4) {
			this.CodeGen.Move(R12, RBP) ; Save RBP into R12, since RBP/13 can't be used as SIB.Base
		
			loop, % Pairs.Count() - 4 {
				Pair := Pairs[A_Index + 4]
				TrueIndex := (A_Index - 1) + 4 ; Get the actual (0 index) parameter number
				
				this.AddVariable(TrueIndex, Pair[2].Value)
				this.Typing.AddVariable(Pair[1].Value, Pair[2].Value) ; Register the variable
				
				this.CodeGen.SmallMove(R11, (TrueIndex - 4) + 2 + 4) ; Store the index into the stack into R11, so we can use it in a SIB
				this.CodeGen.Move_R64_SIB(RBX, SIB(8, R11, R12)) ; Load the parameter value from the stack, into RBX
				this.CodeGen.SmallMove(R11, TrueIndex) ; Load the actual index of the parameter into R11
				this.CodeGen.Move_SIB_R64(SIB(8, R11, R15), RBX) ; Finally store the loaded value of the parameter into this function's parameter space
			}
		}
	}
	
	CompileCall(Expression) {
		if (this.Typing.IsValidType(Expression.Target.Value) && Expression.Params.Expressions.Count() = 1) {
			this.Compile(Expression.Params.Expressions[1])
			return this.Typing.GetType(Expression.Target.Value)
		}
		else if (Expression.Target.Type = ASTNodeTypes.Binary) {
			ModuleExpression := Expression.Target
			
			if (ModuleExpression.Operator.Type = Tokens.COLON) {
				ModuleName := ModuleExpression.Left.Value
				FunctionName := ModuleExpression.Right.Value
				
				Try {
					ModuleFunction := Module.Find(ModuleName, FunctionName)
					FunctionNode := ModuleFunction.Define
				}
				catch {
					new Error("Module")
						.LongText(E.Message)
						.Token(ModuleExpression)
						.Source(this.Source)
					.Throw()
				}
				
				this.Modules[ModuleName] := ModuleFunction
				IsModuleCall := True
			}
		}
	
	
		if (IsModuleCall || FunctionNode := this.Program.Functions[Expression.Target.Value]) {
			static ParamRegisters := [R9, R8, RDX, RCX]
			
			OldIndex := this.RegisterStackIndex ; Store the register stack index before calling, so we know what to save, and what to restore
			
			loop, % OldIndex {
				; Store whatever part of the register stack we're using, just in case the function we call doesn't 
				;  save all registers
				this.CodeGen.Push(this.RegisterStack[A_Index]), this.StackDepth++
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
				this.CodeGen.Push(RSI), this.StackDepth++
			}
			
			loop, % Params.Count() {
				ReversedIndex := Params.Count() - (A_Index - 1)
				ParamValue := Params[ReversedIndex]
				; Push all parameters onto the stack in reverse order, the top 4 will be popped below to save the register stack
				
				ParamType := this.Compile(ParamValue)
				RequiredType := this.Typing.GetType(FunctionNode.Params[ReversedIndex][1].Value)
				
				try {
					this.Cast(ParamType, RequiredType) ; Ensure the passed parameter is of the correct type
					this.CodeGen.Push(this.PopRegisterStack()), this.StackDepth++
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
				this.CodeGen.Pop(ParamRegisters[A_Index]), this.StackDepth--
			}
			
			if (Mod(this.StackDepth, 2) != 1) {
				; Break stack alignment if needed, since 0x20 is even, and the push return addr will align the stack
				this.CodeGen.Push(0), this.StackDepth++, StackParamCount++
			}
			
			this.CodeGen.SmallSub(RSP, 0x20), this.StackDepth += 4 ; Allocate shadow space (below the stack parameters)
			
			if (IsModuleCall) {
				this.CodeGen.ModuleCall(ModuleName, FunctionNode.Name.Value, ModuleFunction.Address)
			}
			else if (FunctionNode.Type = ASTNodeTypes.DllImport) {
				this.CodeGen.DllCall(FunctionNode.DllName, FunctionNode.FunctionName)
			}
			else if (FunctionNode.Type = ASTNodeTypes.Define) {
				this.CodeGen.Call_Label("__Define__" Expression.Target.Value)
			}
			
			this.CodeGen.SmallAdd(RSP, (StackParamCount * 8) + 0x20)
			this.StackDepth -= 4, this.StackDepth -= StackParamCount ; Free shadow space + any stack params/dummy space
			
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