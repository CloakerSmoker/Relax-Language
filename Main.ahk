class VAL {
	static DEBUG := True
}

#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk
#Include Parser.ahk
#Include CodeGen.ahk
#Include Compiler.ahk

Code = 
(
define Int64 Test() {
	return 69
}
)

Test := new Lexer(Code)
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Stringify() "`n"
}
;MsgBox, % s

Pest := new Parser(Test)
a := Pest.Start()

MsgBox, % a[1].Stringify()

C := new Compiler(Test)
G := C.CompileFunction(a[1])
MsgBox, % "Generated code: `n" (Clipboard := G.Stringify()) "`nResult: " G.Execute() 

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

define Int64 Add(Int64 NumberOne, Int64 NumberTwo) {
	return NumberOne + NumberTwo
}

*/


; Each function should be compiled seperately, parameters are variables
;  Variables live on the stack

; Return can just be compiled to `mov rax, %result%; add rsp, %LocalVars%; pop rbp; ret`
;  which doesn't require any block related stuff (besides type checking in functions)