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
	Console:TextColor(Console:Red)
	Console:IWriteLine(ArgC)
	
	Console:TextColor(Console:Bright | Console:Red | Console:Blue)
	
	
	for (i64 Index := 0, Index < ArgC, Index++) {
		i16* NextArg := *(ArgV + (Index * 8))
		Console:WriteLine(NextArg)
	}
	
	Console:TextColor(Console:Blue)
	Console:AWrite("Enter some text!")
	
	i16* Input := Console:ReadLine()
	
	i8 InputIsInt := 0
	i64 AsInt := String:WToI(Input, &InputIsInt)
	
	if !(InputIsInt) {
		Console:AWriteLine("You should have entered a number")
	}
	else {
		Console:IWriteLine(AsInt + 1)
	}
	
	if (String:WAEquals(Input, "abc")) {
		Console:TextColor(Console:Blue)
	}
	else {
		Console:TextColor(Console:Red)
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
