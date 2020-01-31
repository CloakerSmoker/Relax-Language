#Include %A_ScriptDir%
#Include Interface.ahk

SetBatchLines, -1

; TODO: Pick a name

; 6276 lines

Code = 
( % 
Import Console
Import String
Import Memory

define i64 Main(i64 ArgC, void* ArgV) {
	Console:SetColor(0, 1, 0, 0, 0, 0, 0, 0)
	Console:WriteLine(String:IToW(ArgC))
	
	Console:SetColor(1, 1, 0, 1, 0, 0, 0, 0)
	
	
	for (i64 Index := 0, Index < ArgC, Index++) {
		i16* NextArg := *(ArgV + (Index * 8))
		Console:WriteLine(NextArg)
	}
	
	Console:Blue()
	Console:AWrite("Enter some text!")
	
	i16* Input := Console:ReadLine()
	
	
	if (String:WAEquals(Input, "abc")) {
		Console:Blue()
	}
	else {
		Console:Red()
	}
	
	Console:AWrite("You entered: ")
	
	Console:Write(Input)
	Memory:Free(Input As void*)
	
	Console:ResetColors()
}
)
;Console:Blue()
; MessageBoxW(0, NextArg, NextArg, 0)

Start := A_TickCount
C := LanguageName.CompileToEXE(Code)
End := A_TickCount
MsgBox, % "Done, took: " End - Start " ms`n`n" ; C.Program.Stringify()
