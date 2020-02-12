# Changelog

Top of page = most recent.

## 1.0.0-alpha.30

### Added

* Support for compiling to `.dll` files.
* Support for exporting functions through the `export` keyword (which is explained on [the syntax page](../full-syntax#define))

### Changed

* Lots of operations to use slightly bigger operands, which are incredibly easier to read.
* All operations but function calls and register-stack dumps to not use the actual stack (which should increase speed).

### Fixed

* Having identifiers named with the same names as operators (like `i32 Times := 0`) being converted into a `Tokens.OPERATOR` token (and not parsing correctly).
* Both types of comments not working, not `//` and `/* whatever */` should both work fine. 

### Docs changes

* Changed [how to use it](../how-to-use-it) to not mention `Main.exe`, which has been removed since I can never remember to update it.
* Added `export` to the [full syntax page](../full-syntax)
* Added a list of features on the new [feature list page](../feature-list)

---

## 1.0.0-alpha.29

### Added

* Pointer-pointer types, allowing things like `i64**` or `void*******************`. (Maybe don't use that second one though)
* An array-access syntax for pointers which scales the index for you, so `ArgV[Index]` would be equal to `*(ArgV + (8 * Index))` and `ArrayOfI16s[Index]` would be equal to `*(ArrayOfI16s + (2 * Index))`

### Changed

* The `ArgV` parameter to `Main` to be of the type `i16**`.
* The version number
* Binary expressions with the operators `||` or `&&` to result in `i8` typed values.
* The `String` module to use the array access syntax when possible.
* The example programs to use the new `ArgV` type, and to use the array access syntax.

### Fixed

* Programs with 0 global variables generating broken output files.
* Most error messages not have any source code shown.
* Some error messages having the wrong code/not enough code highlighted.
* `*=` Only working with some types.
* Modules which `Import` each other crashing the compiler.
* Regular AHK exceptions causing the compiler to print `"Fatal error, bailing out."` and exit without any context.

### Docs Changes

* Edited [Basic Syntax](../basic-syntax) to remove the mention of not having pointer-pointer types.
* Added [an explanation of array accesses](../basic-syntax#array-access) on the basic syntax page.
* Added [the syntax for an array access](../full-syntax#expressions) on the full syntax page.
* Added [an explanation of pointer-pointer types](../full-syntax#types) on the full syntax page.
* Added [this page](../changelog) to act as a changelog

---

## 1.0.0-alpha.28 (And lower)

None, the change log is new as of `alpha.29`.