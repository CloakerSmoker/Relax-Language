class Parser {
	static ExpressionTests := {"A + B + C": "((A + B) + C)"
							,  "A == B == C": "((A == B) == C)"
							,  "A := B := 1": "(A := (B := 1))"
							,  "1 + 2 - 3 * 4 / 5 == 6 := 7": "((((1 + 2) - ((3 * 4) / 5)) == 6) := 7)"
							,  "0xFF == 0o377 == 0b11111111 == 255": "(((255 == 255) == 255) == 255)"}

	static _ := Parser.Tests()
	
	Tests() {
		if (VAL.DEBUG) {
			this.RunTests()
		}
	}
	RunTests() {
		for Input, Output in Parser.ExpressionTests {
			Lex := new Lexer(Input)
			Tok := Lex.Start()
			
			Par := new Parser(Lex)
			ParAST := Par.ParseExpression()
			
			Assert.String.True(ParAST.Stringify(), Output)
		}
	}

	__New(Tokenizer) {
		this.Tokens := Tokenizer.Tokens
		this.Source := Tokenizer.CodeString
	
		this.Index := 0
	}
	Next() {
		return this.Tokens[++this.Index]
	}
	Current() {
		return this.Tokens[this.Index]
	}
	Previous() {
		return this.Tokens[this.Index - 1]
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
	Ignore(Type) {
		if (this.Check(Type)) {
			this.Next()
		}
		
		return true
	}
	Peek(Count := 1) {
		if (this.Index + Count > this.Tokens.Count()) {
			return false
		}
		
		return this.Tokens[this.Index + Count]
	}
	AtEOF() {
		return (this.Peek().Type = Tokens.EOF)
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
		else if (Next.Type = Tokens.IDENTIFIER && this.Peek().Type = Tokens.COLON) {
			return this.ParseDeclaration() ; TODO - Implement this
		}
		else {
			return this.ParseExpressionStatement()
		}
	}
	ParseKeywordStatement() {
		NextKeyword := this.Next().Value
		
		Switch (NextKeyword) {
			Case Keywords.DEFINE: {
				return this.ParseDefine()
			}
			Case Keywords.RETURN: {
				return new ASTNodes.Statements.Return(this.ParseExpressionStatement().Expression)
			}
			Case Keywords.IF: {
				return this.ParseIf()
			}
			Case Keywords.ELSE: {
				Throw, Exception("Unexpected ELSE")
			}
			; TODO - Add the rest of the keywords
		}
	}
	ParseDefine() {
		ReturnType := this.ParsePrimary()
		
		if (ReturnType.Type != Tokens.IDENTIFIER) {
			Throw, Exception("Invalid function definition return type " ASTNodeTypes[ReturnType.Type])
		}
		
		Name := this.ParsePrimary()
		
		if (Name.Type != Tokens.IDENTIFIER) {
			Throw, Exception("Invalid function definition name type " ASTNodeTypes[Name.Type])
		}
		
		Params := this.ParseParamGrouping()

		Body := this.ParseBlock()
		
		if (Body.Type != ASTNodeTypes.BLOCK) {
			Throw, Exception("Invalid function definition body type " ASTNodeTypes[Params.Type])
		}
		
		return new ASTNodes.Statements.Define(ReturnType, Name, Params, Body)
	}
	
	ParseParamGrouping() {
		this.Consume(Tokens.LEFT_PAREN, "Parameter groupings must start with '('.")
		
		try {
			Pairs := [[this.ParsePrimary(), this.ParsePrimary()]]
		}
		catch {
			Pairs := []
		}
		
		while (this.NextMatches(Tokens.COMMA)) {
			Pair := []
			Pair.Push(this.ParsePrimary()) ; Type
			Pair.Push(this.ParsePrimary()) ; Name
			Pairs.Push(Pair)
		}
	
		this.Consume(Tokens.RIGHT_PAREN, "Parameter groupings require closing ')'.")
		
		return Pairs
	}
	
	ParseExpressionStatement() {
		Expression := this.ParseExpression()
		
		if (this.NextMatches(Tokens.NEWLINE) || this.NextMatches(Tokens.EOF)) {
			return new ASTNodes.Statements.ExpressionLine(Expression)
		}
		else {
			Throw, Exception("Unexpected expression terminator: '" this.Next().Stringify() "'.")
		}
	}
	
	ParseIf() {
		Group := [new ASTNodes.Statements.If(this.ParseExpression(Tokens.LEFT_BRACE), this.ParseBlock())]
	
		while (this.Ignore(Tokens.NEWLINE) && this.Peek().Value = Keywords.ELSE) {
			this.Next()
		
			if (this.Peek().Value = Keywords.IF) {
				this.Next()
				Group.Push(new ASTNodes.Statements.If(this.ParseExpression(Tokens.LEFT_BRACE), this.ParseBlock()))
			}
			else {
				Group.Push(new ASTNodes.Statements.If(new Token(Tokens.INTEGER, True, {}), this.ParseBlock()))
				Break
			}
		}
	
		return new ASTNodes.Statements.IfGroup(Group)
	}
	
	ParseBlock() {
		Statements := []
		this.Ignore(Tokens.NEWLINE)
		this.Consume(Tokens.LEFT_BRACE, "Block expected, but did not have opening '{'.")
		this.Ignore(Tokens.NEWLINE)
		
		while !(this.NextMatches(Tokens.RIGHT_BRACE)) {
			Statements.Push(this.ParseStatement())
			this.Ignore(Tokens.NEWLINE)
			
			if (this.AtEOF()) {
				Break
			}
		}
		
		return Statements
	}
	
	ParseExpression(Terminators*) {
		if ((!IsObject(Terminators)) || (Terminators.Count() = 0)) {
			Terminators := [Tokens.NEWLINE, Tokens.EOF, Tokens.LEFT_BRACE]
		}
	
	
		return this.ExpressionParser(Terminators)[1]
	}
	AddNode(OperandStack, OperandCount, Operator) {
		Operands := []
		
		loop, % OperandCount {
			NextOperand := OperandStack.Pop()
			
			if !(NextOperand) {
				MsgBox, % "Missing Operand for " Operator.Stringify() " around " Operator.Context.Start "-"  Operator.Context.End
			}
			
			Operands.Push(NextOperand)
		}
		
		if !(Operator) {
			MsgBox, % "Missing Operator for " Operands[1].Value " around " Operands[1].Context.Start "-"  Operands[1].Context.End
		}
		
		Switch (OperandCount) {
			Case 1: {
				OperandStack.Push(new ASTNodes.Expressions.Unary(Operands[1], Operator))
			}
			Case 2: {
				OperandStack.Push(new ASTNodes.Expressions.Binary(Operands[2], Operator, Operands[1]))
			}
		}
	}
	
	ExpressionParser(Terminators) {
		OperandStack := []
		OperatorStack := []
	
		loop {
			Next := this.Next()
			Unexpected := True
		
			Switch (Next.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.IDENTIFIER: {
					OperandStack.Push(Next)
					Unexpected := False
				}
				Case Tokens.LEFT_PAREN: {
					this.Index--
					Params := this.ParseGrouping()
				
					if (this.Previous().Type = Tokens.IDENTIFIER && (OperandStack.Count() > 0)) {
						OperandStack.Push(new ASTNodes.Expressions.Call(OperandStack.Pop(), Params))
					}
					else {
						OperandStack.Push(Params)
					}
					
					Unexpected := False
				}
				Case Next.CaseIsOperator(): {
					Operator := Next
					DontPush := False
					
					if (Operator.Type = Tokens.COLON) {
						Param := OperandStack.Pop()
						Name := this.Next()
						
						if (Param.Type != Tokens.IDENTIFIER) {
							Throw, Exception("Invalid (come up with a name for this) value: " Param.Stringify())
						}
						else if (Name.Type != Tokens.IDENTIFIER) {
							Throw, Exception("Invalid name for (come up with a name): " Name.Stringify())
						}
						
						Params := this.ParseGrouping()
						Params.Expressions.InsertAt(1, Param)
						
						OperandStack.Push(new ASTNodes.Expressions.Call(Name, Params))
						DontPush := True
					}
					else if (Operators.IsPostfix(Operator) && this.Previous() && this.Previous().Type != Tokens.Operator) {
						this.AddNode(OperandStack, 1, Operators.EnsurePostfix(Operator))
						DontPush := True
					}
					else if (Operators.IsPrefix(Operator)) {
						OperatorStack.Push(Operator)
						DontPush := True
					}
					
					while (OperatorStack.Count() != 0) {
						NextOperator := OperatorStack.Pop()
						
						if (Operators.IsPrefix(NextOperator)) {
							this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
							Unexpected := False
						}
						
						if (NextOperator.IsOperator() && Operators.CheckPrecedence(Operator, NextOperator)) {
							this.AddNode(OperandStack, Operators.OperandCount(NextOperator), NextOperator)
						}
						else {
							OperatorStack.Push(NextOperator)
							Break
						}
					}
					
					if !(DontPush) {
						OperatorStack.Push(Operator)
					}
					
					Unexpected := False
				}
				Default: {
					; This isn't a character that should be in this expression, but it might be the terminator, so we drop the
					;  index to point at the character again, and run it through the terminator check below before
					;   breaking/erroring
					this.Index-- 
				}
			}
			
			for k, Terminator in Terminators {
				if (this.Check(Terminator)) {
					Break, 2
				}
			}
			
			if (Unexpected) {
				MsgBox, % "Unexpected character '" Next.Stringify() "' in expression around " Next.Context.Start
				Break
			}
		}
		
		while (OperatorStack.Count()) {
			NextOperator := OperatorStack.Pop()
			
			if (Operators.IsPrefix(NextOperator) && OperandStack.Count() < Operators.OperandCount(NextOperator)) {
				MsgBox, % "Missing operand for operator " Tokens[NextOperator.Value] " around " NextOperator.Context.Start
				Continue
			}
			
			this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
		}
		
		return OperandStack
	}
	
	ParsePrimary() {
		Next := this.Next()
	
		Switch (Next.Type) {
			Case Tokens.IDENTIFIER: {
				return this.Current()
			}
			Case Tokens.INTEGER: {
				return this.Current()
			}
			Case Tokens.DOUBLE: {
				return this.Current()
			}
			Case Tokens.LEFT_PAREN: {
				this.Index--
				return this.ParseGrouping()
			}
			Default: {
				this.Index--
				Throw, Exception("Unexpected token " Next.Stringify() " around " Next.Context.Start "-" Next.Context.End)
			}
		}
	}
	
	ParseGrouping() {
		if (this.NextMatches(Tokens.LEFT_PAREN)) {
			Expressions := [this.ParseExpression(Tokens.COMMA, Tokens.RIGHT_PAREN)]
			
			while (this.NextMatches(Tokens.COMMA)) {
				Expressions.Push(this.ParseExpression(Tokens.COMMA, Tokens.RIGHT_PAREN))
			}
			
			this.Consume(Tokens.RIGHT_PAREN, "Expression groupings must have a closing paren")
			
			return new ASTNodes.Expressions.Grouping(Expressions)
		}
	}
}