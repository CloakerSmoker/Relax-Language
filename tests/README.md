# Tests
Test programs for the compiler, along with expected outputs for each program.

All tests are compiled from the root directory, and use paths relative to it. Any files in [src/lib/](./../src/lib/) can be included, output is expected to be written to stdout, and the tests should exit with code 0.

The expected output for a given test is in a file named `{test_name}_tests.txt`, where each line is a separate run of the compiled test program.

Each line is split by the `:` character, with the left side of the `:` being `ArgV` passed to the test program, and the right side being the expected stdout text. Both sides of the `:` can be empty.

Currently, there is no way to expect a test to fail. 
All compiled binaries are deleted after being run, unless a test is failed, in which case the binary is preserved so it can be manually debugged.

Any test failure is detected by the [testing scripts](./../tools/), and will leave the faulting compiler binary in [the build folder](./../build/) along with printing any error message, error code, or incorrect output which caused the test to fail.