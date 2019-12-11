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

define Int64 Test(Int64 P1, Int64 P2, Int64 P3, Int64 P4, Int64 P5) {
	Pointer TitleText := "This is a message box"
	Pointer BodyText := "This is the body of the message box"
	
	for (Int64 i := 0, i <= P4, i++) {
		Test2(0, TitleText, BodyText)
	}
	
	return 0
}
define Int64 Test2(Int64 P1, Pointer T1, Pointer T2) {
	MessageBoxA(0, T1, T2, 0)
	return P1 + 20
}
)

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

MsgBox, % "Result: " G.CallFunction("Test", 99, 1, 4, 3, 4) "`n" A_LastError