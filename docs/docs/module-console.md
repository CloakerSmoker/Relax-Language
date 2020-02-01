# The Console Module
Top 10 reasons I hate the Windows Console API.

## DllImports

| Imported Function Name  | Imported Function Source          |
|-------------------------|-----------------------------------|
| GetStdHandle            | GetStdHandle, Kernel32            |
| WriteConsole            | WriteConsoleW, Kernel32           |
| SetConsoleTextAttribute | SetConsoleTextAttribute, Kernel32 |
| ReadConsole             | ReadConsoleW, Kernel32            |

## Globals

| Full Global Name   | Default Value             |
|--------------------|---------------------------|
| i64 Console:STDIN  | Console:GetStdHandle(-10) |
| i64 Console:STDOUT | Console:GetStdHandle(-11) |
| i64 Console:STDERR | Console:GetStdHandle(-12) |
| i16 Console:Bright | 0x08                      |
| i16 Console:Red    | 0x04                      |
| i16 Console:Green  | 0x02                      |
| i16 Console:Blue   | 0x01                      |
| i16 Console:White  | 0x0F                      |
| i16 Console:Black  | 0x00                      |

## Functions

| Function Name | Return Type | Parameter List                          | Description                                                                                           |
|---------------|-------------|-----------------------------------------|-------------------------------------------------------------------------------------------------------|
| AWrite        | `i32`       | `i8* AString`                           | Converts `AString` to a wide string, and prints it with `Console:Write`.                              |
| AWriteLine    | `i32`       | `i8* AString`                           | Converts `AString` to a wide string, and prints it with `Console:WriteLine`.                          |
| IWrite        | `i32`       | `i64 Number`                            | Converts `Number` to a wide string with `String:IToW` and prints it with `Console:Write`.             |
| IWriteLine    | `i32`       | `i64 Number`                            | Converts `Number` to a wide string with `String:IToW` and prints it with `Console:WriteLine`.         |
| Write         | `i32`       | `i16* WString`                          | Prints `WString` to `Console:STDOUT` using `WriteConsole`.                                            |
| WriteLine     | `i32`       | `i16* WString`                          | Prints `WString` using `Console:Write` and then \r\n using `Console:Write`.                           |
| SetColor      | `void`      | `i8 Foreground`, `i8 Background`        | Changes the console text colors using `SetConsoleTextAttribute`.                                      |
| ResetColors   | `void`      |                                         | Resets the console text colors to white/black using `Console:SetColor`.                               |
| TextColor     | `void`      | `i8 Foreground`                         | Sets the console foreground color to `Foreground` and the background to black with `Console:SetColor`.|
| ReadLine      | `i16*`      |                                         | Waits for the user to enter a line of input and press enter using `ReadConsole`.                      |

## Notes

Console is a relatively high-level module, and manages a lot of things for you. For example, `IWriteXXXX` and `AWriteXXXX` both free any intermediate buffers allocated for you, and `SetColor` builds the correct structure for color settings for you. 

`ReadLine` handles the allocation and extension of a buffer for console input, and calling `ReadConsole` in a loop to read all input.

## Usage Impact

`Console` imports both `String` and `Memory`, which results in ~8 KB of extra code being generated.