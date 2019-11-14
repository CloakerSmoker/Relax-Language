class REX {
	static Prefix := 64
	static W := 1 << 3
	static R := 1 << 2
	static X := 1 << 1
	static B := 1

	static None := 0
}

class RAX  { 
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 0 
}
class RBX  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 3
}
class RCX  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 1
}
class RDX  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 2
}
class RSP  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 4
}
class RBP  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 5
}
class RSI  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 6
}
class RDI  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 7
}

class R8  { 
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 0 
}
class R9  {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 3
}
class R10 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 1
}
class R11 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 2
}
class R12 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 4
}
class R13 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 5
}
class R14 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 6
}
class R15 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 7
}

class Mode {
	static RToR := 3
	static SIBToR := 0
	static RToPtr := 0
	static SIB := 4
	
	static SIB8ToR := 1
}

SplitIntoBytes32(Integer) {
	Array := []

	loop, % 4 {
		Array.Push((Integer >> ((A_Index - 1) * 8)) & 0xFF)
	}
	
	return Array
}

class X64CodeGen {
	__New() {
		this.Bytes := []
		this.Labels := {}
	}
	
	__Get(Key) {
		if (X64CodeGen.Registers.HasKey(Key)) {
			return X64CodeGen.Registers[Key]
		}
	}
	__Call(Key, Params*) {
		if (Params.Count() = 2) {
			Base := ObjGetBase(this)
			
			if (IsNumber(Params[2])) {
				Params[2] := {"Type": "I64", "Value": Params[2]}
			}
			
			FunctionName := Key "_" Params[1].Type "_" Params[2].Type
		
			if (Base.HasKey(FunctionName)) {
				return Base[FunctionName].Call(this, Params[1], Params[2])
			}
			else if (IsNumber(Params[2].Value)) {
				Params[2].Type := "I32"
				
				FunctionName := Key "_" Params[1].Type "_" Params[2].Type

				if (Base.HasKey(FunctionName)) {
					return Base[FunctionName].Call(this, Params[1], Params[2])
				}
			}
		}
	}
	
	Index() {
		return this.Bytes.Count()
	}

	Label(Name) {
		this.Labels[Name] := this.Index()
	}
	LabelPlaceholder(Name) {
		this.Bytes.Push(["Label", Name])
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
	}
	Link() {
		for Index, Byte in this.Bytes {
			if (IsObject(Byte) && Byte[1] = "Label") {
				TargetIndex := this.Labels[Byte[2]]
				CurrentIndex := (Index + 4) - 1
				Offset := TargetIndex - CurrentIndex
			
				for k, v in SplitIntoBytes32(Offset) {
					this.Bytes[Index + k - 1] := v
				}
			}
		}
	}

	PushByte(Byte) {
		this.Bytes.Push(Byte & 0xFF)
	}
	
	SplitIntoBytes32(Integer) {
		loop, % 4 {
			this.PushByte((Integer >> ((A_Index - 1) * 8)) & 0xFF)
		}
	}
	SplitIntoBytes64(Integer) {
		this.SplitIntoBytes32((Integer & 0x00000000FFFFFFFF) >> 0)
		this.SplitIntoBytes32((Integer & 0x7FFFFFFF00000000) >> 32)
	}

	REX(Params*) {
		Prefix := REX.Prefix
		
		for k, v in Params {
			Prefix |= v
		}
		
		this.PushByte(Prefix)
	}
	REXOpcodeMod(Opcode, DestRegister, SourceRegister, NewMode := "None") {
		Prefix := [REX.W, SourceRegister.Requires.REX] ; If the source needs REX.B, then add it to our prefix
		
		if (DestRegister.Requires.REX = REX.B) {
			; If the DestRegister requies REX.B, then we add REX.R, since REX.R functions as REX.B for the RM feild of ModRM
			Prefix.Push(REX.R)
		}
	
		this.REX(Prefix*)
		
		for k, Part in Opcode {
			this.PushByte(Part)
		}
		
		this.Mod((NewMode = "None" ? Mode.RToR : NewMode), DestRegister.Number, SourceRegister.Number)
	}
	REXOpcodeModSIB(Opcode, Register, Scale, IndexRegister, BaseRegister, NewMode := "None") {
		static EncodedScales := {8: 3, 4: 2, 2: 1, 1: 0}
	
		Prefix := [REX.W, BaseRegister.Requires.REX]
		
		if (Register.Requires.REX = REX.B) {
			Prefix.Push(REX.R)
		}
		
		if (IndexRegister.Requires.REX = REX.B) {
			Prefix.Push(REX.X)
		}
		
		this.REX(Prefix*)
		
		for k, Part in Opcode {
			this.PushByte(Part)
		}
	
		this.Mod((NewMode = "None" ? Mode.SIBToR : NewMode), Register.Number, Mode.SIB)
		this.SIB(EncodedScales[Scale], IndexRegister.Number, BaseRegister.Number)
	}
	
	Mod(Mode := 3, Register := 0, RM := 0) {
		this.PushByte((Mode << 6) | (Register << 3) | RM)
	}
	SIB(Scale, Index, Base) {
		this.PushByte((Scale << 6) | (Index << 3) | Base)
	}
	
	
	class Registers {
		static RAX := {"Type": "R64", "Number": 0, "Requires": {"REX": REX.None}}
		static RBX := {"Type": "R64", "Number": 3, "Requires": {"REX": REX.None}}
		static RCX := {"Type": "R64", "Number": 1, "Requires": {"REX": REX.None}}
		static RDX := {"Type": "R64", "Number": 2, "Requires": {"REX": REX.None}}
		static RSP := {"Type": "R64", "Number": 4, "Requires": {"REX": REX.None}}
		static RBP := {"Type": "R64", "Number": 5, "Requires": {"REX": REX.None}}
		static RSI := {"Type": "R64", "Number": 6, "Requires": {"REX": REX.None}}
		static RDI := {"Type": "R64", "Number": 7, "Requires": {"REX": REX.None}}
		
		static R8  := {"Type": "R64", "Number": 0, "Requires": {"REX": REX.B}}
		static R9  := {"Type": "R64", "Number": 1, "Requires": {"REX": REX.B}}
		static R10 := {"Type": "R64", "Number": 2, "Requires": {"REX": REX.B}}
		static R11 := {"Type": "R64", "Number": 3, "Requires": {"REX": REX.B}}
		static R12 := {"Type": "R64", "Number": 4, "Requires": {"REX": REX.B}}
		static R13 := {"Type": "R64", "Number": 5, "Requires": {"REX": REX.B}}
		static R14 := {"Type": "R64", "Number": 6, "Requires": {"REX": REX.B}}
		static R15 := {"Type": "R64", "Number": 7, "Requires": {"REX": REX.B}}
	}
	
	
	SmallMove(Register, Integer) {
		;this.XOR_R64_R64(Register, Register)
		;this.XOR_R64_I8(Register, Byte & 0xFF)
	
		this.REXOpcodeMod([0xC7], {"Number": 0}, Register)
		this.SplitIntoBytes32(Integer)
	}
	
	XOR_R64_R64(RegisterOne, RegisterTwo) {
		if (RegisterOne.Requires.REX || RegisterTwo.Requires.REX) {
			this.REX(REX.W, RegisterOne.Requires.REX, RegisterTwo.Requires.REX)
		}
	
		this.PushByte(0x33)
		this.Mod(Mode.RToR, RegisterOne.Number, RegisterTwo.Number)
		;this.REXOpcodeMod([0x33], RegisterOne, RegisterTwo)
	}
	XOR_R64_I8(Register, Byte) {
		if (Register.Requires.REX) {
			this.REX(Register.Requires.REX)
		}
		
		this.PushByte(0x83)
		this.Mod(Mode.RToR, 6, Register.Number)
		this.PushByte(Byte)
	}
	
	MoveSX_R64_RI32(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x63], RegisterOne, RegisterTwo, Mode.RToPtr)
	}
	MoveSX_R64_RI16(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0xBF], RegisterOne, RegisterTwo, Mode.RToPtr)
	}
	MoveSX_R64_RI8(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0xBE], RegisterOne, RegisterTwo, Mode.RToPtr)
	}

	Move_R64_I64(Register, Integer) {
		; MOV r64, imm64
		; REX.W + B8+ rd io
	
		this.REX(REX.W | Register.Requires.Rex) ; REX.W (| REX.B)
		this.PushByte(0xB8 + Register.Number) ; B8 + rd
		this.SplitIntoBytes64(Integer.Value) ; io
	}
	Move_R64_R64(DestRegister, SourceRegister) {
		; MOV r64,r/m64
		; REX.W + 8B /r
	
		this.REXOpcodeMod([0x8B], DestRegister, SourceRegister)
	}
	Move_R64_SIB(Register, SIB) {
		; MOV r64,r/m64
		; REX.W + 8B /r
		
		this.REXOpcodeModSIB([0x8B], Register, SIB.Scale, SIB.IndexRegister, SIB.BaseRegister)
	}
	Move_SIB_R64(SIB, Register) {
		; MOV r/m64,r64
		; REX.W + 89 /r
		
		this.Lea_R64_SIB(R11, SIB)
		this.REXOpcodeMod([0x89], Register, R11, Mode.RToPtr)
	}
	Move_R8_SIB(Register, SIB) {
		; REX.W + 0F B6 /r
		; MOVZX r64, r/m8
		
		this.REXOpcodeModSIB([0x0F, 0xB6], Register, SIB.Scale, SIB.IndexRegister, SIB.BaseRegister)
	}
	Move_I64_R64(Address, Register) {	
		Dummy := (Register.Number = RAX.Number) ? RBX : RAX
		
		this.Push(Dummy)
		this.Move_R64_I64(Dummy, I64(Address))
	
		this.REXOpcodeMod([0x89], Register, Dummy, Mode.RToPtr)
		
		this.Pop(Dummy)
	}
	
	C_Move_E_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0x44], RegisterOne, RegisterTwo)
	}
	C_Move_NE_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0x45], RegisterOne, RegisterTwo)
	}
	C_Move_L_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0x4C], RegisterOne, RegisterTwo)
	}
	C_Move_LE_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0x4E], RegisterOne, RegisterTwo)
	}
	C_Move_G_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0x4F], RegisterOne, RegisterTwo)
	}
	C_Move_GE_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0x4D], RegisterOne, RegisterTwo)
	}

	Lea_R64_SIB(Register, SIB) {
		; Lea r64,r/m64
		; REX.W + 8D /r
		
		this.REXOpcodeModSIB([0x8D], Register, SIB.Scale, SIB.IndexRegister, SIB.BaseRegister)
	}
	
	JMP(Name) {
		this.PushByte(0xE9)
		this.LabelPlaceholder(Name)
	}
	JE(Name) {
		this.PushByte(0x0F)
		this.PushByte(0x84)
		this.LabelPlaceholder(Name)
	}
	JNE(Name) {
		this.PushByte(0x0F)
		this.PushByte(0x85)
		this.LabelPlaceholder(Name)
	}
	
	Cmp_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x3B], RegisterOne, RegisterTwo)
	}
	
	Add_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x03], RegisterOne, RegisterTwo)
	}
	Add_R64_I32(Register, Integer) {
		this.REXOpcodeMod([0x81], {"Number": 0}, Register, Mode.RToR)
		this.SplitIntoBytes32(Integer.Value)
	}
	Sub_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x2B], RegisterOne, RegisterTwo)
	}
	Sub_R64_I32(Register, Integer) {
		this.REXOpcodeMod([0x81], {"Number": 5}, Register, Mode.RToR)
		this.SplitIntoBytes32(Integer.Value)
	}
	
	
	Push(Operand) {
		Base := ObjGetBase(this)
	
		if (IsNumber(Operand)) {
			Operand := {"Type": "I32", "Value": Operand}
		}
	
		if !(Base.HasKey("Push_" Operand.Type)) {
			Throw, Exception("No conversion for Push_" Operand.Type)
		}
		
		Base["Push_" Operand.Type].Call(this, Operand)
	}
	
	Push_R64(Register) {
		if (Register.Requires.REX) {
			this.REX(Register.Requires.REX)
		}
		
		this.PushByte(0x50 + Register.Number)
	}
	Push_I32(Integer) {
		this.PushByte(0x68)
		this.SplitIntoBytes32(Integer.Value)
	}
	
	Pop(Operand) {
		Base := ObjGetBase(this)
	
		if !(Base.HasKey("Pop_" Operand.Type)) {
			Throw, Exception("No conversion for Pop_" Operand.Type)
		}
		
		Base["Pop_" Operand.Type].Call(this, Operand)
	}
	
	Pop_R64(Register) {
		if (Register.Requires.REX) {
			this.REX(Register.Requires.REX)
		}
		
		this.PushByte(0x58 + Register.Number)
	}
	
	
	Return() {
		this.Return_Near()
	}
	Return_Near() {
		this.PushByte(0xC3)
	}
	
	Stringify() {
		this.Link()
	
		String := ""
		
		for k, v in this.Bytes {
			String .= IntToHex(v) " "
		}
		
		return String
	}
	
	Execute(Params*) {
		this.Link()
	
		pMemory := DllCall("VirtualAlloc", "UInt64", 0, "Ptr", this.Bytes.Count(), "Int", 0x00001000 | 0x00002000, "Int", 0x04)
		
		for k, v in this.Bytes {
			NumPut(v, pMemory + 0, A_Index - 1, "Char")
		}
		
		DllCall("VirtualProtect", "Ptr", pMemory, "Ptr", this.Bytes.Count(), "UInt", 0x20, "UInt*", OldProtection)
		
		Params.InsertAt(1, pMemory)
		
		ReturnValue := DllCall(Params*)
		
		DllCall("VirtualFree", "Ptr", pMemory, "Ptr", this.Bytes.Count(), "UInt", 0x00008000)
		
		return ReturnValue
	}

	CompileTo(Name) {
		this.Link()
		
		pMemory := DllCall("VirtualAlloc", "UInt64", 0, "Ptr", this.Bytes.Count(), "Int", 0x00001000 | 0x00002000, "Int", 0x04)
		
		for k, v in this.Bytes {
			NumPut(v, pMemory + 0, A_Index - 1, "Char")
		}
		
		DllCall("VirtualProtect", "Ptr", pMemory, "Ptr", this.Bytes.Count(), "UInt", 0x20, "UInt*", OldProtection)
		
		MCode.Functions[Name] := {"pCode": pMemory, "Size": this.Bytes.Count()}
		MCode[Name] := Func("DllCall").Bind(pMemory)
	}
}

class _MCode {
	__Delete() {
		for k, Function in this.Functions {
			DllCall("VirtualFree", "Ptr", Function.pCode, "Ptr", Function.Size, "UInt", 0x00008000)
		}
	}
}

class MCode extends _MCode {
	static Functions := {}
}

SIB(Scale, IndexRegister, BaseRegister) {
	if (BaseRegister.Number = 5) {
		Throw, Exception("Registers numbered 5 (RBP, R13) can't be used as Base registers")
	}

	return {"Type": "SIB", "Scale": Scale, "IndexRegister": IndexRegister, "BaseRegister": BaseRegister}
}
I64(Address) {
	return {"Type": "I64", "Value": Address}
}

IntToHex(Int, NoZeros := True) {
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