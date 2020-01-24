class Config {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Interface.ahk

; TODO: Pick a name
; TODO: Write more tests
; TODO: Eventually find a smarted way to handle variables
; TODO: Redo modules, find a way to make them work better with the runtime functions

; TODO: Switch modules to be baked into syntax

Code = 
( % 
DllImport Int64 MessageBoxA(Int64*, Int8*, Int8*, Int32) {User32.dll, MessageBoxA}
DllImport Int8 CloseHandle(Int64) {Kernel32.dll, CloseHandle}
DllImport void* VirtualAlloc(void*, Int32, Int32, Int32) {Kernel32.dll, VirtualAlloc}
DllImport Int8 VirtualFree(void*, Int32, Int32) {Kernel32.dll, VirtualFree}

define Int64 Main() {
	return MessageBoxA(0, "I embrace the .exe format now, it is a work of art.", "My Life Is Complete", 0)
}

)

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

MsgBox, % LanguageName.CompileToEXE(Code)

;MsgBox, % LanguageName.FormatCode(Code)
MsgBox, % LanguageName.CompileToAHKFunctions(Code)

R := LanguageName.CompileCode(Code, {"Features": LanguageNameFlags.ToAHK})

MsgBox, % R.Node.Stringify()
MsgBox, % (Clipboard := R.CodeGen.Stringify())

VarSetCapacity(A, 20, 0)
loop, 20 {
	NumPut(5, &A + 0, A_Index - 1, "Char")
}
MsgBox, % "Result: " R.CallFunction("T2", &A, 20, 1, 3, 4, 2) "`n" A_LastError "`n" ;R.GetFunctionPointer("T1")
;MsgBox, % "Stored: " R.CallFunction("T2")

; Int64* A := &B
; A := 99