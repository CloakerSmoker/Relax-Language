class Config {
	static DEBUG := True
	static VERSION := "0.1.4"
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk
#Include CodeGen.ahk
#Include Compiler.ahk

; TODO: CodeGen linking rewrite
; TODO: (Related to 1) Shorter Jmp encodings

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
;define Int64 Test(Int64 P1) {
;	Test2(P1)
;	
;	return P1
;}

;	for (Int64 i := 0, i <= P4, i++) {
;		Test2(0, TitleText, BodyText)
;	}

Test := new Lexer(Code)
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Debug() "`n"
}
;MsgBox, % s

Pest := new Parser(Test)
a := Pest.Start()

MsgBox, % a.Stringify()

C := new Compiler(Test, Pest.Typing)
G := C.CompileProgram(a)

MsgBox, % (Clipboard := G.CodeGen.Stringify())

MsgBox, % "Result: " G.CallFunction("Test", 3, 1, 4, 3, 4) "`n" A_LastError