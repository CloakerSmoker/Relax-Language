class Lexer {
	__New() {
		this.Index := 0
		this.TokenStart := 0
		this.Tokens := []
		
		this.LineNumber := 1
	}
	
	Start(Code) {
		this.CodeString := Code
		this.Code := StrSplit(Code)
		this.CodeLength := this.Code.Count()
	
		loop {
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
				
				this.AddToken(FoundToken)
				Continue
			}
			else if (CharacterTokens.Misc.HasKey(NextCharacter)) {
				this.AddToken(CharacterTokens.Misc[NextCharacter])
				Continue
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
						MsgBox, % "Unterminated string starting at character " this.TokenStart
						return
					}
					
					this.AddToken(Tokens.STRING, this.SubStr(StringBounds[1], StringBounds[2]))
				}
				Case "'": {
					LiteralCharacter := this.Next()
					
					if !(this.NextMatches("'")) {
						MsgBox, % "Character literals must be followed by '"
						return
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
								this.AddToken(Tokens.INTEGER, Conversions[Next].Converter(Number))
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
					else {
						this.AddToken(Tokens.IDENTIFIER, IdentifierText)
					}
				}
				Default: {
					MsgBox, % "Unexpected character '" NextCharacter "' at position " this.Index
				}
			}
		} until (this.IsAtEnd())
		
		this.AddToken(Tokens.EOF, "EOF")
		
		return this.Tokens
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
		Context := new Context(this.TokenStart, this.Index, this.LineNumber)
		this.Tokens.Push(new Token(Type, Value, Context))
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
				MsgBox, % "Expected closing '" End "' for '" Start "' at " StartIndex " before EOF"
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