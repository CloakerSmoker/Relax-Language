# Relax, a basic compiled programming language.

Note: The compiler is now implemented in Relax itself, it used to be implemented in AutoHotkey. Yes, I regret that.

For more info, see the [docs](https://cloakersmoker.github.io/Relax-Language/#).

## A quick peek at some code

```
#Include Memory.rlx
#Include String.rlx
#Include Console.rlx

DllImport i16* GetCommandLineW() {Kernel32.dll, GetCommandLineW}
DllImport i16** CommandLineToArgvW(i16*, i64*) {Shell32.dll, CommandLineToArgvW}

/* A simple calculator, depends on CommandLineToArgvW splitting the command line by spaces */

define i32 Main() {
	i64 ArgC := 0
	i16* CommandLine := GetCommandLineW()
	i16** ArgV := CommandLineToArgvW(CommandLine, &ArgC)
	
	i64 Left := WToI(ArgV[1])
	i64 Right := WToI(ArgV[3])
	
	i8 Operator := ArgV[2][0] As i8
	
	if (Operator = '+') {
		IWrite(Left + Right)
	}
	else if (Operator = '-') {
		IWrite(Left - Right)
	}
	else if (Operator = '*') {
		IWrite(Left * Right)
	}
	else if (Operator = '/') {
		IWrite(Left / Right)
	}
	
	return 0
}
```