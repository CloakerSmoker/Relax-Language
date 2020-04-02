class RelaxFlags {
	class Optimization {
		static DisableDeadCodeElimination := 1
		static DisableDeadIfElimination := 2
		static DisableConstantFolding := 4
		
		static EnableAll := 0
		static DisableAll := 4 + 2 + 1
	}
	class Features {
		static EnableAll := 0 + 16 + 32
		static DisableAll := 8 + 4 + 2 + 1
		
		static DisableDllCall := 1
		static DisableModules := 2
		static DisableGlobals := 4
		static DisableStrings := 8
		
		static UseStackStrings := 16
		static TargetPE := 32
	}
	
	static O0 := RelaxFlags.Optimization.DisableAll
	static O1 := RelaxFlags.Optimization.EnableAll
	
	static F0 := RelaxFlags.Features.DisableAll
	static F1 := RelaxFlags.Features.EnableAll
}

#Include %A_LineFile%\..\
#Include Parser\Utility.ahk
#Include Parser\Constants.ahk
#Include Parser\Lexer.ahk
#Include Parser\Typing.ahk
#Include Parser\Parser.ahk
#Include Compiler\Optimizer.ahk
#Include Compiler\CodeGen.ahk
#Include Compiler\Compiler.ahk
#Include Compiler\PEBuilder.ahk
#Include Compiler\ToAHK.ahk

class Relax {
	static VERSION := "1.0.0-alpha.33"
	
	; Simple class that handles creating a lexer/parser/compiler for some given code, and just returns a CompiledProgram
	;  object for you
	
	static DefaultFlags := {"OptimizationLevel": RelaxFlags.O1, "Features": RelaxFlags.F1}
	
	CompileToAHK(CodeString, FilePath := "") {
		if !(FilePath) {
			FilePath := A_ScriptDir "\out.ahk"
		}
		
		CodeString .= "`n" Builtins.__Runtime__.Code
		
		CodeCompiler := this.CompileCode(CodeString)
		
		FileOpen(FilePath, "w").Write(Build(CodeCompiler))
		
		return CodeCompiler
	}
	
	CompileToEXE(CodeString, EXEPath := "", AsDLL := False) {
		static Flags := {"Features": RelaxFlags.F1} 
		
		if !(EXEPath) {
			EXEPath := A_ScriptDir "\out.exe"
		}
		
		if (AsDLL) {
			CodeString .= "`n" Builtins.__DllRuntime__.Code
		}
		else {
			CodeString .= "`n" Builtins.__Runtime__.Code
		}
		
		CodeCompiler := this.CompileCode(CodeString, Flags)
		
		if (AsDLL) {
			MainOffset := CodeCompiler.FunctionOffsets["__RunTime__DllMain"]
		}
		else {
			MainOffset := CodeCompiler.FunctionOffsets["__RunTime__CallMain"]
		}
		
		GlobalBytes := []
		
		loop, % CodeCompiler.Globals.Count() * 8 {
			GlobalBytes.Push(0)
		}
		
		CodeEXEBuilder := CodeCompiler.PEBuilder := new PEBuilder()
		
		if (GlobalBytes.Count()) {
			CodeEXEBuilder.AddSection(".data", GlobalBytes, SectionCharacteristics.PackFlags("rw initialized"))
		}
		
		CodeEXEBuilder.AddCodeSection(".text", CodeCompiler.CodeGen.Link(True), MainOffset)
		
		if (CodeCompiler.Exports.Count() && !AsDLL) {
			ShowError("Build error: Program was not compiled to a DLL file, but still has exported functions. Recompile with a '.dll' file as output.")
		}
		
		if (AsDLL) {
			CodeEXEBuilder.Build(EXEPath, CodeCompiler.Exports)
		}
		else {
			CodeEXEBuilder.Build(EXEPath)
		}
		
		return CodeCompiler
	}
	
	CompileCode(CodeString, Flags := "", Name := "") {
		if !(IsObject(Flags)) {
			Flags := this.DefaultFlags
		}
		
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		CodeOptimizer := new ASTOptimizer(CodeLexer, CodeParser, Flags)
		CodeOptimizer.OptimizeProgram(CodeAST)
		
		Log("Finished optimizing")
		
		CodeCompiler := new Compiler(CodeLexer, CodeParser, Flags)
		CodeCompiler.CompileProgram(CodeAST, Name)
		
		return CodeCompiler
	}
}

class Module {
	static Modules := {}
	
	; Simple class to let modules exist at all, Module.Find is called by codegen while linking, and will compile and link any modules needed, and return a function pointer to them
	; Note: The only way to add modules currently is through Module.Add, there is no syntax for it
	
	Add(Name, ModuleClass) {
		this.Modules[Name] := {"Class": ModuleClass, "AST": False}
	}
	Find(Name) {
		FoundModule := this.Modules[Name]
		
		if !(FoundModule) {
			Throw, Exception("Module " Name " not found.")
		}
		
		if !(IsObject(FoundModule.AST)) {
			FoundModule.AST := this.Parse(Name)
		}
		
		return FoundModule
	}
	Parse(Name) {
		CodeString := this.Modules[Name].Class.Code
		
		CodeLexer := new Lexer()
		CodeTokens := CodeLexer.Start(CodeString)
	
		CodeParser := new Parser(CodeLexer)
		CodeAST := CodeParser.Start(CodeTokens)
		
		CodeOptimizer := new ASTOptimizer(CodeLexer, CodeParser, Flags)
		CodeOptimizer.OptimizeProgram(CodeAST)
		
		return CodeAST
	}
}


Module.Add("Memory", Builtins.Memory)
Module.Add("String", Builtins.String)
Module.Add("Console", Builtins.Console)

class Builtins {
	class Memory {
		static Code = "
		(
			DllImport i64 GetProcessHeap() {Kernel32.dll, GetProcessHeap}
			DllImport void* HeapAlloc(i64, i32, i64) {Kernel32.dll, HeapAlloc}
			DllImport void* HeapReAlloc(i64, i32, void*, i64) {Kernel32.dll, HeapReAlloc}
			DllImport i8 HeapFree(i64, i32, void*) {Kernel32.dll, HeapFree}
			
			i64 ProcessHeap := Memory:GetProcessHeap()
			i32 HEAP_ZERO_MEMORY := 0x00000008
			
			define void* _Alloc(i64 Size) {
				return Memory:HeapAlloc(Memory:ProcessHeap, Memory:HEAP_ZERO_MEMORY, Size)
			}
			define void* _ReAlloc(void* Memory, i64 NewSize) {
				return Memory:HeapReAlloc(Memory:ProcessHeap, Memory:HEAP_ZERO_MEMORY, Memory, NewSize)
			}
			define i8 _Free(void* Memory) {
				return Memory:HeapFree(Memory:ProcessHeap, 0, Memory)
			}
		)"
	}
	
	class String {
		static Code := "
		(
			define i32 ALen(i8* AString) {
				for (i32 Length := 0, *(AString + Length) != 0, Length += 1) {
				}
				
				return Length
			}
			define i32 WLen(i16* WString) {
				for (i32 Length := 0, *(WString + Length) != 0, Length += 2) {
				}
				
				return (Length / 2)
			}
			
			define i8 WAEquals(i16* WString, i8* AString) {
				i16* WAString := String:AToW(AString)
				
				i8 Result := String:WEquals(WString, WAString)
				
				Free(WAString As void*)
				
				return Result
			}
			
			define i8 WEquals(i16* WStringOne, i16* WStringTwo) {
				return String:WEqual(String:WTrimNewline(WStringOne), String:WTrimNewline(WStringTwo))
			}
			
			define i8 WEqual(i16* WStringOne, i16* WStringTwo) {
				i32 LengthOne := String:WLen(WStringOne)
				i32 LengthTwo := String:WLen(WStringTwo)
				
				if (LengthOne != LengthTwo) {
					return 0
				}
				
				for (i32 Index := 0, Index < LengthOne, Index++) {
					i16 CharacterOne := *(WStringOne + (Index * 2))
					i16 CharacterTwo := *(WStringTwo + (Index * 2))
					
					if (CharacterOne != CharacterTwo) {
						return 0
					}
				}
				
				return 1
			}
			
			define i16* WTrimNewline(i16* WString) {
				i32 Length := String:WLen(WString) * 2
				i8* AString := WString As i8*
				
				if (*(WString + Length - 2) = 0x0A) {
					(WString + Length - 2) *= 0
				}
				
				if (*(WString + Length - 4) = 0x0D) {
					(WString + Length - 4) *= 0
				}
				
				return WString
			}
			
			define void AReverse(i8* Buffer) {
				i8 Temp := 0
				i32 Length := String:ALen(Buffer)
				
				for (i32 Index := 0, Index < Length, Index++) {
					Temp := *(Buffer + Index)
					(Buffer + Index) *= *(Buffer + Length - 1)
					(Buffer + Length - 1) *= Temp
					
					Length--
				}
			}
			
			define i64 WToI(i16* WString, i8* Success) {
				i64 Result := 0
				i64 Negative := 0
				
				i16 FirstCharacter := WString[0]
				
				if (FirstCharacter = '-') {
					Negative := 1
					WString += 2
					FirstCharacter := WString[0]
				}
				
				
				if !(String:WIsNumeric(FirstCharacter)) {
					Success *= 0
					return 0
				}
				
				i32 Length := String:WLen(WString)
				
				for (i32 Index := 0, Index < Length, Index++) {
					i16 NextCharacter := WString[Index]
					
					if !(String:WIsNumeric(NextCharacter)) {
						Break
					}
					
					Result := (Result * 10) + (NextCharacter - '0')
				}
				
				Success *= 1
				
				if (Negative) {
					Result := -Result
				}
				
				return Result
			}
			
			define i8 WIsNumeric(i16 Character) {
				return (Character >= '0') && (Character <= '9')
			}
			
			define i8* IToA(i64 Number) {
				i8* Buffer := (Alloc(100) As i8*)
				i8 Sign := 0
				
				if (Number = 0) {
					Buffer *= '0'
					return Buffer
				}
				
				if (Number < 0) {
					Sign := 1
					Number := -Number
				}
				
				for (i32 Index := 0, Number > 0, Index++) {
					(Buffer + Index) *= (Number % 10) + '0'
					Number := Number / 10
				}
				
				if (Sign) {
					(Buffer + Index) *= '-'
				}
				
				(Buffer + Index + 1) *= 0
				
				String:AReverse(Buffer)
				
				return Buffer
			}
			define i16* IToW(i64 Number) {
				i8* AString := String:IToA(Number)
				i16* WString := String:AToW(AString)
				
				Free(AString As void*)
				
				return WString
			}
			
			define i16* AToW(i8* AString) {
				i32 Length := String:ALen(AString)
				i16* NewBuffer := (Alloc((Length * 2) + 2) As i16*)
				
				for (i32 Index := 0, Index < Length, Index++) {
					(NewBuffer + (Index * 2)) *= *(AString + Index)
				}
				
				return NewBuffer
			}
		)"
	}
	
	class Console {
		static Code := "
		(
			DllImport i64 GetStdHandle(i32) {Kernel32.dll, GetStdHandle}
			DllImport i8 WriteConsole(i64, i16*, i32, i32*, i64) {Kernel32.dll, WriteConsoleW}
			DllImport i8 SetConsoleTextAttribute(i64, i16) {Kernel32.dll, SetConsoleTextAttribute}
			DllImport i8 ReadConsole(i64, void*, i32, i32*, void) {Kernel32.dll, ReadConsoleW}
			
			Import String
			
			i64 STDIN := Console:GetStdHandle(-10)
			i64 STDOUT := Console:GetStdHandle(-11)
			i64 STDERR := Console:GetStdHandle(-12)
			
			define i32 AWrite(i8* AString) {
				i16* WString := String:AToW(AString)
				
				i32 Result := Console:Write(WString)
				
				Free(WString As void*)
				
				return Result
			}
			
			define i32 AWriteLine(i8* AString) {
				i16* WString := String:AToW(AString)
				
				i32 Result := Console:WriteLine(WString)
				
				Free(WString As void*)
				
				return Result
			}
			
			define i32 Write(i16* WString) {
				i32 CharactersWritten := 0
				
				Console:WriteConsole(Console:STDOUT, WString, String:WLen(WString), &CharactersWritten, 0)
				
				return CharactersWritten
			}
			
			define void WriteCharacter(i16 Character) {
				i32 CharactersWritten := 0
				
				Console:WriteConsole(Console:STDOUT, &Character, 1, &CharactersWritten, 0)
			}
			
			define void WriteNewLine() {
				i64 NewLine := 0x00000000000D000A
				Console:Write((&NewLine) As i16*)
			}
			
			define i32 WriteLine(i16* WString) {
				i64 NewLine := 0x00000000000D000A
				
				i32 ReturnValue := Console:Write(WString)
				Console:Write((&NewLine) As i16*)
				
				return ReturnValue
			}
			
			define i32 IWrite(i64 Number) {
				i16* WString := String:IToW(Number)
				
				i32 Result := Console:Write(WString)
			
				Free(WString As void*)
				
				return Result
			}
			define i32 IWriteLine(i64 Number) {
				i16* WString := String:IToW(Number)
				
				i32 Result := Console:WriteLine(WString)
			
				Free(WString As void*)
				
				return Result
			}
			
			i16 Bright := 0x08
			i16 Red := 0x04
			i16 Green := 0x02
			i16 Blue := 0x01
			
			i16 White := 0x0F
			i16 Black := 0x00
			
			define void ResetColors() {
				Console:SetColor(Console:White, Console:Black)
			}
			define void TextColor(i16 Foreground) {
				return Console:SetColor(Foreground, Console:Black)
			}
			
			define void SetColor(i8 Foreground, i8 Background) {
				Background := Background * 10
				
				Console:SetConsoleTextAttribute(Console:STDOUT, Foreground | Background)
			}
			
			define i16* ReadLine() {
				void* Buffer := Alloc(64)
				i32 ChunkCount := 1
				
				for (i32 CharactersRead := 32, CharactersRead = 32, ChunkCount++) {
					i32 BufferOffset := (ChunkCount - 1) * 64
					CharactersRead := 32
					
					Console:ReadConsole(Console:STDIN, Buffer + BufferOffset, 32, &CharactersRead, 0)
					
					Buffer := ReAlloc(Buffer, BufferOffset + 128)
				}
				
				return (Buffer As i16*)
			}
		)"
	}
	
	class __DllRuntime__ {
		static Code := "
		(
			i64 hThisDll := 0
			
			define void __RunTime__SetGlobals() {
				
			}
			define i8 __RunTime__DllMain(i64 ThisHandle, i32 CallReason, void Reserved) {
				i32 DLL_PROCESS_ATTACH := 1
				
				if (CallReason = DLL_PROCESS_ATTACH) {
					hThisDll := ThisHandle
					__RunTime__SetGlobals()
					
					return 1
				}
				
				return 0
			}
		)"
	
	}
	
	class __Runtime__ {
		static Code := "
		(
			DllImport i16* __GetCommandLineW() {Kernel32.dll, GetCommandLineW}
			DllImport i16** __CommandLineToArgvW(i16*, i64*) {Shell32.dll, CommandLineToArgvW}
			
			DllImport void __LocalFree(void*) {Kernel32.dll, LocalFree}
			DllImport i64 __GetCurrentProcess() {Kernel32.dll, GetCurrentProcess}
			DllImport void __TerminateProcess(i64, i32) {Kernel32.dll, TerminateProcess}
			
			i16** __Saved__ArgV := 0
			
			define void __RunTime__SetGlobals() {
				
			}
			define void __RunTime__CallMain() {
				__RunTime__SetGlobals()
				
				i64 __ArgC := 0
				i16** __ArgV := __CommandLineToArgvW(__GetCommandLineW(), &__ArgC)
				__Saved__ArgV := __ArgV
				
				i32 __ExitCode := (Main(__ArgC, __ArgV) as i32)
				
				__LocalFree(__ArgV As void*)
				
				__TerminateProcess(__GetCurrentProcess(), __ExitCode)
			}
			
			define void Exit(i32 __ExitCode) {
				__LocalFree(__Saved__ArgV As void*)
				
				__TerminateProcess(__GetCurrentProcess(), __ExitCode)
			}
			
			DllImport i64 __GetProcessHeap() {Kernel32.dll, GetProcessHeap}
			DllImport void* __HeapAlloc(i64, i32, i64) {Kernel32.dll, HeapAlloc}
			DllImport void* __HeapReAlloc(i64, i32, void*, i64) {Kernel32.dll, HeapReAlloc}
			DllImport i8 __HeapFree(i64, i32, void*) {Kernel32.dll, HeapFree}
			
			i64 __ProcessHeap := __GetProcessHeap()
			i32 __HEAP_ZERO_MEMORY := 0x00000008
			
			define void* Alloc(i64 Size) {
				return __HeapAlloc(__ProcessHeap, __HEAP_ZERO_MEMORY, Size)
			}
			define void* ReAlloc(void* Memory, i64 NewSize) {
				return __HeapReAlloc(__ProcessHeap, __HEAP_ZERO_MEMORY, Memory, NewSize)
			}
			define i8 Free(void* Memory) {
				return __HeapFree(__ProcessHeap, 0, Memory)
			}
		)"
	}
}