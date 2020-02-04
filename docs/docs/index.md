# Relax
A compiled programming language, implemented entirely in AHK

You might notice that the name is a bit ironic, since writing this in AHK gave me absolutely 0 changes to just *relax*.

## FAQ
##### Q: What the fuck, why, dear god, why?!

A: ¯\\_(ツ)_/¯ (see "Why I Did This")

##### Q: Wait, so this is an actual compiler?

A: Yes, this script takes source code as input, tokenizes it, parses the tokens, optimizes the code a little bit, generates machine code for the parsed/optimized code, and finally builds a `.exe` file holding the compiled code.

All without any outside tools. Every step is personally written by me. (Which probably isn't a good thing, but hey, I'm still proud of it)

For more info, see [how it all works](how-it-works)

## How to use it
See [this page](how-to-use-it) for the different ways Relax can be used.

## How to do most of the work:
(I recommend you follow these in the order 1-2-3 if you already know a C-like language, and 2-1-3 otherwise)

For a quick(-ish) rundown of the syntax, and some quirks, see [the basic syntax page](basic-syntax.md).

For a tutorial sort of thing, see [the tutorial page](tutorial.md).

For a full writeup of the syntax, see [the full syntax page](full-syntax.md).

## How it works

I wanted the header for this on this page, but it's long enough that you'll need to go [to this page](how-it-works) to read that.

## Why I did this

I feel like I need to defend myself here, mostly because I know it's 100% insane to use AHK for a project like this.

AHK was the first language I ever really mastered, and I got used to how everything works, and all of the quirks. 

Because of this, when I decided I wanted to write a toy language, I didn't think of doing it in a "real" language since I already had a language that you can easily (and quickly) prototype things in right in front of me.

---

As for why I'd want to write a language, it's just an interesting topic. I seriously recommend checking out the basics of language design, it's a field which I didn't even know existed until I stumbled on [this ungodly useful (and high quality) free book](https://www.craftinginterpreters.com/) and started reading.

Try your hand at a quick [brainfuck](https://en.wikipedia.org/wiki/Brainfuck) interpreter, and if you like the concept, give that book I mentioned a try.

<br/>

Just make sure that your first project ***is not*** a full on compiled language.

Working on this language has been a rollercoaster, and I blame 100% of that on my ambitions being *way* too high.

If you decide to write your own language, *do not* push yourself to work on it constantly. I did that, and now I'm burnt out enough to stop writing in AHK entirely.

Also, embrace things like LLVM, and pre-made linkers. At some point in this project I decided I wanted to do it all on my own. Which was an ***absolutely terrible*** idea.

Reinventing every part in the car instead of just a wheel will teach you a lot, but its not fun.

Not to mention LLVM can generate much better code than you will manually.