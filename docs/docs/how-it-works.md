## The structure

The compiler is laid out in various separate stages, in the order:

* [Lexer](#lexer)
* [Parser](#parser)
* [Compiler](#compiler)
* [CodeGen](#codegen)
* [PEBuilder](#pebuilder)

### A quick rundown

* The lexer takes source code, makes it into an array of tokens.
* The parser takes an array of tokens, builds it into a tree that represents the code.
* The compiler takes that tree, and converts it into CPU instructions.
* CodeGen takes the CPU instructions that the compiler is trying to generate, and assembles them into raw machine code.
* PEBuilder packs the raw machine code into a `.exe` file.

Simple enough, right? (It only took thousands of line to implement)

### Lexer

The lexer is used to transform plain text like `define i32 Main` or `i32 test := 99 + 2` into an array of "tokens".

A token is like a word, and is the smallest unit that the entire compiler uses. Tokens also have different types.

So, `i32 test := 99 + 2` would have the tokenizer start with the character `i`, which it would see is:

* Not the start of an operator
* Not the start of a string, or character literal
* Not whitespace
* Not a new line
* Not a digit
* *Is* alphanumeric

And now that the lexer has found an alphanumeric character, it will continue to consume all alphanumeric characters after the first.

So, `32` would also be consumed, and added to the `t` token, however, "` `" is not alphanumeric, and would be the end of the `t` token.

Next, to figure out the type of the token, the lexer checks if it is in the list of keywords (found in `Lexer.rlx`, `LookupKeyword`), and since it is not a keyword, the token is created with the type `TOKEN_TYPE_IDENTIFER`, and a value of `i32`.

This would repeat for `test`, giving us the two tokens:

```json
[{Value: "i32", Type: TOKEN_TYPE_IDENTIFER}, {Value: "test", Type: TOKEN_TYPE_IDENTIFER}]
```

Now, the lexer would see the character `:`, and `:` is defined as the first character of an operator (in `Lexer.rlx`'s `GetNextToken`).

Since `:` is an operator (or part of an operator), the lexer will now:

* Check if the next character is part of any operators (In this case the next character is `=`, which is part of `:=`)
* Gather all characters that are part of the operator which matches the next character (`:=` only has two characters, so this step is already done)
* Create a token of the `TOKEN_TYPE_OPERATOR` type, with the value of the found operator (`OPERATOR_COLON_EQUAL` in this case)

Now we've got:

```json
[{Value: "i32", Type: TOKEN_TYPE_IDENTIFER}, {Value: "test", Type: TOKEN_TYPE_IDENTIFER}, {Value: OPERATOR_COLON_EQUAL, Type: TOKEN_TYPE_OPERATOR}]
```

And the next character is `9`, which the lexer would see is:

* Not the start of an operator
* Not the start of a string, or character literal
* Not whitespace
* Not a new line
* *Is* a digit

Now, the lexer will gather all digits following the first, getting us `99`, and create a `TOKEN_TYPE_INTEGER` token, with the value `99`.

Now, applying these same rules to the rest of the string, we get the following array of tokens for the output:

```json
[
    {Value: "i32", Type: TOKEN_TYPE_IDENTIFER}, 
    {Value: "test", Type: TOKEN_TYPE_IDENTIFER}, 
    {Value: OPERATOR_COLON_EQUAL, Type: TOKEN_TYPE_OPERATOR},
    {Value: 99, Type: TOKEN_TYPE_INTEGER},
    {Value: OPERATOR_PLUS, Type: TOKEN_TYPE_OPERATOR},
    {Value: 2, Type: TOKEN_TYPE_INTEGER}
]
```

---

One thing that I haven't mentioned is that all tokens actually contain a bit more data.

* A pointer to the name of the file the token is from
* A pointer to their source text
* What line the token is on
* Where the token is in that line/how long it is

All of this data is used to provide better error printouts

---

And that's all the lexer really does. Of course, there's many-many more token types than I mentioned, and the lexer also supports hex literals, which are given the type `TOKEN_TYPE_IDENTIFER`.

## Parser

The parser takes the array of tokens which the lexer outputs, and builds an abstract syntax tree out of the tokens.

<br/>

And abstract syntax tree (AST) is a how a given program is represented, in this case, each "leaf" of the AST is either a `Token` object (which the lexer outputs) or a `ASTNode` object.

For example, the AST of `1 + 2` would be:

```json
{
    Type: NODE_TYPE_BINARY,
    Left: {
        Type: NODE_TYPE_INTEGER,
        Value: 1
    }
    Operator: {
        Type: TOKEN_TYPE_OPERATOR,
        Value: OPERATOR_PLUS
    }
    Right: {
        Type: NODE_TYPE_INTEGER,
        Value: 2
    }
}
```

This concept is the same throughout the entire parser, you have an AST node, which has other AST nodes inside of it, which can represent any part of a program.

Additionally, AST nodes also contain the same context data as tokens for accurate error reporting.

The hard part is actually building the AST.

I'm not going to go into how the AST is built, due to that being a better topic for a book, not documentation.

## Compiler

The compiler takes the AST from the parser, and walks it, calling into `CodeGen.rlx` to generate machine code for each AST node it visits.

The AST is walked by recursively enumerating each branch of the tree, with each different branch type having a different function which will enumerate any branches it has.

Statements are compiled in mostly-similar ways, with a condition being compiled, then tested, and a conditional jump to either the next statement in a chain, or out of the current statement. More specifically:

* If statements are compiled by compiling the condition expression, testing it with `result != 0`, and conditionally jumping into the `Body` for the statement. After the body, a `jmp` to the end of the statement stops any other branches from running. If the `!= 0` test fails, it `jmp`s to the next condition and body to be checked.
* For loops are compiled with the initialization step first, then a label to jump back to, then the condition (and a jump out of the loop when the condition is false), and then the loop body. After the body is the step expression, and a jump back to the start of the loop.

---

Expressions are a little less label/`jmp` intensive, but more complex to understand.

So, to evaluate expressions, a stack is used to hold operands until they are needed, which means that:

* When we compile a binary operator, we should pop two operands of the stack, and push our result onto the stack.
* When we compile a unary operator, we should pop one operand, and push our result onto the the stack.
* When we compile a function call, we should pop as many operands as the function takes as parameters, and then push the return value onto the stack.

As long as all generated code to evaluate expressions follows these rules, you can always trust an expression to leave its result on the stack.

If this promise of operands/results is every broken, then there has been a code misgeneration, and something is wrong. However, since it isn't broken, expressions can be compiled into a series of very basic instructions.

#### Strings And Other Stuff

The compiler handles strings by allocating `StrLen(String) + 1` bytes much of stack space for each string, and encodes string literals into 64 bit integers, which when stored in the stack, will build the correctly ordered string.

When a string is used, it is replaced with a pointer into the stack where the string was written.

---

Parameters are treated exactly the same as locals.

---

Function calls are a bit of a mess. Since the register stack uses some of the parameter registers, first the register stack has to be saved, and then the parameter registers have to be 0'd, and finally, the parameters can be compiled and moved into the parameter registers.

---

When a function never has a `return` statement compiled, it will automatically return with an undefined result.

This is the only difference for omitting `return`, since the code to return from a function is automatically generated at the end of a function either way.

---

Signed numbers are the only kind of numbers, unsigned operations require entirely different instructions for operations, which is why I don't plan on adding unsigned types.

## CodeGen

This one will be shorter, I promise.

CodeGen is a class which generates the correct bytes for lots of common AMD64 instructions, and automatically handles linking labels and jumps for you.

CodeGen keeps a buffer containing the array of assembled code, along with buffers for book keeping info such as labels and fixups, which are applied before the code is written to the output file.

The backbone of CodeGen is just a few methods:

* `EmitREX(DestinationRegister, SourceRegister, ExtraREX)` Which will build a "REX prefix" for an instruction, which will promote the instruction to use 64 bit registers and data, along with giving it access to the new GPRs R8-R15.
* `EmitREXOpcodeModRM(Opcode, Mode, DestinationRegister, SourceRegister, ExtraREX)` Which will build a REX prefix, write the opcode, and then write a "ModRM" byte, which controls the operands, and operand types of an instruction.
* `EmitREXOpcodeModRMSIB(Opcode, Mode, DestinationRegister, Scale, IndexRegister, BaseRegister, ExtraREX)` Which will build a REX prefix, opcode, and ModRM byte which uses the SIB addressing mode. SIB stands for (S)cale (I)ndex (B)ase, which allows you to have address calculations like `FinalAddress = GetRegisterValue(SIB.Base) + (GetRegisterValue(SIB.Index) * SIB.Scale)`, which are very useful for indexing arrays.
* `ResolveAllLabels` Which will resolve all labels, and return the linked code.

## PEBuilder

A class that handles all the dirty work of building `.exe` files.

Most of the code is spent building the headers, and setting the correct magic numbers.

The only interesting bit is how the import address table (IAT) and `.reloc` (relocation) section is built.

The IAT is built with one structure for each Dll that functions are imported from, and 2 parallel arrays which hold the actual import data.

The structure holds a pointer to the first array, the number of entries in all of the arrays, a pointer to the Dll name, and a pointer to the 2rd array.

Each entry in the 1st and 2nd array is identical until the `.exe` file is loaded, but before that, an entry considered part of a "hint-name table", which is made up of an ordinal value for the imported function, or a pointer to the function's name. 

I do not bother with ordinal values.

Once the loader reads the hint-name table, each entry in the 2nd array is overwritten with a pointer to the function it originally imported, which `PEBuilder` links code to jump into.

The `.reloc` section handles what should happen when the file can't be loaded at the specified base address, and contains pointers to every location inside of the code which references a static address. So, every use of a global variable, and every use of an import function, gets an entry in the `.reloc` section.