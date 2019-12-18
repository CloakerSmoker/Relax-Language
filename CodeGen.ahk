FloatToBinaryInt(Float) {
	VarSetCapacity(Buffer, 8, 0)
	NumPut(Float, &Buffer + 0, 0, "Double")
	return NumGet(&Buffer + 0, 0, "UInt64")
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

SplitIntoBytes32(Integer) {
	Array := []

	loop, % 4 {
		Array.Push((Integer >> ((A_Index - 1) * 8)) & 0xFF)
	}
	
	return Array
}
SplitIntoBytes64(Integer) {
	FirstFour := SplitIntoBytes32((Integer & 0x00000000FFFFFFFF) >> 0)
	LastFour := SplitIntoBytes32((Integer & 0x7FFFFFFF00000000) >> 32)

	return [FirstFour[1], FirstFour[2], FirstFour[3], FirstFour[4], LastFour[1], LastFour[2], LastFour[3], LastFour[4]]
}

IntToI(IntNumber) {
	return StrReplace(IntNumber, "Int", "I")
}
IToInt(INumber) {
	return StrReplace(INumber, "I", "Int")
}

class Mode {
	static RToR := 3
	static SIBToR := 0
	static RToPtr := 0
	static SIB := 4
	
	static SIB8ToR := 1
}

class X64CodeGen {
	__New() {
		this.Bytes := []
		this.Labels := {}
	}

	REX(Params*) {
		Prefix := REX.Prefix
		
		for k, v in Params {
			if (v != "") {
				Prefix |= v
			}
		}
		
		this.PushByte(Prefix)
	}
	
	REXOpcode(OpcodeParts, REXParts) {
		for k, v in REXParts {
			if (v) {
				this.REX(REXParts*)
				Break
			}
		}
		
		for k, Part in OpcodeParts {
			this.PushByte(Part)
		}
	}
	
	REXOpcodeMod(Opcode, DestRegister, SourceRegister, Options := "") {
		NewMode := (Options.Mode != "") ? Options.Mode : Mode.RToR
		
		REXParts := IsObject(Options.REX) ? Options.REX : []
	
		if (DestRegister.OpcodeExtension != "") {
			; When a instruction has an opcode extension, it lives in R/M of the ModRM byte
			;  so we can just convert .OpcodeExtension into .Number to make things a bit more readable
			DestRegister := {"Number": DestRegister.OpcodeExtension}
		}
	
		REXParts.Push(SourceRegister.Requires.REX) ; If the source needs REX.B, then add it to our prefix
		
		if (DestRegister.Requires.REX = REX.B) {
			; If the DestRegister requies REX.B, then we add REX.R, since REX.R functions as REX.B for the RM feild of ModRM
			REXParts.Push(REX.R)
		}
	
		this.REXOpcode(Opcode, REXParts)
		this.Mod(NewMode, DestRegister.Number, SourceRegister.Number)
	}
	REXOpcodeModSIB(Opcode, Register, SIB, Options := "") {
		REXParts := IsObject(Options.REX) ? Options.REX : []
		REXParts.Push(SIB.BaseRegister.Requires.REX)
		
		if (Register.Requires.REX = REX.B) {
			REXParts.Push(REX.R)
		}
		if (SIB.IndexRegister.Requires.REX = REX.B) {
			REXParts.Push(REX.X)
		}
		
		this.REXOpcodeMod(Opcode, Register, {"Number": Mode.SIB}, {"REX": REXParts, "Mode": Mode.SIBToR})
		this.SIB(SIB.Scale, SIB.IndexRegister.Number, SIB.BaseRegister.Number)
	}
	
	Mod(Mode := 3, Register := 0, RM := 0) {
		this.PushByte((Mode << 6) | (Register << 3) | RM)
	}
	SIB(Scale, Index, Base) {
		static EncodedScales := {8: 3, 4: 2, 2: 1, 1: 0}
	
		this.PushByte((EncodedScales[Scale] << 6) | (Index << 3) | Base)
	}

	; TODO: Redo this entire thing, so instruction sizes can change dynamically during linking
	;  ex: removing duplicate instructions shouldn't clobber relative jumps
	;  ex: changing jumps to use 8bit offsets instead of 32 shouln't clobber other jumps
	
	SmallMove(Register, Integer) {
		if (Integer = 0 && False) {
			; o7 RIP XOR 0ing, if only it didn't touch the flags register
			this.XOR_R64_R64(Register, Register)
		}
		else {
			this.Push(Integer)
			this.Pop(Register)
		}
	}
	
	; Calls START
	
	Call_RI64(Register) {
		this.REXOpcodeMod([0xFF], {"OpcodeExtension": 2}, Register)
	}
	Call_Label(Name) {
		this.PushByte(0xE8)
		this.LabelPlaceholder(Name)
	}
	
	; Calls END
	;============================
	; XORs START
	
	XOR_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x33], RegisterOne, RegisterTwo)
	}
	XOR_R64_I8(Register, Byte) {
		if (Register.Requires.REX) {
			this.REX(Register.Requires.REX)
		}
		
		this.PushByte(0x83)
		this.Mod(Mode.RToR, 6, Register.Number)
		this.PushByte(Byte)
	}
	
	; XORs END
	;============================
	; Sign extend moves START
	
	MoveSX_R64_RI32(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x63], RegisterOne, RegisterTwo, {"Mode": Mode.RToPtr})
	}
	MoveSX_R64_RI16(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0xBF], RegisterOne, RegisterTwo, {"Mode": Mode.RToPtr})
	}
	MoveSX_R64_RI8(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0xBE], RegisterOne, RegisterTwo, {"Mode": Mode.RToPtr})
	}

	; Sign extend moves END
	;============================
	; Misc/Register to register moves START

	Move_R64_R64(DestRegister, SourceRegister) {
		; MOV r64,r/m64
		; REX.W + 8B /r
	
		this.REXOpcodeMod([0x8B], DestRegister, SourceRegister, {"REX": [REX.W]})
	}
	Move_SIB_XMM(SIB, Register) {
		this.PushByte(0xF2)
		this.REXOpcodeModSIB([0x0F, 0x11], Register, SIB)
	}
	Move_XMM_SIB(Register, SIB) {
		this.PushByte(0xF2)
		this.REXOpcodeModSIB([0x0F, 0x10], Register, SIB)
	}
	
	; Misc/Register to register moves END 
	;============================
	; Register to (in register) pointer moves START
	
	Move_RI8_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x88], RegisterTwo, RegisterOne, {"Mode": Mode.RToPtr}) ; Op1 = rm(dest), Op2 = r(source)
	}
	Move_RI16_R64(RegisterOne, RegisterTwo) {
		this.PushByte(0x66) ; Legacy opcode size prefix, now using 16 bit instead of 32
		this.PushByte(0x89) ; Opcode
		this.Mod(Mode.RToPtr, RegisterTwo.Number, RegisterOne.Number) ; Rm = Dest, R = Source, so the params are backwards in ModRM
	}
	Move_RI32_R64(RegisterOne, RegisterTwo) {
		this.PushByte(0x89) ; Opcode
		this.Mod(Mode.RToPtr, RegisterTwo.Number, RegisterOne.Number) ; Rm = Dest, R = Source, so the params are backwards in ModRM
	}
	Move_RI64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x89], RegisterTwo, RegisterOne, {"Mode": Mode.RToPtr, "REX": [REX.W]})
	}
	
	Move_R64_RI64(DestRegister, SourceRegister) {
		this.REXOpcodeMod([0x8B], DestRegister, SourceRegister, {"REX": [REX.W], "Mode": Mode.RToPtr})
	}
	Move_R64_RI32(DestRegister, SourceRegister) {
		this.REXOpcodeMod([0x8B], DestRegister, SourceRegister, {"Mode": Mode.RToPtr})
	}
	Move_R64_RI16(DestRegister, SourceRegister) {
		this.PushByte(0x66)
		this.PushByte(0x8B)
		this.Mod(Mode.RToPtr, DestRegister.Number, SourceRegister.Number)
	}
	Move_R64_RI8(DestRegister, SourceRegister) {
		this.REXOpcodeMod([0x8A], DestRegister, SourceRegister, {"Mode": Mode.RToPtr})
	}
	
	; Register to (in register) pointer moves END
	;============================
	; Imm moves START
	
	Move_R64_I64(Register, Integer) {
		; MOV r64, imm64
		; REX.W + B8+ rd io
	
		this.REXOpcode([0xB8 + Register.Number], [REX.W, Register.Requires.Rex])
		this.SplitIntoBytes64(Integer.Value) ; io
	}
	Move_R64_I32R(Register, RawInteger) {
		return this.Move_R64_I32(Register, {"Value": RawInteger})
	}
	Move_R64_I32(Register, Integer) {
		this.REXOpcodeMod([0xC7], {"OpcodeExtension": 0}, Register)
		this.SplitIntoBytes32(Integer.Value)
	}
	Move_R64_I8(Register, Integer) {
		; what a stupid mistake of an instruction. It doesn't touch the top 50+ bits, just the low 8, which is ~~totally useless~~ great
		Throw, Exception("Don't use the idiot instruction.")
		this.REXOpcode([0xB0 + Register.Number], [Register.Requires.REX])
		this.PushByte(Integer.Value)
	}

	; Imm moves END
	;============================
	; SIB-Based moves START

	Move_SIB_R64(SIB, Register) {
		; MOV r/m64,r64
		; REX.W + 89 /r
		
		this.REXOpcodeModSIB([0x89], Register, SIB, {"REX": [REX.W]})
	}
	Move_R64_SIB(Register, SIB) {
		; MOV r64,r/m64
		; REX.W + 8B /r
		
		this.REXOpcodeModSIB([0x8B], Register, SIB, {"REX": [REX.W]})
	}
	Move_R8_SIB(Register, SIB) {
		; REX.W + 0F B6 /r
		; MOVZX r64, r/m8
		
		this.REXOpcodeModSIB([0x0F, 0xB6], Register, SIB, {"REX": [REX.W]})
	}
	Lea_R64_SIB(Register, SIB) {
		; Lea r64,r/m64
		; REX.W + 8D /r
		
		this.REXOpcodeModSIB([0x8D], Register, SIB, {"REX": [REX.W]})
	}
	
	; SIB-Based moves END
	;============================
	; Jumps/Cmp instructions START
	
	Cmp_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x3B], RegisterOne, RegisterTwo, {"REX": [REX.W]})
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
	
	; Jumps/Cmp instructions END
	;============================
	; CMovecc instructions START
	
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
	
	
	; CMovecc instructions END
	;============================
	; Int math instructions START
	
	Inc_R64(Register) {
		this.REXOpcodeMod([0xFF], {"OpcodeExtension": 0}, Register)
	}
	Inc_SIB(SIB) {
		this.REXOpcodeModSIB([0xFF], {"OpcodeExtension": 0}, SIB)
	}
	Dec_SIB(SIB) {
		this.REXOpcodeModSIB([0xFF], {"OpcodeExtension": 1}, SIB)
	}
	
	SmallAdd(Register, Number) {
		this.SmallMove(RBX, Number)
		
		if (Number <= 0xFFFFFFFF) {
			this.Add_R64_R32(Register, RBX)
		}
		else {
			this.Add_R64_R64(Register, RBX)
		}
	}
	Add_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x03], RegisterOne, RegisterTwo, {"REX": [REX.W]})
	}
	Add_R64_R32(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x03], RegisterOne, RegisterTwo)
	}
	Add_R64_I32(Register, Integer) {
		this.REXOpcodeMod([0x81], {"OpcodeExtension": 0}, Register, {"REX": [REX.W]})
		this.SplitIntoBytes32(Integer.Value)
	}
	Add_R64_I16(Register, Integer) {
		this.REXOpcodeMod([0x81], {"OpcodeExtension": 0}, Register, {"REX": [REX.Prefix]})
		this.PushByte(Integer.Value & 0x00FF)
		this.PushByte(Integer.Value & 0xFF00)
	}
	Add_R64_I8(Register, Byte) {
		this.REXOpcodeMod([0x80], {"OpcodeExtension": 0}, Register, {"REX": [REX.Prefix]})
		this.PushByte(Byte.Value & 0xFF)
	}
	
	SmallSub(Register, Number) {
		this.SmallMove(RBX, Number)
		
		if (Number <= 0xFFFFFFFF) {
			this.Sub_R64_R32(Register, RBX)
		}
		else {
			this.Sub_R64_R64(Register, RBX)
		}
	}
	Sub_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x2B], RegisterOne, RegisterTwo, {"REX": [REX.W]})
	}
	Sub_R64_R32(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x2B], RegisterOne, RegisterTwo)
	}
	Sub_R64_I32(Register, Integer) {
		this.REXOpcodeMod([0x81], {"OpcodeExtension": 5}, Register, {"REX": [REX.W]})
		this.SplitIntoBytes32(Integer.Value)
	}	
	Sub_R64_I16(Register, Integer) {
		this.REXOpcodeMod([0x81], {"OpcodeExtension": 5}, Register, {"REX": [REX.Prefix]})
		this.PushByte(Integer.Value & 0x00FF)
		this.PushByte(Integer.Value & 0xFF00)
	}
	Sub_R64_I8(Register, Byte) {
		this.REXOpcodeMod([0x80], {"OpcodeExtension": 5}, Register, {"REX": [REX.Prefix]})
		this.PushByte(Byte.Value & 0xFF)
	}
	
	IMul_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0F, 0xAF], RegisterOne, RegisterTwo)
	}
	
	CDQ() {
		this.REX(REX.W)
		this.PushByte(0x99)
	}
	IDiv_RAX_R64(Register) {
		this.CDQ()
		this.REXOpcodeMod([0xF7], {"OpcodeExtension": 7}, Register)
	}
	
	Neg_SIB(SIB) {
		this.REXOpcodeModSIB([0xF7], {"OpcodeExtension": 3}, SIB, {"REX": [REX.W]})
	}
	And_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x23], RegisterOne, RegisterTwo, {"REX": [REX.W]})
	}
	Or_R64_R64(RegisterOne, RegisterTwo) {
		this.REXOpcodeMod([0x0B], RegisterOne, RegisterTwo, {"REX": [REX.W]})
	}
	
	; Int math instructions END
	;============================
	; Push instructions START
	
	Push(Operand) {
		Base := ObjGetBase(this)
	
		if (IsNumber(Operand)) {
			Operand := {"Type": this.NumberSizeOf(Operand, False), "Value": Operand}
		}
	
		if !(Base.HasKey("Push_" Operand.Type)) {
			Throw, Exception("No conversion for Push_" Operand.Type)
		}
		
		Base["Push_" Operand.Type].Call(this, Operand)
	}
	
	Push_SIB(SIB) {
		this.REXOpcodeModSIB([0xFF], {"OpcodeExtension": 6}, SIB)
	}
	Push_R64(Register) {
		if (Register.Requires.REX) {
			this.REX(Register.Requires.REX)
		}
		
		this.PushByte(0x50 + Register.Number)
	}
	Push_I64(Integer) {
		this.Move_R64_I64(RAX, Integer)
		this.Push(RAX)
	}
	Push_I32(Integer) {
		this.PushByte(0x68)
		this.SplitIntoBytes32(Integer.Value)
	}
	Push_I16(Integer) {
		this.Push_I32(Integer) 
		; This used to use the PUSH imm16 (68 iw) encodings, but it turns out that PUSHW increments RSP by 4, while PUSH imm8 and PUSH imm32 increment by 8
	}
	Push_I8(Byte) {
		if (Byte.Value & 0x80) {
			return this.Push_I32(Byte)
		}
	
		this.PushByte(0x6A)
		this.PushByte(Byte.Value & 0xFF)
	}
	
	; Push instructions END
	;============================
	; Pop instructions START
	
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
	Pop_SIB(SIB) {
		this.REXOpcodeModSIB([0x8F], {"OpcodeExtension": 0}, SIB)
	}
	
	; Pop instructions END
	;============================
	; Return instructions START
	
	Return() {
		this.Return_Near()
	}
	Return_Near() {
		this.PushByte(0xC3)
	}
	Ret_I8(Byte) {
		this.PushByte(0xC2)
		this.PushByte(Byte & 0xFF)
	}
	
	; Return instructions END
	;============================
	; Floating point load instructions START
	
	FLD_SIB(SIB) {
		this.PushByte(0xDD)
		this.Mod(Mode.SIBToR, 0, Mode.SIB)
		this.SIB(SIB.Scale, SIB.IndexRegister.Number, SIB.BaseRegister.Number)
	}
	FILD_SIB(SIB) {
		this.PushByte(0xDF)
		this.Mod(Mode.SIBToR, 5, Mode.SIB)
		this.SIB(SIB.Scale, SIB.IndexRegister.Number, SIB.BaseRegister.Number)
	}
	FSTP_SIB(SIB) {
		this.PushByte(0xDD)
		this.Mod(Mode.SIBToR, 3, Mode.SIB)
		this.SIB(SIB.Scale, SIB.IndexRegister.Number, SIB.BaseRegister.Number)
	}
	FISTP_SIB(SIB) {
		this.PushByte(0xDF)
		this.Mod(Mode.SIBToR, 7, Mode.SIB)
		this.SIB(SIB.Scale, SIB.IndexRegister.Number, SIB.BaseRegister.Number)
	}
	
	FLD_Stack() {
		this.FLD_SIB(SIB(8, RSI, RSP))
	}
	FILD_Stack() {
		this.FILD_SIB(SIB(8, RSI, RSP)) ; Helpers. They assume that RSI is 0
	}
	FSTP_Stack() {
		this.FSTP_SIB(SIB(8, RSI, RSP))
	}
	FISTP_Stack() {
		this.FISTP_SIB(SIB(8, RSI, RSP))
	}
	
	; Floating point load instructions END
	;============================
	; Floating point math instructions START
	
	; Note to self: Make sure you use encodings that use ST(0) as the dest, and ST(1) as the source
	;  otherwise expressions will evaluate like (RIGHT %OPERATOR% LEFT) instead of (LEFT %OPERATOR% RIGHT)

	FAddP() {
		this.PushByte(0xD8)
		this.PushByte(0xC1)
	}
	FSubP() {
		this.PushByte(0xD8)
		this.PushByte(0xE1)
	}
	FMulP() {
		this.PushByte(0xD8)
		this.PushByte(0xC9)
	}
	FDivP() {
		this.PushByte(0xD8)
		this.PushByte(0xF1)
	}
	
	; Floating point math instructions END
	;============================
	; Floating point misc instructions START
	
	FLD_1() {
		this.PushByte(0xD9)
		this.PushByte(0xE8)
	}
	FLD_0() {
		this.PushByte(0xD9)
		this.PushByte(0xEE)
	}
	FLD_LG2() {
		this.PushByte(0xD9)
		this.PushByte(0xEC)
	}
	FXCH() {
		this.PushByte(0xD9)
		this.PushByte(0xC9)
	}
	FYL2X() {
		this.PushByte(0xD9)
		this.PushByte(0xF1)
	}
	FST() {
		this.PushByte(0xDD)
		this.Mod(Mode.SIBToR, 2, RCX.Number)
	}
	
	; Floating point misc instructions END
	;============================
	; RAX size conversion instructions START
	
	CBWE() {
		this.PushByte(0x66) ; Legacy operand size, 16 bits
		this.PushByte(0x98) ; Opcode
	}
	CWDE() {
		this.PushByte(0x98)
	}
	CDQE() {
		this.REX(REX.W)
		this.PushByte(0x98)
	}
	
	; RAX size conversion instructions END
	;============================
	; Magic helper pseudo-instructions
	
	DllCall(DllFile, DllFunction) {	
		this.REXOpcode([0xB8 + RAX.Number], [REX.W])
		this.DllFunctionPlaceholder(DllFile, DllFunction)
		this.Call_RI64(RAX)
	}
	Push_String_Pointer(String) {
		this.REXOpcode([0xB8 + RAX.Number], [REX.W])
		this.StringPlaceholder(String)
		this.Push(RAX)
	}
	
	
	;============================

	__Call(Key, Params*) {
		Base := ObjGetBase(this)
		
		if (Base.HasKey(Key)) {
			return Base[Key].Call(this, Params*)
		}
	
		if (Params.Count() = 2) {
			if (IsNumber(Params[2])) {
				Params[2] := {"Type": this.NumberSizeOf(Params[2], False), "Value": Params[2]}
			}
			
			FunctionName := Key "_" Params[1].Type "_" Params[2].Type
		
			if (Base.HasKey(FunctionName)) {
				return Base[FunctionName].Call(this, Params[1], Params[2])
			}
			else {
				Throw, Exception("No method: " FunctionName)
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
	DllFunctionPlaceholder(DllFile, DllFunction) {
		this.Bytes.Push(["Dll", DllFile, DllFunction])
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
		
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
	}
	StringPlaceholder(String) {
		this.Bytes.Push(["String", String])
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
		
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
		this.PushByte(0x00)
	}
	Link() {
		static HEAP_ZERO_MEMORY := 0x00000008
		static hProcessHeap := DllCall("GetProcessHeap")
	
		if (this.LinkedBytes) {
			return this.LinkedBytes
		}
	
		this.LinkedBytes := LinkedBytes := []
		SkipBytes := 0
	
		for Index, Byte in this.Bytes {
			if (SkipBytes != 0) {
				SkipBytes--
			}
			else if (IsObject(Byte)) {
				Switch (Byte[1]) {
					Case "Label": {
						TargetIndex := this.Labels[Byte[2]]
						CurrentIndex := (Index + 4) - 1
						Offset := TargetIndex - CurrentIndex
					
						for k, v in SplitIntoBytes32(Offset) {
							LinkedBytes.Push(v)
						}
						
						SkipBytes += 3
					}
					Case "Dll": {
						hDllFile := DllCall("GetModuleHandle", "Str", Byte[2], "Ptr")
						pSomeFunction := DllCall("GetProcAddress", "Ptr", hDllFile, "AStr", Byte[3], "Ptr")
						
						for k, v in SplitIntoBytes64(pSomeFunction) {
							LinkedBytes.Push(v)
						}
						
						SkipBytes += 7
					}
					Case "String": {
						pMemory := DllCall("HeapAlloc", "Ptr", hProcessHeap, "UInt", HEAP_ZERO_MEMORY, "UInt", StrLen(Byte[2]) + 1)
						StrPut(Byte[2], pMemory, StrLen(Byte[2]) + 1, "UTF-8")
				
						OnExit(Func("DllCall").Bind("HeapFree", "Ptr", hProcessHeap, "UInt", 0, "Ptr", pMemory))
						
						for k, v in SplitIntoBytes64(pMemory) {
							LinkedBytes.Push(v)
						}
						
						SkipBytes += 7
					}
				}
			}
			else {
				LinkedBytes.Push(Byte)
			}
		}
		
		return LinkedBytes
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
	
	NumberSizeOf(Number, ReturnNumber := true) {
		static Sizes := {8: "I8", 16: "I16", 32: "I32", 64: "I64"}
	
		loop 64 {
			NextBit := Number & (1 << (64 - A_Index))
		
			if (NextBit) {
				Length := A_Index - 1
				break
			}
		}
		
		NewLength := 64 - Length
		
		while !(Sizes.HasKey(NewLength)) {
			NewLength++
		}
		
		return (ReturnNumber ? NewLength : Sizes[NewLength])
	}
	
	Stringify() {
		Bytes := this.Link()
	
		String := ""
		
		for k, v in Bytes {
			String .= Conversions.IntToHex(v) " "
		}
		
		return String
	}
}

class REX {
	static Prefix := 64
	static W := 1 << 3
	static R := 1 << 2
	static X := 1 << 1
	static B := 1

	static None := 0
}

; Super-global classes to hold registers, so they are always in scope

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
	static Number := 1
}
class R10 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 2
}
class R11 {
	static Type := "R64"
	static Requires := {"REX": REX.B}
	static Number := 3
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


class XMM0  { 
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 0 
}
class XMM1  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 1
}
class XMM2  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 2
}
class XMM3  {
	static Type := "R64"
	static Requires := {"REX": REX.None}
	static Number := 3
}