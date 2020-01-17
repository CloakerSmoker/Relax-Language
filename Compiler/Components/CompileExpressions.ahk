﻿	CompileBinary(Expression) {
		if (Expression.Operator.Type = Tokens.TIMES_EQUAL) {
			return this.CompileDerefAssign(Expression)
		}
	
		IsAssignment := OperatorClasses.IsClass(Expression.Operator, "Assignment")
		IsBitwise := OperatorClasses.IsClass(Expression.Operator, "Bitwise")
		
		if (IsAssignment) {
			RightType := this.Compile(Expression.Right)
			LeftType := this.GetVariableType(Expression.Left)
		}
		else {
			LeftType := this.Compile(Expression.Left)
			RightType := this.Compile(Expression.Right)
		}
		
		Try {
			ResultType := this.Typing.ResultType(LeftType, RightType)
			
			if (IsAssignment && (Mod(LeftType.Precision, 8) != Mod(RightType.Precision, 8) || (LeftType.Precision < RightType.Precision))) {
				Throw, Exception("Dummy exception")
			}
		}
		catch {
			new Error("Type")
				.LongText("The operands of '" Expression.Stringify() "' (" LeftType.Name ", " RightType.Name ") are not compatible.")
				.Token(Expression.Operator)
				.Source(this.Source)
			.Throw()
		}
		
		if (IsAssignment) {
			if (ResultType.Family = "Decimal" && Expression.Operator.Type = Tokens.COLON_EQUAL) {
				this.SetVariable(Expression.Left)
				return RightType
			}
			else if (ResultType.Family = "Integer" || ResultType.Family = "Pointer") {
				return this.CompileIntegerAssignment(Expression, LeftType, RightType)
			}
			else {
				new Error("Compile")
					.LongText("Assigning a " LeftType.Name " with the " Expression.Operator.Value " operator is not implemented.")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
		}
		else {
			if (IsBitwise) {
				return this.CompileBinaryBitwise(Expression, LeftType, RightType, ResultType)
			}
			else if (ResultType.Family = "Decimal") {
				return this.CompileBinaryDecimal(Expression, LeftType, RightType, ResultType)
			}
			else if (ResultType.Family = "Integer" || ResultType.Family = "Pointer") {
				return this.CompileBinaryInteger(Expression, LeftType, RightType, ResultType)
			}
		}
	}
	CompileIntegerAssignment(Expression, VariableType, RightType) {
		Switch (Expression.Operator.Type) {
			Case Tokens.COLON_EQUAL: {
				this.SetVariable(Expression.Left)
			}
			Case Tokens.PLUS_EQUAL, Tokens.MINUS_EQUAL: {
				this.GetVariable(Expression.Left) ; Get the current value of the variable
				VariableValueRegister := this.PopRegisterStack() ; And the register holding it
				ValueRegister := this.PopRegisterStack() ; Then the value of the right side expression
				
				if (Expression.Operator.Type = Tokens.PLUS_EQUAL) {
					this.CodeGen.Add(VariableValueRegister, ValueRegister) ; For += add the two
				}
				else if (Expression.Operator.Type = Tokens.MINUS_EQUAL) {
					this.CodeGen.Sub(VariableValueRegister, ValueRegister) ; -= subtract
				}
				
				this.CodeGen.Move(this.PushRegisterStack(), VariableValueRegister) ; Store the result back onto the stack
				this.SetVariable(Expression.Left) ; And set the variable using the top of stack
			}
		}
		
		return this.GetVariableType(Expression.Left)
	}
	
	CompileBinaryBitwise(Expression, LeftType, RightType, ResultType) {
		this.Cast(RightType, ResultType)
		RightRegister := this.PopRegisterStack()
		
		this.Cast(LeftType, ResultType)
		LeftRegister := this.PopRegisterStack()
		
		ResultRegister := this.PushRegisterStack()
		
		Switch (Expression.Operator.Type) {
			Case Tokens.BITWISE_AND: {
				this.CodeGen.And_R64_R64(LeftRegister, RightRegister)
			}
			Case Tokens.BITWISE_OR: {
				this.CodeGen.Or_R64_R64(LeftRegister, RightRegister)
			}
			Case Tokens.BITWISE_XOR: {
				this.CodeGen.XOR_R64_R64(LeftRegister, RightRegister)
			}
		}
		
		this.CodeGen.Move(ResultRegister, LeftRegister)
		
		return ResultType
	}
	
	CompileBinaryDecimal(Expression, LeftType, RightType, ResultType) {
		; Since the operands are in the register stack somewhere, and we need them in the X87 register stack
		;  we push them onto the real stack, and load them from there
		
		this.Cast(RightType, ResultType)
		
		LeftRegister := this.PopRegisterStack()
		this.CodeGen.Push_R64(LeftRegister), this.StackDepth++
		this.CodeGen.FLD_Stack()
		this.CodeGen.Pop(LeftRegister), this.StackDepth--
		
		this.Cast(LeftType, ResultType)
		
		RightRegister := this.PopRegisterStack()
		this.CodeGen.Push_R64(RightRegister), this.StackDepth++
		this.CodeGen.FLD_Stack()
		this.CodeGen.Pop(RightRegister), this.StackDepth--
		
		ResultRegister := this.PushRegisterStack()
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			this.CodeGen.Move(ResultRegister, RSI) ; For comparisons, zero the result register, and compare the operands
			this.CodeGen.FComiP()
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
				this.CodeGen.F_C_Move_E_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.BANG_EQUAL: {
				this.CodeGen.F_C_Move_NE_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.F_C_Move_L_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.LESS_EQUAL: {
				this.CodeGen.F_C_Move_LE_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.GREATER: {
				this.CodeGen.F_C_Move_G_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.GREATER_EQUAL: {
				this.CodeGen.F_C_Move_GE_R64_R64(ResultRegister, RDI)
			}
			Default: {
				new Error("Compile")
					.LongText("Floating-point operator '" Expression.Operator.Stringify() "' is not implemented in the compiler.")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
		}
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			; For comparisons, the result was already CMove'd into the result register, so no need to pop it
			ResultType := this.Typing.GetType("Int64")
		}
		else {
			this.CodeGen.Push(ResultRegister)
			this.CodeGen.FSTP_Stack()
			this.CodeGen.Pop(ResultRegister)
		}
		
		return ResultType
	}
	
	CompileBinaryInteger(Expression, LeftType, RightType, ResultType) {		
		this.Cast(RightType, ResultType)
		RightRegister := this.PopRegisterStack()
		
		this.Cast(LeftType, ResultType)
		LeftRegister := this.PopRegisterStack()
		
		ResultRegister := this.PushRegisterStack()
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			this.CodeGen.Cmp(LeftRegister, RightRegister) ; All comparison operators have a prelude of a CMP instruction
			this.CodeGen.Move(ResultRegister, RSI) ; And a 0-ing of the output register, so the output defaults to false when the MoveCC fails
			
			ResultType := this.Typing.GetType("Int64")
		}
		else if (OperatorClasses.IsClass(Expression.Operator, "Division")) {
			this.CodeGen.Push(RDX)
			this.CodeGen.Move(RAX, LeftRegister)
		}
	
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.CodeGen.Add(LeftRegister, RightRegister)
			}
			Case Tokens.MINUS: {
				this.CodeGen.Sub(LeftRegister, RightRegister)
			}
			Case Tokens.TIMES: {
				this.CodeGen.IMul_R64_R64(LeftRegister, RightRegister)
			}
			Case Tokens.DIVIDE: {
				this.CodeGen.IDiv_RAX_R64(RightRegister)
				this.CodeGen.Move(ResultRegister, RAX)
			}
			Case Tokens.MOD: {
				this.CodeGen.IDiv_RAX_R64(RightRegister)
				this.CodeGen.Move(ResultRegister, RDX)
			}
			Case Tokens.EQUAL: {
				this.CodeGen.C_Move_E_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.BANG_EQUAL: {
				this.CodeGen.C_Move_NE_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.C_Move_L_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.LESS_EQUAL: {
				this.CodeGen.C_Move_LE_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.GREATER: {
				this.CodeGen.C_Move_G_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.GREATER_EQUAL: {
				this.CodeGen.C_Move_GE_R64_R64(ResultRegister, RDI)
			}
			Case Tokens.LOGICAL_AND: {
				this.CodeGen.And_R64_R64(ResultRegister, RBX)
			}
			Case Tokens.LOGICAL_OR: {
				this.CodeGen.Or_R64_R64(ResultRegister, RBX)
			}
			Default: {
				new Error("Compile")
					.LongText("Integer operator '" Expression.Operator.Stringify() "' is not implemented in the compiler.")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
		}
		
		if (OperatorClasses.IsClass(Expression.Operator, "Division")) {
			this.CodeGen.Pop(RDX)
		}
		
		;this.CodeGen.Push(RAX), this.StackDepth++
		return ResultType
	}
	
	;========================
	; Unary/grouping expression methods
	
	CompileUnary(Expression) {
		Operator := Expression.Operator
		OperatorString := Operator.Stringify()
		
		if (OperatorString = "--" || OperatorString = "++") {
			VariableSIB := this.GetVariableSIB(Expression.Operand)
			
			Switch (Operator.Type) {
				Case Tokens.PLUS_PLUS_L: {
					this.CodeGen.Inc_SIB(VariableSIB)
					this.GetVariable(Expression.Operand)
				}
				Case Tokens.PLUS_PLUS_R: {
					this.GetVariable(Expression.Operand)
					this.CodeGen.Inc_SIB(VariableSIB)
				}
				Case Tokens.MINUS_MINUS_L: {
					this.CodeGen.Dec_SIB(VariableSIB)
					this.GetVariable(Expression.Operand)
				}
				Case Tokens.MINUS_MINUS_R: {
					this.GetVariable(Expression.Operand)
					this.CodeGen.Dec_SIB(VariableSIB)
				}
			}
			
			return this.GetVariableType(Expression.Operand)
		}
		else if (Operator.Type = Tokens.DEREF) {
			OperandType := this.Compile(Expression.Operand)
			
			if !(OperandType.Pointer) {
				new Error("Type")
					.LongText("Unary operator '*' requires an operand of a pointer type, not (" OperandType.Name ").")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
			
			OperandResultRegister := this.TopOfRegisterStack()
			
			Switch (OperandType.Pointer.Precision) {
				Case 8: {
					this.CodeGen.Move_R64_RI8(OperandResultRegister, OperandResultRegister)
				}
				Case 16: {
					this.CodeGen.Move_R64_RI16(OperandResultRegister, OperandResultRegister)
				}
				Case 32: {
					this.CodeGen.Move_R64_RI32(OperandResultRegister, OperandResultRegister)
				}
				Case 64: {
					this.CodeGen.Move_R64_RI64(OperandResultRegister, OperandResultRegister)
				}
			}
			
			return OperandType.Pointer
		}
		else if (Operator.Type = Tokens.ADDRESS) {
			if (Function := this.Program.Functions[Expression.Operand.Value]) {
				this.CodeGen.Move_R64_RIP(RAX)
				this.CodeGen.Move_R64_I32_LabelOffset(RBX, "__Define__" Function.Name.Value)
				this.CodeGen.Add(RAX, RBX)
				
				this.CodeGen.SmallMove(RBX, 6)
				this.CodeGen.Add(RAX, RBX)
				
				this.CodeGen.Move(this.PushRegisterStack(), RAX)
				
				return this.Typing.GetType("void*")
			}
			else {
				this.GetVariableAddress(Expression.Operand)
				return this.Typing.GetPointerType(this.GetVariableType(Expression.Operand))
			}
		}
		else if (Operator.Type = Tokens.NEGATE) {
			OperandType := this.Compile(Expression.Operand)
		
			this.CodeGen.Neg_R64(this.TopOfRegisterStack())
			return OperandType
		}
		
		new Error("Compile")
			.LongText("Unary operator " OperatorString " is not implemented in the compiler.")
			.ShortText("<")
			.Token(Operator)
			.Source(this.Source)
		.Throw()
	}
	
	CompileGrouping(Expression) {
		for k, v in Expression.Expressions {
			if (k = 1) {
				ResultType := this.Compile(v)
			}
			else {
				this.Compile(v)
				this.PopRegisterStack()
			}
		}
		
		return ResultType
	}
	
	CompileDerefAssign(Expression) {
		LeftType := this.Compile(Expression.Left)
		
		if !(InStr(LeftType.Name, "*")) {
			new Error("Type")
				.LongText("The left operand of '" Expression.Stringify() "' (" LeftType.Name ") must be a pointer type.")
				.Token(Expression.Left)
				.Source(this.Source)
			.Throw()
		}
		
		RightType := this.Compile(Expression.Right)
		
		LeftValueType := this.Typing.GetType(StrReplace(LeftType.Name, "*"))
		this.Cast(RightType, LeftValueType) ; Cast the right side value to the type the left side points to

		NewValueRegister := this.PopRegisterStack()
		PointerRegister := this.PopRegisterStack()
		
		ShortTypeName := IntToI(LeftValueType.Name)
		
		this.CodeGen["Move_R" ShortTypeName "_R64"].Call(this.CodeGen, PointerRegister, NewValueRegister)
		
		this.CodeGen.Move(this.PushRegisterStack(), NewValueRegister)
		
		return RightType
	}