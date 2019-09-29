#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk

Test := new Lexer("define int32 myfunc() {}")
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Stringify() "`n"
}
MsgBox, % s

Pest := new Parser(Test)
Pest.Start()



/*
Some example code

define Int32 Main(Int32 ArgC, Pointer ArgV) {
	Int64 Example, Example2 := 0
	String Text := Format"Hello, {Example}"
	Print(Text)
	Text := (String(Example) "hello")
	return Example2
}

*/