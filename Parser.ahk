class Parser {
	__New(Tokenizer) {
		this.Source := Tokenizer.CodeString
		this.Typing := new Typing()
	
		this.Index := 0
		this.CriticalError := False
	}
	
	UnwindTo(Tokens*) {
		while !(this.NextMatches(Tokens*)) {
			this.Next()
		}
	}
	UnwindToBlockClose() {
		this.UnwindTo(Tokens.RIGHT_BRACE)
	}
	UnwindToNextLine() {
		this.UnwindTo(Tokens.NEWLINE, Tokens.EOF)
	}
	
	Start(Tokens) {
		this.Tokens := Tokens
		return this.ParseProgram()
	}
	
	ParseProgram() {
		Current := this.CurrentProgram := {"Functions": {}, "Globals": {}}
	
		while !(this.AtEOF()) {
			try {
				this.AddFunction(this.ParseProgramStatement())
			}
			catch E {
				this.CriticalError := True
			}
		}
		
		if (this.CriticalError) {
			Throw, Exception("Critical error while parsing, aborting...")
		}
		
		return new ASTNodes.Statements.Program(Current.Functions, Current.Globals)
	}
	ParseProgramStatement() {
		Next := this.Next() ; A program is a list of DllImports/Defines, so this will only handle those two, and error for anything else
	
		if (Next.Type = Tokens.KEYWORD) {
			if (Next.Value = Keywords.DEFINE) {
				return this.ParseDefine()
			}
			else if (Next.Value = Keywords.DLLIMPORT) {
				return this.ParseImport()
			}
		}
		else if (Next.Type = Tokens.NEWLINE) {
			return new ASTNodes.None()
		}
		
		this.UnwindToNextLine()
		PrettyError("Parse"
				   ,"All top-level statements must be either DllImport or Define."
				   ,"Should be inside of a Define statement."
				   ,Next
				   ,this.Source
				   ,"Code outside of function defintions is invalid")
	}
	ParseDefine() {
		ReturnType := this.EnsureValidType(this.ParsePrimary())
		
		Name := this.ParsePrimary()
		
		if (Name.Type != Tokens.IDENTIFIER) {
			this.UnwindToBlockClose()
			PrettyError("Parse"
					   ,"Invalid function name '" Name.Stringify() "', expected IDENTIFIER."
					   ,"Expected an identifier."
					   ,Name
					   ,this.Source
					   ,"Function names must be identifiers, not numbers or quoted strings.")
		}
		
		Params := this.ParseParamGrouping()

		Locals := {}
		this.CurrentProgram.CurrentFunction := Locals
		
		Body := this.ParseBlock()
		
		return new ASTNodes.Statements.Define(ReturnType, Name, Params, Body, Locals)
	}
	ParseImport() {
		ReturnType := this.EnsureValidType(this.ParsePrimary())
		
		Name := this.ParsePrimary()
		
		if (Name.Type != Tokens.IDENTIFIER) {
			this.UnwindToNextLine()
			PrettyError("Parse"
					   ,"Invalid DllImport name '" Name.Stringify() "', expected IDENTIFIER."
					   ,"Expected an identifier."
					   ,Name
					   ,this.Source
					   ,"Function names must be identifiers, not numbers or quoted strings.")
		}
		
		Params := this.ParseGrouping().Expressions
		
		for k, Param in Params {
			this.EnsureValidType(Param)
			Params[k] := [Param] ; Convert an array of type names into an array of arrays of type names + (empty) var names
			; this is so the compiler can type check an import and define in the same way
		}
		
		this.Consume(Tokens.LEFT_BRACE, "DllImport statements require a '{' after the parameter type list")
		DllName := this.Consume(Tokens.IDENTIFIER, "DllImport file names must be IDENTIFIERs").Value
		
		if (this.NextMatches(Tokens.DOT)) {
			; When there is a dot after a DLL file name, it's the '.dll` extension, and since 'dll' is grouped into an identifier, we can just call .Next() to skip over it
			; TODO - Maybe add validation that this text is actually 'dll'
			this.Next()
		}
		
		this.Consume(Tokens.COMMA, "DllImport bodies must follow the format {FILENAME, FUNCTIONNAME}")
		FunctionName := this.Consume(Tokens.IDENTIFIER, "DllImport function names must be IDENTIFIERs").Value
		
		this.Consume(Tokens.RIGHT_BRACE, "DllImport bodies require a closeing '}'")
		
		if !(this.NextMatches(Tokens.NEWLINE, Tokens.EOF)) {
			this.Consume(Tokens.NEWLINE, "DllImport statements must be followed by \n.")
		}
		
		return new ASTNodes.Statements.DllImport(ReturnType, Name, Params, DllName, FunctionName)
	}
	ParseStatement() {
		; Handles all statement types that are only valid inside of Define statements
	
		Next := this.Peek()
	
		try {
			if (Next.Type = Tokens.KEYWORD) {
				return this.ParseKeywordStatement()
			}
			else if (Next.Type = Tokens.IDENTIFIER && this.Typing.IsValidType(Next.Value)) {
				return this.ParseDeclaration() ; The declaration format is TypeName VarName (ExpressionLine|\n)
			}
			else {
				return this.ParseExpressionStatement()
			}
		}
		catch E {
			this.CriticalError := True
		}
	}
	ParseDeclaration() {
		Type := this.Consume(Tokens.IDENTIFIER, "It is impossible to get this error")
	
		Name := this.Consume(Tokens.IDENTIFIER, "Variable names must be identifiers.")
		this.CurrentProgram.CurrentFunction[Name.Value] := Type.Value
		
		if (this.NextMatches(Tokens.NEWLINE)) {
			return new ASTNodes.None()
		}
		else if (this.NextMatches(Tokens.COLON_EQUAL)) {
			this.Index -= 2
			return this.ParseExpressionStatement()
		}
		else {
			ErrorToken := this.Next()
		
			this.UnwindToNextLine()
			PrettyError("Parse"
					   ,"Declarations can only be followed by ':=' to initialize the declared variable."
					   ,"Not ':='."
					   ,ErrorToken
					   ,this.Source)
		}
	}
	
	ParseKeywordStatement() {
		NextKeyword := this.Next().Value
		
		Switch (NextKeyword) {
			Case Keywords.RETURN: {
				return new ASTNodes.Statements.Return(this.ParseExpressionStatement().Expression)
			}
			Case Keywords.IF: {
				return this.ParseIf()
			}
			Case Keywords.ELSE: {
				Else := this.Current()
				
				this.UnwindToBlockClose()
				PrettyError("Parse"
						   ,"Unexpected ELSE"
						   ,"Not part of an if-statement."
						   ,Else
						   ,this.Source
						   ,"The line above this probably terminates the IF statement this ELSE should be a part of.")
			}
			Case Keywords.FOR: {
				return this.ParseFor()
			
			}
		}
	}
	
	ParseParamGrouping() {
		this.Consume(Tokens.LEFT_PAREN, "Parameter groupings must start with '('.")
		
		try {
			Type := this.ParsePrimary()
			Name := this.ParsePrimary()
			Pairs := [[Type, Name]]
		}
		catch {
			Pairs := []
		}
		
		this.EnsureValidType(Type) ; Done outside of the try so any invalid type errors are still shown
		
		while (this.NextMatches(Tokens.COMMA)) {
			Pair := []
			Pair.Push(this.EnsureValidType(this.ParsePrimary())) ; Type
			Pair.Push(this.ParsePrimary()) ; Name
			Pairs.Push(Pair)
		}
	
		this.Consume(Tokens.RIGHT_PAREN, "Parameter groupings require closing ')'.")
		
		return Pairs
	}
	
	ParseFor() {
		this.Consume(Tokens.LEFT_PAREN, "For loops require a '(' after 'for'.")
		
		if (this.Typing.IsValidType(this.Peek().Value) && this.Peek(2).Type = Tokens.IDENTIFIER) {
			Type := this.Next()
			Name := this.Peek()
			
			this.CurrentProgram.CurrentFunction[Name.Value] := Type.Value
		}
		
		Init := this.ParseExpression(Tokens.COMMA)
		this.Consume(Tokens.COMMA, "For loops must follow the format 'for(Init, Condition, Step)'.")
		
		Condition := this.ParseExpression(Tokens.COMMA)
		this.Consume(Tokens.COMMA, "For loops must follow the format 'for(Init, Condition, Step)'.")
		
		Step := this.ParseExpression(Tokens.COMMA, Tokens.RIGHT_PAREN)
		this.Consume(Tokens.RIGHT_PAREN, "For loops require a closing ')'.")
		
		Body := this.ParseBlock()
		
		return new ASTNodes.Statements.ForLoop(Init, Condition, Step, Body)
	}
	
	ParseExpressionStatement() {
		Expression := this.ParseExpression()
		
		if (this.NextMatches(Tokens.NEWLINE) || this.NextMatches(Tokens.EOF)) {
			return new ASTNodes.Statements.ExpressionLine(Expression)
		}
		else {
			Next := this.Next()
		
			this.UnwindToNextLine()
			PrettyError("Parse"
					   ,"Unexpected expression terminator '" Next.Stringify() "'."
					   ,"Should be \n or EOF"
					   ,Next
					   ,this.Source
					   ,"You might have included two expression statements on a single line (I have no clue how though).")
		}
	}
	
	ParseIf() {
		Group := [new ASTNodes.Statements.If(this.ParseExpression(Tokens.LEFT_BRACE), this.ParseBlock())]
	
		while (this.Ignore(Tokens.NEWLINE) && this.Peek().Value = Keywords.ELSE) {
			this.Next()
		
			if (this.Peek().Value = Keywords.IF) {
				this.Next()
				Group.Push(new ASTNodes.Statements.If(this.ParseExpression(Tokens.LEFT_BRACE), this.ParseBlock()))
			}
			else {
				Group.Push(new ASTNodes.Statements.If(new Token(Tokens.INTEGER, True, {}), this.ParseBlock()))
				Break
			}
		}
	
		return new ASTNodes.Statements.IfGroup(Group)
	}
	
	ParseBlock() {
		Statements := []
		this.Ignore(Tokens.NEWLINE)
		this.Consume(Tokens.LEFT_BRACE, "Expected block, got '" this.Peek().Stringify() "' instead.")
		this.Ignore(Tokens.NEWLINE)
		
		while !(this.NextMatches(Tokens.RIGHT_BRACE)) {
			Statements.Push(this.ParseStatement())
			this.Ignore(Tokens.NEWLINE)
			
			if (this.AtEOF()) {
				Break
			}
		}
		
		return Statements
	}
	
	ParseExpression(Terminators*) {
		if ((!IsObject(Terminators)) || (Terminators.Count() = 0)) {
			Terminators := [Tokens.NEWLINE, Tokens.EOF, Tokens.LEFT_BRACE]
		}
	
	
		return this.ExpressionParser(Terminators)[1]
	}
	AddNode(OperandStack, OperandCount, Operator) {
		Operands := []
		
		loop, % OperandCount {
			NextOperand := OperandStack.Pop()
			
			if !(NextOperand) {
				PrettyError("Parse"
						   ,"Missing operand for operator '" Operator.Stringify() "'."
						   ,"Needs another operand."
						   ,Operator
						   ,this.Source)
			}
			
			Operands.Push(NextOperand)
		}
		
		if !(Operator) {
			PrettyError("Parse"
					   ,"Missing operator for operand '" Operands[1].Stringify() "'."
					   ,"Needs an operator."
					   ,Operands[1]
					   ,this.Source)
		}
		
		Switch (OperandCount) {
			Case 1: {
				OperandStack.Push(new ASTNodes.Expressions.Unary(Operands[1], Operator))
			}
			Case 2: {
				OperandStack.Push(new ASTNodes.Expressions.Binary(Operands[2], Operator, Operands[1]))
			}
		}
	}
	
	ExpressionParser(Terminators) {
		OperandStack := []
		OperatorStack := []
	
		loop {
			Next := this.Next()
			Unexpected := True
		
			Switch (Next.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.IDENTIFIER, Tokens.STRING: {
					OperandStack.Push(Next)
					Unexpected := False
				}
				Case Tokens.LEFT_PAREN: {
					this.Index--
					OldPrevious := this.Current()
					Params := this.ParseGrouping()
				
					if (OperandStack[OperandStack.Count()].Type = Tokens.IDENTIFIER) {
						OperandStack.Push(new ASTNodes.Expressions.Call(OperandStack.Pop(), Params))
					}
					else {
						OperandStack.Push(Params)
					}
					
					Unexpected := False
				}
				Case Next.CaseIsOperator(): {
					Operator := Next
					DontPush := False
					
					if (Operator.Type = Tokens.COLON) {
						Param := OperandStack.Pop()
						Name := this.Next()
						
						if (Name.Type != Tokens.IDENTIFIER) {
							Throw, Exception("Invalid name for (come up with a name): '" Name.Stringify() "'.", Name)
						}
						
						Params := this.ParseGrouping()
						Params.Expressions.InsertAt(1, Param)
						
						OperandStack.Push(new ASTNodes.Expressions.Call(Name, Params))
						DontPush := True
					}
					else if (Operators.IsPostfix(Operator) && this.Previous() && this.Previous().Type != Tokens.Operator) {
						this.AddNode(OperandStack, 1, Operators.EnsurePostfix(Operator))
						DontPush := True
					}
					else if (Operators.IsPrefix(Operator)) {
						OperatorStack.Push(Operator)
						DontPush := True
					}
					
					while (OperatorStack.Count() != 0) {
						NextOperator := OperatorStack.Pop()
						
						if (Operators.IsPrefix(NextOperator)) {
							this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
							Unexpected := False
						}
						
						if (NextOperator.IsOperator() && Operators.CheckPrecedence(Operator, NextOperator)) {
							this.AddNode(OperandStack, Operators.OperandCount(NextOperator), NextOperator)
						}
						else {
							OperatorStack.Push(NextOperator)
							Break
						}
					}
					
					if !(DontPush) {
						OperatorStack.Push(Operator)
					}
					
					Unexpected := False
				}
				Default: {
					; This isn't a character that should be in this expression, but it might be the terminator, so we drop the
					;  index to point at the character again, and run it through the terminator check below before
					;   breaking/erroring
					this.Index-- 
				}
			}
			
			for k, Terminator in Terminators {
				if (this.Check(Terminator)) {
					Break, 2
				}
			}
			
			if (Unexpected) {
				this.UnwindToBlockClose()
				PrettyError("Parse"
						   ,"Unexpected character '" Next.Stringify() "' in expression."
						   ,""
						   ,Next
						   ,this.Source)
			}
		}
		
		while (OperatorStack.Count()) {
			NextOperator := OperatorStack.Pop()
			
			if (Operators.IsPrefix(NextOperator) && OperandStack.Count() < Operators.OperandCount(NextOperator)) {
				PrettyError("Parse"
						   ,"Missing operand for operator '" NextOperator.Stringify() "'."
						   ,"Needs another operand."
						   ,NextOperator
						   ,this.Source)
			}
			
			this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
		}
		
		if (OperandStack.Count() > 1) {
			Operand := OperandStack.Pop()
		
			PrettyError("Parse"
					   ,"Missing operator for operand '" Operand.Stringify() "'."
					   ,"Needs an operator."
					   ,Operand
					   ,this.Source)
		}
		
		return OperandStack
	}
	
	ParsePrimary() {
		Next := this.Next()
	
		Switch (Next.Type) {
			Case Tokens.IDENTIFIER: {
				return this.Current()
			}
			Case Tokens.INTEGER: {
				return this.Current()
			}
			Case Tokens.DOUBLE: {
				return this.Current()
			}
			Case Tokens.LEFT_PAREN: {
				this.Index--
				return this.ParseGrouping()
			}
			Default: {
				this.Index--
				
				PrettyError("Parse"
						   ,"Unexpected token '" Next.Stringify() "'."
						   ,""
						   ,Next
						   ,this.Source)
			}
		}
	}
	
	ParseGrouping() {
		if (this.NextMatches(Tokens.LEFT_PAREN)) {
			Expressions := [this.ParseExpression(Tokens.COMMA, Tokens.RIGHT_PAREN)]
			
			if (Expressions[1].Count() < 1) {
				this.Consume(Tokens.RIGHT_PAREN, "Expression groupings must have a closing paren")
				return new ASTNodes.Expressions.Grouping([])
			}
			
			while (this.NextMatches(Tokens.COMMA)) {
				Expressions.Push(this.ParseExpression(Tokens.COMMA, Tokens.RIGHT_PAREN))
			}
			
			this.Consume(Tokens.RIGHT_PAREN, "Expression groupings must have a closing paren")
			
			return new ASTNodes.Expressions.Grouping(Expressions)
		}
		else {
			Next := this.Next()
			
			this.UnwindToNextLine()
			PrettyError("Parse"
					  , "Expression grouping expected, got '" Next.Stringify() "' instead."
					  , "'(' expected."
					  , Next
					  , this.Source
					  , "You might be missing an open/close paren, or have whitespace between a name and '('.")
		}
	}
	
	; Tests
	
	static ExpressionTests := {"A + B + C": "((A + B) + C)"
							,  "A == B == C": "((A == B) == C)"
							,  "A := B := 1": "(A := (B := 1))"
							,  "1 + 2 - 3 * 4 / 5 == 6 := 7": "((((1 + 2) - ((3 * 4) / 5)) == 6) := 7)"
							,  "0xFF == 0o377 == 0b11111111 == 255": "(((255 == 255) == 255) == 255)"}

	static _ := Parser.Tests()
	
	Tests() {
		if (Config.DEBUG) {
			this.RunTests()
		}
	}
	RunTests() {
		for Input, Output in Parser.ExpressionTests {
			TestLexer := new Lexer()
			InputTokens := TestLexer.Start(Input)
			
			TestParser := new Parser(TestLexer)
			TestParser.Tokens := InputTokens
			InputAST := TestParser.ParseExpression()
			
			Assert.String.True(InputAST.Stringify(), Output)
		}
	}
	
	; Helper methods
	
	EnsureValidType(TypeToken) {
		if !(this.Typing.IsValidType(TypeToken.Value)) {
			PrettyError("Type"
					   ,"Invalid type '" TypeToken.Stringify() "'."
					   ,"Not a valid type name."
					   ,TypeToken
					   ,this.Source)
		}
		
		return TypeToken
	}
	
	AddFunction(Node) {
		if (Node.Type = ASTNodeTypes.None) {
			return
		}
	
		FunctionName := Node.Name.Value
		
		if (this.CurrentProgram.Functions.HasKey(FunctionName)) {
			this.UnwindToBlockClose()
			PrettyError("Parse"
					   ,"Duplicate defintion"
					   ,""
					   ,Node.Name
					   ,this.Source)
		}
	
		this.CurrentProgram.Functions[FunctionName] := Node
	}
	Next() {
		return this.Tokens[++this.Index]
	}
	Current() {
		return this.Tokens[this.Index]
	}
	Previous() {
		return this.Tokens[this.Index - 1]
	}
	Consume(Type, Reason) {
		if !(this.NextMatches(Type)) {
			Next := this.Next()
			
			this.UnwindToNextLine()
			PrettyError("Parse"
					   ,Reason
					   ,""
					   ,Next
					   ,this.Source)
		}
		
		return this.Current()
	}
	NextMatches(Types*) {
		for k, Type in Types {
			if (this.Check(Type)) {
				this.Next()
				return True
			}
		}
		
		return False
	}
	Check(Type) {
		return this.Peek().Type = Type
	}
	Ignore(Type) {
		if (this.Check(Type)) {
			this.Next()
		}
		
		return true
	}
	Peek(Count := 1) {
		if (this.Index + Count > this.Tokens.Count()) {
			return false
		}
		
		return this.Tokens[this.Index + Count]
	}
	AtEOF() {
		return (this.Peek().Type = Tokens.EOF)
	}
}

class Typing {
	class TypeSet {
		static Pointer := {"Name": "Pointer", "Next": "Pointer", "Precision": 65
							, "Escape": {"Int64": 1}
							, "Exclude": {"Float": 1, "Double": 1, "Int8": 1, "Int16": 1, "Int32": 1}}
	
		static Int64   := {"Name": "Int64", "Next": "Int8" , "Precision": 64, "Escape": {"Double": 1, "Pointer": 1}}
		static Int32   := {"Name": "Int32", "Next": "Int64", "Precision": 32, "Escape": {"Float": 1}}
		static Int16   := {"Name": "Int16", "Next": "Int32", "Precision": 16}
		static Int8    := {"Name": "Int8" , "Next": "Int16", "Precision": 8 }
		
		static Double  := {"Name": "Double", "Next": "Float" , "Precision": 65, "Escape": {"Int64": 1}}
		static Float   := {"Name": "Float" , "Next": "Double", "Precision": 33, "Escape": {"Int32": 1}}
	
	}
	
	__New() {
		this.Variables := {}
	}
	
	ResultType(LeftType, RightType) {
		if (LeftType.Exclude.HasKey(RightType.Name) || RightType.Exclude.HasKey(LeftType.Name)) {
			Throw, Exception("Invalid")
		}
	
		if (LeftType.Precision > RightType.Precision) {
			return LeftType
		}
		else {
			return RightType
		}
	}
	
	GetVariableType(Name) {
		return this.Variables[Name]
	}
	
	AddVariable(Type, Name) {
		this.Variables[Name] := this.GetType(Type)
	}
	
	IsValidType(Name) {
		try {
			this.GetType(Name)
			return True
		}
		catch {
			return False
		}
	}
	
	CastPath(FromType, ToType) {
		if (FromType.Name = ToType.Name) {
			return []
		}
	
		NextType := FromType
		Path := []
		
		loop {
			NextName := NextType.Next
			TempType := this.GetType(NextName)
			Path.Push(NextName)
		
			if (TempType.Name = ToType.Name) {
				return Path
			}
			else if (TempType.Name = FromType.Name) {
				Break
			}
			else if !(TempType) {
				Break
			}
			else {
				NextType := TempType
			}
		}
		
		; If we haven't returned by here, then the cast requires a int->float/float->int jump
		
		NextType := FromType
		Path := []
		
		loop {
			NextName := NextType.Next
			TempType := this.GetType(NextName)
			Path.Push(NextName)
			
			if (TempType.Escape.HasKey(ToType.Name)) {
				Path.Push(ToType.Name)
				return Path
			}
			else {
				NextType := TempType
			}
		}
		
		Throw, Exception("No cast possible")
	}
	
	GetType(TypeName) {
		if !(TypeName) {
			return
		}
	
		if (this.TypeSet.HasKey(TypeName)) {
			return this.TypeSet[TypeName]
		}
		else {
			Throw, Exception("Invalid type: " TypeName)
		}
	}
}