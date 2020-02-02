## The structure

The compiler is laid out in various separate stages, in the order:

* [Lexer](#lexer)
* [Parser](#parser)
* [Optimizer](#optimizer)
* [Compiler](#compiler)
* [CodeGen](#codegen)
* [PEBuilder](#pebuilder)/[ToAHK](#toahk)

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

So, `32` would also be consumed, and added to the `t` token, however, ` ` is not alphanumeric, and would be the end of the `t` token.

Next, to figure out the type of the token, the lexer checks if it is in the list of keywords (found in `Constants.ahk`), and since it is not a keyword, the token is created with the type `Tokens.IDENTIFIER`, and a value of `i32`.

This would repeat for `test`, giving us the two tokens:

```json
[{Value: "i32", Type: Tokens.IDENTIFIER}, {Value: "test", Type: Tokens.IDENTIFIER}]
```

Now, the lexer would see the character `:`, and `:` is defined as the first character of an operator (in `Constants.ahk`'s `CharacterTokens.Operators`).

Since `:` is an operator (or part of an operator), the lexer will now:

* Check if the next character is part of any operators (In this case the next character is `=`, which is part of `:=`)
* Gather all characters that are part of the operator which matches the next character (`:=` only has two characters, so this step is already done)
* Create a token of the `Tokens.OPERATOR` type, with the value of the found operator (`Tokens.COLON_EQUAL` in this case)

Now we've got:

```json
[{Value: "i32", Type: Tokens.IDENTIFIER}, {Value: "test", Type: Tokens.IDENTIFIER}, {Value: ":=", Type: Tokens.OPERATOR}]
```

And the next character is `9`, which the lexer would see is:

* Not the start of an operator
* Not the start of a string, or character literal
* Not whitespace
* Not a new line
* *Is* a digit

Now, the lexer will gather all digits following the first, getting us `99`, and create a `Tokens.INTEGER` token, with the value `99`. (If the lexer found the character `.` inside the number, the token type would be `Tokens.DOUBLE`)

Now, applying these same rules to the rest of the string, we get the following array of tokens for the output:

```json
[
    {Value: "i32", Type: Tokens.IDENTIFIER}, 
    {Value: "test", Type: Tokens.IDENTIFIER}, 
    {Value: ":=", Type: Tokens.OPERATOR},
    {Value: 99, Type: Tokens.INTEGER},
    {Value: "+", Type: Tokens.OPERATOR},
    {Value: 2, Type: Tokens.INTEGER}
]
```

---

And that's all the lexer really does. Of course, there's many-many more token types than I mentioned, and the lexer also has cases for hex/binary/octal literals, which are given the type `Tokens.INTEGER`.

## Parser

The parser takes the array of tokens which the lexer outputs, and builds an abstract syntax tree out of the tokens.

<br/>

And abstract syntax tree (AST) is a how a given program is represented, in this case, each "leaf" of the AST is either a `Token` object (which the lexer outputs) or a `ASTNode` object.

For example, the AST of `1 + 2` would be:

```json
{
    Type: ASTNodeTypes.BINARY,
    Left: {
        Type: Tokens.INTEGER,
        Value: 1
    }
    Operator: {
        Type: Tokens.OPERATOR,
        Value: "+"
    }
    Right: {
        Type: Tokens.INTEGER,
        Value: 2
    }
}
```

This concept is the same throughout the entire parser, you have an AST node, which has other AST nodes inside of it, which can represent any part of a program.

The hard part is actually building the AST.

---

To build the AST, the parser starts with `Parser.ParseProgram`, which uses the array of tokens from the lexer (passed in `Parser.__New`), and calls `Parser.ParseProgramStatement` until the parser has processed all of the given tokens.

`.ParseProgramStatement` looks at the next token to be parsed, and does a few different things based on *what* the next token is:

* When the next token is a `Tokens.KEYWORD` and has the value `Keywords.DEFINE`, then the parser will call `Parser.ParseDefine`
* When the next token is a `Tokens.KEYWORD` and has the value `Keywords.DLLIMPORT`, then the parser will call `Parser.ParseDllImport`
* When the next token is a `Tokens.KEYWORD` and has the value `Keywords.IMPORT`, then the parser will add the following token to a running list of imported modules.
* When the next token is a `Tokens.IDENTIFIER` and is a valid type name, then the parser will call `Parser.ParseDeclaration`
* If none of the earlier cases were met, the parser will throw an error.

In cases 1, 2, and 4, the parser branches off to a different function, which will try to match the stream of tokens to a format.

Each of these formats can be found in [the full syntax description](../full-syntax), but as a quick example, here's the `DllImport` format:

```
DllImport i32 FunctionName(i32, i32) {DllFileName.dll, FunctionNameInDLL}
```

Which is the token type pattern of:

```
DllImport       i32                FunctionName       (                  i32                ,             i32                )                   {                    DllFileName        .           dll                ,             FunctionNameInDLL  }
Tokens.KEYWORD, Tokens.IDENTIFIER, Tokens.IDENTIFIER, Tokens.LEFT_PAREN, Tokens.IDENTIFIER, Tokens.COMMA, Tokens.IDENTIFIER, Tokens.RIGHT_PAREN, Tokens.LEFT_BRACKET, Tokens.IDENTIFIER, Tokens.DOT, Tokens.IDENTIFIER, Tokens.COMMA, Tokens.IDENTIFIER, Tokens.RIGHT_BRACKET
```

And when a `DllImport` statement does not match this pattern, then there is a syntax error. 

The entire parser follows this general idea, you have a token type pattern associated with an AST node type, and when the token stream matches that pattern, then it can be consumed and built into an AST node. When the token stream only partially matches the pattern, then there is a syntax error.

For example, 

```
DllImport i32 123() {Fn.doo, "hello world"}
```

Does not match the `Tokens.IDENTIFIER` rule for `FunctionName`, since `123` is a `Tokens.INTEGER`.
Then `"hello world"` does not match the `Tokens.IDENTIFER` rule for `DllFileName`.

Both of these are syntax errors, and will be detected by the parser.

---

Now, for something a bit more advanced, we'll mode on to the `Define` statement, which follows the 

```
Define ReturnType FunctionName(ParameterList) {
    Body
}
```

pattern (and is handled by `.ParseDefine`).

Since everything but `Body` was already defined in the last example, we'll jump straight to that.

After everything up to `{` has been parsed, the parser calls into `.ParseBlock`, which consumes the `{` token, and calls `.ParseStatement` until it reaches a `}` token.

Now, looking into `.ParseStatement`, you can see it has three branches:

* When the next token is a keyword, call into `.ParseKeywordStatement`
* When the next token is an identifier, and a valid type name, call into `.ParseDeclaration`
* Else, call into `.ParseExpressionStatement`

I'm only going to talk about the first and third options, since `.ParseDeclaration` doesn't do much, and is pretty much the same kind of matching as `DllImport`.

So, `.ParseKeywordStatement` is for when we've already matched a `Tokens.KEYWORD` type token, so by switching on the `Value` of that token, we can figure out which kind of statement is starting.

The statement types and actions are:

* For a Keywords.RETURN, return a `return` AST node, which returns the value given by `.ParseExpressionStatement` (which I'll get to later)
* For a Keywords.IF, return the result of `.ParseIf`
* For a Keywords.ELSE, throw an error, since any `else if`/`else` statements are parsed by `.ParseIf`
* For a Keywords.FOR, return the result of `.ParseFor`
* For a Keywords.CONTINUE or Keywords.BREAk, return a `ContinueBreak` node, with the keyword used ("continue" or "break")
* If none of these have matched, then throw an error.

I'm just going to go through the Keywords.IF case, since it uses all of the capabilities that the other cases use, and will explain everything you need to know.

So, now we're inside of `.ParseIf`, and this first think we do is build an `if` AST node using `.ParseExpression` and `.ParseBlock`.

You might notice that we already called `.ParseBlock` back in `.ParseDefine`, and that is a key part of the parser.

This parser is a "recursive descent parser" (which sounds super cool), which means that through recursive function calls, the call stack itself takes the shape of the AST as we parse the program.

For example:

```
define i32 abc() {
    if (1) {
        return 8
    }
}
```

Would have the call stack (bottom = first call, top = most recent call)
```
.ParseExpression (Handles the 8 after return)
.ParseKeywordStatement (Handles return)
.ParseBlock (Handles {} after the if)
.ParseIf (Handles the if)
.ParseBlock (Handles {} after abc)
.ParseDefine (Handles the define)
.ParseProgram
```

and the AST is

```json
{
    Type: "Program",
    Functions: [
        {
            Type: "Define",
            Body: [
                {
                    Type: "If",
                    Body: [
                        {
                            Type: "Return",
                            Value: 8
                        }
                    ]
                }
            ]
        }
    ]
}
```

Which means that by using the result of a `.ParseXXXXX` method inside of another `.ParseXXXXX` method to build a new AST node, we can summon a properly structured AST out of thin air.

Which is pretty neat.

<br/>

Now, back to `.ParseIf`.

The template is 

```
if Expression {
    Body
}
else if Expression {
    Body
}
else Expression {
    Body
}
```

Where: 

* `if Expression` only occurs once, at the start of this "chain" of statements
* `else if Expression` can be repeated as many times as you'd like
* `else` can only occur once, at the end of the chain

Each `Expression` is parsed by `.ParseExpression`, which we'll get into next, and each `Body` is parsed with `.ParseBlock`.

And since the results of these `.ParseXXXX` calls are being used to build a bigger AST node, we are taking advantage of the recursive descent parser again to build AST nodes.

---

Now, this is how all statements are parsed, first they match a token type pattern, and then they contain other AST nodes that make up the statements themselves.

The only exception to this style is expressions, since they do not fit a set token type pattern, and are much more unpredictable.

---

#### Expressions

The parser does not use recursive descent to parse expressions, so it's worth separating the two part.

Instead, the parser uses the "shunting yard algorithm", which sounds much less cool than recursive descent, but is an *incredible* technique.

---

I actually don't understand the shunting yard algorithm enough to explain it fully, but the general idea is:

* At the start of parsing an expression, set up an "Operator" stack, and an "Operand" stack.
* Iterate through each token of the expression, and:
*  When you find data (Like a number, string, or variable), push it onto the "Operand" stack and continue the loop.
*  (This is not part of the standard algorithm) When you find '(', call `.ParseGrouping` to parse the grouping, and push it onto the "Operand" stack.
*  When you find an operator, go through the "Operator" stack, and check the "Precedence" of the current operator against the one on the top of the stack.
*   If the operator on the top of the stack has higher precedence than the current operator (meaning that you should check if it should be evaluated before the current operator)
*    Then pop two operands off the "Operand" stack, and build an AST node with (PoppedOperand1, PoppedOperator, PoppedOperand2), and push it onto the "Operand" stack
*   Continue this for the entire "Operator" stack, until you find an operator with lower precedence than the current operator, or the "Operator" stack is empty
*   Finally, push the current operator onto the "Operator" stack
* Once all tokens are consumed, loop through any operators left in the "Operator" stack, and pop two operands from the "Operand" stack for each, then push them back onto the "Operand" stack.
* Return `OperandStack[1]`

So, for example, `1 * 2 + 3` would be parsed with the following steps:

Start with `1`, it's data, so we'll push it onto the operand stack

```
OperandStack = [1]
OperatorStack = []
```

Next we have `*`, which is an operator, and since the operator stack is empty, all we do is push it onto the operator stack

```
OperandStack = [1]
OperatorStack = ["*"]
```

Next up is `2`, which is data again

```js
OperandStack = [1, 2]
OperatorStack = ["*"]
```

And now we've got `+`, which is an operator, and since the operator stack has something in it, we need to check `+`'s precedence against `*`'s precedence.
Now, `+` has a precedence of 5, and `*` has a precedence of `6`, which means that `*` needs to be evaluated before `+`.
So, we'll pop two operands off of the operand stack, and combine `1, *, 2` into a single `Binary` AST node, and push that onto the operand stack.
Finally, we push `+` onto the operator stack.

```js
OperandStack = [{Type: ASTNodeTypes.BINARY, Left: 1, Operator: "*", Right: 2}]
OperatorStack = ["+"]
```

Next is `3`, which is data, so it goes onto the operand stack, leaving us with:

```js
OperandStack = [{Type: ASTNodeTypes.BINARY, Left: 1, Operator: "*", Right: 2}, 3]
OperatorStack = ["+"]
```

And before we return a result, we go through the operator stack one last time, and build AST nodes for each operator left on the stack.

So, we pop `+` off the operator stack, pop `3` and `{Type: ASTNodeTypes.BINARY, Left: 1, Operator: "*", Right: 2}` off of the operand stack, and build the AST node:

```js
{Type: ASTNodeTypes.BINARY, Left: {Type: ASTNodeTypes.BINARY, Left: 1, Operator: "*", Right: 2}, Operator: "+", Right: 3}
```
And push it onto the operand stack. Then finally, we return `OperandStack[1]`, which is that same AST node we just built, giving us 

```js
{
    Type: ASTNodeTypes.BINARY,
    Left: 
    {
        Type: ASTNodeTypes.BINARY, 
        Left: 1, 
        Operator: "*", 
        Right: 2
    }, 
    Operator: "+",
    Right: 3
}
```

Aka `(1 * 2) + 3`

---

And that's the parser, a little oversimplified, but I think it gets the general design across well enough.

If you're interested in either of the parsing techniques used, google them, there's load of good articles and graphics explaining them better than I can.

## Optimizer

The optimizer takes the resulting AST from the parser, and walks it, replacing AST nodes with slightly optimized versions of themselves.

The "walking" is done by recursively visiting each branch of an AST node, so a binary expression would have the `"Left"` and `"Right"` branches optimized before the binary expression itself is optimized.

Most of the optimizer depends on `.IsConstant`, and `.ExpressionHasSideEffects`, which are both used to determine if an expression is a candidate for being optimized or removed entirely.

And AST node which contains an `ASTNodeTypes.EXPRESSION` is optimized by calling `.Optimize%ExpressionType%`, which:

* For unary expressions, nothing. I do not optimize unary expressions, mostly because only ~2 of the unary operators don't have side-effects.
* For binary expressions, I optimize both sides, and if both sides are constant values (ex: 1 and 2), then I manually evaluate the expression, and build a token containing the new result.
* For grouping, I optimize all sub-expressions, and then remove any which do not have side-effects. (for example, `(1, 2 + 3)` would become `1`, since `2 + 3` has no side-effects, and only wastes space)
* Function calls are not optimized, since I got lazy while writing the optimizer.

Additionally, some statements are optimized:

* For if statements, if an `else if` has a constant condition which is false, the entire `else if` is eliminated, and when an `else if` has a constant true condition, all `else if`s after are eliminated.
* Expression statements are totally eliminated if they do not have side-effects, for example, `1 + 2` alone on a line would be eliminated.

And that's the optimizer. It's very basic, and I wish I'd written more for it, but I was reaching max-burnout while writing it.

## Compiler

The compiler takes the optimized AST from the optimizer, and walks it, calling into `CodeGen` to generate machine code for each AST node it visits.

The AST walking is done in the same way as the optimizer, with each AST node calling `.Compile` for any leaves it has.

Statements are compiled in mostly-similar ways, with a condition being compiled, then tested, and a conditional jump to either the next statement in a chain, or out of the current statement, or more specifically:

* If statements are compiled by compiling the condition expression, testing it with `result != 0`, and conditionally jumping into the `Body` for the statement. After the body, a `jmp` to the end of the statement stops any other branches from running. If the `!= 0` test fails, it `jmp`s to the next condition and body to be checked.
* For loops are compiled with the initialization step first, then a label to jump back to, then the condition (and a jump out of the loop when the condition is false), and then the loop body. After the body is the step expression, and a jump back to the start of the loop.
* Break/Continue are compiled by jumping either out of the current loop, or the end of the current loop, using the `.CurrentForLoop` property which holds a label name for the current for loop.
* Return statements are compiled by jumping to a special label for the current function (`__Return` then the number of functions compiled before this one) which is placed at the end of the function
* Function definitions are compiled with a label in the format `__Define__FunctionName` which can be used to call the function via a relative offset. Then the entire function body is compiled, and postlude code is generated to clean up the stack, and then return from the function.

---

Expressions are a little less label/`jmp` intensive, but more complex to understand.

Expressions are evaluated using a "register stack". This means that instead of pushing operands onto the regular stack, operands are moved into certain registers, which are used like a stack. 

So `1 + 2` could be 
```asm
push 1
push 2
pop rbx
pop rax
add rax, rbx
push rax
```
using the regular stack, but with the register stack, it would be
```asm
mov rcx, 1
mov rdx, 2
add rcx, rdx
```
Which allows us to generate much more compact code, while also improving speed (since operands stay in registers).

---

Now, this technique is used for everything but: local variables, global variables, and floating point numbers.

And for everything but those mentioned, it works great.

Local variables and parameters are treated exactly the same, and live on the stack, in space allocated by the current function's prelude.

`R15` is always set to a pointer into the stack where the locals are for simplicity.

Global variables live in pre-allocated memory from either: the windows loader, or the AHK boilerplate code.

And finally, floating point numbers. Floating point numbers are handled with the x87 FPU, which is older than me, and not very fun to work with.
Back when the x87 FPU was first dreamt up, general purpose registers (GPRs) were only 16 bits, while x87 registers were up to 80 bits. So, there are 0 instructions to load an x87 register from a 64 bit GPR.

<br/>

To get around this, when a value is going to be used in floating point math, it is pushed onto the CPU stack, and then a x87 register is loaded by using `RSP + 0` as an address to load from.
Then, once the x87 register is loaded, the stack is popped, and all things are good in the world.

Except for when you reach the point where you actually need to do the floating point operation. All x87 instructions only work with x87 registers, so after an x87 operation completes, you need to push some dummy data onto the stack, tell x87 to write a value into `RSP + 0`, and then pop the stack into the true result register.

Now's a good time to mention some fun x87 instruction names.

To cast a floating point number in an x87 register to an integer, and then store that integer, you use the 
```
FISTP
```
instruction.

To compare two floating point numbers, and to set the standard flags register accordingly, you use the
```
FCOMI
```
instruction. (Which I'm pretty sure would have been added some time during the cold war)

---

And that's pretty much the compiler. It's a lot more lines than it needs to be, mostly because as much work as possible in the compiler instead of in the generated code.

## CodeGen

This one will be shorter, I promise.

CodeGen is a class which generates the correct bytes for lots of common AMD64 instructions, and automatically handles linking labels and jumps for you.

This is done by storing an internal array of bytes, which contains assembled instructions, with objects pushed onto the array when `CodeGen` does not have enough information at the time to link the given label to an address. Additionally, `CodeGen` pushes objects for pointers to global variables, and pointers to functions imported from Dll files.

`CodeGen` doesn't actually process these extra objects, but keeps them intact until either the "second stage" linkers in `PEBuilder` or `ToAHK` can link the code to actual pointers.

The backbone of CodeGen is just a few methods:

* `.REX(REXBits)` Which will build a "REX prefix" for an instruction, which will promote the instruction to use 64 bit registers and data, along with giving it access to the new GPRs R8-R15.
* `.REXOpcode(OpcodeBytes, REXParts)` Which will build a REX prefix, and then write an opcode.
* `.REXOpcodeMod(OpcodeBytes, DestRegister, SourceRegister, Options)` Which will build a REX prefix, write the opcode, and then write a "ModRM" byte, which controls the operands, and operand types of an instruction.
* `.REXOpcodeModSIB(Opcode, Register, SIB, Options)` Which will build a REX prefix, opcode, and ModRM byte which uses the SIB addressing mode. SIB stands for (S)cale (I)ndex (B)ase, which allows you to have address calculations like `FinalAddress = GetRegisterValue(SIB.Base) + (GetRegisterValue(SIB.Index) * SIB.Scale)`, which are very useful for indexing the local table, global table, and import table.
* `.NumberSizeOf(Number)` Which returns the minimum number of bits needed to store the given number (used for instruction selection).
* `.SplitIntoBytes32(Number)` Which splits a 32 bit number into bytes, and stores it big-endian (like the processor expects).
* `.SplitIntoBytes64(Number)` Same as above, but with a 64 bit number.
* `.Link()` Which will resolve all labels, and return the partially linked code for a second stage linker.

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

---

If you're wondering, the default section layout (which you can't change) is:

| Section Name | What it's for |
|--------------|---------------|
| `.data`      | Holds global variables |
| `.text`      | Holds compiled code, and the program entry point |
| `.idata`     | Holds the IAT, hint-name table, import file/name strings |
| `.reloc`     | Holds the relocation info |

## ToAHK

A single function, which just dumps a program as a bunch of AHK functions

It pretends to be the windows loader via some boilerplate, and pretends to be `PEBuilder` in the same boilerplate, by linking global pointers and imported function pointers.

There's really not much to say about it.