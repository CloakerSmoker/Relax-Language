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
		-o [OutputFile]	(Should have the extension "exe" or "ahk" or "dll")
		--no-confirm	(Does not ask if arguments are correct before running)
		--no-overwrite-output-file (Exit when the output file already exists)
		--fast-exit 	(Skips asking to press {Enter} before exiting)
		--silent 	(Skips asking for user input)
		--verbose	(Includes detailed logs of what the compiler is doing)
		--dump      (Lists function offsets)
)

ConsoleWrite(Colors.Purple, "Relax Compiler Version " Relax.Version)

SetWorkingDir, % A_ScriptDir
;A_Args := StrSplit("-i Examples\Struct.rlx -o out.exe --no-confirm", " ")
;A_Args := StrSplit("-i Bootstrap\Lexer.rlx -o out.exe --dump --no-confirm", " ")

;todo memory module is fucked

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
			Seperator := InStr(InputFile, "\") ? "\" : "/"
			
			SetWorkingDir, % A_WorkingDir Seperator SubStr(InputFile, 1, InStr(InputFile, Seperator))
			InputFile := SubStr(InputFile, InStr(InputFile, Seperator) + 1)
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
		Case "--verbose": {
			IsVerbose := True
		}
		Case "--print-ast": {
			PrintAST := True
		}
		Case "--dump": {
			DumpOffsets := True
		}
		Default: {
			ConsoleWrite(Colors.Red, "Unknown arg: '" Arg "'")
			Exit()
		}
	}
}

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

HasHadError := False
Start := A_TickCount

try {
	if (OutputType = "ahk") {
		CodeCompiler := Relax.CompileToAHK(Source, OutputFile)
	}
	else if (OutputType = "dll") {
		CodeCompiler := Relax.CompileToEXE(Source, OutputFile, True)
	}
	else {
		CodeCompiler := Relax.CompileToEXE(Source, OutputFile)
	}
	
	if (HasHadError) {
		Throw, Exception("Dummy error|")
	}
}
catch E {
	ConsoleWrite(Colors.Red, "Fatal error, bailing out.`n" (InStr(E.Message, "|") ? "" : E.Message))
	Exit()
}

End := A_TickCount

if (PrintAST) {
	for k, v in StrSplit(CodeCompiler.Program.Stringify(), "`n", "`r") {
		ConsoleWrite(Colors.White, v)
	}
}

if (DumpOffsets) {
	Base := CodeCompiler.PEBuilder.BaseOfCode
	
	for k, v in CodeCompiler.FunctionOffsets {
		ConsoleWrite(Colors.White, k ": " Conversions.IntToHex(Base + v))
	}
}

ConsoleWrite(Colors.Green, "Done, took " ((End - Start) / 1000) " seconds to compile.")

Exit()

Log(Info) {
	global IsVerbose
	static Silenced := False
	
	if (IsObject(Info)) {
		Silenced := !Silenced
	}
	else if (IsVerbose && !Silenced) {
		ConsoleWrite(Colors.BrightBlue, A_Hour ":" A_Min ":" A_Sec "." A_MSec "`t" Info)
	}
}

Exit() {
	global SkipExitConfirm
	
	if !(SkipExitConfirm) {
		ConsoleWrite(Colors.White, "Press {Enter} to close.")
		
		ConsoleReadLine()
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

ShowError(Message) {
	global HasHadError
	static Hide := False
	
	if (Message = "Hide") {
		return Hide := True
	}
	else if (Message = "Show") {
		return Hide := False
	}
	
	if !(Hide) {
		HasHadError := True
		ConsoleWrite(Colors.Red, Message)
		ConsoleWrite(Colors.Red, StringifyCallstack(4))
	}
	
	Throw, Exception(Message)
}