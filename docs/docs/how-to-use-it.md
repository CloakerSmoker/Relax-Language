## Main

`Main.ahk` contains pretty basic command line interface, which is used to compile Relax programs.

### Programs

A Relax program is described in a few different places, so I won't describe it again, but you should know that the unofficial `.rlx` file type can be used for Relax source files.

This is not official in any way, and `Main` doesn't even check the extensions.

### How to use it

`Main` takes the arguments:

| Name | Parameter | Meaning |
|------|-----------|---------|
| `-i` | [InputFile] | Read the source code to compile from the given path |
| `-o` | [OutputFile] | See [output files](#output-files). |
| `--no-confirm` | N/A | Stops a confirmation message and user input being required before `[InputFile]` is compiled. |
| `--no-overwrite-output-file` | N/A | Causes `Main` to exit when `[OutputFile]` already exists. (for safety) |
| `--fast-exit` | N/A | Skips asking the user to press `{Enter}` before `Main` closes. |
| `--silent` | N/A | Skips all steps that require user input. |
| `--verbose` | N/A | Prints a log of what the compiler is doing. |

Where `[InputFile]` and `[OutputFile]` must both be given.

For example, compiling `Examples\SimpleConsoleProgram.rlx` with no extra confirmation message into `a.exe` with verbose mode enabled would be:
```
Main.ahk --no-confirm --verbose -i Examples\SimpleConsoleProgram.rlx -o a.exe
```

Or, to compile the example DLL and program which uses the DLL:
```
Main.ahk -i Examples\ExampleDll.rlx -o ExampleDll.dll
Main.ahk -i Examples\ExampleDllCaller.rlx -o out.exe
```
Which can then be run with
```
out.exe
```

(Note: if you change the name of `ExampleDll.Dll`, you'll need to change the `DllImport` in `ExampleDllCaller.rlx` to import from the new name of the DLL)

---

If there are any errors while compiling, they will be printed, and the compiler will abort.

### Output-files

The `[OutputFile]` parameter decides where to write the output to, and which format the output will be in. The formats are as follows:

| Format Extension | Format description |
|------------------|--------------------|
| `.ahk`           | Will write the output code to `[OutputFile]` as a group of AHK functions, which can be `#Include`'d |
| `.exe`           | Will write the output code to `[OutputFile]` as a `.exe` file, with an entry point of the user-defined `Main` function |
| `.dll`           | Will write the output code to `[OutputFile]` as a `.dll` file, with each function with the `export` keyword as an exported function of the `.dll` file |