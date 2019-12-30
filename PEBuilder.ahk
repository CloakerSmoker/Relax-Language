class MZHeader {
	BuildAndGenerate(StubString := "This program cannot be run in DOS mode.", HeaderSize := 0xF0, FillByte := 0x00) {
		CG := new I386CodeGen()
		CG.Push_CS()
		CG.Pop_DS()
		CG.Move_DX_I16(0x0E)
		CG.Move_AH_I8(0x09)
		CG.Int_I8(0x21)
		CG.Move_AX_I16(0x4C01)
		CG.Int_I8(0x21)
		CG.Push_String(StubString)
		
		return this.Build(HeaderSize, CG.Bytes, FillByte)
	}

	Build(PEHeaderOffset, CodeBytes, FillByte := 0x00) {
		if (0x40 + CodeBytes.Count() > PEHeaderOffset) {
			Throw, Exception("PEHeaderOffset passed to MZHeader.Build not large enough for generated header.")
		}
	
		PageCount := Ceil((0x40 + CodeBytes.Count()) / 512)
		PageBytes := PageCount * 512
	
		VarSetCapacity(Buffer, PageBytes, 0)
		
		this.pBuffer := &Buffer
		
		this.Put(Asc("M"), "Char"), this.Put(Asc("Z"), "Char") ; Magic
		this.Put(0, "Short") ; BytesInLastPage
		this.Put(PageCount, "Short") ; PageCount
		this.Put(0, "Short") ; RelocationCount
		this.Put(4, "Short") ; HeaderParagraphCount (Paragraph = 16 bytes)
		this.Put(0, "Short") ; MinimumExtraParagraphCount
		this.Put(255, "Short") ; MaximumExtraParagraphCount
		this.Put(0, "Short") ; StartingSS
		this.Put(0, "Short") ; StartingSP
		this.Put(0, "Short") ; Checksum
		this.Put(0, "Short") ; StartingIP
		this.Put(0, "Short") ; StartingCS
		this.Put(0, "Short") ; RelocationTable
		this.Put(0, "Short") ; OverlayNumber
		this.Put(0, "Int64") ; Padding e_res[4]
		this.Put(0, "Short") ; e_oemid
		this.Put(0, "Short") ; e_oeminfo
		this.Put(0, "Int64"), this.Put(0, "Short") ; Padding e_res2[10]
		this.Put(0, "Int64"), this.Put(0, "Short") ; Padding e_res2[10]
		this.Put(PEHeaderOffset, "UInt") ; e_lfanew
		
		Bytes := CodeBytes.Clone()
		
		Loop, % 4 * 16 {
			Bytes.InsertAt(A_Index, NumGet(&Buffer + 0, A_Index - 1, "UChar"))
		}
		
		VarSetCapacity(Buffer, 0, 0)
		
		Loop, % PEHeaderOffset - Bytes.Count() {
			Bytes.Push(FillByte)
		}
		
		return Bytes
	}
	Put(Number, Type) {
		this.pBuffer := NumPut(Number, this.pBuffer + 0, 0, Type)
	}
}