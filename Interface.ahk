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
	
	static ToAHK := LanguageNameFlags.F1 + LanguageNameFlags.Features.DisableGlobals + LanguageNameFlags.Features.UseStackStrings
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
	
	static VERSION := "1.0.0-alpha.18"
	
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
		
		MainOffset := CodeCompiler.FunctionOffsets["__RunTime__CallMain__"]
		
		CodeEXEBuilder := new PEBuilder()
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
		
		try {
			this.CallFunction("Main") ; And try to call Main, this will fail when the program doesn't define Main
		}
		
		OnExit(this.Delete.Bind(this)) ; OnExit, bind freeing the memory we wrote the compiled code into
	}
	Delete() {
		try {
			this.CallFunction("Exit") ; Try to call the exit function, doesn't really matter if it works or not
		}
		
		DllCall("VirtualFree", "Ptr", this.pMemory, "Ptr", 0, "UInt", 0x00008000) ; Free our memory
	}
	
	GetAHKType(TypeName) {
		; Converts types that don't exist in the eyes of DllCall into regular DllCall types
		
		static AHKTypes := {"Int8": "Char", "Int16": "Short", "Int32": "Int", "void": "Int64"}
	
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

Module.Add("Handle", Builtins.Handle) ; Add some built in modules
Module.Add("Memory", Builtins.Memory)
Module.Add("Console", Builtins.Console)

class Module {
	static Modules := {}
	
	; Simple class to let modules exist at all, Module.Find is called by codegen while linking, and will compile and link any modules needed, and return a function pointer to them
	; Note: The only way to add modules currently is through Module.Add, there is no syntax for it
	
	Add(Name, ModuleClass) {
		this.Modules[Name] := {"Class": ModuleClass, "AST": False}
	}
	Find(Name, FunctionName) {
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

class Builtins {
	class Handle {
		static Code := "
		(
			DllImport Int8 CloseHandle(Int64) {Kernel32.dll, CloseHandle}
		
			inline Int8 Close(Int64 Handle) {
				return CloseHandle(Handle)
			}
		)"
	}

	class Memory {
		static Code := "
		(
			DllImport void* VirtualAlloc(void*, Int32, Int32, Int32) {Kernel32.dll, VirtualAlloc}
			DllImport Int8 VirtualFree(void*, Int32, Int32) {Kernel32.dll, VirtualFree}
			
			inline void* Alloc(Int32 Count) {
				/*
					MEM_RESERVE_COMMIT := 0x00001000 | 0x00002000
					PAGE_READWRITE := 0x04
				*/
				
				return VirtualAlloc(0, Count, 0x00001000 | 0x00002000, 0x04)
			}
			inline Int64 Free(void* Memory) {
				/*
					MEM_RELEASE := 0x00008000
				*/ 
				
				return VirtualFree(Memory, 0, 0x00008000)
			}
		)"
	}
	
	class Console {
		static Code := "
		(
			DllImport Int64 Console_GetStdHandle(Int32) {Kernel32.dll, GetStdHandle}
			DllImport Int8 Console_WriteConsole(Int64, Int16*, Int32, Int32*, void) {Kernel32.dll, WriteConsoleW}
			
			inline Int64 GetHandle(Int32 StreamID) {
				return Console_GetStdHandle(-10 - StreamID)
			}
			inline Int32 Write(Int64 Console, Int16* Text, Int32 TextLength) {
				Int32 Out_CharactersWritten := 0
				
				Console_WriteConsole(Console, Text, TextLength, &Out_CharactersWritten, 0)
				
				return Out_CharactersWritten
			}
		)"
	}
	
	class __Runtime__ {
		static Code := "
		(
			DllImport Int16* __GetCommandLineW__() {Kernel32.dll, GetCommandLineW}
			DllImport void* __CommandLineToArgvW__(Int16*, Int64*) {Shell32.dll, CommandLineToArgvW}
			
			
			
			DllImport void __LocalFree__(void*) {Kernel32.dll, LocalFree}
			DllImport void __ExitProcess__(Int32) {Kernel32.dll, ExitProcess}
			
			define void __RunTime__CallMain__() {
				Int64 __ArgC__ := 0
				void* __ArgV__ := __CommandLineToArgvW__(__GetCommandLineW__(), &__ArgC__)
				
				Int32 __ExitCode__ := (Main(__ArgC__, __ArgV__) as Int32)
				
				__LocalFree__(__ArgV__)
				
				__ExitProcess__(__ExitCode__)
			}
		)"
	}
}