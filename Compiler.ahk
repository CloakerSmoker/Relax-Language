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
		Type := this.Typing.GetVariableType(Name)
	
		this.CodeGen.Push(SIB(8, IndexRegister, R15))
		
		return Type
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
			Case Tokens.DOUBLE: {
				this.CodeGen.Push(FloatToBinaryInt(TargetToken.Value))				
				return this.Typing.GetType("Double")
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
	
	CompileProgram(Program) {
		this.FunctionIndex := 0
		this.CodeGen := new X64CodeGen()
		Current := this.CurrentProgram := {"Node": Program, "FunctionOffsets": {}}
		FunctionOffset := 0
		
		for FunctionName, FunctionDefine in Program.Functions {
			Current.FunctionOffsets[FunctionName] := FunctionOffset
			this.Compile(FunctionDefine) ; Compile a function starting from FunctionOffset
			FunctionOffset := this.CodeGen.Index() ; And store the new offset for the next function
		}
		
		return new CompiledProgram(Program, this.CodeGen, Current.FunctionOffsets)
	}
	
	CompileDefine(DefineAST) {
		this.FunctionIndex++
		this.Variables := {}
		; TODO - Add type checking (Duh) and type check .ReturnType against Int64/EAX
		ParamSizes := DefineAST.Params.Count()
		CG := this.CodeGen
		
		for LocalName, LocalType in DefineAST.Locals {
			this.AddVariable(ParamSizes++, LocalName)
			this.Typing.AddVariable(LocalType, LocalName)
		}
		
		;CG.Label(DefineAST.Name.Value)
		CG.Push(RBP)
		CG.Move(RBP, RSP)
			if (ParamSizes != 0) {
				CG.Sub(RSP, ParamSizes * 8)
				CG.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			CG.SmallMove(RSI, 0)
			CG.SmallMove(RDI, 1)
			
			this.FunctionParameters(DefineAST.Params)
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
		CG.Label("__Return" this.FunctionIndex)
		
		if (ParamSizes != 0) {
			CG.Add(RSP, ParamSizes * 8)
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
	
	CompileExpressionLine(Statement) {
		this.Compile(Statement.Expression)
		this.CodeGen.Pop(RAX)
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
		this.CodeGen.JMP("__Return" this.FunctionIndex)
	}
	
	CompileBinary(Expression) {
		; Thonking time:
		;  To mix types in the middle of an expression, get the result type, cast both operands to that type, and then do the operation with just that type
		
		IsAssignment := OperatorClasses.IsClass(Expression.Operator, "Assignment")
		
		if (IsAssignment) {
			RightType := this.Compile(Expression.Right)
			LeftType := this.Typing.GetVariableType(Expression.Left.Value)
		}
		else {
			LeftType := this.Compile(Expression.Left)
			RightType := this.Compile(Expression.Right)
		}
		
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
		
		if (IsAssignment) {
			return this.CompileTypeAssignment(ResultType, Expression, LeftType, RightType)
		}
		else {
			return this.CompileTypeExpression(ResultType, Expression, LeftType, RightType, ResultType) ; TODO: Remove duplicate param
		}
	}
	
	CompileTypeAssignment(Type, Expression, VariableType, RightType) {
		if (Mod(VariableType.Precision, 8) != Mod(RightType.Precision, 8)) {
			PrettyError("Type"
					   ,"The type " RightType.Name " is not a valid right side operand type for assigning a variable of type " VariableType.Name " ."
					   ,""
					   ,Expression.Operator
					   ,this.Tokenizer.CodeString)
		}
		
		this.CodeGen.Pop(RBX)
		this.GetVariableAddress(Expression.Left.Value)
		this.CodeGen.Pop(RAX)
	
		if (Type.Name = "Double") {
			this.CompileDoubleAssignment(Expression, VariableType, RightType)
		}
		else {
			this.CompileInt64Assignment(Expression, VariableType, RightType)
		}
		
		this.CodeGen.Push(RBX)
		
		return RightType
	}
	
	CompileTypeExpression(Type, Params*) {
		if (Type.Name = "Double") {
			return this.CompileBinaryDouble(Params*)
		}
		else {
			return this.CompileBinaryInt64(Params*)
		}
	}
	
	CompileDoubleAssignment(Expression, VariableType, RightType) {
		Switch (Expression.Operator.Type) {
			Case Tokens.COLON_EQUAL: {
				this.CodeGen.Move_RI64_R64(RAX, RBX)
			}
		}
	}
	
	CompileInt64Assignment(Expression, VariableType, RightType) {
		Switch (Expression.Operator.Type) {
			Case Tokens.COLON_EQUAL: {
				this.CodeGen.Move_RI64_R64(RAX, RBX)
			}
		}
	}
	
	CompileBinaryDouble(Expression, LeftType, RightType, ResultType) {
		this.Cast(RightType, ResultType)
		this.CodeGen.FLD_Stack()
		this.CodeGen.Pop(RBX)
		
		this.Cast(LeftType, ResultType)
		this.CodeGen.FLD_Stack()
		this.CodeGen.Pop(RAX)
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			this.CodeGen.Cmp(RAX, RBX) ; Comparisons are done as integers, since x87 equality checks are a nightmare
		}
	
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.CodeGen.FAddP()
			}
			Case Tokens.MINUS: {
				this.CodeGen.FSubP()
			}
			Case Tokens.TIMES: {
				this.CodeGen.FMulP()
			}
			Case Tokens.DIVIDE: {
				this.CodeGen.FDivP()
			}
			Case Tokens.EQUAL: {
				this.CodeGen.C_Move_E_R64_R64(RAX, RDI)
			}
			Case Tokens.BANG_EQUAL: {
				this.CodeGen.C_Move_NE_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.C_Move_L_R64_R64(RAX, RDI) ; WARNING, ALL COMPARISIONS BELOW HERE MIGHT BE WRONG. Since floats are just used as ints for the comparisons
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
						   ,"Operator '" Expression.Operator.Stringify() "' is not implemented in the dblbin compiler."
						   ,""
						   ,Expression.Operator
						   ,this.Tokenizer.CodeString)
			}
		}
		
		this.CodeGen.Push(RAX)
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			ResultType := this.Typing.GetType("Int8")
		}
		else {
			this.CodeGen.FSTP_Stack() ; Use the stack space from pushing RAX to store the actual result
		}
		
		return ResultType
	}
	
	CompileBinaryInt64(Expression, LeftType, RightType, ResultType) {
		this.Cast(RightType, ResultType)
		this.CodeGen.Pop(RBX)
	
		this.Cast(LeftType, ResultType)
		this.CodeGen.Pop(RAX)
	
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
						   ,"Operator '" Expression.Operator.Stringify() "' is not implemented in the intbin compiler."
						   ,""
						   ,Expression.Operator
						   ,this.Tokenizer.CodeString)
			}
		}
		
		this.CodeGen.Push(RAX)
		return ResultType
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
	
	
	Cast(TypeOne, TypeTwo, StackLess := False) {
		if (TypeOne.Name = TypeTwo.Name) {
			return
		}
	
		; Parameter should be on the stack
		; RAX is the only register used for casts
		; StackLess param is for when the operand is already in RAX, otherwise RAX is loaded with the first thing on the stack
		
		if !(StackLess) {
			this.CodeGen.Pop(RAX)
		}
		
		Base := ObjGetBase(this)
		Path := this.Typing.CastPath(TypeOne, TypeTwo)
		
		for k, v in Path {
			if !(Path[k + 1]) {
				Break
			}
		
			Name := "Cast_" IntToI(v) "_" IntToI(Path[k + 1])
		
			if (Base.HasKey(Name)) {
				Base[Name].Call(this)
			}
			else {
				Throw, Exception("Invalid cast: " Name)
			}
		}
		
		if !(StackLess) {
			this.CodeGen.Push(RAX)
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
		this.Cast(this.Typing.GetType("Int8"), this.Typing.GetType("Int64"), True)
	}
	
	
	Cast_I64_Pointer() {
		return ; Lmao
	}
	Cast_Pointer_I64() {
		return ; These are some really useful casts
	}
	
	
	Cast_I64_Double() {
		this.CodeGen.Push(RAX)
		this.CodeGen.FILD_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(RAX)
	}
	Cast_Double_I64() {
		this.CodeGen.Push(RAX)
		this.CodeGen.FISTP_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(RAX)
	}
	
	Cast_I32_Float() {
	
	}
	Cast_Float_I32() {
		
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