# Relax
A C-like compiled programming language.
The original compiler was implemented in AutoHotkey, and is now implemented in Relax itself.

## Note

The Relax compiler generates 64 bit machine code, and depends on certain features that only exist on 64 bit processors. This means that there is *no* 32 bit support.

I have no plans for adding 32 bit support, considering that 32 bit machine code is actually much more complex, and would need lots of special cases compared to 64 bit code.

## How to use it
The Relax compiler is packaged along with each commit to the repo (as of [this](https://github.com/CloakerSmoker/Relax-Language/commit/bc91bd89ae900e0646a9e994d338537dc0bfa3ae) commit onwards) as the file `stable_version.exe`, and is ran as: `stable_version.exe [InputFile] [OutputExe]`

Any compilation errors will be written to stderr, with general info being written to stdout.

<br>

If you don't trust the pre-compiled version, you're sadly out of luck. The source code of the Relax compiler can no longer be compiled with the original (AHK) compiler, or older versions of the self-hosted compiler.

Which means that in order to generate your own modern copy of `stable_version.exe`, you'd need to compile the last version of the compiler which was compatible with the original (AHK) compiler. Then from there, you'd need to compile each commit which adds a new feature to the language until you can compile the most recent version of the compiler.

`stable_version.exe` has already done this for you, as it is the running copy of the 'most modern' version of the compiler.

<br>

The only guarantee in terms of what `stable_version.exe` can compile is that: 

`stable_version.exe` ***must*** always be able to compile the version of the source code it shares a commit with (along with all the test programs).

## How to write Relax code:
Pretend it is C with a whole bunch of stuff `#define`'d into existence.

For a quick(-ish) rundown of the syntax, and some quirks, see [the basic syntax page](basic-syntax.md).

For a full writeup of the syntax, see [the full syntax page](full-syntax.md).

## How it works

I wanted the header for this on this page, but it's long enough that you'll need to go [to this page](how-it-works) to read that.

## Why I did this

I have lots of time to waste, and when I started this project, my only goal was to finish it.

#### Note: This next part is outdated, but is being kept since I still think it was insane to write the original compiler in AHK

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