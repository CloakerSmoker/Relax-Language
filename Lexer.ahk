class Token {
	__New(Type, Value, Context) {
		this.Type := Type
		this.Value := Value
		this.Context := Context
	}
}
class Context {
	__New(Start, End) {
		this.Start := Start
		this.End := End
	}
	Merge(OtherContext) {
		NewStart := Min(OtherContext.Start, this.Start)
		NewEnd := Max(OtherContext.End, this.End)

		return new Context(NewStart, NewEnd)
	}
	ExtractFrom(String) {
		return SubStr(this.Start, this.End - this.Start)
	}
}

class Lexer {
	__New(Code) {
		this.CodeString := Code
		this.Code := StrSplit(Code)
		this.CodeLength := this.Code.Count()
		this.Index := 0
		this.TokenStart := 0
		this.Tokens := []
	}
	IsAtEnd() {
		return this.Index >= this.CodeLength
	}
	Advance() {
		return this.Next()
	}
	Next() {
		return this.Code[++this.Index]
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
		Context := new Context(this.TokenStart, this.Index)
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
		Start := this.Index
		
		loop {
			this.Index++
		} until (this.SubStr(this.Index - 2, this.Index - 2 + EndLength) = End || this.IsAtEnd())
		
		return [Start, this.Index - EndLength]
	}
	
	
	Start() {
		loop {
			NextCharacter := this.Next()
			
			if (CharacterTokens.Operators.HasKey(NextCharacter)) {
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
							this.AddToken(Tokens.SLASH)
						}
					}
				}
				Case CaseWrapper.IsWhiteSpace(NextCharacter): {
					
				}
			}
		} until (this.IsAtEnd())
	}
}