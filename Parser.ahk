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
			}
			; TODO - Add the rest of the keywords
		}
	}
	
	
	ParsePrimary() {
		if (this.NextMatches(Tokens.IDENTIFIER)) {
			return new ASTNodes.Expressions.Identifier(this.Previous())
		}
	
		if (this.NextMatches(Tokens.LEFT_PAREN)) {
			Expressions := [this.ParseExpression()]
			
			while (this.NextMatches(Tokens.COMMA)) {
				Expressions.Push(this.ParseExpression())
			}
			
			this.Consume(Tokens.RIGHT_PAREN, "Expression groupings must have a closing paren")
			
			return new ASTNodes.Expressions.Grouping(Expressions)
		}
	}
}