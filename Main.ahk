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
	Test2(0, P1, P2)
	
	return P1
}
define Int64 Test2(Int64 P1, Int64 T1, Pointer T2) {
	T1 := 999
	
	return 0
}
)

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

MsgBox, % "Result: " G.CallFunction("Test", 99, 1, 4, 3, 4) "`n" A_LastError