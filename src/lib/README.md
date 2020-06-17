# The standard (and only) library

## Index

* Memory allocation: [Memory](#Memory.rlx), [SimpleHeap](#SimpleHeap.rlx)
* String manipulation: [String](#String.rlx), [SafeString](#SafeString.rlx)
* Console IO: [Console](#Console.rlx)
* File IO: [File](#File.rlx)
* Managed data structures: [HashMap](#HashMap.rlx), [Memory](#Memory.rlx)

### Note:
Everything in this list can be compiled for both Windows or Linux, however, [SimpleHeap](#SimpleHeap.rlx) does not generate any code on Windows, as Windows has a built in heap manager, and does not need a re-implementation.

So, instead of calling any `SimpleHeapXXXX` functions directly, it is recommended you use the [Memory](#Memory.rlx) functions instead, as they will call the correct underlying function for your target platform.

It is also recommended that you use these library functions whenever possible, as they are 100% platform independent (except when mentioned), and produce functionally equivalent code for Windows and Linux without any source code changes.

## Memory.rlx
Provides platform independent functions to allocate/free/reallocate memory.

### Depends on
* [SimpleHeap.rlx](#SimpleHeap.rlx) for an actual heap implementation on Linux.

### Functions
* `Alloc` allocates the passed number of bytes from the heap.
* `ReAlloc` extends and returns a new pointer to the pass memory, which is large enough to hold the passed number of bytes.
* `Free` frees the passed pointer.
* `AllocArray` allocates an simple managed array.
* `ReAllocArray` extends the above array.
* `GetArrayLength` returns how many elements an array holds.
* `FreeArray` frees the entire array.

### Globals
* `i64 hProcessHeap` a handle to the process heap on Windows.
* `i32 HEAP_ZERO_MEMORY` a Windows API constant to 0 allocated memory.

### Types
* `struct ExpandArray` the basic managed array.

## SimpleHeap.rlx
A (bad) heap manager, since Linux does not come with one.
Does nothing on Windows.

### Functions
* `SimpleHeapInit` will set the program break, and write a `SimpleHeap` structure to it, which tracks the heap start/end.
* `SimpleHeapGrow` will extend the program break.
* `SimpleHeapAlloc` will allocate memory out of the program break, growing it if needed.
* `SimpleHeapCopyClear` will copy data between two locations in memory, clobbering the data in the `From` memory.
* `SimpleHeapReAlloc` will allocate new memory, and copy/clear the old memory into the new.

### Globals
* `i32 DEFAULT_HEAP_SIZE` the starting size of the heap, along with how much the heap is grown by.
* `SimpleHeap* ProcessHeap` a pointer to the backing `SimpleHeap` structure used to track the program break end/next free address.

### Types
* `struct SimpleHeap` a struct which tracks how large the heap is, and where the next free memory is.

## String.rlx
Provides some basic string manipulation functions.

### Depends on
* [Memory.rlx](#Memory.rlx) for allocating memory to store new strings in.

### Functions
* `AToW` converts an `i8*` string to an `i16*` string.
* `WToA` converts an `i16*` string to an `i8*` string (with potential data loss).
* `ALen` finds the length (in characters) of the passed `i8*` string.
* `WLen` same as `ALen`, but for `i16*` strings.
* `HeapString` copies a stack allocated `i8*` into heap allocated memory, for passing a string literal backwards up the call stack.
* `Lower` returns `A-Z` converted to `a-z`, or the passed character when it is not `A-Z`.
* `CharacterEqualsNoCase` checks that two characters are equal, ignoring if they differ in case.
* `IsAlpha` returns if a character is `A-Z` or `a-z`.
* `IsNumeric` returns if a character is `0-9`.
* `IsAlphaNumeric` returns if a character is alphanumeric, or "`_`".
* `IsPath` returns if a character could (sanely) be included in a file path. `A-Z`, `a-z`, `_/\.` are included in this check.
* `_IsHex` returns if a character is between `A-Fa-f`.
* `IsHex` returns if a character is `_IsHex`, or `IsNumeric`. Aka `A-F`, `a-f`, `0-9`.
* `IsWhiteSpace` returns if a character is a space, tab, or line end character.
* `AReverse` reverses the passed `i8*` string in place.
* `IToA` prints an `i64` into an `i8*` string, and returns the `i8*`.
* `NumberToHex` converts a number from `0-15` into a character `0-F`.
* `IToAH` is `IToA`, but prints the number in hex (`0x` prefix included)
* `IToW` is `IToA`, but converts the result to a `i16*` string.
* `IToWH` is `IToAH`, but converts the result to a `i16*` string.
* `AToI` reads a (positive or negative) `i64` out of the passed `i8*` string.
* `WToI` is `AToI`, but with an `i16*` string.
* `StringEquals` returns if the two passed `i8*` strings are equal.

## Console.rlx
Provides functions to write various different data types to the console.

### Depends on

* [Memory.rlx](#Memory.rlx) for allocating temporary buffers, along with freeing buffers created by:
* [String.rlx](#String.rlx) for getting string lengths, converting between wide/char strings, stringify-ing numbers.

### Functions
* `GetStdHandle` for getting a 'handle' (or file descriptor) for stdio streams.
* `SwapOutputStream` for switching from writing to stdout to writing to stderr (and back).
* `WriteNewLine` guess.
* `WriteCharacter` guess.
* `AWrite` writes a null terminated `i8*` (C string) to stdout/err.
* `AWriteLine` calls `AWrite`, then `WriteNewLine`.
* `Write` writes a null terminated `i16*` (Wide string) to stdout/err.
* `WriteLine` calls `Write`, then `WriteNewLine`.
* `IWrite` stringifies an `i64`, and writes it to stdout/err.
* `IWriteLine` calls `IWrite`, then `WriteNewLine`.
* `IWriteHex` is `IWrite`, but prints the number in hex.
* `IWriteHexLine` take a another guess.
* `TranslateWindowsColor` is internal, and translates a windows console color to an ANSI escape color.
* `WriteANSIEscape` writes the ANSI escapes to change the console color to the passed fore/background colors.
* `SetColor` sets the console fore/background colors to the passed colors, independent of the platform.
* `ResetColors` sets the console back to white text, on a black background.
* `TextColor` just sets the foreground color.
* `ReadLine` does not work.
* `ParseCommandLine` parses the passed command line string, and sets the passed pointers to the parsed `ArgC`/`ArgV`.
* `GetArgs` just calls `ParseCommandLine`, except for on Linux, in which case the command line is already parsed, and it does nothing.

### Globals
* `i64 STDIN` a file handle/descriptor for stdin.
* `i64 STDOUT` a file handle/descriptor for stdout.
* `i64 STDERR` a file handle/descriptor for stderr.
* `i8 Bright` bit flag to make a console color brighter.
* `i8 Red` bit flag to add red to a console color.
* `i8 Green` bit flag to add green to a console color.
* `i8 Blue` bit flag to add blue to a console color.
* `i8 White` (Bright | Red | Green | Blue), aka white. Not a bit flag.
* `i8 Black` 0, aka black. Also not a bit flag.

## SafeString.rlx
A safe-ish string type, with some helper functions.
Not null terminated, length is tracked.

### Depends on
* [Memory.rlx](#Memory.rlx) for allocating strings.
* [String.rlx](#String.rlx) for basic string manipulation.
* [Console.rlx](#Console.rlx) for printing a safe string.

### Functions

* `AllocateNewSafeString` allocates and returns a `SafeWideString*`.
* `FreeSafeString` frees a `SafeWideString*`.
* `AToS` converts an `i8*` string to a `SafeWideString*`.
* `SafeStringEqualsAString` checks if a `SafeWideString*` has the same characters as an `i8*` string.
* `PrintSafeString` prints a `SafeWideString*` to the console.
* `SafeStringHexToI64` is `WToI`, but for a hex literal inside of a `SafeWideString*` string.
* `SafeStringToI64` is `WToI`, but for a `SafeWideString*`.

### Types
* `struct SafeWideString` a container for a `i16*` string, and the length of the string.

## HashMap.rlx
A sort of bad hash map implementation.

### Depends on
* [Memory.rlx](#Memory.rlx) for allocating memory for a hash map.
* [SafeString.rlx](#SafeString.rlx) for key strings.

### Functions
* `NewHashMap` returns a freshly allocated `HashMap*`.
* `HashString` hashes a `SafeWideString*` string, and returns the hash.
* `HashMapGetIndex` returns the bucket index for the given hash and given bucket count.
* `HashMapFindElement` finds either: the `HashMapElement` with the given hash, or the last `HashMapElement` in the bucket containing the given hash.
* `HashMapGetValue` will return the `HashMapElement` (if there is any) in the map with the given `SafeWideString*` hash.
* `HashMapAddValue` will insert/update the `HashMapElement` inside of the hash map with the passed value.

### Types
* `struct HashMap` a container for an array of buckets which make up the actual hash map.
* `struct HashMapElement` container for a single element in a hash map, forms a linked list when a bucket contains 1+ element.

## File.rlx
Platform independent file manipulation.

### Depends on
* [Memory.rlx](#Memory.rlx) to allocate memory to read file data into.

### Functions
* `FileOpen` opens the given `i8*` file path, with the given `OpenMode`, and returns a handle/descriptor to the file.
* `FileSeek` seeks the file pointer for `File` to `Offset`, relative to `Mode`.
* `FileTell` gets the file pointer offset for `File`.
* `FileRead` reads `BytesToRead` bytes out of `File` into `Buffer`.
* `FileReadAll` reads all data from `File` into a buffer, and returns the buffer.
* `FileWrite` writes `BufferSize` bytes out of `Buffer` into `File`
* `FileClose` closes a file handle/descriptor.
* `FileGetError` returns if the result of any `FileXXXX` function was an error, and translates it to a platform specific error code.
* `FileDelete` deletes the file at the passed `i8*` file path.

### Globals
* `i32 FILE_READ` bit flag to open a file for reading.
* `i32 FILE_WRITE` bit flag to open a file for writing.
* `i32 FILE_READ_WRITE` combination of `FILE_READ | FILE_WRITE`.
* `i32 FILE_CREATE_NEW` bit flag to signal that `FileOpen` should create the given file if it does not already exist.

* `i32 SEEK_SET` flag for `FileSeek` to set the file pointer relative to the start of the file.
* `i32 SEEK_RELATIVE` flag for `FileSeek` to set the file pointer relative to the current file pointer.
* `i32 SEEK_END` flag for `FileSeek` to set the file pointer relative to the end of the file.