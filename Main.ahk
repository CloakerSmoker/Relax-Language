class Config {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Interface.ahk

SetBatchLines, -1

; TODO: Pick a name
; TODO: Write more tests
; TODO: Eventually find a smarted way to handle variables

; 6276 lines

Code = 
( % 
Import Console
Import String

define i64 Main(i64 ArgC, void* ArgV) {
	Console:SetColor(0, 1, 0, 0, 0, 0, 0, 0)
	Console:WriteLine(String:IToW(ArgC))
	
	Console:SetColor(1, 1, 0, 1, 0, 0, 0, 0)
	
	for (i64 Index := 0, Index < ArgC, Index++) {
		i16* NextArg := *(ArgV + (Index * 8))
		Console:WriteLine(NextArg)
	}
	
	Console:WriteLine(String:AToW("Enter some text!"))
	
	Console:Blue()
	i16* Input := Console:ReadLine()
	
	Console:Red()
	Console:Write(String:AToW("You entered: "))
	
	Console:Blue()
	Console:Write(Input)
	
	Console:ResetColors()
}
)
; MessageBoxW(0, NextArg, NextArg, 0)

Start := A_TickCount
LanguageName.CompileToEXE(Code)
End := A_TickCount
MsgBox, % "Done, took: " End - Start " ms`n`n" 
exitapp
;MessageBoxA(0, "I embrace the .exe format now, it is a work of art.", "My Life Is Complete", 0)
R := LanguageName.CompileCode(Code, {"Features": LanguageNameFlags.ToAHK})

MsgBox, % R.Node.Stringify()
MsgBox, % (Clipboard := R.CodeGen.Stringify())

VarSetCapacity(A, 20, 0)
loop, 20 {
	NumPut(5, &A + 0, A_Index - 1, "Char")
}
MsgBox, % "Result: " R.CallFunction("T2", &A, 20, 1, 3, 4, 2) "`n" A_LastError 