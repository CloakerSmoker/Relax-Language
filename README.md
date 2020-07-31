# Relax, a basic compiled programming language.

![Linux Tests](https://github.com/CloakerSmoker/Relax-Language/workflows/Linux%20Tests/badge.svg)

![Windows Tests](https://github.com/CloakerSmoker/Relax-Language/workflows/Windows%20Tests/badge.svg)

Note: The compiler is now implemented in Relax itself, it used to be implemented in AutoHotkey. Yes, I regret that.

For more info, see the [docs](https://cloakersmoker.github.io/Relax-Language/#).

## A quick peek at some code

```
/* Paths are relative to the root directory of the repo, compiler should be ran with:
		./build/compiler.exe -i path/to/this_file.rlx -o path/to/binary.exe
	to ensure the working dir is correct.
*/

#Include ./src/lib/Memory.rlx
#Include ./src/lib/String.rlx
#Include ./src/lib/Console.rlx

/* 
	A simple calculator, which works when compiled for both Windows and Linux.
*/

define i32 Main(i64 ArgC, i8** ArgV) {
	GetArgs(&ArgC, &ArgV) /* Ensures that ArgC/ArgV are set on Windows, does nothing on Linux */
	
	i64 Left := AToI(ArgV[1])
	i64 Right := AToI(ArgV[3])
	
	i8 Operator := ArgV[2][0]
	
	/* IWrite boils down to `WriteFile(STDOUT, NumberAsString)` on Windows, and `sys_write(STDOUT, NumberAsString)` on Linux */

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
	
	return 0 /* Returns from `Main()` like normal on Windows, calls `sys_exit(0)` on Linux */
}
```
