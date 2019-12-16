﻿class Config {
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
; TODO: Write more tests
; TODO: Make type checking much more strict
; TODO: Eventually find a smarted way to handle variables
; TODO: Start to optimize code

class LanguageName {
	; Change ^ when you've come up with a name
	
	static VERSION := "1.0.0-alpha.2"

	CompileCode(CodeString) {
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		CodeCompiler := new Compiler(CodeLexer, CodeParser)
		Program := CodeCompiler.CompileProgram(CodeAST)
		
		return Program
	}

}

Code = 
( % 
DllImport Int64 MessageBoxA(Pointer, Pointer, Pointer, Int32) {User32.dll, MessageBoxA}

define Int64 Test(Int64 P1) {
	Pointer TitleText := "this is the title"
	Pointer BodyText := "this is the body text"

	for (Int64 i := 0, i <= P1, i++) {
		Tes t2(0, TitleText, BodyText)
	}

	return 0
}
define Int64 Test2(Int64 P1, Pointer TT, Pointer BT) {
	return MessageBoxA(P1, TT, BT, 0)
}
)
; TODO: Fix the }}}}}}}}}}}}} errror when a non-token AST node is passed to PrettyError

R := LanguageName.CompileCode(Code)

MsgBox, % R.Node.Stringify()
MsgBox, % (Clipboard := R.CodeGen.Stringify())
MsgBox, % "Result: " R.CallFunction("Test", 3, 1, 4, 3, 4) "`n" A_LastError