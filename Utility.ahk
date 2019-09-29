global A_Quote := """"

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
	if Value is number
		return true
	
	return false
}

class _CaseWrapper {
	; Simple class to allow for a filter function to decide if a case is true of not
	
	; Used like CaseWrapper.FunctionName(SwitchValue)
	;  Will return SwitchValue when FunctionName returns true for SwitchValue (making the case true)
	;  Will return SwitchValue = 0 (which will never equal SwitchValue) when FunctionName returns false (making the case false)
	__Call(Key, Value, Params*) {
		if (Func(Key).Call(Value)) {
			return Value
		}
		else {
			return Value = 0
		}
	}
}

class CaseWrapper extends _CaseWrapper{
	

}

class Enum {
	__Get(Key) {
		if (Key = "InitDone") {
			return False
		}
	
		return this.Init(Key)
	}
	Init(Key) {
		if !(this.InitDone) {
			for k, Line in StrSplit(this.Options, "`n", "`r") {
				TrimmedLine := LTrim(Line)
				
				if (StrLen(TrimmedLine) = 0) {
					Continue
				}
				
				this[TrimmedLine] := k
				this[k] := TrimmedLine
			}
			
			this.InitDone := True
		}
	
		if (this.HasKey(Key)) {
			return this[Key]
		}
		
		return
	}
}