class Config {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk
#Include CodeGen.ahk
#Include Compiler.ahk

; TODO: Pick a name
; TODO: CodeGen linking rewrite
; TODO: (Related to above) Shorter Jmp encodings
; TODO: Clean up source string passing between step classes
; TODO: Clean up tokenizer/typing passing
; TODO: Write more tests
; TODO: Make type checking much more strict
; TODO: Eventually find a smarted way to handle variables
; TODO: Start to optimize code

class LanguageName {
	; Change ^ when you've come up with a name
	
	static VERSION := "1.0.0-alpha.0"

	CompileCode(CodeString) {
		CodeLexer := new Lexer(CodeString) ; TODO: Clean up this process, it's very inconistant
		CodeTokens := CodeLexer.Start()
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start()
		
		CodeCompiler := new Compiler(CodeLexer, CodeParser.Typing)
		Program := CodeCompiler.CompileProgram(CodeAST)
		
		return {"Program": Program, "AST": CodeAST} ; Maybe change CompiledProgram to include the AST/Source by default?
	}

}


Code = 
( % 
DllImport Int64 MessageBoxA(Pointer, Pointer, Pointer, Int32) {User32.dll, MessageBoxA}

define Int64 Test(Int64 P1) {
	Pointer TitleText := "this is the title"
	Pointer BodyText := "this is the body text"

	for (Int64 i := 0, i <= P1, i++) {
		Test2(0, TitleText, BodyText)
	}

	return 0
}
define Int64 Test2(Int64 P1, Pointer TT, Pointer BT) {
	return MessageBoxA(P1, TT, BT, 0)
}
)

R := LanguageName.CompileCode(Code)
A := R.AST
G := R.Program

MsgBox, % A.Stringify()
MsgBox, % (Clipboard := G.CodeGen.Stringify())
MsgBox, % "Result: " G.CallFunction("Test", 3, 1, 4, 3, 4) "`n" A_LastError