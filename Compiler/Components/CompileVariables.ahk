	GetVariableSIB(NameToken) {
		Switch (NameToken.Type) {
			Case ASTNodeTypes.BINARY: {
				LeftType := this.GetVariableType(NameToken.Left)
				
				this.CodeGen.Lea_R64_SIB(RBX, this.GetVariableSIB(NameToken.Left))
				this.CodeGen.SmallMove(RAX, LeftType.Offsets[NameToken.Right.Value])
				
				return SIB(1, RAX, RBX)
			}
			Case ASTNodeTypes.ARRAYACCESS: {
				TargetType := this.GetVariableType(NameToken.Target)
				
				this.Compile(NameToken.Index)
				this.CodeGen.Lea_R64_SIB(RBX, this.GetVariableSIB(NameToken.Left))
				this.CodeGen.Move(RAX, this.PopRegisterStack())
				
				return SIB(1, RAX, RBX)
			}
		}
	
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
			
			if (this.GetVariableType(NameToken).Family = "Custom") {
				this.CodeGen.Move_R64_SIB(RAX, SIB(8, IndexRegister, R15))
				return SIB(1, RSI, RAX)
			}
			else {
				return SIB(8, IndexRegister, R15)
			}
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
		
		Name := "Move_R" VariableType.Precision "_SIB"
		
		this.CodeGen[Name].Call(this.CodeGen, this.PushRegisterStack(), VariableSIB)
		
		return this.GetVariableType(NameToken)
	}
	GetVariableType(NameToken) {
		Switch (NameToken.Type) {
			Case ASTNodeTypes.BINARY: {
				LeftType := this.GetVariableType(NameToken.Left)
				
				return LeftType.Types[NameToken.Right.Value]
			}
			Case ASTNodeTypes.ARRAYACCESS: {
				return this.GetVariableType(NameToken.Target).Pointer
			}
		}
		
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