class Config {
	static DEBUG := True
	static VERSION := "0.1.3"
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
DllImport Int64 MessageBoxA(Pointer, Pointer, Pointer, Int32) {User32.dll, MessageBoxA}

define Int64 Test(Int64 P1, Int64 P2, Int64 P3) {
	Pointer TitleText := "This is a message box"
	Pointer BodyText := "This is the body of the message box"
	Int64 i
	
	for (i := 0, i <= 1, i++) {
		MessageBoxA(0, TitleText, BodyText, 0)
	}
	
	return 0
}
)

;	for (Int64 i := 0, i <= P2, i++) {
;		MessageBoxA(0, TitleText, BodyText, 0)
;	}

;DllImport Int64 MessageBeep(Int32) {User32.dll, MessageBeep}
;DllImport Int64 MessageBoxA(Pointer, Pointer, Pointer, Int32) {User32.dll, MessageBoxA}
;DllImport Int64 Lock() {User32.dll, LockWorkStation}
;DllImport Int64 CreateFileA(Pointer, Int32, Int32, Pointer, Int32, Int32, Int32) {Kernel32.dll, CreateFileA}

; (6 + MessageBoxA(0, P, 0, 0))
; Pointer S := "hello":Store()
;  Pointer P := MessageBoxA(0, A:Address(), 0, 0)
;define Double Test2(Int64 P1, Int64 P2, Double P3) {
;	return (P3 * 2) / 3
;}

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
	s .= v.Debug() "`n"
}
;MsgBox, % s

Pest := new Parser(Test)
a := Pest.Start()

MsgBox, % a.Stringify()

C := new Compiler(Test, Pest.Typing)
G := C.CompileProgram(a)

MsgBox, % (Clipboard := G.CodeGen.Stringify())

MsgBox, % "Result: " G.CallFunction("Test", 99, 1, 4) "`n" A_LastError

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