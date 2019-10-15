class Parser {
	__New(Tokenizer) {
		this.Tokens := Tokenizer.Tokens
		this.Source := Tokenizer.CodeString
	
		this.Index := 0
	}
	Next() {
		return this.Tokens[++this.Index]
	}
	Previous() {
		return this.Tokens[this.Index]
	}
	Consume(Type, Reason) {
		if !(this.NextMatches(Type)) {
			MsgBox, % Reason
		}
	}
	NextMatches(Types*) {
		for k, Type in Types {
			if (this.Check(Type)) {
				this.Next()
				return True
			}
		}
		
		return False
	}
	Check(Type) {
		return this.Peek().Type = Type
	}
	Peek(Count := 1) {
		if (this.Index + Count > this.Tokens.Count()) {
			return false
		}
		
		return this.Tokens[this.Index + Count]
	}
	AtEOF() {
		return this.Peek().Type = Tokens.EOF
	}
	Start() {
		return this.ParseProgram()
	}
	ParseProgram() {
		Statements := []
	
		while !(this.AtEOF()) {
			NextStatement := this.ParseStatement()
			Statements.Push(NextStatement)
		}
		
		return Statements
	}
	ParseStatement() {
		Next := this.Peek()
	
		if (Next.Type = Tokens.KEYWORD) {
			return this.ParseKeywordStatement()
		}
		else if (Next.Type = Tokens.IDENIFIER && this.Peek(2).Type = Tokens.COLON) {
			return this.ParseDeclaration() ; TODO - Implement this
		}
		else {
			return this.ParseExpressionStatement() ; TODO - Implement this
		}
	}
	ParseKeywordStatement() {
		NextKeyword := this.Next().Value
		
		switch (NextKeyword) {
			case Keywords.DEFINE: {
				this.ParseDefine()
			}
			; TODO - Add the rest of the keywords
		}
	}
	ParseDefine() {
		ReturnType := this.ParsePrimary()
		
		if (ReturnType.Type != ASTNodeTypes.IDENIFIER) {
			MsgBox, % "Invalid function definition return type " ASTNodeTypes[ReturnType.Type]
		}
		
		Name := this.ParsePrimary()
		
		if (Name.Type != ASTNodeTypes.IDENIFIER) {
			MsgBox, % "Invalid function definition name type " ASTNodeTypes[Name.Type]
		}
		
		Params := this.ParsePrimary() ; TODO - This is supposed to return a grouping, but since
		; ParseExpression does not exist, it returns a broken one
		
		if (Params.Type != ASTNodeTypes.GROUPING) {
			MsgBox, % "Invalid function definition parameter group type " ASTNodeTypes[Params.Type]
		}
		
		; TODO - Parse the body of the definition
		Body := this.ParseBlock()
		
		if (Body.Type != ASTNodeTypes.BLOCK) {
			MsgBox, % "Invalid function definition body type " ASTNodeTypes[Params.Type]
		}
		
		return new ASTNodes.Statements.Define(ReturnType, Name, Params, Body)
	}
	
	ParseExpression(Terminators*) {
		if !IsObject(Terminators) {
			Terminators := [Tokens.NEWLINE]
		}
	
	
		return ExpressionParser := this.ExpressionParser(Terminators)
	}
	AddNode(OperandStack, Operators, Operator) {
		Right := OperandStack.Pop()
		Left := OperandStack.Pop()
		
		if !(Left && Right) {
			MsgBox, % "Missing Operand for " Tokens[Operator.Value] " around " Operator.Context.Start "-"  Operator.Context.End
		}
		else if !(Operand) {
			MsgBox, % "Missing Operator for " Tokens[Left.Value] " around " Operator.Context.Start "-"  Operator.Context.End
		}
		
		OperandStack.Push(new ASTNodes.Expressions.Binary(Left, Operator, Right))
	}
	
	ExpressionParser(Terminators) {
		OperandStack := []
		OperatorStack := []
	
		loop {
			Next := this.Next()
		
			Switch (Next.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.IDENIFIER: {
					OperandStack.Push(Next)
				}
				Case Tokens.LEFT_PAREN: {
					if (this.Previous().Type != Tokens.Operator) {
						this.Index--
						Params := this.ParseGrouping()
						OperandStack.Push(new ASTNodes.Expressions.Call(OperandStack.Pop(), Params))
					}
					else {
						OperatorStack.Push(Next)
					}
				}
				Case Tokens.RIGHT_PAREN: {
					while (OperatorStack.Count()) {
						NextOperator := OperatorStack.Pop()
					
						if (NextOperator.Type = Tokens.LEFT_PAREN) {
							Continue, 2
						}
						else {
							this.AddNode(OperandStack, OperatorStack, NextOperator)
						}
					}
					
					MsgBox, % "Unbalenced parens"
				}
				Case Tokens.OPERATOR: {
					Operator := Next
					
					while (OperatorStack.Count() != 0) {
						NextOperator := OperatorStack.Pop()
						
						if (NextOperator.Type = Tokens.OPERATOR && Operators.CheckPrecedence(Operator, NextOperator)) {
							this.AddNode(OperandStack, OperatorStack, NextOperator)
						}
						else {
							OperatorStack.Push(NextOperator)
							Break
						}
					}
					
					OperatorStack.Push(Operator)
				}
				Default: {
					Break
				}
			}
			
			for k, Terminator in Terminators {
				if (this.Check(Terminator)) {
					Break, 2
				}
			}
		}
		
		while (OperatorStack.Count()) {
			this.AddNode(OperandStack, OperatorStack, OperatorStack.Pop())
		}
		
		return OperandStack
	}
	
	ParsePrimary() {
		Next := this.Next()
	
		Switch (Next.Value) {
			Case Tokens.IDENIFIER: {
				return new ASTNodes.Expressions.Identifier(this.Previous())
			}
			Case Tokens.INTEGER: {
				return new ASTNodes.Expressions.IntegerLiteral(this.Previous())
			}
			Case Tokens.DOUBLE: {
				return new ASTNodes.Expressions.DoubleLiteral(this.Previous())
			}
			Case Tokens.LEFT_PAREN: {
				this.Index--
				return this.ParseGrouping()
			}
			Default: {
				MsgBox, % "Unexpected token " Next.Context.Start "-" Next.Context.End
			}
		}
	}
	
	ParseGrouping() {
		if (this.NextMatches(Tokens.LEFT_PAREN)) {
			Expressions := [this.ParseExpression(Tokens.COMMA, Tokens.RIGHT_PAREN)]
			
			while (this.NextMatches(Tokens.COMMA)) {
				Expressions.Push(this.ParseExpression())
			}
			
			this.Consume(Tokens.RIGHT_PAREN, "Expression groupings must have a closing paren")
			
			return new ASTNodes.Expressions.Grouping(Expressions)
		}
	}
}