#Include C:\Users\Connor\Desktop\Valite\Parser\Utility.ahk
#Include C:\Users\Connor\Desktop\Valite\Compiler\CodeGen.ahk
#Include C:\Users\Connor\Desktop\lib\JSON.ahk

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
		Bytes := []
		
		loop, % ObjGetBase(this).Size {
			Bytes.Push(NumGet(this.pBuffer + 0, A_Index - 1, "UChar"))
		}
		
		return Bytes
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
						,  "idata": SectionCharacteristics.IMAGE_SCN_CNT_INITIALIZED_DATA
						,  "udata": SectionCharacteristics.IMAGE_SCN_CNT_UNINITIALIZED_DATA
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

class PEBuilder {
	static ImageBase := 0x00500000
	static SectionAlignment := 0x1000
	static FileAlignment := 0x200

	__New() {
		; DOS header generation
		this.DOSHeader := MZHeader.BuildAndGenerate()
		
		; COFF header setup
		this.COFFHeader := COFF := new COFFHeader()
		
		static COFF_M_AMD64 := 0x8664
		COFF.Machine(COFF_M_AMD64)
		
		COFF.SizeOfOptionalHeader(PEHeader.Size)
		
		static COFF_C_RELOCS_STRIPPED := 0x0001
		static COFF_C_EXECUTABLE_IMAGE := 0x0002
		static COFF_C_LARGE_ADDRESS_AWARE := 0x0020
		static COFF_C_DEBUG_STRIPPED := 0x0200
		COFF.Characteristics(COFF_C_RELOCS_STRIPPED | COFF_C_EXECUTABLE_IMAGE | COFF_C_DEBUG_STRIPPED)
		
		; PE header setup
		this.PEHeader := PE := new PEHeader()
		
		static PE_32_PLUS_MAGIC := 0x020b
		PE.Magic(PE_32_PLUS_MAGIC)
		
		PE.ImageBase(this.ImageBase)
		PE.SectionAlignment(this.SectionAlignment)
		PE.FileAlignment(this.FileAlignment)
		
		static MAJOR_MIN_OS_VERSION := 10
		static MINOR_MIN_OS_VERSION := 0
		PE.MajorOSVersion(MAJOR_MIN_OS_VERSION), PE.MinorOSVersion(MINOR_MIN_OS_VERSION)
		PE.MajorSubsystemVersion(MAJOR_MIN_OS_VERSION), PE.MinorSubsystemVersion(MINOR_MIN_OS_VERSION)
		
		PE.Win32Version(0)
		
		static IMAGE_SUBSYSTEM_WINDOWS_CUI := 3
		PE.Subsystem(IMAGE_SUBSYSTEM_WINDOWS_CUI)
		
		PE.DllCharacteristics(0)
		
		static DEFAULT_RESERVE := 0x00100000
		static DEFAULT_COMMIT := 0x1000
		PE.SizeOfStackReserve(DEFAULT_RESERVE)
		PE.SizeOfStackCommit(DEFAULT_COMMIT)
		PE.SizeOfHeapReserve(DEFAULT_RESERVE)
		PE.SizeOfHeapCommit(DEFAULT_COMMIT)
		
		PE.NumberOfRvaAndSizes(16)
	
		this.Sections := []
		this.NextSectionRVA := this.SectionAlignment
		this.FileData := {}
		this.FileIndex := this.FileAlignment * 2
		this.Size := this.FileIndex + this.FileAlignment
	}
	
	Build(FilePath) {
		this.File := F := FileOpen(FilePath, "rw")
		
		for k, Byte in this.DOSHeader {
			F.WriteChar(Byte)
		}
		
		F.Write("PE"), F.WriteShort(0) ; PE\0\0 magic
		
		this.COFFHeader.NumberOfSections(this.Sections.Count())
		this.PEBuilder.SizeOfHeaders(this.RoundToAlignment(F.Tell() + 240 + (this.Sections.Count() * 40)), this.FileAlignment)
		
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
			
			for k, Byte in Bytes {
				F.WriteChar(Byte)
			}
		}
		
		loop, % this.Size - F.Tell() {
			F.WriteChar(0)
		}
		
		F.Close()
	}
	
	AddDataSection(Name, Bytes) {
	
	}
	AddCodeSection(Name, Bytes) {
	
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
		
		this.NextSectionRVA := this.RoundToAlignment(this.NextSectionRVA + RoundedSize)
		this.Sections.Push(NewSection)
		
		this.FileData[FilePointer] := Bytes
	}
	
	GetFilePointer(ByteCount) {
		RoundedCount := this.RoundToAlignment(ByteCount, this.FileAlignment)
		
		this.Size += RoundedCount
		return this.FileIndex += RoundedCount
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
	
	StringToInt64(String) {
		Int := 0
		
		for k, v in StrSplit(SubStr(String, 1, 8)) {
			Int |= Asc(v) << ((A_Index - 1) * 8)
		}
		
		return Int
	}

}

P := new PEBuilder()
P.AddSection(".test", [100, 101, 102, 103], SectionCharacteristics.PackFlags("rx code"))
P.Build(A_ScriptDir "\test.exe")