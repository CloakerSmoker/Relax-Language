global A_Quote := """"

OnError(Func("ErrorCallstack"), -1)

ErrorCallstack(ExceptionObject) {
	ExceptionObject.Message .= "`n`nCallstack:`n" StringifyCallstack(8)
}
StringifyCallstack(Limit := 1) {
	Stack := GetCallstack(Limit)
	Stack.RemoveAt(1), Stack.RemoveAt(1)
	String := ""
	
	for k, v in Stack {
		String .= v.File ":" v.Line "." v.Func "`n"
	}
	
	return String
}

GetCallstack(Limit := -1) {
	Stack := []
		
	loop {
		E := Exception("", -A_Index)
		Stack.Push({"File": E.File, "Line": E.line, "Func": E.What})
	} until ((A_Index - 1 == Limit) || ((-A_Index . "") = E.What))
	
	Stack.Pop()
	Stack.RemoveAt(1)
	
	return stack
}

class Error {
	__New(Phase) {
		this.Phase := Phase
	}
	__Call(Key, Value) {
		static Keys := {"Phase": 0, "LongText": 0, "ShortText": 0, "Token": 0, "Source": 0, "Help": 0}
	
		if (Keys.HasKey(Key)) {
			this[Key] := Value
			return this
		}
	}
	Throw() {
		if (this.Phase && this.LongText && this.Token && this.Source) {
			PrettyError(this.Phase, this.LongText, this.ShortText, this.Token, this.Source, this.Help)
		}
	}
}

PrettyError(Phase, LongText, ShortText, Token, Source, Help := False) {
	TokenContext := Token.Context
	
	TokenText := TokenContext.ExtractFrom(Source)
	
	Lines := StrSplit(Source, "`n", "`r")

	TokenLine := Lines[TokenContext.Line]

	Message := ""
	Message .= Phase " Error: " LongText "`n"
	
	Padding := 2 + Max(StrLen(TokenContext.Line - 1), StrLen(TokenContext.Line))
	
	if (TokenContext.Line != 1) {
		Message .= Spaces(Padding - StrLen(TokenContext.Line - 1) - 1)
		Message .= TokenContext.Line - 1
		Message .= " | " StrReplace(Lines[TokenContext.Line - 1], "`t", "    ") "`n"
	}
	
	TokenLineText := TokenText
	TokenLineStart := TokenContext.Start
	TabCount := 0
	
	loop {
		NextCharacter := SubStr(Source, TokenLineStart, 1)
	
		if (NextCharacter = "`n" || TokenLineStart = 0) {
			TokenStart := A_Index
			Break
		}
		else if (NextCharacter = "`t") {
			TokenLineText := "    " TokenLineText
			TabCount++
			TokenLineStart--
		}
		else {
			TokenLineText := NextCharacter TokenLineText
			TokenLineStart--
		}
	}
	
	loop {
		NextCharacter := SubStr(Source, TokenContext.End + A_Index, 1)
	
		if (NextCharacter = "`n") {
			Break
		}
		else if (NextCharacter = "`t") {
			TokenLineText .= "    "
			TabCount++
			TokenLineStart--
		}
		else {
			TokenLineText .= NextCharacter 
		}
	} until (A_Index >= StrLen(Source))
	
	TokenStart := (TokenStart - TabCount) + (TabCount * 4)
	TokenEnd := StrLen(TokenText)
	
	Message .= Spaces(Padding - StrLen(TokenContext.Line) - 1) TokenContext.Line " | " TokenLineText
	Message .= "`n" Spaces(Padding) "|-"
	
	loop, % TokenStart - 1 {
		Message .= "-"
	}
	
	loop, % TokenEnd {
		Message .= "^"
	}

	Message .= "`n" Spaces(Padding) "| "
	
	loop, % TokenStart - 1 {
		Message .= " "
	}
	
	if (ShortText) {
		Message .= "|> " ShortText
	}
	
	if (Help) {
		Message .= "`nHelp: " Help
	}
	
	Message .= "`n{Enter} to continue."
	
	ShowError(Message)
}

StatementError(Statement, Message) {
	ShowError("Error: " Message "`n" Statement)
}

ShowError(Message) {
	Gui, ShowError:New
	Gui, ShowError:Font, s10, Terminal
	Gui, ShowError:Add, Text, w800 0x80, % Message
	Gui, ShowError:Show
	
	KeyWait, Enter, D
	
	Gui, ShowError:Destroy
	
	Throw, Exception(Message)
}
Spaces(Count) {
	String := ""
	
	loop, % Count {
		String .= " "
	}
	
	return String
}

; %Phase% Error: %LongText%
;  %ErrorLine - 1% | %Lines[ErrorLine - 1]%
;  %ErrorLine - 0% | %Lines[ErrorLine - 0]%
;
;

IsDigit(Character) {
	return Asc(Character) >= Asc("0") && Asc(Character) <= Asc("9") 
}
IsAlpha(Character) {
	CharacterCode := Asc(Character)
	
	if (CharacterCode >= Asc("a") && CharacterCode <= Asc("z")) {
		return true
	}
	else if (CharacterCode >= Asc("A") && CharacterCode <= Asc("Z")) {
		return true
	}
	else if (Character = "_") {
		return true
	}

	return false
}
IsAlphaNumeric(Character) {
	return (IsDigit(Character) || IsAlpha(Character)) && !IsWhiteSpace(Character)
}
IsWhiteSpace(Character) {
	static Whitespace := {" ": true, "`r": true, "`t": true}
	return Whitespace.HasKey(Character)
}
IsHexadecimal(Character) {
	CharacterCode := Asc(Character)

	if (IsDigit(Character)) {
		return true
	}
	else if (Asc("a") <= CharacterCode && CharacterCode <= Asc("f")) {
		return true
	}
	else if (Asc("A") <= CharacterCode && CharacterCode <= Asc("F")) {
		return true
	}
	else {
		return false
	}
}
IsBinary(Character) {
	; lmao
	return (Character = "0" || Character = "1")
}
IsOctal(Character) {
	return (Asc("0") <= Asc(Character) && Asc(Character) <= Asc("7"))
}

IsNumber(Value) {
	if Value is Integer
		return true
	
	return false
}
IsFloat(Value) {
	if Value is Float
		return true

	return false
}

class _CaseWrapper {
	; Simple class to allow for a filter function to decide if a case is true of not
	
	; Used like CaseWrapper.FunctionName(SwitchValue)
	;  Will return SwitchValue when FunctionName returns true for SwitchValue (making the case true)
	;  Will return SwitchValue = 0 (which will never equal SwitchValue) when FunctionName returns false (making the case false)
	
	; Any extra params must also be true for the case as a whole to be true
	__Call(Key, Value, Params*) {
		if (Func(Key).Call(Value)) {
			for k, v in Params {
				if !(v) {
					return Value = 0
				}
			}
		
			return Value
		}
		else {
			return Value = 0
		}
	}
}

class CaseWrapper extends _CaseWrapper {
}
; Shorter name for shorter cases
class CW extends _CaseWrapper {
}

class Enum {
	__Get(Key) {
		if (Key = "InitDone") {
			return False
		}
	
		return this.Init(Key)
	}
	HasKey(Key) {
		return this[Key] != ""
	}
	Init(Key) {
		if !(this.InitDone) {
			for k, Line in StrSplit(this.Options, "`n", "`r") {
				TrimmedLine := LTrim(Line)
				
				if (StrLen(TrimmedLine) = 0 || (SubStr(TrimmedLine, 1, 1) = ";")) {
					Continue
				}
				
				this[TrimmedLine] := k
				this[k] := TrimmedLine
			}
			
			this.InitDone := True
			
			if (this.HasKey(Key)) {
				return this[Key]
			}
		}
		
		return ""
	}
}

class Conversions {
	static x := {"Filter": Func("IsHexadecimal"), "Converter": Conversions.HexToInt}
	static b := {"Filter": Func("IsBinary"), "Converter": Conversions.BinToInt}
	static o := {"Filter": Func("IsOctal"), "Converter": Conversions.OctToInt}

	HexToInt(HexString) {
		if !(SubStr(HexString, 1, 2) = "0x") {
			Throw, Exception("HexToInt can not convert non-hex (" HexString ") to int")
		}
	
		Base := StrLen(HexString) - 2 ; Subtract out the 0x
		Decimal := 0
		
		for k, Character in StrSplit(SubStr(HexString, 3)) {
			CharacterCode := Asc(Character)
			
			if (Asc("0") <= CharacterCode && CharacterCode <= Asc("9")) {
				CharacterCode := (CharacterCode - 48)
			}
			else if (Asc("a") <= CharacterCode && CharacterCode <= Asc("f")) {
				CharacterCode := (CharacterCode - 97) + 10
			}
			else if (Asc("A") <= CharacterCode && CharacterCode <= Asc("F")) {
				CharacterCode := (CharacterCode - 65) + 10
			}
			
			Decimal += CharacterCode * (16 ** --Base)
		}
		
		return Decimal
	}
	BinToInt(BinString) {
		if !(SubStr(BinString, 1, 2) = "0b") {
			Throw, Exception("BinToInt can not convert non-binary (" BinString ") to int")
		}
		
		Base := StrLen(BinString) - 2
		Decimal := 0
		
		for k, Character in StrSplit(SubStr(BinString, 3)) {
			Decimal += Character * (2 ** --Base)
		}
		
		return Decimal
	}
	OctToInt(OctString) {
		if !(SubStr(OctString, 1, 2) = "0o") {
			Throw, Exception("OctToInt can not convert non-octal (" OctString ") to int")
		}
		
		Base := StrLen(OctString) - 2
		Decimal := 0
		
		for k, Character in StrSplit(SubStr(OctString, 3)) {
			Decimal += Character * (8 ** --Base)
		}
		
		return Decimal
	}
	IntToHex(Int, NoZeros := True) {
		if !(IsNumber(Int)) {
			return "0x00"
		}
	
		static HexCharacters := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]
		End := (NoZeros ? "" : "0x")
		HexString := ""
		Quotient := Int
		
		loop {
			Remainder := Mod(Quotient, 16)
			HexString := HexCharacters[Remainder + 1] HexString
			Quotient := Floor(Quotient / 16)
		} until (Quotient = 0)
		
		loop % 2 - StrLen(HexString) {
			HexString := "0" HexString
		}
		
		if (Mod(StrLen(HexString), 2)) {
			HexString := "0" HexString
		}
		
		return End HexString
	}
}

class Assert {
	True(Condition) {
		if !(Condition) {
			Throw, Exception("Assert.True failed in " CallStack(2)[2].Func ".")
		}
	}
	False(Condition) {
		if (Condition) {
			Throw, Exception("Assert.False failed in " CallStack(2)[2].Func ".")
		}
	}
	
	class String {
		True(StringOne, StringTwo) {
			if (StringOne != StringTwo) {
				Throw, Exception("Assert.String.True for `n`t" StringOne "`n`t" StringTwo "`n     failed in " CallStack(2)[2].Func ".")
			}
		}
		False(StringOne, StringTwo) {
			if (StringOne = StringTwo) {
				Throw, Exception("Assert.String.False for `n`t" StringOne "`n`t" StringTwo "`n     failed in " CallStack(2)[2].Func ".")
			}
		}
	}
	
	Unreachable(Info := "") {
		Throw, Exception("Assert.Unreachable failed in " CallStack(2)[2].Func "." (Info ? "`nInfo: " Info : ""))
	}
}

CallStack(Limit := -1) {
	Stack := []
		
	loop {
		E := exception("", -A_Index)
		Stack.Push({"File": E.File, "Line": E.line, "Func": E.What})
	} until ((A_Index - 1 == Limit) || ((-A_Index . "") == E.What))
	
	Stack.RemoveAt(1)
	return stack
}