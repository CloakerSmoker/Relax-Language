# A basic compiled programming language.

![Tests](https://github.com/CloakerSmoker/Relax-Language/workflows/Linux%20Tests/badge.svg)

Note: The compiler is now bootstrapped, it used to be implemented in AutoHotkey. Yes, I regret that.

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

define i32 Main(i64 ArgC, i8** ArgV) {
	GetArgs(&ArgC, &ArgV) ; Ensures that ArgC/ArgV are set on Windows, does nothing on Linux
	
	i64 Left := AToI(ArgV[1])
	i64 Right := AToI(ArgV[3])
	
	i8 Operator := ArgV[2][0]
	
	/* The `Print` function is overloaded, with the `i64` version implemented as
		 Print(IToA(Number))
		with the `i8*`/string overload of the `Print` function working as
		 WriteFile(StdOut, String)
		when compiled for Windows, and 
		 sys_write(StdOut, String)
		when compiled for Linux
	 */

	if (Operator = '+') {
		Print(Left + Right)
	}
	else if (Operator = '-') {
		Print(Left - Right)
	}
	else if (Operator = '*') {
		Print(Left * Right)
	}
	else if (Operator = '/') {
		Print(Left / Right)
	}
	
	return 0 /* Returns from `Main()` like normal on Windows, calls `sys_exit(0)` on Linux */
}
```

(For more examples, check out the tests inside of `tests/`, or the compiler source itself in `src/compiler/`)
