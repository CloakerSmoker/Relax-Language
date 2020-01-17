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
	}
	
	static O0 := LanguageNameFlags.Optimization.DisableAll
	static O1 := LanguageNameFlags.Optimization.EnableAll
	
	static F0 := LanguageNameFlags.Features.DisableAll
	static F1 := LanguageNameFlags.Features.EnableAll
	
	static ToAHK := LanguageNameFlags.F0 - LanguageNameFlags.Features.DisableStrings + LanguageNameFlags.Features.UseStackStrings - LanguageNameFlags.Features.DisableDllCall
}

#Include %A_ScriptDir%
#Include Parser\Utility.ahk
#Include Parser\Constants.ahk
#Include Parser\Lexer.ahk
#Include Parser\Typing.ahk
#Include Parser\Parser.ahk
#Include Compiler\Optimizer.ahk
#Include Compiler\CodeGen.ahk
#Include Compiler\Compiler.ahk

class LanguageName {
	; Change ^ when you've come up with a name
	
	static VERSION := "1.0.0-alpha.16"
	
	; Simple class that handles creating a lexer/parser/compiler for some given code, and just returns a CompiledProgram
	;  object for you
	
	static DefaultFlags := {"OptimizationLevel": LanguageNameFlags.O1, "Features": LanguageNameFlags.F1}
	
	CompileToAHKFunctions(CodeString, FunctionPrefix := "MyProgram") {
		Program := this.CompileCode(CodeString, {"Features": LanguageNameFlags.ToAHK})
		
		return Program.ToAHK()
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
		
		DllCall("VirtualFree", "Ptr", this.pMemory, "Ptr", LinkedCode.Count(), "UInt", 0x00008000) ; Free our memory
	}
	
	GetAHKType(TypeName) {
		; Converts types that don't exist in the eyes of DllCall into regular DllCall types
		
		static AHKTypes := {"Int8": "Char", "Int16": "Short", "Int32": "Int", "void": "Int64", "void*": "Ptr"}
	
		if (AHKTypes.HasKey(TypeName)) {
			return AHKTypes[TypeName]
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
			if (FunctionNode.Type = ASTNodeTypes.DllImport) {
				Continue
			}
			
			DefinitionString := WithName "_" FunctionName "("
			ParameterListString := ""
			
			for k, ParamPair in FunctionNode.Param {
				ParameterListString .= ParamPair[2].Value ", "
			}
			
			ParameterListString := SubStr(ParameterListString, 1, -2)
			DefinitionString .= ParameterListString ") {`n"
			
			BodyString := "`treturn " WithName "_Call(""" FunctionName """" (ParameterListString = "" ? "" : ", ") ParameterListString ")`n"
			BodyString .= "}`n"
			
			StubFunctionsString .= DefinitionString BodyString
		}
		
		return StubFunctionsString
	}
	
	
	GenerateCallerFunction(WithName) {
		DefinitionString := WithName "_Call(Name, Parameters*) {`n"
		DefinitionString .= "`tstatic pProgram := " WithName "_Init()`n"
		
		ParameterTypesString := "`tstatic ParameterTypes := {"
		FunctionOffsetsString := "`tstatic FunctionOffsets := {"
		ReturnTypesString := "`tstatic ReturnTypes := {"
		
		for FunctionName, FunctionNode in this.Node.Functions {
			if (FunctionNode.Type = ASTNodeTypes.DllImport) {
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
		DefinitionString := WithName "_Init() {`n"
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
		MemoryString .= "`tOnExit(Func(""DllCall"").Bind(""VirtualFree"", ""Ptr"", pMemory, ""Ptr"", " Bytes.Count() ", ""UInt"", 0x00008000))`n"
		
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

class Module {
	static Modules := {}
	
	; Simple class to let modules exist at all, Module.Find is called by codegen while linking, and will compile and link any modules needed, and return a function pointer to them
	; Note: The only way to add modules currently is through Module.Add, there is no syntax for it
	
	Add(Name, ModuleClass) {
		this.Modules[Name] := {"Class": ModuleClass, "Compiled": False}
	}
	Find(Name, FunctionName) {
		FoundModule := this.Modules[Name]
		
		if !(FoundModule) {
			Throw, Exception("Module " Name " not found.")
		}
		
		if !(IsObject(FoundModule.Compiled)) {
			FoundModule.Compiled := LanguageName.CompileCode(FoundModule.Class.Code)
		}
		
		return FoundModule.Compiled.GetFunction(FunctionName)
	}
}

class Builtins {
	class Handle {
		static Code := "
		(
			DllImport Int8 CloseHandle(Int64) {Kernel32.dll, CloseHandle}
		
			define Int8 Close(Int64 Handle) {
				return CloseHandle(Handle)
			}
		)"
	}

	class Memory {
		static Code := "
		(
			DllImport Int64 GetProcessHeap() {Kernel32.dll, GetProcessHeap}
			DllImport void* HeapAlloc(Int64, Int32, Int64) {Kernel32.dll, HeapAlloc}
			DllImport Int8 HeapFree(Int64, Int32, Int8*) {Kernel32.dll, HeapFree}
			
			global Int64 hProcessHeap
					
			define void Main() {
				hProcessHeap := GetProcessHeap()
			}
			define void Exit() {
				Handle:Close(hProcessHeap)
			}
			
			define void* Alloc(Int64 Count) {
				return HeapAlloc(hProcessHeap, 0x08, Count)
			}
			define Int8 Free(Int8* pMemory) {
				return HeapFree(hProcessHeap, 0, pMemory)
			}
		)"
	}
}