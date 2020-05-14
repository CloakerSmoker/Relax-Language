## The full syntax description

### Program
The compiler expects input code to be a "program", a program is defined as a list of the following statements:

* [Struct statements](#struct)
* [Declare statements](#declare)
* [DllImport statements](#dllimport)
* [Define statements](#define)
* [Global declarations](#global)
* [Directives](#directive)

### Directives
Directives follow the format:
```
#Directive Parameter
```

* `Directive` is a directive name (`include` is the only one implemented)
* `Parameter` is a parameter for the directive

Directives are direct instructions for the compiler, and do not generate any code.

The `include` directive will copy-paste the contents of another file into the position the directive is at.

### Declare
Declare statements follow the format:
```
Declare ReturnType FunctionName(ParameterTypeList)
```

* `ReturnType` is the [type](#types) that the function is expected to return.
* `FunctionName` is the [name](#names) of the function.
* `ParameterTypeList` is a list of comma-separated [types](#types), without any names, since the parameter names are not needed.

Declare statements are use to tell the compiler what types `FunctionName` should be passed (and will return) before it has parsed the full definition of `FunctionName`

### DllImport
DllImport statements follow the format:
```
DllImport ReturnType FunctionName(ParameterTypeList) {DllFileName.dll, FunctionNameInsideDLL}
```

* `ReturnType` is the [type](#types) that the function is expected to return.
* `FunctionName` is the [name](#names) that the function will have internally, and is the name you use to call it. This name does not need to be the same as `FunctionNameInsideDLL`.
* `ParameterTypeList` is a list of comma-separated [types](#types), without any names, since the parameter names are not needed.
* `DllFileName.dll` is the name of the file which contains the given function.
* `FunctionNameInsideDLL` is the name of the function, as it is exported in from the DLL.

### Define
Define statements follow the format:
```
Define ReturnType FunctionName(ParameterList) export {
    Body
}
```

* `ReturnType` is the [type](#types) that the function is expected to return.
* `FunctionName` is the [name](#names) that the function will have, and is the name you use to call it.
* `ParameterList` is a list of comma-separated [type](#types) [name](#names) pairs.
* `Body` is a list of [statements](#statements).
* `Export` is optionally the word `export`, which will cause the function to be exported from the resulting file (if the file is a `.dll`)

### Struct
Struct statements follow the format:
```
struct StructName {
    Type Name,
    Type Name,
    union {
        Type Name,
        Type Name
    },
    Type Name
}
```

* `StructName` is the type name the struct type should have
* `Type` is a [type name](#types) for the field
* `Name` is a [name](#names) for the field

### Global
Global declarations follow the same format as regular [declarations](#declarations).
However, global declarations make variables that are [program](#program)-wide, and can be used from any function.
Additionally, global declarations run just before `Main` is run, making them a suitable method to run setup code.

### Statements
Statements follow multiple different formats, depending on the type of statement.

* [Declarations](#declarations)
* [Keyword statements](#keywords)
* [Expression statements](#expression-statements)

It is important to note that this 'statement' category does not include the [program](#program) statements, which are not allowed inside of functions.

All of the above statements are allowed inside of functions and other structures such as [for loops](#for) or [if statements](#if).

### Declarations
Declarations follow the format(s):
```
TypeName VariableName
TypeName VariableName := Value
```

* `TypeName` is the [type](#types) that the variable will have.
* `VariableName` is the [name](#names) the variable will have.
* `:= Value` is an optional [assignment](#expression) to give the variable a default value.

Variables that do not have a default value should be considered to have an undefined value until they are otherwise assigned.

### Keywords
Keyword statements follow multiple different formats, depending on the keyword used.

* [if/else if/else statements](#if)
* [for loops](#for)
* [break/continue statements](#break-continue)
* [return statements](#return)

These are all of the statements implemented, there are no `while` loops.

### If 
If statements follow a single variable format, depending on the structure of the if statement:
```
if (Condition) {
    Body
}
else if (OtherCondition) {
    Body
}
else {
    Body
}
```

* `if` is the required keyword to start an if statement.
* `(Condition)` an [expression](#expression) which will be tested in order to decide if the next block will run or not.
* `Body` (in all places) is a list of statements(#statements) which will run if the prior condition resulted in a non-zero result.
* `else if` the required keyword to add another [condition](#expression) and [body](#statements) to the entire if statement.
* `else` the required keyword to add a final [body](#statements) to the if statement, which will only run when no other conditions are met.

`else if` can be repeated any number of times, for any number of conditions. There can only be one `else` for each if statement.

### For
For loops follow the format:
```
for (Init, Condition, Step) {
    Body
}
```

* `Init`, `Condition`, and `Step` are all [expressions](#expression) which run at different points. 
* `Body` is a list of statements(#statements) which will run each iteration of the loop.

`Init` can optionally be a [declaration](#declarations) and is run before the loop first stats, and never again. 

`Condition` is checked before the loop runs an iteration, and if it is false, the loop will stop. 

`Step` is run after each iteration of the loop.

### Break-Continue
Break and continue both follow the format:
```
Break
Continue
```
With no extra code.

The break and continue statements are only valid inside of [for loops](#for).

### Return
Return statements follow the format:
```
Return Value
```

* `Value` is any kind of [expression](#expression), which will be returned to the caller.

`Value` must evaluate to a type compatible to the return type of the current [function](#define).

### Expression-Statements
Expression statements follow the format:
```
Expression
```

* `Expression` is any kind of [expression](#expression).

If `Expression` does not call a function or set a variable, it will be eliminated by the compiler during dead-code elimination.

### Expression
Expressions follow many formats, examples:
```
A := B + C
(2 - E) / 2
9999 + *(G) % H
```

* Any unquoted text inside an expression is treated as a variable.
* Quoted text is treated as an `i8*` typed value.
* Numbers are treated as the smallest possible type to hold them (ex: `58` would be an `i8`, `9999` would be an `i16`)
* Operators are evaluated according to precedence and associativity, which is defined in `Parser.rlx`.
* Some operators may not be implemented for a given type
* Some expressions may be used as booleans inside of [for loops](#for) or [if statements](#if). This is done by checking if the expressions results in `0` or not.

Additionally, there is the format:
```
Something[SomethingElse]
```
Where `Something` is an expression which results in a pointer-type, and `SomethingElse` results in an integer, which will be used as an index into `Something`.

Operators are listed on [this page](../basic-syntax)

### Types

A type is simply a combination of a identifier, with any number of `*`s after it (each `*` increases the level of nested pointers)

The base type names are 

* `i8`, `i16`, `i32`, `i64`
* `void`

With pointer (and pointer-pointer) types for each, like:

```
void*  - Pointer to void
i16**  - Pointer to a pointer to an i16
i8*    - Pointer to an i8

void*****************    - Pointer to a pointer to a pointer to a pointer to a pointer to a pointer to a pointer.... you get it
```

### Names

Names are simply combinations of characters and numbers. Names must start with a-z, but can contain numbers after the first letter.