# Compiling To AHK

Relax supports compiling to AHK through a boilerplate function which is used as a linker+loader for the compiled code.

All you need to do to compile to `.ahk` instead of `.exe`  (or `.dll`) is change the `[OutputFile]` path given to [`Main`](how-to-use-it) to have the `.ahk` extension.

## The boilerplate

The boilerplate function is used to:

* Set up an import table (which holds pointers to all imported functions)
* Set up a global table (which is the memory used for global variables)
* Populate the import table with all imported functions
* Allocate executable memory for the compiled code
* Link any references to the import table or global table while writing the compiled code into memory
* Get pointers to compiled functions (The boilerplate function also stores the offsets to each function)
* Free the compiled code on exit

---

Additionally, "caller" functions are generated for each function inside of the given program, which follow the format

```
FunctionName(ParameterList) {
    static pThisFunction := _CompiledCodeAddressOf(FunctionName)
    return DllCall(pThisFunction, ParameterTypeList + ParameterList, ReturnType)
}
```

Where:

* `FunctionName` is replaced with the name of the function as it is written in the source code
* `ParameterList` is a comma-separated list of the functions parameters (name only, as found in the source)
* `ParameterTypeList + ParameterList` is a list of `ParameterType, ParameterName` pairs, with `ParameterType` being an AHK DllCall type for the parameter's actual type.
* `ReturnType` is an AHK DllCall type for the function's return type.

The template for the boilerplate function can be found in `Compiler\ToAHK.ahk`.

### Note

By default, the boilerplate function ***does not*** initialize global variables to their defaults. This is because if compiled code requires prior setup (like a call to `AllocConsole`), the setup ***must*** be done before global defaults are set.

To manually set global variables after any setup code is done, include a call to `__RunTime__SetGlobals`.

It is not recommended to call `__RunTime__CallMain`, as it is the program entry point for `.exe` files, and automatically calls `ExitProcess` after the `Main` function returns.