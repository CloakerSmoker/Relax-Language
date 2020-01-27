class Config {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Interface.ahk

; TODO: Pick a name
; TODO: Write more tests
; TODO: Eventually find a smarted way to handle variables
; TODO: Redo modules, find a way to make them work better with the runtime functions
; TODO: UTF-16 support

; TODO: Switch modules to be baked into syntax
; TODO: Modules have to just flat out be redone
; With compiling to EXE being a thing, and inline functions being so gimped to debug
;  it's time to work modules into a real thing. I'm thinking that every time a module is called, we should merge
;   namespaces, and have tokens track their own source for throwing errors

; 6276 lines

Code = 
( % 
DllImport i64 MessageBoxA(i64*, i8*, i8*, i32) {User32.dll, MessageBoxA}
DllImport i64 MessageBoxW(i64*, i16*, i16*, i32) {User32.dll, MessageBoxW}
DllImport i8 CloseHandle(i64) {Kernel32.dll, CloseHandle}
DllImport void* VirtualAlloc(void*, i32, i32, i32) {Kernel32.dll, VirtualAlloc}
DllImport i8 VirtualFree(void*, i32, i32) {Kernel32.dll, VirtualFree} 

define i64 Main(i64 ArgC, void* ArgV) {
	MessageBoxW(0, *ArgV, *ArgV, 0)
	
	MessageBoxA(0, "I embrace the .exe format now, it is a work of art.", "My Life Is Complete", 0)
	return ArgC
}
)


Start := A_TickCount
LanguageName.CompileToEXE(Code)
End := A_TickCount
MsgBox, % "Done, took: " End - Start " ms`n`n" 

R := LanguageName.CompileCode(Code, {"Features": LanguageNameFlags.ToAHK})

MsgBox, % R.Node.Stringify()
MsgBox, % (Clipboard := R.CodeGen.Stringify())

VarSetCapacity(A, 20, 0)
loop, 20 {
	NumPut(5, &A + 0, A_Index - 1, "Char")
}
MsgBox, % "Result: " R.CallFunction("T2", &A, 20, 1, 3, 4, 2) "`n" A_LastError 