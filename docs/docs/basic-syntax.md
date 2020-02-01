## The basic syntax
It's pretty much C, but with minor changes. Although many things are borrowed from C, this is *not* a C compiler, and does not have all the features C has.


#### Types

Type names are changed to be more concise, and shorter.

Integer types:

| Precision | C Name | (LanguageName) Name |
|-----------|--------|---------------------|
| 8 bits    |`char`  | `i8`                |
| 16 bits   |`short` | `i16`               |
| 32 bits   |`long`  | `i32`               |
| 64 bits   |`long long`/`__int64`| `i64`  |

Floating point types:

| Precision | C Name | (LanguageName) Name |
|-----------|--------|---------------------|
| 32 bits   |`float` | `f32`               |
| 64 bits   |`double`| `f64`               |

Additionally, there is the `void` type, which is exactly what you'd expect it to be: a 64 bit integer (I can't remember why I made it this way).

Of course, there are also pointer types, which follow C syntax of `TypeName*`. Pointer-pointer types are not implemented.

#### General Things
String literals are supported, and are replaced with an `i8*` to the given string. This `i8*` will point into the stack, so **DO NOT** try to free this memory. You can alter it, but changing the size of it, or overrunning it's length is ***VERY VERY BAD***.

If a function does not have a return, a `return 0` is implicitly added.

The magic entry-point function is named `Main`, and receives a `i64` parameter containing the number of command line arguments, along with a `void*` which is actually an array of `i16*` pointers to the individual command line arguments (Just like how in C you have `ArgC` and `ArgV`)

`Main` should have a return type of `i32`, as the return value will be given to the Windows API `ExitProcess` function as the program's exit code.

Now's a good time to note: If you prefix the name of a variable or function with `__`, you are very likely to break something internal. The `__` prefix is reserved, and I will be *very unhappy* with you if you use it.

#### Assignment operators

Most assignment operators act as you'd expect, except for `*=`. 

Since I really like the C syntax for pointers, but ***hate*** the C syntax to assign the value a pointer points to, the `*=` is used for assignment of a memory address to a new value. 

For example `(PointerToAString + 90) *= 'H'` would set the character at `PointerToAString + 90` to be `H`.

Since `*=` is taken, `/=` is also not implemented, `+=` and `-=` are the only shorthand assignment operators.

Additionally, since floating point number support is half-baked (at best), `+=` and `-=` are not implemented for floating point numbers.

So, that leaves us with the 4 assignment operators: `:=`, `*=`, `+=`, `-=`.

#### Binary operators

Another minor change is with the logical operators `&&` and `||`. 
I can't think of a good way to generate code which will have these operators short-circuit, so they don't.

Additionally, some operators are not implemented for floating point operands. This is mostly because I do floating point math with the (actually older than me) x87 FPU, and can't figure out the FPU instructions needed for some operators.

These operators are: `%` (Modulo), `&&`, and `||`. (You'll get an error message when you try to use them on floating point operands)

Bitwise operators are allowed on all data types, simply because I think it's dumb that they aren't in some languages. If you want to mangle the floating point number format, go for it.

The full list of binary operators: `+`, `-`, `*`, `/`, `%` (Modulo), `=` (regular equality, there's no `==`), `!=`, `<`, `<=`, `>`, `>=`, `&&`, `||`, `&`, `|`, `^`

Yes, I know there's no bit-shifts. If anyone besides me ever uses this language and wants bit-shifts, I'll implement them.

##### Casting

Casting between types is usually implicit, but if you want to explicitly cast between two obviously incompatible types, the `As` operator does it.
The format is `Operand As TypeName`, just be careful with `Operand`, since `As` will take the closest thing on its left, so `1 + 2 As f32` would be parsed as `1 + (2 As f32)`.

This funky word operator is because I honestly fear for my mental and physical health if I have to modify the expression parser to handle C style casting.

#### Unary operators

Unary operators also have some odd bits, mostly because I forgot to implement how they work with different types. (All data types are treated like integers with unary operators)

So make sure not to have something like `-AFloatingPointNumber`, because that'll cause some problems. `0 - AFloatingPointNumber` works fine though.
Oh, and `AFloatingPointNumber` with `++` or `--` will also cause some problems.

`&` Functions as you'd expect in C, same with `*` (which requires a pointer type as the operand).

`++Variable` and `Variable++` also function as you'd expect, I made sure.

`++PointerVariable` is also implemented to increment `PointerVariable` by however big the value it points to is, ex:
```c
i64 SomeNumber := 99
i64* PointerVariable := &SomeNumber
++PointerVariable
```
Would increment `PointerVariable` by 8 

## What next?

For a tutorial sort of thing, see [the tutorial page](tutorial.md).

For a full writeup of the syntax, see [the full syntax page](full-syntax.md).