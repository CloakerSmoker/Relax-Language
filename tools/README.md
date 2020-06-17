# Tools
Python scripts which are used to test that a certain executable can:

* Compile all of the [test programs](./../tests/) at all.
* Compile all of the [test programs](./../tests/) correctly, so that they produce the correct output.
* Compile itself, and have the output file compile, run, and pass all tests.
* Repeat above steps multiple times to ensure the compiler doesn't break after a few iterations.

Additionally, a diff percentage along with a byte count difference is shown, to help get an idea of the scale of code generation changes.

(Disclaimer: The scripts are not good Python, but they work, and that's all I need from them.)