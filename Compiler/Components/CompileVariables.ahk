	GetVariableSIB(NameToken) {
		Name := NameToken.Value
		
		if (this.Variables.HasKey(Name)) {
			Index := this.Variables[Name]
			
			if (Index = 0) {
				IndexRegister := RSI
			}
			else if (Index = 1) {
				IndexRegister := RDI
			}
			else {
				this.CodeGen.SmallMove(RAX, Index)
				IndexRegister := RAX
			}
			
			return SIB(8, IndexRegister, R15)
		}
		else if (this.Globals.HasKey(Name)) {
			this.CodeGen.Move_R64_Global_Pointer(RAX, Name)
			return SIB(8, RSI, RAX)
		}
		else {
			new Error("Compile")
				.LongText("Undeclared variable.")
				.ShortText("Is not a local, global, or parameter")
				.Token(NameToken)
				.Source(this.Source)
			.Throw()
		}
	}
	SetVariable(NameToken) {
		Name := NameToken.Value
		
		VariableSIB := this.GetVariableSIB(NameToken)
		this.CodeGen.Move_SIB_R64(VariableSIB, this.TopOfRegisterStack())
	}
	GetVariable(NameToken) {
		VariableSIB := this.GetVariableSIB(NameToken)
		
		this.CodeGen.Move_R64_SIB(this.PushRegisterStack(), VariableSIB)
		
		return this.GetVariableType(NameToken)
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
		
		this.CodeGen.Lea(this.PushRegisterStack(), VariableSIB)
	}
	AddVariable(RSPIndex, Name) {
		this.Variables[Name] := RSPIndex
	}