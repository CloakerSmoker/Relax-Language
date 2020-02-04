## Main

`Main.ahk` contains pretty basic command line interface, which is used to compile Relax programs.

`Main.exe` is simply a compiled (by AHK) version of `Main.ahk` with the `Subsystem` header field set to `IMAGE_SUBSYSTEM_WINDOWS_CUI` instead of the standard `IMAGE_SUBSYSTEM_WINDOWS_GUI` for AHK files, which allows it to run like another other command line program.

Since both `Main.ahk` and `Main.exe` function the same, I'll just be referring to them as `Main` from here on.

### Note

If `Main.exe` has problems building a program (ex: has no output, doesn't write to output file), it might have been blocked by windows. To solve this, just use `Main.ahk`, which just opens a new console window when run.

### Programs

A Relax program is described in a few different places, so I won't describe it again, but you should know that the unofficial `.rlx` file type can be used for Relax source files.

This is not official in any way, and `Main` doesn't even check the extensions.

### How to use it

`Main` takes the arguments:

| Name | Parameter | Meaning |
|------|-----------|---------|
| `-i` | [InputFile] | Read the source code to compile from the given path |
| `-o` | [OutputFile] | Write the compiled code to the given path. If this path has the extension `.ahk`, then the input file will be compiled into AHK functions. Otherwise, a `.exe` file will be built at the path. |
| `--no-confirm` | N/A | Stops a confirmation message and user input being required before `[InputFile]` is compiled. |
| `--no-overwrite-output-file` | N/A | Causes `Main` to exit when `[OutputFile]` already exists. (for safety) |
| `--fast-exit` | N/A | Skips asking the user to press `{Enter}` before `Main` closes. |
| `--silent` | N/A | Skips all steps that require user input. |
| `--verbose` | N/A | Prints a log of what the compiler is doing. |

Where `[InputFile]` and `[OutputFile]` must both be given.

For example, compiling `Examples\SimpleConsoleProgram.rlx` with no extra confirmation message into `a.exe` with verbose mode enabled would be:
```
Main.exe --no-confirm --verbose -i Examples\SimpleConsoleProgram.rlx -o a.exe
```

---

If there are any errors while compiling, they will be printed, and the compiler will abort.