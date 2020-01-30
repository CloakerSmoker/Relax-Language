class MZHeader {
	static Size := 0xF0
	
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
		this.Put(0x90, "Short") ; BytesInLastPage
		this.Put(3, "Short") ; PageCount
		this.Put(0, "Short") ; RelocationCount
		this.Put(4, "Short") ; HeaderParagraphCount (Paragraph = 16 bytes)
		this.Put(0, "Short") ; MinimumExtraParagraphCount
		this.Put(0xFFFF, "Short") ; MaximumExtraParagraphCount
		this.Put(0, "Short") ; StartingSS
		this.Put(0xB8, "Short") ; StartingSP
		this.Put(0, "Short") ; Checksum
		this.Put(0, "Short") ; StartingIP
		this.Put(0, "Short") ; StartingCS
		this.Put(0x40, "Short") ; RelocationTable
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

class Header {
	__New() {
		this.Buffer := ""
		this.SetCapacity("Buffer", ObjGetBase(this).Size)
		this.pBuffer := this.GetAddress("Buffer")
		
		loop, % ObjGetBase(this).Size {
			NumPut(0, this.pBuffer + 0, A_Index - 1, "Char")
		}
	}
	__Call(Key, Params*) {
		Base := ObjGetBase(this)
		
		if (Base.Properties.HasKey(Key)) {
			PropertyToSet := Base.Properties[Key]
			
			NumPut(Params[1], this.pBuffer + 0, PropertyToSet[1], PropertyToSet[2])
			return this
		}
	}
	__Delete() {
		this.SetCapacity("Buffer", 0)
	}
	Build() {
		return this
	}
	_NewEnum() {
		return new BufferEnum(this.pBuffer, ObjGetBase(this).Size)
	}
}

class BufferEnum {
	__New(pBuffer, BufferLength) {
		this.pBuffer := pBuffer
		this.Length := BufferLength
		this.Index := 0
	}
	Next(ByRef Key, ByRef Value) {
		Key := this.Index
		Value := NumGet(this.pBuffer + 0, this.Index++, "UChar") 
		
		return !(this.Index > this.Length)
	}
}

class COFFHeader extends Header {
	static Size := 20
	
	class Properties {
		static Machine := [0, "Short"]
		static NumberOfSections := [2, "Short"]
		static TimeDateStamp := [4, "Int"] ; Can be 0
		static PointerToSymbolTable := [8, "Int"] ; Should be 0
		static NumberOfSymbols := [12, "Int"] ; Should be 0
		static SizeOfOptionalHeader := [16, "Short"] ; 240
		static Characteristics := [18, "Short"] ; Changes
	}
}

class PEHeader extends Header {
	static Size := 240
	
	class Properties {
		static Magic := [0, "Short"]
		
		static MajorLinkerVersion := [2, "Char"]
		static MinorLinkerVersion := [3, "Char"]
		
		static SizeOfCode := [4, "Int"] ; Size of .text
		static SizeOfInitializedData := [8, "Int"] ; Size of all data sections
		static SizeOfUninitializedData := [12, "Int"] ; Size of .bss
		
		static AddressOfEntryPoint := [16, "Int"] ; RVA of main
		static BaseOfCode := [20, "Int"] ; RVA of the .text section
		static ImageBase := [24, "Int64"] ; Impacts RVAs, try to decide something unique
		static SectionAlignment := [32, "Int"] ; Default is a single page, use 4kb
		static FileAlignment := [36, "Int"] ; Default to 512
		
		static MajorOSVersion := [40, "Short"]
		static MinorOSVersion := [42, "Short"]
		static MajorImageVersion := [44, "Short"]
		static MinorImageVersion := [46, "Short"]
		static MajorSubsystemVersion := [48, "Short"]
		static MinorSubsystemVersion := [50, "Short"]
		
		static Win32Version := [52, "Int"] ; Must be 0
		static SizeOfImage := [56, "Int"] ; Must be a multiple of SectionAlignment
		static SizeOfHeaders := [60, "Int"] ; Rounded to FileAlignment, size of all headers
		static Checksum := [64, "Int"] ; Ignored for most things, can be 0
		static Subsystem := [68, "Short"] ; Will only end up being the console subsystem for this
		static DllCharacteristics := [70, "Short"] ; Low nibble must be 0, other flags won't be needed
		
		static SizeOfStackReserve := [72, "Int64"] ; Starting stack size
		static SizeOfStackCommit := [80, "Int64"] ; amount of stack memory commited
		static SizeOfHeapReserve := [88, "Int64"] ; Starting heap size
		static SizeOfHeapCommit := [96, "Int64"] ; amount of heap memory commited
		
		static LoaderFlags := [104, "Int"] ; Leave as 0
		static NumberOfRvaAndSizes := [108, "Int"] ; Always 16
		
		static ExportTableRVA := [112, "Int"]
		static ExportTableSize := [116, "Int"]
		
		static ImportTableRVA := [120, "Int"]
		static ImportTableSize := [124, "Int"]
		
		static ResourceTableRVA := [128, "Int"]
		static ResourceTableSize := [132, "Int"]
		
		static ExceptionTableRVA := [136, "Int"]
		static ExceptionTableSize := [140, "Int"]
		
		static CertificateTableRVA := [144, "Int"]
		static CertificateTableSize := [148, "Int"]
		
		static BaseRelocationTableRVA := [152, "Int"]
		static BaseRelocationTableSize := [156, "Int"]
		
		static DebugTableRVA := [160, "Int"]
		static DebugTableSize := [164, "Int"]
		
		static Architecture := [168, "Int64"]
		
		static GlobalPointerRVA := [176, "Int"]
		static GlobalPointerSize := [180, "Int"]
		
		static TLSTableRVA := [184, "Int"]
		static TLSTableSize := [188, "Int"]
		
		static LoadConfigTableRVA := [192, "Int"]
		static LoadConfigTableSize := [196, "Int"]
		
		static BoundImportTableRVA := [200, "Int"]
		static BoundImportTableSize := [204, "Int"]
		
		static ImportAddressTableRVA := [208, "Int"]
		static ImportAddressTableSize := [212, "Int"]
		
		static DelayImportTableRVA := [216, "Int"]
		static DelayImportTableSize := [220, "Int"]
		
		static CLRRuntimeHeaderRVA := [224, "Int"]
		static CLRRuntimeHeaderSize := [228, "Int"]
		
		static Reserved := [232, "Int64"]
	}
}

class SectionHeader extends Header {
	static Size := 40
	
	class Properties {
		static Name := [0, "Int64"]
		static VirtualSize := [8, "Int"] ; Actual size of code/data
		static VirtualAddress := [12, "Int"] ; RVA of the section
		static SizeOfRawData := [16, "Int"] ; FileAlignment rounded VirtualSize
		static PointerToRawData := [20, "Int"] ; File pointer
		static PointerToRelocations := [24, "Int"] ; Should be 0
		static PointerToLinenumbers := [28, "Int"] ; Should be 0
		static NumberOfRelocations := [32, "Short"] ; Should be 0
		static NumberOfLinenumbers := [34, "Short"] ; Should also be 0
		static Characteristics := [36, "Int"] ; Decides what special handling the section gets, Ex: .bss has IMAGE_SCN_CNT_UNINITIALIZED_DATA | IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE
	}
}

class SectionCharacteristics {
	static IMAGE_SCN_CNT_CODE := 0x00000020
	static IMAGE_SCN_CNT_INITIALIZED_DATA := 0x00000040
	static IMAGE_SCN_CNT_UNINITIALIZED_DATA := 0x00000080
	
	static IMAGE_SCN_MEM_DISCARDABLE := 0x02000000
	
	static IMAGE_SCN_MEM_SHARED := 0x10000000
	
	static IMAGE_SCN_MEM_EXECUTE := 0x20000000
	static IMAGE_SCN_MEM_READ := 0x40000000
	static IMAGE_SCN_MEM_WRITE := 0x80000000
	
	static FlagToValue := {"code": SectionCharacteristics.IMAGE_SCN_CNT_CODE
						,  "initialized": SectionCharacteristics.IMAGE_SCN_CNT_INITIALIZED_DATA
						,  "uninitialized": SectionCharacteristics.IMAGE_SCN_CNT_UNINITIALIZED_DATA
						,  "discard": SectionCharacteristics.IMAGE_SCN_MEM_DISCARDABLE
						,  "shared": SectionCharacteristics.IMAGE_SCN_MEM_SHARED
						,  "x": SectionCharacteristics.IMAGE_SCN_MEM_EXECUTE
						,  "r": SectionCharacteristics.IMAGE_SCN_MEM_READ
						,  "w": SectionCharacteristics.IMAGE_SCN_MEM_WRITE}
						
	PackFlags(FlagsString) {
		FlagsValue := 0
		
		for k, Flag in StrSplit(FlagsString, " ") {
			if (this.FlagToValue.HasKey(Flag)) {
				FlagsValue |= this.FlagToValue[Flag]
			}
			else {
				SubFlag := 0
				
				for k, Character in StrSplit(Flag) {
					if !(this.FlagToValue.HasKey(Character)) {
						Throw, Exception("Invalid flag '" Flag "'.")
					}
					
					SubFlag |= this.FlagToValue[Character]
				}
				
				FlagsValue |= SubFlag
			}
		}
		
		return FlagsValue
	}
}

class ImportHeader extends Header {
	static Size := 20
	
	class Properties {
		static LookupTableRVA := [0, "Int"]
		static TimeDateStamp := [4, "Int"] ; Should be left as 0
		static ForwarderIndex := [8, "Int"] ; Should be left as 0
		static NameRVA := [12, "Int"]
		static ThunkTableRVA := [16, "Int"]
	}
}

class RelocationBlock extends Header {
	static Size := 8
	
	class Properties {
		static PageRVA := [0, "Int"]
		static BlockSize := [4, "Int"]
	}
}

class PEBuilder {
	static ImageBase := 0x40000000
	static SectionAlignment := 0x1000
	static FileAlignment := 0x200

	__New() {
		; DOS header generation
		this.DOSHeader := MZHeader.BuildAndGenerate()
		
		; COFF header setup
		this.COFFHeader := COFF := new COFFHeader()
		
		static COFF_M_AMD64 := 0x8664
		COFF.Machine(COFF_M_AMD64)
		
		COFF.TimeDateStamp(this.CurrentTimeToInt32())
		
		COFF.SizeOfOptionalHeader(PEHeader.Size)
		
		static COFF_C_RELOCS_STRIPPED := 0x0001
		static COFF_C_EXECUTABLE_IMAGE := 0x0002
		static COFF_C_LARGE_ADDRESS_AWARE := 0x0020
		static COFF_C_DEBUG_STRIPPED := 0x0200
		COFF.Characteristics(COFF_C_EXECUTABLE_IMAGE | COFF_C_LARGE_ADDRESS_AWARE)
		
		; PE header setup
		this.PEHeader := PE := new PEHeader()
		
		static PE_32_PLUS_MAGIC := 0x020b
		PE.Magic(PE_32_PLUS_MAGIC)
		
		PE.ImageBase(this.ImageBase)
		PE.SectionAlignment(this.SectionAlignment)
		PE.FileAlignment(this.FileAlignment)
		
		static MAJOR_MIN_OS_VERSION := 6 ; These feilds are nearly ignored with how many versions there are now, 6.0 is just what VS 2019 outputs
		static MINOR_MIN_OS_VERSION := 0
		PE.MajorOSVersion(MAJOR_MIN_OS_VERSION), PE.MinorOSVersion(MINOR_MIN_OS_VERSION)
		PE.MajorSubsystemVersion(MAJOR_MIN_OS_VERSION), PE.MinorSubsystemVersion(MINOR_MIN_OS_VERSION)
		
		PE.MajorLinkerVersion(6)
		PE.MinorLinkerVersion(9)
		
		PE.Win32Version(0)
		
		static IMAGE_SUBSYSTEM_WINDOWS_CUI := 3
		PE.Subsystem(IMAGE_SUBSYSTEM_WINDOWS_CUI)
		
		static I_DC_TERMINAL_SERVER_AWARE := 0x8000
		static I_DC_NX_COMPAT := 0x0100
		static I_DC_DYNAMIC_BASE := 0x0040
		static I_DC_NO_SEH := 0x0400
		static I_DC_NO_ISOLATION := 0x0200
		static I_DC_HIGH_ENTROPY_VA := 0x0020
		
		PE.DllCharacteristics(I_DC_TERMINAL_SERVER_AWARE | I_DC_DYNAMIC_BASE | I_DC_NX_COMPAT | I_DC_HIGH_ENTROPY_VA)
		
		static DEFAULT_RESERVE := 0x00100000
		static DEFAULT_COMMIT := 0x8000
		PE.SizeOfStackReserve(DEFAULT_RESERVE)
		PE.SizeOfStackCommit(DEFAULT_COMMIT)
		PE.SizeOfHeapReserve(DEFAULT_RESERVE)
		PE.SizeOfHeapCommit(DEFAULT_COMMIT)
		
		PE.NumberOfRvaAndSizes(16)
		
		
		this.Sections := []
		this.SectionRVAs := {}
		this.NextSectionRVA := this.SectionAlignment
		
		this.FileData := {}
		
		this.Imports := {}
		this.ImportFunctionCount := 0
		this.TotalImportNameLengths := 0
		
		this.PageRelocations := {}
		this.RelocationCount := 0
		
		this.Size := this.RoundToAlignment(MZHeader.Size + COFFHeader.Size + PEHeader.Size + (3 * 40), this.FileAlignment)
		
		this.SizeOfCode := 0
		this.SizeOfData := 0
		this.BaseOfCode := 0
		this.ImportBase := 0
	}
	
	Build(FilePath) {
		this.File := F := FileOpen(FilePath, "rw-rwd")
		
		if !(IsObject(F)) {
			Throw, Exception("Could not lock output file: " FilePath)
		}
		
		F.Length := 0
		
		for k, Byte in this.DOSHeader {
			F.WriteChar(Byte)
		}
		
		F.Write("PE"), F.WriteShort(0) ; PE\0\0 magic
		
		IDataSize := ((this.Imports.Count() + 1) * (20 + 16)) + this.TotalImportNameLengths + (16 * this.ImportFunctionCount)
		; Each Dll import header is 20 bytes, and each imported function has 2 8 byte feilds, and two more terminating 8 byte feilds
		
		IDataFilePointer := this.GetFilePointer(IDataSize)
		
		IData := new SectionHeader()
		IData.Name(this.StringToInt64(".idata"))
		IData.VirtualSize(IDataSize)
		IData.SizeOfRawData(this.RoundToAlignment(IDataSize, this.FileAlignment))
		IData.VirtualAddress(this.NextSectionRVA)
		IData.Characteristics(SectionCharacteristics.PackFlags("r initialized"))
		IData.PointerToRawData(IDataFilePointer)
		this.Sections.Push(IData)
		
		this.BuildIData(IDataSize, IDataFilePointer)
		this.IDataRVA := this.NextSectionRVA
		this.NextSectionRVA := this.RoundToAlignment(this.NextSectionRVA + this.SectionAlignment, this.SectionAlignment)
		this.Size += IDataSize
		this.PEHeader.ImportTableSize(IDataSize)
		
		
		RelocSize := (this.PageRelocations.Count() * 32) + (this.RelocationCount * 2)
		; Each relocation entry is a page descriptor + size for 8 bytes, and N number of 2 byte relocations
		; But since there is padding, a size of 32 is used to ensure we have enough space to pad
		
		RelocFilePointer := this.GetFilePointer(RelocSize)
		
		Reloc := new SectionHeader()
		Reloc.Name(this.StringToInt64(".reloc"))
		Reloc.VirtualSize(RelocSize)
		Reloc.SizeOfRawData(this.RoundToAlignment(RelocSize, this.FileAlignment))
		Reloc.VirtualAddress(this.NextSectionRVA)
		Reloc.Characteristics(SectionCharacteristics.PackFlags("r initialized discard"))
		Reloc.PointerToRawData(RelocFilePointer)
		this.Sections.Push(Reloc)
		
		this.BuildReloc(RelocSize, RelocFilePointer)
		this.PEHeader.BaseRelocationTableRVA(this.NextSectionRVA)
		this.PEHeader.BaseRelocationTableSize(RelocSize)
		
		SectionCount := this.Sections.Count()
		
		this.COFFHeader.NumberOfSections(SectionCount)
		
		this.PEHeader.SizeOfInitializedData(this.RoundToAlignment(this.SizeOfData, this.SectionAlignment))
		this.PEHeader.SizeOfCode(this.RoundToAlignment(this.SizeOfCode, this.SectionAlignment))
		this.PEHeader.BaseOfCode(this.BaseOfCode)
		
		if (this.EntryPoint) {
			this.PEHeader.AddressOfEntryPoint(this.EntryPoint)
		}
		else {
			this.PEHeader.AddressOfEntryPoint(this.BaseOfCode)
		}
		
		this.PEHeader.SizeOfHeaders(this.RoundToAlignment(MZHeader.Size + COFFHeader.Size + PEHeader.Size + (SectionCount * 40), this.FileAlignment))
		this.PEHeader.SizeOfImage(this.RoundToAlignment(this.NextSectionRVA + (this.SectionAlignment * 3) + this.Size, this.SectionAlignment))
		
		for k, Byte in this.COFFHeader.Build() {
			F.WriteChar(Byte)
		}
		
		for k, Byte in this.PEHeader.Build() {
			F.WriteChar(Byte)
		}
		
		for k, Section in this.Sections {
			for k, Byte in Section.Build() {
				F.WriteChar(Byte)
			}
		}
		
		for FilePointer, Bytes in this.FileData {
			F.Seek(FilePointer)
			SkipBytes := 0
			
			for k, Byte in Bytes {
				if (SkipBytes) {
					SkipBytes--
				}
				else if (IsObject(Byte)) {
					if (Byte[1] = "IAT") {
						F.WriteUInt64(this.ImageBase + this.IDataRVA + this.IATOffsets[Byte[2]])
						SkipBytes := 7
					}
					else if (Byte[1] = "SectionPointer") {
						F.WriteUInt64(Byte[2])
						SkipBytes := 7
					}
					else {
						Throw, Exception(Byte[1] " is unlinkable in the PE builder.")
					}
				}
				else {
					F.WriteChar(Byte)
				}
			}
		}
		
		loop, % this.Size - F.Tell() {
			F.WriteChar(0)
		}
		
		F.Close()
	}
	
	BuildIData(IDataSize, IDataFilePointer) {
		this.SizeOfData += IDataSize
		
		Imports := this.Imports
		
		VarSetCapacity(Buffer, IDataSize, 0)
		pBuffer := &Buffer
		
		IDataRVA := this.NextSectionRVA
		
		ThunkTableOffset := 0
		ThunkTableRVA := IDataRVA
		
		HintNameTableOffset := (this.ImportFunctionCount * 8) + (8 * Imports.Count())
		HintNameTableRVA := IDataRVA + HintNameTableOffset
		
		LookupTablesOffset := HintNameTableOffset * 2
		LookupTablesRVA := IDataRVA + LookupTablesOffset
		
		this.PEHeader.ImportTableRVA(LookupTablesRVA)
		this.PEHeader.ImportAddressTableSize(this.ImportFunctionCount * 8)
		this.PEHeader.ImportAddressTableRVA(ThunkTableRVA)
		
		StringsOffset := LookupTablesOffset + ((Imports.Count() + 1) * 20)
		StringsRVA := IDataRVA + StringsOffset
		
		pStrings := pBuffer + StringsOffset
		
		CurrentStringOffset := 0
		CurrentLookupTableOffset := 0 ; The offset into the Thunk/HintName tables
		this.IATOffsets := {}
		
		for DllName, DllImportList in Imports {
			DllNameRVA := StringsRVA + CurrentStringOffset
			
			pThisLookupTable := pBuffer + LookupTablesOffset + (20 * (A_Index - 1))
			
			NumPut(HintNameTableRVA + CurrentLookupTableOffset, pThisLookupTable + 0, 0, "UInt")
			NumPut(DllNameRVA, pThisLookupTable + 0, 12, "UInt")
			NumPut(ThunkTableRVA + CurrentLookupTableOffset, pThisLookupTable + 0, 16, "UInt")
			
			CurrentStringOffset += StrPut(DllName, pStrings + CurrentStringOffset, StrLen(DllName) + 1, "UTF-8") + 2
			
			for k, FunctionName in DllImportList {
				this.IATOffsets[FunctionName "@" DllName] := CurrentLookupTableOffset
				
				FunctionNameRVA := StringsRVA + CurrentStringOffset
				
				NumPut(FunctionNameRVA - 2, pBuffer + ThunkTableOffset, CurrentLookupTableOffset, "UInt")
				NumPut(FunctionNameRVA - 2, pBuffer + HintNameTableOffset, CurrentLookupTableOffset, "UInt")
				CurrentLookupTableOffset += 8
				
				CurrentStringOffset += StrPut(FunctionName, pStrings + CurrentStringOffset, StrLen(FunctionName) + 1, "UTF-8") + 2
			}
			
			CurrentLookupTableOffset += 8
		}
	
		IDataBytes := []
		
		loop, % IDataSize {
			IDataBytes.Push(NumGet(pBuffer + 0, A_Index - 1, "UChar"))
		}
		
		this.FileData[IDataFilePointer] := IDataBytes
	}
	
	BuildReloc(RelocSize, RelocFilePointer) {
		static ABSOLUTE := 0
		static HIGHLOW := 3
		static DIR64 := 10
		
		VarSetCapacity(Buffer, RelocSize, 0)
		pBuffer := &Buffer
		Offset := 0
		
		for PageRVA, RelocationsInPage in this.PageRelocations {
			ThisPageRelocationCount := RelocationsInPage.Count()
			
			RelocationBlockSize := 8 + (2 * ThisPageRelocationCount)
			
			PaddingSpace := Mod(RelocationBlockSize, 32)
			
			NumPut(PageRVA, pBuffer + Offset, 0, "Int")
			NumPut(RelocationBlockSize, pBuffer + Offset, 4, "Int")
			
			Offset += 8
			
			for k, RelocationOffset in RelocationsInPage {
				NumPut(this.MakeRelocationEntry(DIR64, RelocationOffset), pBuffer + Offset, 0, "Short")
				Offset += 2
			}
			
			Offset += PaddingSpace
		}
	
		RelocBytes := []
		
		loop, % RelocSize {
			RelocBytes.Push(NumGet(pBuffer + 0, A_Index - 1, "UChar"))
		}
		
		this.FileData[RelocFilePointer] := RelocBytes
	}
	
	MakeRelocationEntry(RelocationType, OffsetInPage) {
		Value := 0
		Value |= RelocationType << 12
		Value |= OffsetInPage & ((2 << 11) - 1)
		return Value
	}
	
	AddCodeSection(Name, Bytes, EntryPoint := 0) {	
		if (this.SizeOfCode = 0) {
			this.BaseOfCode := this.NextSectionRVA
		}
		
		if (EntryPoint > 0) {
			this.EntryPoint := this.NextSectionRVA + EntryPoint
		}
		
		Bytes := this.LinkCode(Bytes)
		
		this.SizeOfCode += Bytes.Count()
		
		this.AddSection(Name, Bytes, SectionCharacteristics.PackFlags("rx code"))
	}
	
	AddSection(Name, Bytes, Characteristics) {
		NewSection := new SectionHeader()
		
		Size := Bytes.Count()
		RoundedSize := this.RoundToAlignment(Size, this.FileAlignment)
		FilePointer := this.GetFilePointer(Size)
		
		NewSection.Name(this.StringToInt64(Name))
		NewSection.VirtualSize(Size)
		NewSection.SizeOfRawData(RoundedSize)
		NewSection.VirtualAddress(this.NextSectionRVA)
		NewSection.Characteristics(Characteristics)
		NewSection.PointerToRawData(FilePointer)
		
		this.SectionRVAs[Name] := this.NextSectionRVA
		this.NextSectionRVA := this.RoundToAlignment(this.NextSectionRVA + RoundedSize, this.SectionAlignment)
		this.Sections.Push(NewSection)
		
		this.FileData[FilePointer] := Bytes
	}
	
	GetFilePointer(ByteCount) {
		RoundedCount := this.RoundToAlignment(ByteCount, this.FileAlignment)
		
		OldSize := this.Size
		this.Size += RoundedCount
		return OldSize
	}
	
	RoundToAlignment(Value, Alignment) {
		Remainder := Mod(Value, Alignment)
		
		if (Remainder = 0) {
			return Value
		}
		else {
			return Value + (Alignment - Remainder)
		}
	}
	
	LinkCode(Bytes) {
		LinkedBytes := []
		
		for k, Byte in Bytes {
			if (IsObject(Byte)) {
				Switch (Byte[1]) {
					Case "Dll": {
						DllName := Byte[2]
						FunctionName := Byte[3]
						
						if !(this.Imports.HasKey(DllName)) {
							this.Imports[DllName] := []
							
							this.TotalImportNameLengths += StrLen(DllName) + 3
						}
						
						AlreadyImported := False
						
						for k, ImportName in this.Imports[DllName] {
							if (ImportName = FunctionName) {
								AlreadyImported := True
							}
						}
						
						if !(AlreadyImported) {
							this.Imports[DllName].Push(FunctionName)
							
							this.TotalImportNameLengths += StrLen(FunctionName) + 3
							this.ImportFunctionCount++
						}
						
						LinkedBytes.Push(["IAT", FunctionName "@" DllName])
						this.AddRelocation(this.NextSectionRVA, k - 1)
					}
					Case "Global": {
						GlobalName := Byte[2]
						SectionName := Byte[3]
						SectionOffset := Byte[4]
						
						SectionRVA := this.SectionRVAs[SectionName]
						
						LinkedBytes.Push(["SectionPointer", this.ImageBase + SectionRVA + SectionOffset])
						
						this.AddRelocation(this.NextSectionRVA, k - 1)
					}
				}
			}
			else {
				LinkedBytes.Push(Byte)
			}
		}
		
		return LinkedBytes
	}
	
	AddRelocation(PageRVA, OffsetInPage) {
		if (OffsetInPage >= this.SectionAlignment) {
			PageRVA += Floor(OffsetInPage / this.SectionAlignment)
			OffsetInPage := Mod(OffsetInPage, this.SectionAlignment)
		}
		
		if !(this.PageRelocations.HasKey(PageRVA)) {
			this.PageRelocations[PageRVA] := []
		}
		
		this.PageRelocations[PageRVA].Push(OffsetInPage)
		this.RelocationCount++
	}
	
	StringToInt64(String) {
		Int := 0
		
		for k, v in StrSplit(SubStr(String, 1, 8)) {
			Int |= Asc(v) << ((A_Index - 1) * 8)
		}
		
		return Int
	}
	
	CurrentTimeToInt32() {
		DaysSinceEpoch := -1
		
		loop, % A_YYYY - 1970 {
			if (this.IsLeapYear(A_YYYY + A_Index)) {
				DaysSinceEpoch++
			}
			
			DaysSinceEpoch += 365
		}
		
		Stamp := 0
		
		Stamp += (DaysSinceEpoch) * 24 * 60 * 60
		Stamp += (A_YDay) * 24 * 60 * 60
		Stamp += (A_Hour) * 60 * 60
		Stamp += (A_Min) * 60
		Stamp += (A_Sec)
		
		return Stamp
	}
	IsLeapYear(Year) {
		return (!Mod(Year, 4) && Mod(Year, 100)) || !Mod(Year, 400)
	}
}