class Tokens extends Enum {
	static Options := "
	(
		IDENTIFIER
		KEYWORD
		
		INTEGER
		DOUBLE
		STRING
		
		LEFT_PAREN
		RIGHT_PAREN
		
		LEFT_BRACE
		RIGHT_BRACE
		
		LEFT_BRACKET
		RIGHT_BRACKET
		
		COMMA
		POUND
		NEWLINE
		EOF
		
		
		OPERATOR
		
		BANG
		BANG_EQUAL
		
		EQUAL
		EQUAL_EQUAL
		
		GREATER
		GREATER_EQUAL
		
		LESS
		LESS_EQUAL
	
		COLON
		COLON_EQUAL
		
		PLUS
		PLUS_PLUS
		PLUS_EQUALS
		
		MINUS
		MINUS_MINUS
		MINUS_EQUALS
		
		DOT
		DOT_EQUALS
		
		TIMES
		TIMES_EQUALS
		
		BITWISE_OR
		LOGICAL_OR
		
		BITWISE_AND
		LOGICAL_AND
		
		BITWISE_XOR
		XOR_EQUALS
		
		BITWISE_NOT
	)"
}

class CharacterTokens {
	static Operators := {"!": {"NONE": Tokens.BANG, "=": Tokens.BANG_EQUAL}
						,"=": {"NONE": Tokens.EQUAL, "=": Tokens.EQUAL_EQUAL}
						,"<": {"NONE": Tokens.LESS, "=": Tokens.LESS_EQUAL}
						,">": {"NONE": Tokens.GREATER, "=": Tokens.GREATER_EQUAL, "<": Tokens.CONCAT}
						,":": {"NONE": Tokens.COLON, "=": Tokens.COLON_EQUALS}
						,"+": {"NONE": Tokens.PLUS, "+": Tokens.PLUS_PLUS, "=": Tokens.PLUS_EQUALS}
						,"-": {"NONE": Tokens.MINUS, "-": Tokens.MINUS_MINUS, "=": Tokens.MINUS_EQUALS}
						,".": {"NONE": Tokens.DOT, "=": Tokens.DOT_EQUALS}
						,"*": {"NONE": Tokens.TIMES, "=": Tokens.TIMES_EQUALS}
						,"|": {"NONE": Tokens.BITWISE_OR, "|": Tokens.LOGICAL_OR}
						,"&": {"NONE": Tokens.BITWISE_AND, "&": Tokens.LOGICAL_AND}
						,"^": {"NONE": Tokens.BITWISE_XOR, "=": Tokens.XOR_EQUALS}}
				
				
	static Misc := { "(": Tokens.LEFT_PAREN
					,")": Tokens.RIGHT_PAREN
					,"{": Tokens.LEFT_BRACE
					,"}": Tokens.RIGHT_BRACE
					,"[": Tokens.LEFT_BRACKET
					,"]": Tokens.RIGHT_BRACKET
					,",": Tokens.COMMA
					,"#": Tokens.POUND
					,"~": Tokens.BITWISE_NOT}
}

class OperatorClasses {
	static Assignment := {"Precedence": 0
						, "Associative": "Right"
						, "Tokens": [Tokens.COLON_EQUAL, Tokens.PLUS_EQUALS, Tokens.MINUS_EQUALS, Tokens.DOT_EQUALS, Tokens.TIMES_EQUALS]}
	
	static Equality   := {"Precedence": 1
						, "Associative": "Left"
						, "Tokens": [Tokens.BANG_EQUAL, Tokens.EQUAL, Tokens.EQUAL_EQUAL]}
						
	static Comparison := {"Precedence": 2
						, "Associative": "Right"
						, "Tokens": [Tokens.LESS, Tokens.LESS_EQUAL, Tokens.GREATER, Tokens.GREATER_EQUAL]}
						
	static Concat	  := {"Precedence": 3
						, "Associative": "Left"
						, "Tokens": [Tokens.CONCAT]}
						
	static Addition	  := {"Precedence": 4
						, "Associative": "Left"
						, "Tokens": [Tokens.PLUS, Tokens.MINUS]}
}

class Operators {
	Precedence(Operator) {
		for k, v in OperatorClasses {
			for k, FoundOperator in v.Tokens {
				if (Operator.Value = FoundOperator) {
					return v
				}
			}
		}
	
		MsgBox, % "Fuck off"
	}

	CheckPrecedence(FirstOperator, SecondOperator) {
		OperatorOne := this.Precedence(FirstOperator)
		OperatorTwo := this.Precedence(SecondOperator)
	
		if (OperatorOne.Associative = "Left" && (OperatorOne.Precedence = OperatorTwo.Precedence)) {
			return 1
		}
		else if (OperatorOne.Precedence < OperatorTwo.Precedence) {
			return 1
		}
		else {
			return 0
		}
	}

}


class Keywords extends Enum {
	static Options := "
	(
		define
	)"
}



class ASTNode {
	__New(Params*) {
		if (Params.Count() != this.Parameters.Count()) {
			Msgbox, % "Not enough parameters passed to " this.__Class ".__New, " Params.Count() " != " this.Parameters.Count()
		}
	
		for k, v in this.Parameters {
			this[v] := Params[k]
		}
		
		this.Type := ASTNodeTypes[StrSplit(this.__Class, ".")[3]] ; Translates ASTNode.Expressions.Identifier into 
		;  just 'Identifier', and then gets the enum value for 'Identifier'
	}
}

class ASTNodeTypes extends Enum {
	static Options := "
	(
		DEFINE
		EXPRESSION
		
		IDENTIFER
		GROUPING
		BINARY
	)"
}

class ASTNodes {
	class Statements {
		class Define extends ASTNode {
			static Parameters := ["Name", "ReturnType", "Params", "Body"]
		}
	}
	
	class Expressions {
		class Identifier extends ASTNode {
			static Parameters := ["Name"]
		}
		
		class Grouping extends ASTNode {
			static Parameters := ["Expressions"]
		}
		
		class Binary extends ASTNode {
			static Parameters := ["Left", "Operator", "Right"]
		}
		
		class IntegerLiteral extends ASTNode {
			static Parameters := ["Value"]
		}
		
		class DoubleLiteral extends ASTNode {
			static Parameters := ["Value"]
		}
	}
}