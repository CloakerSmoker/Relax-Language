class Config {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Interface.ahk

; TODO: Pick a name
; TODO: Write more tests
; TODO: Eventually find a smarted way to handle variables
; TODO: Redo modules, find a way to make them work better with the runtime functions
; TODO: Figure out how to do ArgC/ArgV
; TODO: UTF-16 support

; TODO: Switch modules to be baked into syntax
; TODO: Modules have to just flat out be redone
; With compiling to EXE being a thing, and inline functions being so gimped to debug
;  it's time to work modules into a real thing. I'm thinking that every time a module is called, we should merge
;   namespaces, and have tokens track their own source for throwing errors

; 6276 lines

Code = 
( % 
DllImport Int64 MessageBoxA(Int64*, Int8*, Int8*, Int32) {User32.dll, MessageBoxA}
DllImport Int64 MessageBoxW(Int64*, Int16*, Int16*, Int32) {User32.dll, MessageBoxW}
DllImport Int8 CloseHandle(Int64) {Kernel32.dll, CloseHandle}
DllImport void* VirtualAlloc(void*, Int32, Int32, Int32) {Kernel32.dll, VirtualAlloc}
DllImport Int8 VirtualFree(void*, Int32, Int32) {Kernel32.dll, VirtualFree} 

define Int64 Main(Int64 ArgC, void* ArgV) {
	MessageBoxW(0, *ArgV, *ArgV, 0)
	
	MessageBoxA(0, "I embrace the .exe format now, it is a work of art.", "My Life Is Complete", 0)
	return ArgC
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

Start := A_TickCount
LanguageName.CompileToEXE(Code)
End := A_TickCount
MsgBox, % "Done, took: " End - Start " ms`n`n" 
;MsgBox, % LanguageName.CompileToEXE(Code)

;MsgBox, % LanguageName.FormatCode(Code)
;MsgBox, % LanguageName.CompileToAHKFunctions(Code)

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