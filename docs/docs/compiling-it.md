# Compiling the compiler

This is the only page I have enjoyed (re)writing.

## Rules

* 1) DO NOT COMMIT UNTIL ALL TESTS PASS
* 2) DO NOT COMMIT UNTIL ALL TESTS PASS
* 3) DO NOT COMMIT UNTIL ALL TESTS PASS
* 4) DO NOT COMMIT UNTIL YOU CAN COMPILE YOURSELF

## How To

The `Main` function of the compiler is implemented in `Bain.rlx`, which includes all other components.
The file is not named `Main.rlx` because that was taken by the version for the original (AHK) compiler, which had runtime code that no longer exists.

So, to compile the compiler we run `stable_version.exe Bain.rlx output_name.exe`, simple enough, right? ***Wrong***.

### Testing

Since the compiler has reached a stage where it can only be compiled with the previous version of itself, it is ***100% crucial*** that any version of the compiler can compile itself, otherwise the repo could get stranded where there are 0 versions of the compiler which can compile the source.

I've made the testing process easy with some scripts through, so to actually compile the compiler, you run:
```
python test_boostrap.py
```
which will ensure the latest version of the source can:

* A) Be compiled with the previous version
* B) Compile itself correctly
* C) Compile a series of test programs correctly

If any of these steps fail, `test_bootstrap.py` will error out. However, if none fail, the output will be written to `new_stable.exe`, which can then overwrite `stable.version.exe` and then be used to compile code which requires a new feature.

<br>

For example, to implement unions I followed these steps:

* 1) Change `Lexer.rlx` and `Parser.rlx` to handle the `union` keyword, and correctly alter structure layouts based on the keyword.
* 2) Run `test_bootstrap` to ensure that my changes did not break anything.
* 3) Use `new_stable.exe` to test that I had implemented unions correctly.
* 4) Overwrite `stable_version.exe` with `new_stable.exe`, which now supported the `union` keyword.
* 5) Change `Parser.rlx` and `Compiler.rlx` to use unions for some things.
* 6) Run `test_bootstrap` to ensure that using unions did not break anything.
* 7) Replace `stable_version.exe` with `new_stable.exe` again, which resulted in: A version of `stable_version.exe` which supports the `union` keyword, along with using the `union` keyword in it's own implementation.
* 8) Add tests for the `union` keyword, to ensure the implementation stays correct.

Now that `stable_version.exe` can 100% certainly compile itself correctly, it is safe to make a commit.
Just in case though, step 9 would be to run `test_compiler.py` on `stable_version.exe`, which just runs the `\tests` on the passed compiler, without having it recompile itself.

Through these steps, a new language feature can be implemented almost seamlessly, and with minimal brain-meltage. 

This might be an incredibly roundabout way to implement new features in a bootstrapped compiler, but I legitimately am not smart enough to come up with another way.