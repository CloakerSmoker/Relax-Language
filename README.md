# Bootstrap branch, aka dev with extra steps

Bootstrap is where I commit if I don't want to update the documentation.

Bootstrap also happens to be where I'm doing all the work of bootstrapping the compiler.

Bootstrap also happens to be the branch with all the cool features, since bootstrapping the compiler needs lots of syntax sugar.

Differences:

* Bootstrap has struct types (and the `.` operator)
* Bootstrap has full array access syntax support (Ex: `A[B + 10] := 9`, not just `return A[B + 10]`)
* Bootstrap has many minor bugs fixed (which wasn't my smartest move, those fixes should be on master)
* Bootstrap has true/false
* Bootstrap has struct-pointer types (and the `->` operator)
* Bootstrap has better built in functions (`Alloc`, `Free`, `ReAlloc`, `Exit`)
* Bootstrap has the prototype self-compiling compiler, which is already a way better parser better than the original (even `A->B->C[D]` parses correctly)
* I like bootstrap a lot more than master.
