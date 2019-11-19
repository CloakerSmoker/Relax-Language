class Compiler {
	__New(Tokenizer, Typingizer) {
		this.Tokenizer := Tokenizer
		this.Typing := Typingizer
	}
	Compile(Something) {
		if (Something.__Class = "Token") {
			return this.CompileToken(Something)
		}
	
		return this["Compile" ASTNodeTypes[Something.Type]].Call(this, Something)
	}
	
	GetVariablePrelude(Name) {
		if !(this.Variables.HasKey(Name)) {
			Throw, Exception("Variable '" Name "' not found.")
		}
		
		Index := this.Variables[Name]
		
		if (Index = 0) {
			return RSI
		}
		else if (Index = 1) {
			return RDI
		}
		else {
			this.CodeGen.SmallMove(R10, Index)
			return R10
		}
	}
	
	GetVariable(Name) {
		IndexRegister := this.GetVariablePrelude(Name)
		
		this.CodeGen.Push(SIB(8, IndexRegister, R15))
		return this.Typing.GetVariableType(Name)
	}
	GetVariableAddress(Name) {
		IndexRegister := this.GetVariablePrelude(Name)
		
		this.CodeGen.Lea(R11, SIB(8, IndexRegister, R15))
		this.CodeGen.Push(R11)
	}
	
	AddVariable(RSPIndex, Name) {
		this.Variables[Name] := RSPIndex
	}
	
	CompileToken(TargetToken) {
		Switch (TargetToken.Type) {
			Case Tokens.INTEGER: {
				this.CodeGen.Push(TargetToken.Value)
				ShortTypeName := this.CodeGen.NumberSizeOf(TargetToken.Value, False)
				FullTypeName := IToInt(ShortTypeName)
				return this.Typing.GetType(FullTypeName)
			}
			Case Tokens.IDENTIFIER: {
				return this.GetVariable(TargetToken.Value)
			}
			Default: {
				PrettyError("Compile"
						   ,"Token '" TargetToken.Stringify() "' can not be compiled."
						   ,"Is not implemented in the compiler."
						   ,TargetToken
						   ,this.Tokenizer.CodeString)
			}
		}
	}
	
	CompileFunction(DefineAST) {
		this.Variables := {}
		; TODO - Add type checking (Duh) and type check .ReturnType against Int64/EAX
		ParamSizes := DefineAST.Params.Count() * 8
		CG := this.CodeGen := new X64CodeGen()
		
	
		CG.Push(RBP)
		CG.Move(RBP, RSP)
			if (ParamSizes != 0) {
				CG.Sub(RSP, ParamSizes)
				CG.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			CG.SmallMove(RSI, 0)
			CG.SmallMove(RDI, 1)
			
			this.FunctionParameters(DefineAST.Params)
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
		CG.Label("__Return")
		
		if (ParamSizes != 0) {
			CG.Add(RSP, ParamSizes)
		}
		
		this.Leave()
		
		return CG
	}
	Leave() {
		this.CodeGen.Pop(RBP)
		this.CodeGen.Return()
	}
	
	FunctionParameters(Pairs) {
		static IntFirstFour := [RCX, RDX, R8, R9]
		static XMMFirstFour := [XMM0, XMM1, XMM2, XMM3]
	
		Size := 0
		Count := Pairs.Count()
		
		for k, Pair in Pairs {
			Type := Pair[1].Value

			TrueIndex := k - 1
			
			this.AddVariable(TrueIndex, Pair[2].Value)
			this.Typing.AddVariable(Type, Pair[2].Value)
			
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
			
			Size += 8
		}
	
		return Size
	}
	
	CompileIfGroup(Statement) {
		static Index := 0
		
		ThisIndex := Index++
	
		for k, ElseIf in Statement.Options {
			this.CodeGen.Label("__If__" Index)
			this.Compile(ElseIf.Condition)
			this.CodeGen.Pop(RCX)
			this.CodeGen.Cmp(RCX, RSI)
			this.CodeGen.JE("__If__" Index + 1)
			
			for k, Line in ElseIf.Body {
				this.Compile(Line)
			}
			
			this.CodeGen.Jmp("__If__" ThisIndex "__End")
			Index++
		}
	
		this.CodeGen.Label("__If__" Index)
		this.CodeGen.Label("__If__" ThisIndex "__End")
	}
	
	CompileReturn(Statement) {
		this.Compile(Statement.Expression)
		this.CodeGen.Move_XMM_SIB(XMM0, SIB(8, RSI, RSP))
		this.CodeGen.Pop(RAX)
		this.CodeGen.JMP("__Return")
	}
	
	CompileBinary(Expression) {
		; Thonking time:
		;  To mix types in the middle of an expression, get the result type, cast both operands to that type, and then do the operation with just that type
		
	
		LeftType := this.Compile(Expression.Left)
		RightType := this.Compile(Expression.Right)
		
		this.CodeGen.Pop(RBX)
		this.CodeGen.Pop(RAX)
		
		Try {
			ResultType := this.Typing.ResultType(LeftType, RightType)
		}
		Catch E {
			PrettyError("Compile"
					   ,"The operands of '" Expression.Stringify() "' (" LeftType.Name ", " RightType.Name ") are not compatible."
					   ,""
					   ,Expression.Operator
					   ,this.Tokenizer.CodeString)
		}

		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			this.CodeGen.Cmp(RAX, RBX) ; All comparison operators have a prelude of a CMP instruction
			this.CodeGen.Move(RAX, RSI) ; And a 0-ing of the output register, so the output defaults to false when the MoveCC fails
		}
	
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.CodeGen.Add(RAX, RBX)
			}
			Case Tokens.MINUS: {
				this.CodeGen.Sub(RAX, RBX)
			}
			Case Tokens.TIMES: {
				this.CodeGen.IMul_R64_R64(RAX, RBX)
			}
			Case Tokens.DIVIDE: {
				this.CodeGen.IDiv_RAX_R64(RBX)
			}
			Case Tokens.MOD: {
				this.CodeGen.IDiv_RAX_R64(RBX)
				this.CodeGen.Move(RAX, RDX)
			}
			Case Tokens.EQUAL: {
				this.CodeGen.C_Move_E_R64_R64(RAX, RDI)
			}
			Case Tokens.BANG_EQUAL: {
				this.CodeGen.C_Move_NE_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.C_Move_L_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS_EQUAL: {
				this.CodeGen.C_Move_LE_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER: {
				this.CodeGen.C_Move_G_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER_EQUAL: {
				this.CodeGen.C_Move_GE_R64_R64(RAX, RDI)
			}
			Default: {
				PrettyError("Compile"
						   ,"Operator '" Expression.Operator.Stringify() "' is not implemented in the compiler."
						   ,""
						   ,Expression.Operator
						   ,this.Tokenizer.CodeString)
			}
		}
		
		this.CodeGen.Push(RAX)
	}
	
	CompileGrouping(Expression) {
		for k, v in Expression.Expressions {
			if (k = 1) {
				ResultType := this.Compile(v)
			}
			else {
				this.Compile(v)
				this.CodeGen.Pop(RDX)
			}
		}
		
		return ResultType
	}
	
	CompileCall(Expression) {
		if (Expression.Target.Value = "Deref") {
			return this.CompileDeref(Expression.Params.Expressions)
		}
		else if (Expression.Target.Value = "Put") {
			return this.CompilePut(Expression.Params.Expressions)
		}
		else if (Expression.Target.Value = "Address") {
			return this.GetVariableAddress(Expression.Params.Expressions[1].Value)
		}
		
		PrettyError("Compile"
				   ,"Function '" Expression.Target.Stringify() "' is not callable."
				   ,""
				   ,Expression.Operator
				   ,this.Tokenizer.CodeString
				   ,"Only inbuilt functions are currently callable")
	}
	
	CompileDeref(Params) {
		PointerType := this.Compile(Params[1])
		
		if (PointerType.Name != "Pointer") {
			PrettyError("Compile"
					   ,":Deref requires an operand of type Pointer, not '" PointerType.Name "'."
					   ,"Not a pointer"
					   ,Params[1]
					   ,this.Tokenizer.CodeString)
		}
		
		this.CodeGen.Pop(RCX)
	
		ResultType := this.Typing.GetType(Params[2].Value)
	
		Switch (ResultType.Precision) {
			Case 8: {
				this.CodeGen.MoveSX_R64_RI8(RDX, RCX)
			}
			Case 16: {
				this.CodeGen.MoveSX_R64_RI16(RDX, RCX)
			}
			Case 32: {
				this.CodeGen.MoveSX_R64_RI32(RDX, RCX)
			}
			Case 33: {
				; TODO same as below
			}
			Case 64: {
				this.CodeGen.Move_R64_RI64(RDX, RCX)
			}
			Case 65: {
				; TODO - Implement for more than a test
			}
			Default: {
				Throw, Exception("Un-supported deref type: '" Params[2].Stringify() "'.")
			}
		}
		
		this.CodeGen.Push(RDX)
		return ResultType
	}
	
	CompilePut(Params) {
		PointerType := this.Compile(Params[1])
		
		if (PointerType.Name != "Pointer") {
			PrettyError("Compile"
					   ,":Put requires an operand of type Pointer, not '" PointerType.Name "'."
					   ,"Not a pointer"
					   ,Params[1]
					   ,this.Tokenizer.CodeString)
		}
		
		this.CodeGen.Pop(RCX)
		
		this.Compile(Params[2])
		this.CodeGen.Pop(RDX)
		
		PutType := this.Typing.GetType(Params[3].Value)
		
		Switch (PutType.Precision) {
			Case 8: {
				this.CodeGen.Move_RI8_R64(RCX, RDX)
				this.CodeGen.Push(1)
			}
			Case 16: {
				this.CodeGen.Move_RI16_R64(RCX, RDX)
				this.CodeGen.Push(2)
			}
			Case 32: {
				this.CodeGen.Move_RI32_R64(RCX, RDX)
				this.CodeGen.Push(4)
			}
			Case 64: {
				this.CodeGen.Move_RI64_R64(RCX, RDX)
				this.CodeGen.Push(8)
			}
		}
		
		return this.Typing.GetType("Int64")
	}
}