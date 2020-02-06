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
	AddLocal(Type, Name) {
		this.CurrentFunction.Locals[Name.Value] := {"Type": Type.Value}
		
		Log("Found local variable '" Name.Value "' with type '" Type.Value "'")
		
		return new ASTNodes.None()
	}
	AddGlobal(Type, Name, Initializer) {
		this.CurrentProgram.Globals[Name.Value] := {"Type": Type.Value, "Initializer": Initializer}
		
		Log("Found global variable '" Name.Value "' with type '" Type.Value "' and " (Initializer.Type = ASTNodeTypes.None ? "no" : "a") " default value.")
		
		return new ASTNodes.None()
	}
	AddString(Text) {
		Log("Found string '" Text.Value "' used")
		
		this.CurrentFunction.Strings.Push(Text)
	}
	
	Start(Tokens) {
		this.Tokens := Tokens
		
		Log("Started parser job for " Tokens.Count() " tokens")
		
		return this.ParseProgram()
	}
	
	ParseTypeName() {
		BaseTypeName := this.Next()
		
		if !(this.Typing.IsValidType(BaseTypeName.Value)) {
			new Error("Type")
				.LongText("Invalid type.")
				.ShortText("Not a valid type name.")
				.Token(BaseTypeName)
				.Source(this.Source)
			.Throw()
		}
		
		while (this.NextMatches(Tokens.TIMES)) {
			BaseTypeName.Value .= "*"
		}
		
		return BaseTypeName
	}
	
	ParseProgram() {
		Current := this.CurrentProgram := {"Functions": {}, "Globals": {}, "Modules": []}
	
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
		
		return new ASTNodes.Statements.Program(Current.Functions, Current.Globals, Current.Modules)
	}
	ParseProgramStatement() {
		Next := this.Next() ; A program is a list of DllImports/Defines, so this will only handle those two, and error for anything else
	
		if (Next.Type = Tokens.KEYWORD) {
			if (Next.Value = Keywords.DEFINE) {
				return this.ParseDefine(Next.Value)
			}
			else if (Next.Value = Keywords.DLLIMPORT) {
				return this.ParseDllImport()
			}
			else if (Next.Value = Keywords.IMPORT) {
				this.CurrentProgram.Modules.Push(this.Next().Value)
				return new ASTNodes.None()
			}
		}
		else if (Next.Type = Tokens.IDENTIFIER && this.Typing.IsValidType(Next.Value)) {
			this.Index-- ; Backtrack to capture the type name again
			return this.ParseDeclaration(False)
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
	ParseDefine(KeywordUsed) {
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
		Strings := {}
		this.CurrentFunction := {"Locals": Locals, "Strings": Strings}
		
		Body := this.ParseBlock()
		
		Log("Found function definition '" Name.Value "' with return type '" ReturnType.Value "' and " Params.Count() " parameters")
		
		return new ASTNodes.Statements.Define(KeywordUsed, ReturnType, Name, Params, Body, Locals, Strings)
	}
	ParseDllImport() {
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
		; (i16, i32) is valid, and (i16 A, i16 B) isn't
		
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
		
		Log("Found DllImport '" Name.Value "' with return type '" ReturnType.Value "' from " FunctionName "@" DllName)
		
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
	ParseDeclaration(AsLocal := True) {
		Type := this.ParseTypeName()
		Name := this.Consume(Tokens.IDENTIFIER, "Variable names must be identifiers.")
		
		Initializer := new ASTNodes.None()
		
		if (this.NextMatches(Tokens.COLON_EQUAL)) {
			this.Index -= 2
			Initializer := this.ParseExpressionStatement()
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
		
		if (AsLocal) {
			this.AddLocal(Type, Name)
			return Initializer
		}
		else {
			this.AddGlobal(Type, Name, Initializer)
			return new ASTNodes.None()
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
			Case Keywords.CONTINUE, Keywords.BREAK: {
				return new ASTNodes.Statements.ContinueBreak(this.Current())
			}
			Default: {
				new Error("Parse")
					.LongText("Unexpected statement.")
					.ShortText("Is not allowed in this position.")
					.Help("This keyword is only allowed outside of function definitions, and cannot be run conditionally or dynamically.")
					.Token(this.Current())
					.Source(this.Source)
				.Throw()
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
			this.AddLocal(this.Next(), this.Peek(), new ASTNodes.None())
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
		return new ASTNodes.Statements.ExpressionLine(this.ParseExpression())
		
		;Expression := this.ParseExpression()
		
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
				Group.Push(new ASTNodes.Statements.If(new Token(Tokens.INTEGER, True, {}, ""), this.ParseBlock()))
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
			Terminators := [Tokens.NEWLINE, Tokens.EOF, Tokens.LEFT_BRACE, Tokens.RIGHT_BRACE]
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
			StartIndex := this.Index
			Next := this.Next()
		
			Switch (Next.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.IDENTIFIER: {
					OperandStack.Push(Next)
				}
				Case Tokens.STRING: {
					this.AddString(Next)
					OperandStack.Push(Next)
				}
				Case Tokens.LEFT_PAREN: {
					this.Index--
					OldPrevious := this.Current()
				
					if (this.Peek(-2).Type = Tokens.IDENTIFIER && this.Peek(-1).Type = Tokens.COLON && this.Current().Type = Tokens.IDENTIFIER) {
						OperandStack.Pop(), OperatorStack.Pop(), OperandStack.Pop()
					
						Target := new ASTNodes.Expressions.Binary(this.Peek(-2), this.Peek(-1), this.Current())
						OperandStack.Push(new ASTNodes.Expressions.Call(Target, this.ParseGrouping()))
						Continue
					}
					
					
					Params := this.ParseGrouping()
					
					if (OperandStack.Count() >= 1 && OldPrevious.Type = Tokens.IDENTIFIER) {
						OperandStack.Push(new ASTNodes.Expressions.Call(OperandStack.Pop(), Params))
					}
					else {
						OperandStack.Push(Params)
					}
				}
				Case Next.CaseIsOperator(): {
					Operator := Next
					
					if (Operator.Type = Tokens.AS) {
						TypeName := this.ParseTypeName()
						Params := new ASTNodes.Expressions.Grouping([OperandStack.Pop()])
					
						OperandStack.Push(new ASTNodes.Expressions.Call(TypeName, Params))
					}
					else if (Operators.IsPostfix(Operator) && this.Previous().IsData()) {
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
			
			if (this.Index = StartIndex) {
				; If the index has not moved since the start of the loop, then the token was not consumed, and is unexpected
			
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
				; Wtf? TODO: Figure out *what* this means, and then remove it
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