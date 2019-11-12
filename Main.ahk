class VAL {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk

Test := new Lexer("0xFF == 0o377 == 0b11111111 /* + 9000 - /* 10 */ == 8 */ == 255")
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Stringify() "`n"
}
;MsgBox, % s

Pest := new Parser(Test)
a := Pest.ParseExpression()

MsgBox, % a[1].Stringify()

;Gui, New
;Gui, Add, TreeView, w400 h900
;Gui, Show
;
;TV_Delete()
;Start := TV_Add("<AST>",, "Expand")
;AddToTree(Start, a)
return

AddToTree(Parent, Object) {
	static Depth := 0
	static MAX_DEPTH := 40
	
	if (Depth >= MAX_DEPTH) {
		return
	}
	
	Depth++
	if !(IsObject(Object)) {
		Depth--
		return TV_Add(Object, Parent)
	}

	if (Object.__Class) {
		NewNode := TV_Add("<Base>", Parent)
		AddToTree(NewNode, Object.Base)
	}

	for k, v in Object {
		if (IsNumber(k)) {
			k := "[" k "]"
		}
		
		if (v.__Class) {
			k .= " <" v.__Class ">"
		}
		else if (IsFunc(v)) {
			k .= " <Func>"
		}
		
		NewNode := TV_Add(k, Parent, "Expand")
		AddToTree(NewNode, v)
	}
	Depth--
}


/*
Some example code

define Int32: Main(Int64: ArgC, Pointer: ArgV) {
	Int64: Example := 0
	String Text := Format"Hello, {Example}"
	Print(Text)

	return Example
}

*/