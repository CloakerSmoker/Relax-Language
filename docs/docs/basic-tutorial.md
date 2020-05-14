## Good luck.
Let's be honest here, nobody's going to use this language at all, let alone people who are new to programming.

Either way, I've got time to waste. Get ready for a bad intro to low-level compiled languages.

##### Ignore that part right above here

In Relax, all variables and values have 'types'. This means that a variable can only hold one kind of thing, and that variables will only *ever* hold one kind of thing.

Additionally, you can only use two variables when they have compatible types, so you can't do something like `"This Is My String Of Text" * 9.2`.

The way you decide what type a variable has is by 'declaring' the variable to be a certain type. In Relax you declare a variable to be a certain type by typing a 'type name' along with the variable name, for example:
```
i64 MyVariable
i8 TestVariable
```
Additionally, you can include an 'initial value' after the declaration, like
```
i64 MyVariable := 99 + 20
i32 MyOtherVariable := 10
```

Variables only need to be declared once, however, you can change a variable's value as much as you like.

Great, now that we've got that down, we can move on to *functions*.

A function is a way to wrap a bunch of lines of code which accomplish a task into a single *thing*.

For example: You might have a function to print some text to the screen.

A function has a few components: 

 * A name, which is used when 'calling' the function (calling = running it)
 * A return type, which is what kind of value the function returns (returns = gives back to whatever is running the function)
 * A list of parameters, and parameter types, which are values which are passed to the function to change what it does (passed = given to the function before it runs)
 * The body of the function, which is simply lines of code that are run when the function is called.

So, if we want to write a function to add two numbers, we'd start with the name and return type, along with a special word to signal we are defining a function.
Which leaves us with the format:
```
define ReturnType Name
```

Now we'll replace `ReturnType` with the standard number type, which is `i64`, and `Name` with the name of the function (we will call it `Add`)
```
define i64 Add
```
Great, now we're getting there.

Next we need a list of parameters. Remember that parameters are values given to a function, which change what it does.

In this case, the parameters should be the two numbers to add, since an `Add` function which only does the math for `1 + 1` isn't very useful.

The format for parameters is:
```
(TypeName ParameterName, TypeName ParameterName)
```
Where you can have as many `TypeName ParameterName` combos as you'd like

Since we want to take two numbers, we'll replace `TypeName` with `i64`. Then, `ParameterName` is the name of a variable, which will be set to whatever value is passed to this function.

So, each parameter name needs to be unique. We'll go with `LeftNumber` and `RightNumber` for the names here, which leaves us with:
```
(i64 LeftNumber, i64 RightNumber)
```
And then we stick that onto the code from earlier and get:
```
define i64 Add(i64 LeftNumber, i64 RightNumber)
```

Alright, to save myself some pain and suffering, I'm just going to finish the function and explain it

```
define i64 Add(i64 LeftNumber, i64 RightNumber) {
    return LeftNumber + RightNumber
}
```

`return` will run the code to the right of it, and give the result back to whatever is using this function.
`LeftNumber + RightNumber` will use the two parameters, and add them.

### God does this tutorial suck