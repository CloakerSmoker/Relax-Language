# (Replace with name)
A compiled programming language, implemented entirely in AHK

## FAQ
##### Q: What the fuck, why, dear god, why?!

A: ¯\\_(ツ)_/¯

##### Q: Wait, so this is an actual compiler?

A: Yes, this script takes source code as input, tokenizes it, parses the tokens, optimizes the code a little bit, generates machine code for the parsed/optimized code, and finally builds a `.exe` file holding the compiled code.

All without any outside tools. Every step is personally written by me. (Which probably isn't a good thing, but hey, I'm still proud)

For more info, see [the implementation details](details.md)

## How to use
`#Include` the file `Interface.ahk`, which will `#Include` all of the components of the compiler.

Call `(Replace with language class name).CompileToEXE` with a string of code as the first parameter, and a path to an output file which the code will be compiled into.

That's it. Except that most of the work is writing the string of code.

For a quick(-ish) rundown of the syntax, and some quirks, see [the basic syntax page](basic-syntax.md).

For a tutorial sort of thing, see [the tutorial page](tutorial.md).

For a full writeup of the syntax, see [the full syntax page](full-syntax.md).