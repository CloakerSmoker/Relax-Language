class Lexer {
	__New() {
		this.Index := 0
		this.TokenStart := 0
		this.Tokens := []
		
		this.LineNumber := 1
	}
	ErrorFakeToken(Length := 1) {
		ErrorAreaText := this.SubStr(this.TokenStart, this.TokenStart + Length) ; We can't trust this.Index, since whatever caused the error probably currupted it
		ErrorAreaContext := new Context(this.TokenStart, this.TokenStart + Length, this.LineNumber)
		
		return new Token(Tokens.IDENTIFIER, ErrorAreaText, ErrorAreaContext, this.CodeString)
	}
	
	Start(Code) {
		this.CodeString := Code
		this.Source := Code
		this.Code := StrSplit(Code)
		this.CodeLength := this.Code.Count()
		this.CriticalError := False
		
		Log("Starting lexer job for " this.CodeLength " characters")
	
		try {
			loop {
				this.GetNextToken()
			} until (this.IsAtEnd())
		}
		catch E {
			this.CriticalError := True
		}
		
		this.AddToken(Tokens.EOF, "EOF")
		
		if (this.CriticalError) {
			Throw, Exception("Critical error while tokenizing, aborting...")
		}
		
		Log("Finished lexer job for " this.CodeLength " characters, with " this.Tokens.Count() " tokens generated")
		
		return this.Tokens
	}
	
	GetNextToken() {
		this.TokenStart := this.Index
		NextCharacter := this.Next()
		
		if (CharacterTokens.Operators.HasKey(NextCharacter)) {
			FoundToken := ""
			
			for OperatorPart, OperatorType in CharacterTokens.Operators[NextCharacter] {
				if (this.NextMatches(OperatorPart)) {
					FoundToken := OperatorType
					break
				}
			}
			
			if !(FoundToken) {
				FoundToken := CharacterTokens.Operators[NextCharacter]["NONE"]
			}
			
			return this.AddToken(FoundToken)
		}
		else if (CharacterTokens.Misc.HasKey(NextCharacter)) {
			return this.AddToken(CharacterTokens.Misc[NextCharacter])
		}
		
		Switch (NextCharacter) {
			Case "/": {
				Next := this.Peek()
				
				Switch (Next) {
					Case "*": {
						this.Index -= 1
						this.AdvanceThrough("/*", "*/")
					}
					Case "/": {
						this.Index -= 1
						this.AdvanceThrough("//", "`n")
					}
					Default: {
						this.AddToken(Tokens.DIVIDE)
					}
				}
			}
			Case A_Quote: {
				this.Index -= 1
				StringBounds := this.AdvanceThrough(A_Quote, A_Quote)
				
				if !(this.Previous() = A_Quote) {
					new Error("Tokenizer")
						.LongText("Unterminated string starting at position " this.TokenStart)
						.ShortText("Missing a terminator")
						.Token(this.ErrorFakeToken())
						.Source(this.Source)
					.Throw()
				}
				
				this.AddToken(Tokens.STRING, this.SubStr(StringBounds[1], StringBounds[2]))
			}
			Case "'": {
				LiteralCharacter := this.Next()
				
				if !(this.NextMatches("'")) {
					new Error("Tokenizer")
						.LongText("Invalid character literal format.")
						.ShortText("Must follow the 'C' format.")
						.Token(this.ErrorFakeToken(3))
						.Source(this.Source)
					.Throw()
				}
				
				this.AddToken(Tokens.INTEGER, Asc(LiteralCharacter))
			}
			Case "`n": {
				if (this.Tokens[this.Tokens.Count()].Type != Tokens.NEWLINE) {
					this.AddToken(Tokens.NEWLINE, "\n")
				}
			}
			Case CW.IsWhiteSpace(NextCharacter): {
				; Ignore whitespace
			}
			Case CW.IsDigit(NextCharacter): {
				if (NextCharacter = 0) {
					Next := this.Next()
				
					Switch (Next) {
						Case "x", "b", "o": {
							NumberBounds := this.AdvanceThroughFilter(Conversions[Next].Filter)
							Number := this.SubStr(NumberBounds[1], NumberBounds[2])
							AsInteger := Conversions[Next].Converter(Number)
							
							Log("Found non-base10 number '" Number "' with base10 value " AsInteger)
							
							this.AddToken(Tokens.INTEGER, AsInteger)
						}
						Default: {
							this.Index -= 2 
							; Roll back by the 0, and whatever .Next returned, so we start AdvanceThroughNumber at the right index
							this.AdvanceThroughNumber()
						}
					}
				}
				else {
					this.AdvanceThroughNumber()
				}
			}
			Case CW.IsAlpha(NextCharacter): {
				while (IsAlphaNumeric(this.Peek())) {
					this.Advance()
				}
				
				IdentifierText := this.SubStr(this.TokenStart, this.Index)
				
				if (Keywords.HasKey(IdentifierText)) {
					this.AddToken(Tokens.KEYWORD, Keywords[IdentifierText])
				}
				else if (Operators.IsOperator(IdentifierText)) {
					this.AddToken(Tokens[IdentifierText], IdentifierText)
				}
				else {
					this.AddToken(Tokens.IDENTIFIER, IdentifierText)
				}
			}
			Default: {
				new Error("Tokenizer")
					.LongText("Unexpected character")
					.Token(this.ErrorFakeToken())
					.Source(this.Source)
				.Throw()
			}
		}
	}
	
	IsAtEnd() {
		return this.Index >= this.CodeLength
	}
	Advance() {
		return this.Next()
	}
	Next() {
		Next := this.Code[++this.Index]
		
		if (Next = "`n") {
			this.LineNumber++
		}
		
		return Next
	}
	Previous() {
		return this.Code[this.Index]
	}
	Peek(Offset := 1) {
		if (this.Index + Offset > this.CodeLength) {
			return
		}
		
		return this.Code[this.Index + Offset]
	}
	NextMatches(What) {
		if (this.IsAtEnd() || this.Code[this.Index + 1] != What) {
			return false
		}

		this.Index++
		return true
	}
	AddToken(Type, Value := false) {
		Value := Value ? Value : this.SubStr(this.TokenStart, this.Index)
		NewContext := new Context(this.TokenStart, this.Index, this.LineNumber)
		this.Tokens.Push(new Token(Type, Value, NewContext, this.CodeString))
	}
	SubStr(From, To) {
		String := ""
		
		loop, % To - From {
			String .= this.Code[From + A_Index]
		}
		
		return String
	}
	AdvanceThrough(Start, End) {
		for k, Character in StrSplit(Start) {
			if !(this.NextMatches(Character)) {
				return -1
			}
		}
		
		EndLength := StrLen(End)
		StartLength := StrLen(Start)
		StartIndex := this.Index
		Depth := 1
		
		loop {
			this.Advance()
			
			if (Start != End) {
				if (this.SubStr(this.Index - StartLength, this.Index) = Start) {
					Depth++
				}
				else if (this.SubStr(this.Index - EndLength, this.Index) = End) {
					Depth--
				}
				else if (Depth = 0) {
					Break
				}
			}
			else {
				if (this.SubStr(this.Index - StartLength, this.Index) = End) {
					Break
				}
			
			}
			
			if (this.IsAtEnd()) {
				Break
			}
		}
		
		return [StartIndex, this.Index - EndLength]
	}
	AdvanceThroughFilter(FilterFunction) {
		while (FilterFunction.Call(this.Peek())) {
			this.Advance()
		}
		
		return [this.TokenStart, this.Index]
	}
	AdvanceThroughNumber() {
		while (IsDigit(this.Peek())) {
			this.Advance()
		}
		
		if (this.NextMatches(".")) {
			while (IsDigit(this.Peek())) {
				this.Advance()
			}
			
			Type := Tokens.DOUBLE
		}
		else {
			Type := Tokens.INTEGER
		}
		
		this.AddToken(Type, this.SubStr(this.TokenStart, this.Index) + 0)
	}
}