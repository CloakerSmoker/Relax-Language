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
You can ignore the parameters for this tutorial, they might be explained later.

"But wait" I hear you ask, "How are we going to print 'hello world'?".
We're going to use the `Console` module, which is part of the painstakingly written standard library.

To use the `Console` module, we need to import it with `Import Console`, so our code is now:
```
Import Console

define i32 Main(i64 ArgC, void* ArgV) {

}
```
Now, we need to get to printing.

First we'll store the text we want to print into the variable `Message`, which will be a `i8*`. This is because a string of text is stored as a list of `i8` values.
```
Import Console

define i32 Main(i64 ArgC, void* ArgV) {
    i8* Message := "Hello world!"
}
```
Now, we'll use the `Console` module's function `AWrite` to write `Message` to the console. 

The `AWrite` name stands for `ASCII Write` because `i8*` text is stored as ASCII characters, and require special treatment.

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
Congrats, you just wrote hello world. You might notice that it takes ~2 seconds to compile. That is because I am an idiot.