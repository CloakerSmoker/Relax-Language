# Implementation Details
Oooo, goodie, I get to explain the fun parts.

Spoiler: Most of the lexer and parser follow the format described in [this wonderful book (that I stopped following after the parser chapter)](https://www.craftinginterpreters.com/)

The optimizer and compiler themselves are all of my own design, same with `CodeGen` and `PEBuilder`.

Of course, the holy bible of AMD64 parts [one](https://www.amd.com/system/files/TechDocs/24592.pdf) and [three](http://support.amd.com/TechDocs/24594.pdf) were wonderful reasources, along with [the holy bible of AMD64 cheat sheet](https://www.felixcloutier.com/x86/index.html) which I got most of the instruction encodings from.

And you can't forget the absolute mess of deprecated things that is the [MSDN page for the PE/`.exe` file format](https://docs.microsoft.com/en-us/windows/win32/debug/pe-format) along with [the 25 year old article](https://docs.microsoft.com/en-us/previous-versions/ms809762(v=msdn.10)) it recommends you read if you ever want to understand the format (Note: that article is still really good though).

___

## Lexer/Tokenizer

Probably the most boring part, but hey, every house needs a foundation, and this is a *very* solid foundation.

I think the last tokenizer bug I found was in October.

Just a simple loop through all the characters, which consumes a single token per iteration, grouping as many characters as possible together into a single token.

It uses lots of helpers, which honestly made it a breeze to write, and probably my favorite part to change, considering how simple it is.

___

## Parser

The part that scares me the most.

A good old fashioned [recursive descent parser](https://en.wikipedia.org/wiki/Recursive_descent_parser) that handles everything but expressions. 

Expressions are handled by a somewhat seperate [shunting yard](https://en.wikipedia.org/wiki/Shunting-yard_algorithm) parser, which works with `Constants.ahk` to get operator precendence/associativity.

All kinds of functions `inline/define/dllimport` are stored inside of the `.CurrentProgram.Functions` object, which is why you can call a `DllImport` function just like any other, since they are treated nearly exactly the same.

Yeah, that's it. The parser isn't very interesting. It parses, and that's that.

Each different header in [the full syntax listing](full-syntax) is implemented as a rule in the parser, except the actual parser has a lot more rules I don't mention in the syntax.

There's lots of ways the parser could be improved, like adding more helpers to increase the code density, and cleaning up the expression parser. However, it was originally written months ago, and I really don't want to fix it when there's nothing broken.

___

## Optimizer

The most half-baked part.

I had very high hopes for `Optimizer`, and I felt very cool while writing it, but it didn't work out. 

I felt like a real language designer until I realized that I'd need to redo it if I ever want to implement larger scale optimizations. 

The optimizer works a lot like the compiler, it walks the AST, and tries to replace each node it walks with a more optimized version, which sounded like a good way to do this at the time.

The problem is that I wrote it to be too narrow. It only looks at one node at a time, and can't eliminate code that's after a `return`, since it only knows that it is trying to optimize a `return`, and doesn't know the outside context. This same problem applies to variables which may/may not hold constant values.

All the optimizer knows is that it has a variable getting used here, it doesn't know that the variable might have been set to `1` the line before.

So, overall, it was a good idea, but a bad implementation.

___

## Compiler

The (second) most boring part.

You wouldn't expect walking an AST and generating machine code to be boring, but after so many hours of debugging, it 100% is.

Debugging compiled code isn't usually that bad, since you get a nice disassembly to look at. Except for when you're debugging code that `DllCall` is jumping into. Every single code generation bug until I got `PEBuilder` working was fixed by manually disassemling the code, and running it in my head. 

You ever count the stack-depth using your fingers? Well, I have. It's not fun.

I like to think that this struggle made me a better programmer, but it really just made me sad.

<br/>

Thanks to `CodeGen.ahk` the actual code generation is all done behind the scenes, and inside of the compiler you get an assembly-like interface from `CodeGen`, which is nice.

What's not as nice is the number of shims and odd-implementations I had to put in.

<br/>

For example, expressions used to be evaluated using the CPU stack to hold operands until use, but then I realized that the stack is in memory, and memory is slow.
So, I sat there thinking and thinking. And then I had a terrrible idea. In the x87 FPU, registers work as a stack, which is a massive pain to deal with.

But of course, my genius idea was to use `[RCX, RDX, R8-R13]` as a fake stack, which is dumped onto the real stack when another register is needed past `R13`.

This was a stupid excuse to avoid reading about real register allocation techniques, but it *does* work.

<br/>

Another fun one is how string literals are handled:

Originally, before compiling to `.exe`, I'd just `DllCall` into the compiled code, which meant I could just use AHK to store a string in memory, and use the AHK-stored version in the compiled code. Except that wouldn't work in a context that AHK isn't setting up for me.

So, I came up with a genius plan. I'd just push 8 characters of the string onto the stack, in reverse. Through lots of mental gymnastics, I figured out a way to do this as well.
Except now that I compile to `.exe`, I can just store string literals in the `.exe` file (which I don't do, putting them on the stack works fine enough, I don't plan to fix it).

<br/>

Yeah, so the compiler is theoretically the coolest part of the entire thing, but I made lots of poor choices, and turned it into a chore to work on.

___

## CodeGen

My second-favorite part.

I mostly just like the fact that by calling into `CodeGen`, the correct magic numbers that the magic rock inside your computer understands are generated.

At first, I hated AMD64 entirely. It seemed so overcomplicated (which it is), but after slowly reading through the manuals for about 6 months, I finally managed to wrap my head around it.

And I abused that power ***as much as possible*** in `CodeGen`.

<br/>

`CodeGen` uses just a few helper methods to generate almost any instruction, with any register you could ever want to use. `CodeGen` even has a basic instruction selector, where you just give it some operands and it'll pick the encoding that can do an operation in the least number of bytes.

Although it is a bit messy, `CodeGen` has classes for every register, which lets you write code that is super-close to assembly. `CodeGen` is even smart enough to have labels, which are resolved both forwards, and backwards (which isn't a big thing at all, I just really like it).

God do I love `CodeGen`, it's got a cool name and everything.

I even gave `CodeGen` a little brother, `i386CodeGen` which is used for generating the DOS stub in `.exe` files.

## PEBuilder

`PEBuilder` feels like a fever dream.
It's foreign to me, even though I wrote every single line of it. 

It took a solid 4 weeks of reading articles, taking apart other `.exe` files, and trying to build my own. 

And I can't remember a single day of that. I can remember having a working DOS stub generator, and then it's all blank until all of the sudden `out.exe` doesn't crash.

Obviously, this is the part of the project I understand the least. I understand the parts of `.exe` files which I use, but nothing else; so I'm inclined to leave it as a bit of a black box until I've recovered from 4+ months of constant work on this language.

## Errors

Big shocker, but this is actually my *absolute* favorite part of the project.

If you haven't seen the error messages yet, try to compile
```
define a_invalid_type_name Main() {}
```

That, is a `PrettyError()`. I borrowed some of the visual style from Rust, but the implementation is my own. 
It's gone through a few versions, but at this point I think it's nearly bug-free (with correct input), and is a very good display of where the error is, and what the problem is.

A life-saver during actual developement has been `OnError(Func("ErrorCallstack"), -1)`, which adds a printout of the callstack to uncaught exceptions, which should really be in AHK by default.

## Other things

`Constants.ahk` isn't perfectly named, but it holds the token type enum, the {OperatorString:TokenType} map, the operator precedence list, the operator precedence checks, the `Token` class, the `Context` class (which just holds info on where in the source code a token was from), the keyword value enum, the AST node type enum, and the AST node classes themselves.

So, it's a boring file, but it's really the backbone of the entire project. Technically, `Utility.ahk` should have most/all of these things in it, but the name stuck. And I'm sick of super long files.

<br/>

`Typing.ahk` handles all of the typing rules. It's actually very boring, and really just tells you when two types are incompatible, and how to cast between two types.

<br/>

The compiler is split into a few categories, since the file was getting too long to debug, so things are split by what kind of node they compile. 