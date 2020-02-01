## So you want to write a program, eh?

### For if you don't know C, or have problems guessing syntax from examples
See the [basic tutorial](basic-tutorial.md) before reading this.

And since the basic tutorial is a mess, don't expect much more from this one.

### The goal: Write a nice hello world program

So, we'll start with the `Main` function, which is automatically run when you run the output `.exe` file.
`Main` always has the same definition:
```
define i32 Main(i64 ArgC, void* ArgV) {

}
```

The parameters and return type do not matter for this tutorial, but it's worth knowing that:

* The `i32` return value is used as the program's exit code.
* `ArgC` is the number of command line args.
* `ArgV` is an array of `i16*` values, which are the command line args as strings.

___


First off, just know that a "module" is just a group of functions which are all related. Modules can't be defined, but a few come pre-made.

In order to to actually use a module, we need to `Import` it first, and so for interacting with the console, we'll need the `Console` module.

So our code is now:

```
Import Console

define i32 Main(i64 ArgC, void* ArgV) {

}
```

___

Now, we need to get to the printing.

First we'll store the text we want to print into the variable `Message`, which will be a `i8*`. This is because a string of text is stored as a list of `i8` values.
```
Import Console

define i32 Main(i64 ArgC, void* ArgV) {
    i8* Message := "Hello world!"
}
```

___

Now, we'll use the `Console` module's function `AWrite` to write `Message` to the console. 

The `AWrite` name stands for `ASCII Write` because `i8*` text is stored as ASCII characters.

In order to call `AWrite`, we need to prefix it with the module name, and a `:` character, like:
```
Console:AWrite()
```
Now we'll just add that, and get:
```
Import Console

define i32 Main(i64 ArgC, void* ArgV) {
    i8* Message := "Hello world!"
    Console:AWrite(Message)
}
```

___

Congrats, you just wrote hello world. You can now run `out.exe` and see the result.



### Summary
So, you know the format for defining functions, declaring variables, along with setting variables, which is good. And just in case you didn't quite catch those, here they are in a list:

* Function definitions follow the format `define ReturnType Name(ParameterList) {}`
* Parameter lists follow the format `ParameterType ParameterName, ParameterType ParameterName` which can be repeated as much as you like.
* Function bodies are just lists of lines, including more function calls, variable declarations, and statements like `if`, `for`, and `return`
* Variable declarations follow the format `TypeName VariableName` with the optional `:= Value`.
* Function calls follow the format `Name(Parameters)` where `Parameters` is a list of comma-seperated values. Function calls into modules are prefixed with `ModuleName:`
* the `Main` function is always declared as `define i32 Main(i64 ArgC, void* ArgV)` and is always the first function called.

#### One last thing
I'm sorry if this tutorial wasn't very helpful. 

I've put so much work into this language over the last half a year that I am 100% burnt out.