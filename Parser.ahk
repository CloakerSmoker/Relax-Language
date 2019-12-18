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
	
	ParseTypeName() {
		TypeToken := this.Next()
		
		if (this.NextMatches(Tokens.TIMES)) {
			TypeToken.Value .= "*"
		}
	
		if !(this.Typing.IsValidType(TypeToken.Value)) {
			new Error("Type")
				.LongText("Invalid type.")
				.ShortText("Not a valid type name.")
				.Token(TypeToken)
				.Source(this.Source)
			.Throw()
		}
		
		return TypeToken
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
		
		new Error("Parse")
			.LongText("All top-level statements must be either DllImport or Define.")
			.ShortText("Should be inside of a Define statement.")
			.Help("Code outside of function defintions is invalid")
			.Token(Next)
			.Source(this.Source)
		.Throw()
	}
	ParseDefine() {
		ReturnType := this.ParseTypeName()
		
		Name := this.ParsePrimary()
		
		if (Name.Type != Tokens.IDENTIFIER) {
			this.UnwindToBlockClose()
			
			new Error("Parse")
				.LongText("Invalid function name, expected an identifier.")
				.ShortText("Expected an identifier.")
				.Help("Function names must be identifiers, not numbers or quoted strings.")
				.Token(Name)
				.Source(this.Source)
			.Throw()
		}
		
		Params := this.ParseParamGrouping()

		Locals := {}
		this.CurrentProgram.CurrentFunction := Locals
		
		Body := this.ParseBlock()
		
		return new ASTNodes.Statements.Define(ReturnType, Name, Params, Body, Locals)
	}
	ParseImport() {
		ReturnType := this.ParseTypeName()
		
		Name := this.ParsePrimary()
		
		if (Name.Type != Tokens.IDENTIFIER) {
			this.UnwindToNextLine()
			
			new Error("Parse")
				.LongText("Invalid DllImport name, expected an identifier.")
				.ShortText("Not an identifier.")
				.Help("Function names must be identifiers, not numbers or quoted strings.")
				.Token(Name)
				.Source(this.Source)
			.Throw()
		}
		
		Params := this.ParseParamGrouping(True) ; True = don't bother consuming a token after each time name so
		; (Int16, Int32) is valid, and (Int16 A, Int16 B) isn't
		
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
		Type := this.ParseTypeName()
	
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
			
			new Error("Parse")
				.LongText("Declarations can only be followed by ':=' to initialize the declared variable.")
				.ShortText("Not ':='.")
				.Token(ErrorToken)
				.Source(this.Source)
			.Throw()
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
				
				new Error("Parse")
					.LongText("Unexpected ELSE.")
					.ShortText("Not part of an if-statement.")
					.Help("The line above this probably terminates the IF statement this ELSE should be a part of.")
					.Token(Else)
					.Source(this.Source)
				.Throw()
			}
			Case Keywords.FOR: {
				return this.ParseFor()
			}
		}
	}
	
	ParseParamGrouping(ImportStyle := False) {
		; Since DllImport statements just take a list of types without var names, we can reuse this function for both
		;  Define and DllImport
	
		this.Consume(Tokens.LEFT_PAREN, "Parameter groupings must start with '('.")
		
		Pairs := []
		
		if !(this.Check(Tokens.RIGHT_PAREN)) {
			Type := this.ParseTypeName()
			
			if !(ImportStyle) {
				Name := this.ParsePrimary()
			}
				
			Pairs.Push([Type, Name])
			
			while (this.NextMatches(Tokens.COMMA)) {
				Pair := []
				Pair.Push(this.ParseTypeName()) ; Type
				
				if !(ImportStyle) {
					Pair.Push(this.ParsePrimary()) ; Name
				}
				
				Pairs.Push(Pair)
			}
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
			
			new Error("Parse")
				.LongText("Unexpected expression terminator.")
				.ShortText("Should be \n or EOF")
				.Token(Next)
				.Source(this.Source)
			.Throw()
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
				new Error("Parse")
					.LongText("Missing operand for operator.")
					.ShortText("Needs another operand.")
					.Token(Operator)
					.Source(this.Source)
				.Throw()
			}
			
			Operands.Push(NextOperand)
		}
		
		if !(Operator) {
			new Error("Parse")
				.LongText("Missing operator for operand.")
				.ShortText("Needs an operator.")
				.Token(Operands[1])
				.Source(this.Source)
			.Throw()
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
		
			Switch (Next.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.IDENTIFIER, Tokens.STRING: {
					OperandStack.Push(Next)
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
				}
				Case Next.CaseIsOperator(): {
					Operator := Next
					
					if (Operators.IsPostfix(Operator) && this.Previous().IsData()) {
						this.AddNode(OperandStack, 1, Operators.EnsurePostfix(Operator))
					}
					else if ((Operators.IsPrefix(Operator) || Operators.IsBinaryOrPrefix(Operator)) && this.Previous().IsNotData()) {
						OperatorStack.Push(Operators.BinaryToPrefix(Operator))
					}
					else {
						while (OperatorStack.Count() != 0) {
							NextOperator := OperatorStack.Pop()
							
							if (Operators.IsPrefix(NextOperator)) {
								this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
								Break
							}
							
							if (NextOperator.IsOperator() && Operators.CheckPrecedence(Operator, NextOperator)) {
								this.AddNode(OperandStack, Operators.OperandCount(NextOperator), NextOperator)
							}
							else {
								OperatorStack.Push(NextOperator)
								Break
							}
						}
						
						OperatorStack.Push(Operator)
					}
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
			
			if (Next.Context.Start = this.Previous().Context.Start) {
				; When the Previous token starts at the same place as our "Next" token,
				;  then the token was not consumed, and is unexpected
			
				this.UnwindToNextLine()
				
				new Error("Parse")
					.LongText("Unexpected character.")
					.ShortText("Unexpected in expression.")
					.Token(Next)
					.Source(this.Source)
				.Throw()
			}
		}
		
		while (OperatorStack.Count()) {
			NextOperator := OperatorStack.Pop()
			
			if (Operators.IsPrefix(NextOperator) && OperandStack.Count() < Operators.OperandCount(NextOperator)) {
				new Error("Parse")
					.LongText("Missing operand for operator.")
					.ShortText("Needs another operand.")
					.Token(NextOperator)
					.Source(this.Source)
				.Throw()
			}
			
			this.AddNode(OperandStack, Operators.OperandCount(NextOperator), Operators.EnsurePrefix(NextOperator))
		}
		
		if (OperandStack.Count() > 1) {
			Operand := OperandStack.Pop()
			
			new Error("Parse")
				.LongText("Missing operator for operand")
				.ShortText("Needs an operator.")
				.Token(Operand)
				.Source(this.Source)
			.Throw()
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
				
				new Error("Parse")
					.LongText("Unexpected token.")
					.ShortText("Not part of any other construct.")
					.Token(Next)
					.Source(this.Source)
				.Throw()
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
			
			new Error("Parse")
				.LongText("Expression grouping expected.")
				.ShortText("'(' expected.")
				.Token(Next)
				.Source(this.Source)
			.Throw()
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
			new Error("Type")
				.LongText("Invalid type.")
				.ShortText("Not a valid type name.")
				.Token(TypeToken)
				.Source(this.Source)
			.Throw()
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
			
			new Error("Parse")
				.LongText("Duplicate defintion")
				.ShortText("Already defined elsewhere.")
				.Token(Node.Name)
				.Source(this.Source)
			.Throw()
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
			
			new Error("Parse")
				.LongText(Reason)
				.Token(Next)
				.Source(this.Source)
			.Throw()
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