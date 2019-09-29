#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk

Test := new Lexer("19.89`nABC + 9`ndefine abc(int a) /*ab dasda*/ {hello world}")
t := Test.Start()

s := ""
for k, v in t {
	s .= v.Stringify() "`n"
}
MsgBox, % s