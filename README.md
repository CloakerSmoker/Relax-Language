# Relax, a basic compiled programming language.

Note: The compiler is now implemented in Relax itself, it used to be implemented in AutoHotkey. Yes, I regret that.

For more info, see the [docs](https://cloakersmoker.github.io/Relax-Language/#).

## A quick peek at some code

```
#Include Memory.rlx
#Include String.rlx
#Include Console.rlx

/* 
	A simple calculator, which works when compiled for both Windows and Linux.
*/

define i32 Main(i64 ArgC, i8** ArgV) {
	GetArgs(&ArgC, &ArgV) /* Ensures that ArgC/ArgV are set on Windows, does nothing on Linux */
	
	i64 Left := AToI(ArgV[1])
	i64 Right := AToI(ArgV[3])
	
	i8 Operator := ArgV[2][0]
	
	/* IWrite calls print with `WriteFile(STDOUT, NumberAsString)` on Windows, and `sys_write(STDOUT, NumberAsString)` on Linux */

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