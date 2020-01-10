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
	
	static VERSION := "1.0.0-alpha.12"

	; Simple class that handles creating a lexer/parser/compiler for some given code, and just returns a CompiledProgram
	;  object for you

	CompileCode(CodeString) {
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		ASTOptimizer.OptimizeProgram(CodeAST)
		
		CodeCompiler := new Compiler(CodeLexer, CodeParser)
		Program := CodeCompiler.CompileProgram(CodeAST)
		
		return Program
	}
	FormatCode(CodeString) {
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		return CodeAST.Stringify()
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
	
	ToAHK() {
		; TODO: Implement
	
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