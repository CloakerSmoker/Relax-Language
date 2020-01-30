class LanguageNameFlags {
	class Optimization {
		static DisableDeadCodeElimination := 1
		static DisableDeadIfElimination := 2
		static DisableConstantFolding := 4
		
		static EnableAll := 0
		static DisableAll := 4 + 2 + 1
	}
	class Features {
		static EnableAll := 0
		static DisableAll := 8 + 4 + 2 + 1
		
		static DisableDllCall := 1
		static DisableModules := 2
		static DisableGlobals := 4
		static DisableStrings := 8
		
		static UseStackStrings := 16
		static TargetPE := 32
	}
	
	static O0 := LanguageNameFlags.Optimization.DisableAll
	static O1 := LanguageNameFlags.Optimization.EnableAll
	
	static F0 := LanguageNameFlags.Features.DisableAll
	static F1 := LanguageNameFlags.Features.EnableAll
	
	static ToAHK := LanguageNameFlags.F1 + LanguageNameFlags.Features.UseStackStrings
}

#Include %A_LineFile%\..\
#Include Parser\Utility.ahk
#Include Parser\Constants.ahk
#Include Parser\Lexer.ahk
#Include Parser\Typing.ahk
#Include Parser\Parser.ahk
#Include Compiler\Optimizer.ahk
#Include Compiler\CodeGen.ahk
#Include Compiler\Compiler.ahk
#Include Compiler\PEBuilder.ahk

class LanguageName {
	; Change ^ when you've come up with a name
	
	static VERSION := "1.0.0-alpha.20"
	
	; Simple class that handles creating a lexer/parser/compiler for some given code, and just returns a CompiledProgram
	;  object for you
	
	static DefaultFlags := {"OptimizationLevel": LanguageNameFlags.O1, "Features": LanguageNameFlags.F1}
	
	CompileToAHKFunctions(CodeString, FunctionPrefix := "MyProgram") {
		Program := this.CompileCode(CodeString, {"Features": LanguageNameFlags.ToAHK})
		
		return Program.ToAHK()
	}
	
	CompileToEXE(CodeString, EXEPath := "") {
		static Flags := {"Features": LanguageNameFlags.ToAHK | LanguageNameFlags.Features.TargetPE}
		
		if !(EXEPath) {
			EXEPath := A_ScriptDir "\out.exe"
		}
		
		CodeString .= "`n" Builtins.__Runtime__.Code
		
		CodeCompiler := this.CompileCode(CodeString, Flags)
		
		MainOffset := CodeCompiler.FunctionOffsets["__RunTime__CallMain"]
		
		GlobalBytes := []
		
		loop, % CodeCompiler.Globals.Count() * 8 {
			GlobalBytes.Push(0)
		}
		
		CodeEXEBuilder := new PEBuilder()
		CodeEXEBuilder.AddSection(".data", GlobalBytes, SectionCharacteristics.PackFlags("rw initialized"))
		CodeEXEBuilder.AddCodeSection(".text", CodeCompiler.CodeGen.Link(True), MainOffset)
		CodeEXEBuilder.Build(EXEPath)
		
		return EXEPath
	}
	
	CompileCode(CodeString, Flags := "") {
		if !(IsObject(Flags)) {
			Flags := this.DefaultFlags
		}
		
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		CodeOptimizer := new ASTOptimizer(CodeLexer, CodeParser, Flags)
		CodeOptimizer.OptimizeProgram(CodeAST)
		
		CodeCompiler := new Compiler(CodeLexer, CodeParser, Flags)
		Program := CodeCompiler.CompileProgram(CodeAST)
		
		return Program
	}
}

class CompiledProgram {
	; A (not as) simple class that wraps around a CodeGen object (Which holds the compiled machine code) for some given code

	__New(ProgramNode, CodeGen, FunctionOffsets, Modules) {
		; Called interally by the compiler once it finishes compiling a program, the passed CodeGen has not been linked yet 
		;  (AKA it has unresolved label offsets, and any imported modules/dll functions are not resolved)
		
		this.Node := ProgramNode ; AST node representing the function
		this.CodeGen := CodeGen
		this.Offsets := FunctionOffsets ; This stores how far into CodeGen.Bytes you need to jump for a given function
		this.Modules := Modules ; List of modules the code uses
		
		LinkedCode := CodeGen.Link() ; Fixes up label offsets, allocates space for globals, and so on
		; At this point the code is fully compiled, and can run
		
		pMemory := this.pMemory := DllCall("VirtualAlloc", "UInt64", 0, "Ptr", LinkedCode.Count(), "Int", 0x00001000 | 0x00002000, "Int", 0x04)
		; Allocate some RW memory
		
		for k, v in LinkedCode {
			NumPut(v, pMemory + 0, A_Index - 1, "Char") ; Write the code into it
		}
		
		DllCall("VirtualProtect", "Ptr", pMemory, "Ptr", LinkedCode.Count(), "UInt", 0x20, "UInt*", OldProtection)
		; Switch the memory to X
		
		OnExit(this.Delete.Bind(this)) ; OnExit, bind freeing the memory we wrote the compiled code into
	}
	Delete() {
		DllCall("VirtualFree", "Ptr", this.pMemory, "Ptr", 0, "UInt", 0x00008000) ; Free our memory
	}
	
	GetAHKType(TypeName) {
		; Converts types that don't exist in the eyes of DllCall into regular DllCall types
		
		static AHKTypes := {"i8": "Char", "i16": "Short", "i32": "Int", "i64": "Int64", "void": "Int64", "f32": "float", "f64": "double"}
	
		if (AHKTypes.HasKey(TypeName)) {
			return AHKTypes[TypeName]
		}
		else if (InStr(TypeName, "*")) {
			return "Ptr"
		}
		else {
			return TypeName
		}
	}
	
	CallFunction(Name, Params*) {
		TypedParams := []
		
		for k, ParamPair in this.Node.Functions[Name].Params {
			TypedParams.Push(this.GetAHKType(ParamPair[1].Value))
			TypedParams.Push(Params[k]) ; Use the types the function is defined to take instead of requiring people to 
			; pass types for each param
		}
		
		TypedParams.Push(this.GetAHKType(this.Node.Functions[Name].ReturnType.Value)) ; Use the function's return type
		; for the DllCall return type
		
		return DllCall(this.GetFunctionPointer(Name), TypedParams*) ; And then call the function by pointer
	}
	GetFunctionPointer(Name) {
		Offset := this.Offsets[Name]
		
		if (Offset = "") {
			Throw, Exception("Function " Name " not found.")
		}
		
		return this.pMemory + Offset
	}
	GetFunction(Name) {
		Address := this.GetFunctionPointer(Name)
		Node := this.Node.Functions[Name]
		
		return {"Address": Address, "Define": Node}
	}
	
	ToAHK(WithName := "MyProgram") {
		CodeString := this.GenerateInitFunction(WithName)
		CodeString .= this.GenerateCallerFunction(WithName)
		CodeString .= this.GenerateStubFunctions(WithName)
		
		return CodeString
	}
	
	GenerateStubFunctions(WithName) {
		StubFunctionsString := ""
		
		for FunctionName, FunctionNode in this.Node.Functions {
			if (FunctionNode.Type != ASTNodeTypes.Define || FunctionNode.Keyword != Keywords.Define) {
				Continue
			}
			
			DefinitionString := WithName FunctionName "("
			ParameterListString := ""
			
			for k, ParamPair in FunctionNode.Params {
				ParameterListString .= ParamPair[2].Value ", "
			}
			
			ParameterListString := SubStr(ParameterListString, 1, -2)
			DefinitionString .= ParameterListString ") {`n"
			
			BodyString := "`treturn " WithName "Call(""" FunctionName """" (ParameterListString = "" ? "" : ", ") ParameterListString ")`n"
			BodyString .= "}`n"
			
			StubFunctionsString .= DefinitionString BodyString
		}
		
		return StubFunctionsString
	}
	
	
	GenerateCallerFunction(WithName) {
		DefinitionString := WithName "Call(Name, Parameters*) {`n"
		DefinitionString .= "`tstatic pProgram := " WithName "Init()`n"
		
		ParameterTypesString := "`tstatic ParameterTypes := {"
		FunctionOffsetsString := "`tstatic FunctionOffsets := {"
		ReturnTypesString := "`tstatic ReturnTypes := {"
		
		for FunctionName, FunctionNode in this.Node.Functions {
			if (FunctionNode.Type != ASTNodeTypes.Define || FunctionNode.Keyword != Keywords.Define) {
				Continue
			}
			
			ParameterTypesString .= """" FunctionName """: ["
			FunctionOffsetsString .= """" FunctionName """: " this.Offsets[FunctionName] ", "
			ReturnTypesString .= """" FunctionName """: """ this.GetAHKType(FunctionNode.ReturnType.Value) """, "
			
			for k, ParamPair in FunctionNode.Params {
				ParameterTypesString .= """" this.GetAHKType(ParamPair[1].Value) """, "
			}
			
			ParameterTypesString := (FunctionNode.Params.Count() ? SubStr(ParameterTypesString, 1, -2) : ParameterTypesString) "], "
		}
		
		ParameterTypesString := SubStr(ParameterTypesString, 1, -2) "}`n"
		FunctionOffsetsString := SubStr(FunctionOffsetsString, 1, -2) "}`n"
		ReturnTypesString := SubStr(ReturnTypesString, 1, -2) "}`n"
		
		ParamBuilderString := "`tfor k, Type in ParameterTypes[Name] {`n"
		ParamBuilderString .= "`t`tParameters.InsertAt(1 + ((k - 1) * 2), Type)`n"
		ParamBuilderString .= "`t}`n`n"
		ParamBuilderString .= "`tParameters.Push(ReturnTypes[Name])`n"
		
		CallingCode := "`treturn DllCall(pProgram + FunctionOffsets[Name], Parameters*)`n"
		CallingCode .= "}`n"
		
		return DefinitionString "`n" ParameterTypesString ReturnTypesString FunctionOffsetsString "`n" ParamBuilderString "`n" CallingCode
	}
	
	
	GenerateInitFunction(WithName) {
		DefinitionString := WithName "Init() {`n"
		DefinitionString .= "`tstatic FunctionTable`n"
	
		FunctionsString := "`tVarSetCapacity(FunctionTable, " this.CodeGen.IndexToFunction.Count() * 8 ", 0)`n"
		
		DllList := {}
		
		for k, Name in this.CodeGen.IndexToFunction {
			DllFile := StrSplit(Name, "@")[2]
			
			if !(DllList.HasKey(DllFile)) {
				DllList[DllFile] := {}
				FunctionsString .= "`th" DllFile " := DllCall(""GetModuleHandle"", ""Str"", """ DllFile """, ""Ptr"")`n"
			}
		}
		
		for k, Name in this.CodeGen.IndexToFunction {
			Name := StrSplit(Name, "@")
			
			FunctionName := Name[1]
			DllFile := Name[2]
			
			if !(DllList[DllFile].HasKey(FunctionName)) {
				FunctionsString .= "`tp" FunctionName " := DllCall(""GetProcAddress"", ""Ptr"", h" DllFile ", ""AStr"", """ FunctionName """, ""Ptr"")`n"
			}
		}
		
		for k, Name in this.CodeGen.IndexToFunction {
			FunctionsString .= "`tNumPut(p" StrSplit(Name, "@")[1] ", &FunctionTable + 0, " (k - 1) * 8 ", ""Ptr"")`n"
		}
		
		Bytes := this.CodeGen.Link(True)
		
		BytesString := "`tBytes := []`n" 
		BytesString .= "`tBytes.Push("
		
		for k, Byte in Bytes {
			if (Mod(k, 200) = 0) {
				BytesString := SubStr(BytesString, 1, -2) ")`n"
				BytesString .= "`tBytes.Push("
			}
			
			if (IsObject(Byte) && Byte[1] = "FunctionTable") {
				FunctionTableIndex := k - 1
				BytesString .= "0, "
			}
			else {
				BytesString .= Byte ", "
			}
		}
		
		BytesString := SubStr(BytesString, 1, -2) ")`n"
		
		MemoryString := "`tpMemory := DllCall(""VirtualAlloc"", ""UInt64"", 0, ""Ptr"", " Bytes.Count() ", ""Int"", 0x00001000 | 0x00002000, ""Int"", 0x04)`n"
		MemoryString .= "`tOnExit(Func(""DllCall"").Bind(""VirtualFree"", ""Ptr"", pMemory, ""Ptr"", 0, ""UInt"", 0x00008000))`n"
		
		ForLoopString := "`tfor k, Byte in Bytes {`n"
		ForLoopString .= "`t`tNumPut(Byte, pMemory + 0, k - 1, ""UChar"")`n"
		ForLoopString .= "`t}`n"
		
		CleanupString := "`tNumPut(&FunctionTable, pMemory + 0, " FunctionTableIndex ", ""Ptr"")`n"
		
		MakeExecutableString := "`tDllCall(""VirtualProtect"", ""Ptr"", pMemory, ""Ptr"", " Bytes.Count() ", ""UInt"", 0x20, ""UInt*"", OldProtection)`n"
		MakeExecutableString .= "`treturn pMemory`n"
		MakeExecutableString .= "}`n"
		
		return DefinitionString "`n" FunctionsString "`n" BytesString "`n" MemoryString "`n" ForLoopString "`n" CleanupString "`n" MakeExecutableString
	}
}

class Module {
	static Modules := {}
	
	; Simple class to let modules exist at all, Module.Find is called by codegen while linking, and will compile and link any modules needed, and return a function pointer to them
	; Note: The only way to add modules currently is through Module.Add, there is no syntax for it
	
	Add(Name, ModuleClass) {
		this.Modules[Name] := {"Class": ModuleClass, "AST": False}
	}
	Find(Name) {
		FoundModule := this.Modules[Name]
		
		if !(FoundModule) {
			Throw, Exception("Module " Name " not found.")
		}
		
		if !(IsObject(FoundModule.AST)) {
			FoundModule.AST := this.Parse(Name)
		}
		
		return FoundModule.AST
	}
	Parse(Name) {
		CodeString := this.Modules[Name].Class.Code
		
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		CodeOptimizer := new ASTOptimizer(CodeLexer, CodeParser, Flags)
		CodeOptimizer.OptimizeProgram(CodeAST)
		
		return CodeAST
	}
}


Module.Add("Memory", Builtins.Memory)
Module.Add("String", Builtins.String)
Module.Add("Console", Builtins.Console)

class Builtins {
	class Memory {
		static Code = "
		(
			DllImport i64 GetProcessHeap() {Kernel32.dll, GetProcessHeap}
			DllImport void* HeapAlloc(i64, i32, i64) {Kernel32.dll, HeapAlloc}
			DllImport void* HeapReAlloc(i64, i32, void*, i64) {Kernel32.dll, HeapReAlloc}
			DllImport i8 HeapFree(i64, i32, void*) {Kernel32.dll, HeapFree}
			
			i64 ProcessHeap := GetProcessHeap()
			i32 HEAP_ZERO_MEMORY := 0x00000008
			
			define void* Alloc(i64 Size) {
				return HeapAlloc(ProcessHeap, HEAP_ZERO_MEMORY, Size)
			}
			define void* ReAlloc(void* Memory, i64 NewSize) {
				return HeapReAlloc(ProcessHeap, HEAP_ZERO_MEMORY, Memory, NewSize)
			}
			define i8 Free(void* Memory) {
				return HeapFree(ProcessHeap, 0, Memory)
			}
		)"
	}
	
	class String {
		static Code := "
		(
			define i32 ALen(i8* AString) {
				for (i32 Length := 0, *(AString + Length) != 0, Length += 1) {
				}
				
				return Length
			}
			define i32 WLen(i16* WString) {
				for (i32 Length := 0, *(WString + Length) != 0, Length += 2) {
				}
				
				return (Length / 2)
			}
			
			Import Memory
			
			define void AReverse(i8* Buffer) {
				i8 Temp := 0
				i32 Length := ALen(Buffer)
				
				for (i32 Index := 0, Index < Length, Index++) {
					Temp := *(Buffer + Index)
					(Buffer + Index) *= *(Buffer + Length - 1)
					(Buffer + Length - 1) *= Temp
					
					Length--
				}
			}
			
			define i8* IToA(i64 Number) {
				i8* Buffer := (Memory:Alloc(100) As i8*)
				i8 Sign := 0
				
				if (Number = 0) {
					Buffer *= '0'
					return Buffer
				}
				
				if (Number < 0) {
					Sign := 1
					Number := -Number
				}
				
				for (i32 Index := 0, Number > 0, Index++) {
					(Buffer + Index) *= (Number % 10) + '0'
					Number := Number / 10
				}
				
				if (Sign) {
					(Buffer + Index) *= '-'
				}
				
				(Buffer + Index + 1) *= 0
				
				AReverse(Buffer)
				
				return Buffer
			}
			define i16* IToW(i64 Number) {
				i8* AString := IToA(Number)
				i16* WString := AToW(AString)
				
				Memory:Free(AString As void*)
				
				return WString
			}
			
			define i16* AToW(i8* AString) {
				i32 Length := ALen(AString)
				i16* NewBuffer := (Memory:Alloc((Length * 2) + 2) As i16*)
				
				for (i32 Index := 0, Index < Length, Index++) {
					(NewBuffer + (Index * 2)) *= *(AString + Index)
				}
				
				return NewBuffer
			}
		)"
	}
	
	class Console {
		static Code := "
		(
			DllImport i64 GetStdHandle(i32) {Kernel32.dll, GetStdHandle}
			DllImport i8 WriteConsole(i64, i16*, i32, i32*, i64) {Kernel32.dll, WriteConsoleW}
			DllImport i8 SetConsoleTextAttribute(i64, i16) {Kernel32.dll, SetConsoleTextAttribute}
			DllImport i8 ReadConsole(i64, void*, i32, i32*, void) {Kernel32.dll, ReadConsoleW}
			
			Import String
			
			i64 STDIN := GetStdHandle(-10)
			i64 STDOUT := GetStdHandle(-11)
			i64 STDERR := GetStdHandle(-12)
			
			define i32 Write(i16* Characters) {
				i32 CharactersWritten := 0
				
				WriteConsole(STDOUT, Characters, String:WLen(Characters), &CharactersWritten, 0)
				
				return CharactersWritten
			}
			
			define i32 WriteLine(i16* Characters) {
				i64 NewLine := 0x000D000A
				
				i32 ReturnValue := Write(Characters)
				Write((&NewLine) As i16*)
				
				return ReturnValue
			}
			
			define void White() {
				SetColor(1, 1, 1, 1, 0, 0, 0, 0)
			}
			define void Red() {
				SetColor(0, 1, 0, 0, 0, 0, 0, 0)
			}
			define void Green() {
				SetColor(0, 0, 1, 0, 0, 0, 0, 0)
			}
			define void Blue() {
				SetColor(0, 0, 0, 1, 0, 0, 0, 0)
			}
			
			define void ResetColors() {
				SetColor(1, 1, 1, 1, 0, 0, 0, 0)
			}
			
			define void SetColor(i8 ForegroundBright, i8 ForegroundRed, i8 ForegroundGreen, i8 ForegroundBlue, i8 BackgroundBright, i8 BackgroundRed, i8 BackgroundBlue, i8 BackgroundGreen) {
				i16 ColorSettings := 0
				
				ColorSettings := ColorSettings | (BackgroundBright * 0x80)
				ColorSettings := ColorSettings | (BackgroundRed * 0x40)
				ColorSettings := ColorSettings | (BackgroundGreen * 0x20)
				ColorSettings := ColorSettings | (BackgroundBlue * 0x10)
				
				ColorSettings := ColorSettings | (ForegroundBright * 0x08)
				ColorSettings := ColorSettings | (ForegroundRed * 0x04)
				ColorSettings := ColorSettings | (ForegroundGreen * 0x02)
				ColorSettings := ColorSettings | (ForegroundBlue * 0x01)
				
				SetConsoleTextAttribute(STDOUT, ColorSettings)
			}
			
			define i16* ReadLine() {
				void* Buffer := Memory:Alloc(64)
				i32 ChunkCount := 1
				
				for (i32 CharactersRead := 32, CharactersRead = 32, ChunkCount++) {
					i32 BufferOffset := (ChunkCount - 1) * 64
					CharactersRead := 32
					
					ReadConsole(STDIN, Buffer + BufferOffset, 32, &CharactersRead, 0)
					
					Buffer := Memory:ReAlloc(Buffer, BufferOffset + 128)
				}
				
				return (Buffer As i16*)
			}
		)"
	}
	
	class __Runtime__ {
		static Code := "
		(
			DllImport i16* __GetCommandLineW() {Kernel32.dll, GetCommandLineW}
			DllImport void* __CommandLineToArgvW(i16*, i64*) {Shell32.dll, CommandLineToArgvW}
			
			
			
			DllImport void __LocalFree(void*) {Kernel32.dll, LocalFree}
			DllImport void __ExitProcess(i32) {Kernel32.dll, ExitProcess}
			
			define void __RunTime__SetGlobals() {
				
			}
			define void __RunTime__CallMain() {
				__RunTime__SetGlobals()
				
				i64 __ArgC := 0
				void* __ArgV := __CommandLineToArgvW(__GetCommandLineW(), &__ArgC)
				
				i32 __ExitCode := (Main(__ArgC, __ArgV) as i32)
				
				__LocalFree(__ArgV)
				
				__ExitProcess(__ExitCode)
			}
		)"
	}
}