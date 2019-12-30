class Config {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Typing.ahk
#Include Parser.ahk
#Include CodeGen.ahk
#Include Compiler.ahk

Module.Add("Handle", Builtins.Handle)
Module.Add("Memory", Builtins.Memory)
Module.Add("Tester", Builtins.Tester)


; TODO: Pick a name
; TODO: Fix typing using global scope instead of function scope
; TODO: CodeGen linking rewrite
; TODO: (Related to above) Shorter Jmp encodings
; TODO: Write more tests
; TODO: Make type checking much more strict
; TODO: Eventually find a smarted way to handle variables
; TODO: Start to optimize code
; TODO: Fix floating point comparison operators

class LanguageName {
	; Change ^ when you've come up with a name
	
	static VERSION := "1.0.0-alpha.11"

	CompileCode(CodeString) {
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
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

Code = 
( % 
define Int64 T1() {
	Int8* StringBuffer := Memory:Alloc(40) as Int8*
	
	StringBuffer *= 'h'
	StringBuffer + 1 *= 'i'
	
	return StringBuffer as Int64
}
)

;global Int64 TestGlobal
;
;define Int64 T1(Int64 Value) {
;	TestGlobal := Value
;	Int8* A := Memory:HeapAlloc(8)
;	return 0
;}
;define Int64 T2() {
;	return TestGlobal
;}


;define Int64 Test3(Int64 B) {if (B >= 2) {return 20} return 90}
;
;DllImport Int64 MessageBoxA(Int64*, Int8*, Int8*, Int32) {User32.dll, MessageBoxA}
;define Int64 Test2(Int64 P1, Int8* BT, Int8* TT) {return MessageBoxA(P1, TT, BT, 0)}

;define Int8 Test(Int64 P1) {
;	Int8* TitleText := "this is the title" 
;	Int8* BodyText := "this is the body text"
;	Int16 A := 999
;	/*Int8* B := &A*/
;	/*B *= 999*/
;
;	for (Int64 i := 0, i <= P1, i++) {
;		(BodyText + i) *= *(BodyText + 12 + i + -4)
;		Test2(0, TitleText, BodyText)
;	}
;
;	return 0
;}


;MsgBox, % LanguageName.FormatCode(Code)
R := LanguageName.CompileCode(Code)

MsgBox, % R.Node.Stringify()
MsgBox, % (Clipboard := R.CodeGen.Stringify())
MsgBox, % "Result: " StrGet(R.CallFunction("T1", 6, 1, 4, 3, 4), "UTF-8") "`n" A_LastError
;MsgBox, % "Stored: " R.CallFunction("T2")

; Int64* A := &B
; A := 99


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
	class Tester {
		static Code := "
		(
			DllImport Int64 MessageBoxA(Int64, Int8*, Int8*, Int32) {User32.dll, MessageBoxA}
			
			define void Main() {
				Int8* Title := ""Tester: Main Title Text""
				Int8* Body := ""Tester: Main Body Text""
				MessageBoxA(0, Body, Title, 0)
			}
			
			define void Test() {
				Int8* Title := ""Tester: Test Title Text""
				Int8* Body := ""Tester: Test Body Text""
				MessageBoxA(0, Body, Title, 0)
			}
			
			define void Exit() {
				Int8* Title := ""Tester: Exit Title Text""
				Int8* Body := ""Tester: Exit Body Text""
				MessageBoxA(0, Body, Title, 0)
			}
		)"
	}
}

class Module {
	static Modules := {}

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