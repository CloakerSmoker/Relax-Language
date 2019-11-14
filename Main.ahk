class VAL {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk
#Include CodeGen.ahk
#Include Compiler.ahk

Code = 
(
define Int64 Add(Int64 ValueOne, Int64 ValueTwo) {
	if (0) {
		return 55
	}
	else if (0) {
		return 99
	}
	else {
		return 101
	}
}
)

Test := new Lexer(Code)
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Stringify() "`n"
}
;MsgBox, % s

Pest := new Parser(Test)
a := Pest.Start()

MsgBox, % a[1].Stringify()

C := new Compiler(Test)
G := C.CompileFunction(a[1])

VarSetCapacity(M, 8, 0)
NumPut(0, &M + 0, 0, "Char")

MsgBox, % "Input:`n" a[1].Stringify() "`nGenerated code: `n" (Clipboard := G.Stringify()) "`nResult (60, 9): " G.Execute("Ptr", &M, "Ptr", 69)
;MsgBox, % NumGet(&M + 0, 0, "Short")
; deref cptr as char
; char(cptr)
; cptr:deref(char)
;  deref(cptr, char)

; small:cast(int64)
;  cast(small, int64)

; ptr:Put(Value, Type)