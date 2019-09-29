#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk

Test := new Lexer(A_Quote "abc" A_Quote)
Test.Start()