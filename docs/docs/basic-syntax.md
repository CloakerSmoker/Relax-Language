## The basic syntax

It looks like C, it is written like C, but it *is not* C.

#### Types

Instead of long historic names, Relax uses shortened type names:

Integer types:

| Precision | C Name | (LanguageName) Name |
|-----------|--------|---------------------|
| 8 bits    |`char`  | `i8`                |
| 16 bits   |`short` | `i16`               |
| 32 bits   |`long`  | `i32`               |
| 64 bits   |`long long`/`__int64`| `i64`  |

Additionally, there is the `void` type, which is exactly what you'd expect it to be: a 64 bit integer (I can't remember why I made it this way).

Of course, there are also pointer types, which follow C syntax of `TypeName*`.

Additionally, you can define a structure type with the `struct` keyword, which can then be pointed-to like any other type.

#### Type checking

Type checking is done in the parser, so globals/locals/functions/structs must (usually) be defined above where they are used.

To avoid circular references being impossible to compile, the `declare` statement can be used to state a function's parameters/return type before defining it.

Additionally, undefined types can be used as long as they only used in pointer types, and do not have and fields referenced.

#### General Things
String literals are supported, and are replaced with an `i8*` to the given string. This `i8*` will point into the stack, so **DO NOT** try to free this memory. You can alter it, but poking at the memory around it is a terrible idea.

<br>

If a function does not have a return in it, the return value is undefined. However, functions are not required to have a `return`, and will still run.

<br>

The magic entry-point function is named `Main`, which is not expected to follow any prototype. This is to avoid having to include additional runtime code to support ArgV/ArgC. If a program requires ArgC/ArgV, this snippet will provide it:

```py
DllImport i16* GetCommandLineW() {Kernel32.dll, GetCommandLineW}
DllImport i16** CommandLineToArgvW(i16*, i64*) {Shell32.dll, CommandLineToArgvW}

define i32 Main() {
	i64 ArgC := 0
	i16* CommandLine := GetCommandLineW()
	i16** ArgV := CommandLineToArgvW(CommandLine, &ArgC)
    
    ...
}
```

The return value of `Main` is considered the program's exit code.

<br>

This is the list of reserved names:

* `if`, `else`
* `return`
* `continue`, `break`
* `struct`, `union`
* `define`, `declare`, `dllimport` 
* `for`, `while`, `loop`
* `as`

#### Assignment operators

The left side of each assignment operator can be any of the following:

* A variable, such as `A`
* An array access, such as `String[Index]`
* A struct access, such as `Something.Field` or `SomethingPointer->Field`

The assignment operators are:

* `:=` 
* `+=`
* `-=`

#### Binary operators

Note: `&&` and `||` both short-circuit, `%` is modulo, `.` is local struct field access, `->` is pointer struct field access.
`As` is explained further [here](#casting)

* `+`, `-`
* `*`, `/`, `%`
* `=`, `!=`
* `<`, `<=`, `>`, `>=`
* `&`, `|`, `^`
* `&&`, `||`
* `.`, `->`
* `as`

#### Unary operators

Note: `&` is 'address of', and `*` is dereference, `-` is negation.

* `&`, `*`
* `-`, `!`

`++` and `--` have been deliberately excluded, as they are a pain to parse.

#### Casting

Casting between types is usually implicit, but if you want to explicitly cast between two obviously incompatible types, the `As` operator does it.
The format is `Operand As TypeName`.

#### Array-access

Array accesses are really just pointer syntax sugar, but god do they make things easier.

`Pointer[Index]` will do the same operation as `*(Pointer + (SizeOfPointedToType(Pointer) * Index))`, with much less code generated.

Instead of evaluating a bunch of expressions manually, the addition and multiplication steps are both done by the CPU directly, which should be a speed up.

#### Struct-access

Struct accesses are technically also syntax sugar, but allow for much higher level code.

A struct access will automatically calculate the offset of a field inside of a structure, and encode that offset directly into an instruction.
Additionally, since struct fields have names, cryptic code such as `*(SomeStruct + 8 As i8*)` can be written as `SomeStruct->Field`.

The operators `.` and `->` are mostly interchangeable, however, `.` only works for local structs, and `->` only works for pointers to structs.

## What next?

For a full writeup of the syntax, see [the full syntax page](full-syntax.md).