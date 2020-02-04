#Include %A_ScriptDir%
#Include Interface.ahk

SetBatchLines, -1

; 6276 lines

; 365

class Colors {
	static White := 0x0F
	
	static Bright := 0x08
	static Red := 0x04
	static Green := 0x02
	static Blue := 0x01
	
	static BrightBlue := Colors.Bright | Colors.Blue
	
	static Purple := Colors.Red | Colors.Blue
}

HelpText =
(
		Options:
			-i [InputFile]
			-o [OutputFile] (Should have the extension "exe" or "ahk")
			--no-confirm    (Does not ask if arguments are correct before running)
			--no-overwrite-output-file (Exit when the output file already exists)
			--fast-exit (Skips asking to press {Enter} before exiting)
			--silent (Skips asking for use input)
)

ConsoleWrite(Colors.Purple, "Relax Compiler Version " Relax.Version)

;A_Args := ["-i", "Examples\HelloWorld.rlx", "-o", "a.exe"]

ArgCount := A_Args.Count()

if (ArgCount = 0) {
	ConsoleWrite(Colors.White, HelpText)
	Exit()
}

for k, Arg in A_Args {
	if (SubStr(Arg, 1, 1) != "-") {
		ConsoleWrite(Colors.Red, "Unknown arg: '" Arg "'")
		Exit()
	}
	
	Switch (Arg) {
		Case "-i": {
			InputFile := A_Args.RemoveAt(k + 1)
		}
		Case "-o": {
			OutputFile := StrReplace(A_Args.RemoveAt(k + 1), "/", "\")
			OutputType := StrSplit(StrSplit(OutputFile, "\").Pop(), ".").Pop()
		}
		Case "--no-confirm": {
			SkipConfirm := True
		}
		Case "--no-overwrite-output-file": {
			NoOverwriteOutput := True
		}
		Case "--fast-exit": {
			SkipExitConfirm := True
		}
		Case "--silent": {
			SkipConfirm := True
			SkipExitConfirm := True
		}
		Default: {
			ConsoleWrite(Colors.Red, "Unknown arg: '" Arg "'")
			Exit()
		}
	}
}

MsgBox, % SkipConfirm

if !(SkipConfirm) {
	ConsoleWrite(Colors.White, "	Input path: " InputFile)
	ConsoleWrite(Colors.White, "	Output file path: " OutputFile)
	ConsoleWrite(Colors.White, "	Output file type: " OutputType)
	ConsoleWrite(Colors.Green, "Is this correct? (y/n)")
	
	Next := ConsoleReadLine()
	
	if (Next != "y") {
		Exit()
	}
}

if !(FileExist(InputFile)) {
	ConsoleWrite(Colors.Red, "Input file does not exist.")
	Exit()
}
else if (NoOverwriteOutput && FileExist(OutputFile)) {
	ConsoleWrite(Colors.Red, "Output file already exists.")
	Exit()
}

Source := FileOpen(InputFile, "r").Read()

if (StrLen(Source) = 0) {
	ConsoleWrite(Colors.Red, "Could not read input file.")
	Exit()
}

Start := A_TickCount

if (OutputType = "ahk") {
	Relax.CompileToAHK(Source, OutputFile)
}
else {
	Relax.CompileToEXE(Source, OutputFile)
}

End := A_TickCount

ConsoleWrite(Colors.Green, "Done, took " ((End - Start) / 1000) " seconds to compile.")

Exit()

Exit() {
	global SkipExitConfirm
	
	if !(SkipExitConfirm) {
		ConsoleWrite(Colors.White, "Press {Enter} to close.")
		
		Sleep, 250
		KeyWait, Enter, D
	}
	
	ExitApp (A_IsCompiled ? 0 : DllCall("FreeConsole"))
}

ConsoleWrite(Color, Text) {
	static Console := (A_IsCompiled ? 1 : DllCall("AllocConsole"))
	static hSTDOUT := DllCall("GetStdHandle", "Int", -11, "Ptr")
	
	Text .= "`r`n"
	
	DllCall("SetConsoleTextAttribute", "Ptr", hSTDOUT, "Short", Color)
	DllCall("WriteConsoleW", "Ptr", hSTDOUT, "Str", Text, "Int", StrLen(Text), "Int*", CharactersWritten, "Ptr", 0)
	
	return CharactersWritten
}

ConsoleReadLine() {
	static hSTDIN := DllCall("GetStdHandle", "Int", -10, "Ptr")
	
	VarSetCapacity(Buffer, 64, 0)
	InputText := ""
	
	loop {
		DllCall("ReadConsoleW", "Ptr", hSTDIN, "Ptr", &Buffer, "Int", 64, "Int*", CharactersWritten, "Ptr", 0)
		
		InputText .= StrGet(&Buffer, CharactersWritten, "UTF-16")
		
		if (CharactersWritten != 64) {
			return RTrim(InputText, "`r`n")
		}
	}
}

;Console:Blue()
; MessageBoxW(0, NextArg, NextArg, 0)

Relax.CompileToAHK(Code)
MsgBox, % "DDDone"

Start := A_TickCount
C := Relax.CompileToEXE(Code)
End := A_TickCount
MsgBox, % "Done, took: " End - Start " ms`n`n" ; C.Program.Stringify()
ExitApp


ShowError(Message) {
	Gui, ShowError:New
	Gui, ShowError:Font, s10, Terminal
	Gui, ShowError:Add, Text, w800 0x80, % Message
	Gui, ShowError:Show
	
	KeyWait, Enter, D
	
	Gui, ShowError:Destroy
	
	Throw, Exception(Message)
}