class VAL {
	static DEBUG := False
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


Code = 
( % 
define Int64 Test(Int64 ValueOne, Float ValueTwo) {
	return ValueOne % 2
}
)

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

MsgBox, % a[1].Stringify()

C := new Compiler(Test, Pest.Typing)
G := C.CompileFunction(a[1])

VarSetCapacity(M, 8, 0)
NumPut(0, &M + 0, 0, "Char")

MsgBox, % "Input:`n" a[1].Stringify() "`nGenerated code: `n" (Clipboard := G.Stringify()) "`nResult (60, 9): " G.Execute("Int", 11, "Double", 6.9, "Int")
MsgBox, % NumGet(&M + 0, 0, "Short")
; deref cptr as char
; char(cptr)
; cptr:deref(char)
;  deref(cptr, char)

; small:cast(int64)
;  cast(small, int64)

; ptr:Put(Value, Type)


; asm { Move_R64_R64(RAX, RAX) }