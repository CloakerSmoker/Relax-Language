### Disclaimer
I reserve the right to call any code I don't like undefined behavior. 

Same with any code which seems to trigger a compiler bug.

Also the same with any code I can't read.

Also the same with any code that's so dumb I can't believe that it didn't get caught as an error.

___

## Undefined-Behavior

When you write code which does things I didn't expect. 

For example, overwriting a bunch of the stack by using a string literal's address in an unbounded loop.

Well, not that example, since I expect it now. I'm not going to stop you from crashing your own program though.

Here's a good one: `&1`. 'What will it do?' you might ask, well, I've got no clue. It's undefined, and I can't be bothered to check what happens. Just don't do it.

## Undefined-Values

When I've forgotten to set a variable to something, or you go peeking into something internal, then you've got an undefined value.

This includes variables before they are initialized, or other places where I've forgotten to make an operator actually work.

___

## How to deal with undefined-anything
Well, it's a 

```
> Doctor, it hurts when I do X
```

kind of situation, just don't do `X`.

Unless it's a perfectly normal operation which doesn't work, then maybe let me know.