#Include %A_ScriptDir%
#Include Utility.ahk
#Include Constants.ahk
#Include Lexer.ahk

Test := new Lexer("0xFF")
Test.Start()