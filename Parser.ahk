class Parser {
	__New(Tokenizer) {
		this.Tokens := Tokenizer.Tokens
		this.Source := Tokenizer.CodeString
	
		this.Index := 0
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
			return this.ParseDeclaration()
		}
		else {
			return this.ParseExpressionStatement()
		}
	}
	ParseKeywordStatement() {
		NextKeyword := this.Next().Value
		
		switch (NextStatement) {
			case Keywords.DEFINE: {
				
			}
		}
	}
}