class Config {
	static DEBUG := True
	static VERSION := "0.1.0"
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk
#Include CodeGen.ahk
#Include Compiler.ahk

; TODO: CodeGen linking rewrite
; TODO: Loops
; TODO: (Related to 1) Shorter Jmp encodings

; DllImport Int64 MsgBox(Pointer, Pointer, Pointer, Int32) {User32.dll, MessageBoxW}

Code = 
( % 

define Int64 Test(Int64 P1, Int64 P2, Int64 P3) {
	return P3
}
define Int64 Test2(Int64 P1, Int64 P2, Int64 P3) {
	return P1
}
)

; 	Int64 FirstLocal := 99


;	if (0) {
;		return 55
;	}
;	else if (0) {
;		return 99
;	}
;	else {
;		return 101
;	}

Test := new Lexer(Code)
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Stringify() "`n"
}
;MsgBox, % s

Pest := new Parser(Test)
a := Pest.Start()

MsgBox, % a.Stringify()

C := new Compiler(Test, Pest.Typing)
G := C.CompileProgram(a)

MsgBox, % G.CallFunction("Test2", 99, 22, 33)

;VarSetCapacity(M, 8, 0)
;NumPut(0, &M + 0, 0, "Char")
;
;MsgBox, % "Input:`n" a[1].Stringify() "`nGenerated code: `n" (Clipboard := G.Stringify()) "`nResult (60, 9): " G.Execute("Int64", 6, "Int", 9, "Int", 1, "Int64")
;MsgBox, % NumGet(&M + 0, 0, "Short")



; char(cptr)
; cptr:deref(char)
;  deref(cptr, char)

; small:cast(int64)
;  cast(small, int64)

; ptr:Put(Value, Type)

; dllimport Int64 MessageBox(Int64, Pointer) {user32.dll, MessageBoxA}
; asm { Move_R64_R64(RAX, RAX) }