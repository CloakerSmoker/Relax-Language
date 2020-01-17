	CompileExpressionLine(Statement) {
		this.Compile(Statement.Expression)
		this.PopRegisterStack()
	}
	
	CompileIfGroup(Statement) {
		static Index := 0
		
		IfCount := Statement.Options.Count()
		
		if (IfCount = 1 && Statement.Options[1].Value >= 1) {
			; If the if group only has one expression, and the one expression has a constant truthy result
			;  We can just compile the body, and skip the branching
			
			for k, Line in Statement.Options[1] {
				this.Compile(Line)
			}
			
			return
		}
		
		ThisIndex := Index++
		
		for k, ElseIf in Statement.Options {
			this.CodeGen.Label("__If__" Index)
			
			if (k != IfCount) {
				; If this is the last else if, don't bother with the condition, since it is pretty much just 'else'
			
				this.Compile(ElseIf.Condition)
				
				ResultRegister := this.PopRegisterStack()
				
				this.CodeGen.Cmp(ResultRegister, RSI)
				this.CodeGen.JE("__If__" Index + 1)
			}
			
			for k, Line in ElseIf.Body {
				this.Compile(Line)
			}
			
			this.CodeGen.Jmp("__If__" ThisIndex "__End")
			Index++
		}
	
		this.CodeGen.Label("__If__" Index)
		this.CodeGen.Label("__If__" ThisIndex "__End")
	}
	
	CompileForLoop(Statement) {
		static Index := 0
		
		ThisIndex := Index++
		
		this.Compile(Statement.Init) ; Run the init first
		this.PopRegisterStack() ; And discard the result
		
		this.CodeGen.Label("__For__" ThisIndex)
		
		this.Compile(Statement.Condition) ; Check the condition
		ConditionRegister := this.PopRegisterStack() ; Store the result
		
		this.CodeGen.Cmp(ConditionRegister, RSI) ; If the condition is already false, then jump out
		this.CodeGen.JE("__For__" ThisIndex "__End")
		
		for k, Line in Statement.Body {
			this.Compile(Line)
		}
		
		this.Compile(Statement.Step) ; After the body runs, run the step
		this.PopRegisterStack() ; And discard the result
		
		this.CodeGen.Jmp("__For__" ThisIndex) ; Then jump back to the top (where the condition is checked)
		
		this.CodeGen.Label("__For__" ThisIndex "__End")
	}
	
	CompileReturn(Statement) {
		this.HasReturn := True
		
		ResultType := this.Compile(Statement.Expression)
		ReturnType := this.Typing.GetType(this.Function.ReturnType.Value)
		
		if (ResultType.Family != ReturnType.Family || ResultType.Precision > ReturnType.Precision) {
			new Error("Type")
				.LongText("Wrong return type, should be " ReturnType.Name " or smaller.")
				.Token(Statement.Expression)
				.Source(this.Source)
			.Throw()
		}
		
		ResultRegister := this.PopRegisterStack()
		
		if (ResultType.Family = "Decimal") {
			this.CodeGen.Push(ResultRegister)
			this.CodeGen.Move_XMM_SIB(XMM0, SIB(8, RSI, RSP))
			this.CodeGen.Pop(ResultRegister)
		}
		else if (ResultType.Family = "Integer" || ResultType.Family = "Pointer") {
			if (ResultRegister.__Class != "RAX") {
				this.CodeGen.Move(RAX, ResultRegister)
			}
		}
		
		this.CodeGen.JMP("__Return" this.FunctionIndex)
	}