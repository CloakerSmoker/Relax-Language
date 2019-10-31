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
			this.Values := {}
			
			for k, Line in StrSplit(this.Options, "`n", "`r") {
				TrimmedLine := LTrim(Line)
				
				if (StrLen(TrimmedLine) = 0 || (SubStr(TrimmedLine, 1, 1) = ";")) {
					Continue
				}
				
				this.Values[TrimmedLine] := k
				this.Values[k] := TrimmedLine
			}
			
			this.InitDone := True
		}
	
		if (this.Values.HasKey(Key)) {
			return this.Values[Key]
		}
		
		return
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
		End := (NoZeros ? "x" : "0x")
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