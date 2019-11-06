﻿class Parser {
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
			
			Assert.String.True(ParAST[1].Stringify(), Output)
		
			Lex := ""
			Tok := ""
			Par := ""
			ParAST := ""
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
		if ((!IsObject(Terminators)) || (Terminators.Count() = 0)) {
			Terminators := [Tokens.NEWLINE, Tokens.EOF]
		}
	
	
		return this.ExpressionParser(Terminators)
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
		
			Switch (Next.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.IDENTIFIER: {
					OperandStack.Push(Next)
					Continue
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
					
					Continue
				}
				Case Tokens.RIGHT_PAREN: {
					while (OperatorStack.Count()) {
						NextOperator := OperatorStack.Pop()
					
						if (NextOperator.Type = Tokens.LEFT_PAREN) {
							Continue, 2
						}
						else {
							this.AddNode(OperandStack, 2, NextOperator)
						}
					}
					
					MsgBox, % "Unbalenced parens"
				}
				Case Next.CaseIsOperator(): {
					Operator := Next
					
					if (Operators.IsPostfix(Operator) && this.Previous() && this.Previous().Type != Tokens.Operator) {
						this.AddNode(OperandStack, 1, Operators.EnsurePostfix(Operator))
						Continue
					}
					else if (Operators.IsPrefix(Operator)) {
						OperatorStack.Push(Operator)
						Continue
					}
					
					while (OperatorStack.Count() != 0) {
						NextOperator := OperatorStack.Pop()
						
						if (Operators.IsPrefix(NextOperator)) {
							this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
							Continue
						}
						
						if (NextOperator.IsOperator() && Operators.CheckPrecedence(Operator, NextOperator)) {
							this.AddNode(OperandStack, Operators.OperandCount(NextOperator), NextOperator)
						}
						else {
							OperatorStack.Push(NextOperator)
							Break
						}
					}
					
					OperatorStack.Push(Operator)
					Continue
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
			
			MsgBox, % "Unexpected character '" Next.Stringify() "' in expression around " Next.Context.Start
			Break
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