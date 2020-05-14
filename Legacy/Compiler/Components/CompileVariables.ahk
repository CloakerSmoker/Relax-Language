	GetVariableSIB(NameToken) {
		Name := NameToken.Value
		
		if (this.Variables.HasKey(Name)) {
			Index := this.Variables[Name]
			Multiplier := 8
			
			if (Index = 0) {
				IndexRegister := RSI
			}
			else if (Index = 1) {
				IndexRegister := RDI
			}
			else {
				this.CodeGen.SmallMove(RAX, Index)
				IndexRegister := RAX
				Multiplier := 1
			}
			
			return SIB(Multiplier, IndexRegister, R15)
		}
		else if (this.Globals.HasKey(Name)) {
			this.CodeGen.Move_R64_Global_Pointer(RAX, Name)
			return SIB(1, RSI, RAX)
		}
		else {
			new Error("Compile")
				.LongText("Undeclared variable.")
				.ShortText("Is not a local, global, or parameter")
				.Token(NameToken)
			.Throw()
		}
	}
	SetVariable(NameToken) {
		VariableType := this.GetVariableType(NameToken)
		VariableSIB := this.GetVariableSIB(NameToken)
		
		Name := "Move_SIB_R" VariableType.Precision
		
		this.CodeGen[Name].Call(this.CodeGen, VariableSIB, this.TopOfRegisterStack())
	}
	GetVariable(NameToken) {
		VariableType := this.GetVariableType(NameToken)
		VariableSIB := this.GetVariableSIB(NameToken)
		
		if (VariableType.Family = "Custom") {
			this.CodeGen.Lea_R64_SIB(this.PushRegisterStack(), VariableSIB)
		}
		else {
			TargetRegister := this.PushRegisterStack()
			
			if (VariableType.Precision <= 16) {
				this.CodeGen.SmallMove(TargetRegister, 0)
			}
			
			Name := "Move_R" VariableType.Precision "_SIB"
			
			this.CodeGen[Name].Call(this.CodeGen, TargetRegister, VariableSIB)	
		}
		
		return VariableType
	}
	GetVariableType(NameToken) {
		Name := NameToken.Value
		
		if (this.Globals.HasKey(Name)) {
			return this.Typing.GetType(this.Globals[Name].Type)
		}
		else {
			try {
				return this.Typing.GetVariableType(Name)
			}
			catch {
				new Error("Compile")
					.LongText("Undeclared variable.")
					.ShortText("Is not a local, global, or parameter")
					.Token(NameToken)
					.Source(this.Source)
				.Throw()
			}
		}
	}
	GetVariableAddress(NameToken) {
		VariableSIB := this.GetVariableSIB(NameToken)
		
		this.CodeGen.Lea_R64_SIB(this.PushRegisterStack(), VariableSIB)
	}
	AddVariable(RSPIndex, Name) {
		this.Variables[Name] := RSPIndex
	}
	
	
	GetStructField(Expression) {
		if (this.CustomTypes.HasKey(Expression.Left.Value) && Expression.Right.Value = "Size") {
			this.CodeGen.Move_R64_I32(this.PushRegisterStack(), I32(this.CustomTypes[Expression.Left.Value].Size))
			return this.Typing.GetType("i32")
		}
		
		
		StructType := this.GetStructFieldPointer(Expression)
		FieldName := Expression.Right.Value
		
		TargetRegister := this.TopOfRegisterStack()
		TargetSize := StructType.Types[FieldName].Precision
		
		Name := "Move_R64_RI" TargetSize
		
		if (TargetSize < 32) {
			this.CodeGen.SmallMove(RAX, 0)
		}
		
		this.CodeGen[Name].Call(this.CodeGen, RAX, TargetRegister)
		
		this.CodeGen.Move(TargetRegister, RAX)
		
		return StructType.Types[FieldName]
	}
	SetSturctField(Expression) {
		StructType := this.GetStructFieldPointer(Expression)
		FieldName := Expression.Right.Value
		
		TargetRegister := this.PopRegisterStack()
		
		Name := "Move_RI" StructType.Types[FieldName].Precision "_R64"
		
		this.CodeGen[Name].Call(this.CodeGen, TargetRegister, this.TopOfRegisterStack())
		
		return StructType.Types[FieldName]
	}
	
	GetStructFieldSIB(Expression) {
		this.GetStructFieldPointer()
		this.CodeGen.Move(RAX, this.TopOfRegisterStack())
		this.PopRegisterStack()
		
		return SIB(1, RSI, RAX)
	}
	GetStructFieldPointer(Expression, ReturnFieldType := False) {
		StructType := this.Compile(Expression.Left)
		FieldName := Expression.Right.Value
		
		if (Expression.Operator.Type = Tokens.MINUS_GREATER) {
			if (StructType.Family != "Pointer") {
				new Error("Compile")
					.LongText("Left side operands of '->' must be struct pointer types")
					.ShortText("Not a struct pointer")
					.Token(Expression.Left)
				.Throw()
			}
			
			StructType := StructType.Pointer
		}
		else if (Expression.Operator.Type = Tokens.DOT) {
			if (StructType.Family != "Custom") {
				new Error("Compile")
					.LongText("Left side operands of '.' must be struct types")
					.ShortText("Not a struct")
					.Token(Expression.Left)
				.Throw()
			}
		}
		else {
			new Error("Compile")
				.LongText("Struct access expected")
				.Token(Expression.Left)
			.Throw()
		}
		
		if !(StructType.Offsets.HasKey(FieldName)) {
			new Error("Compile")
				.LongText("Unknown struct member.")
				.Token(Expression.Right)
			.Throw()
		}
		
		TargetRegister := this.TopOfRegisterStack()
		this.CodeGen.SmallAdd(TargetRegister, StructType.Offsets[FieldName])
		
		if (ReturnFieldType) {
			return StructType.Types[FieldName]
		}
		else {
			return StructType
		}
	}