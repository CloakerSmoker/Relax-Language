# The String Module
Lots and lots of unsafe code.

## DllImports

None

## Globals

None

## Functions

| Function Name | Return Type | Parameter List                          | Description                                                                                           |
|---------------|-------------|-----------------------------------------|-------------------------------------------------------------------------------------------------------|
| ALen          | `i32`       | `i8* AString`                           | Counts how long the given ASCII string is by finding the null-terminator of the string.               |
| WLen          | `i32`       | `i16* WString`                          | Counts how long the given UTF-16 string is by finding the null-terminator of the string.              |
| WAEquals      | `i8`        | `i16* WString`, `i8* AString`           | Compares the two given strings using `String:WEquals` after converting `AString` to a wide string.    |
| WEquals       | `i8`        | `i16* WStringOne`, `i16* WStringTwo`    | Trims \r\n from both strings using `String:WTrimNewline`, and compares the two using `String:WEqual`. |
| WEqual        | `i8`        | `i16* WStringOne`, `i16* WStringTwo`    | Compares the two strings character by character, and returns `1` if the strings are equal.            |
| WTrimNewline  | `i16*`      | `i16* WString`                          | Removes \r\n from the last two characters of the string, if they are there.                           |
| AReverse      | `i8*`       | `i8* AString`                           | Reverses `AString` character by character, leaving the null-terminator in place.                      |
| WToI          | `i64`       | `i16* WString`, `i8* Success`           | Tries to read an integer from `WString`, sets `Success` to 1 when an integer was read, and returns it.  |
| WIsNumeric    | `i8`        | `i16 Character`                         | Returns if the character is in the range of '0'->'9'.                                                 |
| IToA          | `i8*`       | `i64 Number`                            | Converts `Number` to an ASCII string, including '-' if `Number` is negative.                          |
| IToW          | `i16*`      | `i64 Number`                            | Calls `String:IToA`, converts the result to a wide string with `String:AToW` and returns it.          |
| AToW          | `i16*`      | `i8* AString`                           | Converts `AString` to a wide string, and returns the new wide string.                                 |

## Notes

None of these functions take string lengths, mostly because memory safety has been bleeding out on the floor since the start of this project. They work as long as you don't break things.

Also, they don't take an output buffer as parameters, mostly because that would just shift the blame of who needs to allocate memory.
If a function returns a string type, you are expected to free it with `Memory:Free`.

## Usage Impact

`String` imports the [`Memory`](module-memory.md) module, which alone is not very impactful.
However, since `String` is entirely implemented in (Replace with language name), and many of the `String:` functions depend on each other, the module generates upwards of 5 KB of code.