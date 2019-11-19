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
		
		
		FIRST_OPERATOR
		
		FIRST_PREFIX
			BANG
			BITWISE_NOT
		
			FIRST_POSTFIX
				; The overlap here is since ++/-- are both pre/postfix
				PLUS_PLUS
				MINUS_MINUS
		LAST_PREFIX
			LAST_POSTFIX
		
		; Operator varients so they can be told apart
		
		PLUS_PLUS_L
		PLUS_PLUS_R
		
		MINUS_MINUS_L
		MINUS_MINUS_R
		
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
		PLUS_EQUAL
		
		MINUS
		MINUS_EQUAL
		
		DOT
		DOT_EQUAL
		
		TIMES
		TIMES_EQUAL
		
		BITWISE_OR
		LOGICAL_OR
		
		BITWISE_AND
		LOGICAL_AND
		
		BITWISE_XOR
		XOR_EQUAL
		
		DIVIDE
		
		MOD
		
		LAST_OPERATOR
	)"
}

class CharacterTokens {
	static Operators := {"!": {"NONE": Tokens.BANG, "=": Tokens.BANG_EQUAL}
						,"=": {"NONE": Tokens.EQUAL, "=": Tokens.EQUAL_EQUAL}
						,"<": {"NONE": Tokens.LESS, "=": Tokens.LESS_EQUAL}
						,">": {"NONE": Tokens.GREATER, "=": Tokens.GREATER_EQUAL, "<": Tokens.CONCAT}
						,":": {"NONE": Tokens.COLON, "=": Tokens.COLON_EQUAL}
						,"+": {"NONE": Tokens.PLUS, "+": Tokens.PLUS_PLUS, "=": Tokens.PLUS_EQUAL}
						,"-": {"NONE": Tokens.MINUS, "-": Tokens.MINUS_MINUS, "=": Tokens.MINUS_EQUAL}
						,".": {"NONE": Tokens.DOT, "=": Tokens.DOT_EQUAL}
						,"*": {"NONE": Tokens.TIMES, "=": Tokens.TIMES_EQUAL}
						,"|": {"NONE": Tokens.BITWISE_OR, "|": Tokens.LOGICAL_OR}
						,"&": {"NONE": Tokens.BITWISE_AND, "&": Tokens.LOGICAL_AND}
						,"^": {"NONE": Tokens.BITWISE_XOR, "=": Tokens.XOR_EQUAL}
						,"~": {"NONE": Tokens.BITWISE_NOT}
						,"%": {"NONE": Tokens.MOD}}
	
	
	static Misc := { "(": Tokens.LEFT_PAREN
					,")": Tokens.RIGHT_PAREN
					,"{": Tokens.LEFT_BRACE
					,"}": Tokens.RIGHT_BRACE
					,"[": Tokens.LEFT_BRACKET
					,"]": Tokens.RIGHT_BRACKET
					,",": Tokens.COMMA
					,"#": Tokens.POUND}
}

class OperatorClasses {
	static Prefix	  := {"Precedence": -1
						, "Associative": "Right"
						, "Tokens": [Tokens.PLUS_PLUS, Tokens.MINUS_MINUS, Tokens.BANG, Tokens.BITWISE_NOT]}

	static Assignment := {"Precedence": 0
						, "Associative": "Right"
						, "Tokens": [Tokens.COLON_EQUAL, Tokens.PLUS_EQUAL, Tokens.MINUS_EQUAL, Tokens.DOT_EQUAL, Tokens.TIMES_EQUAL]}
	
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
						
	static Division	  := {"Precedence": 5
						, "Associative": "Left"
						, "Tokens": [Tokens.DIVIDE, Tokens.TIMES, Tokens.MOD]}
						
	IsClass(OperatorToken, ClassNames*) {
		for k, ClassName in ClassNames {
			for TokenNumber, PotentialToken in OperatorClasses[ClassName].Tokens {
				if (OperatorToken.Type = PotentialToken) {
					return True
				}
			}
		}
		
		return False
	}
}

IsOperator(OperatorType) {
	return Tokens.FIRST_OPERATOR < OperatorType && OperatorType < Tokens.LAST_OPERATOR
}

class Operators {
	Precedence(Operator) {
		for k, v in OperatorClasses {
			for k, FoundOperator in v.Tokens {
				if (Operator.Type = FoundOperator) {
					return v
				}
			}
		}
	
		Assert.Unreachable(this.ToString(Operator))
	}

	ToString(Operator) {
		return Operator.Value
	
		OperatorName := Tokens[Operator.Type]
		
		if (SubStr(OperatorName, StrLen(OperatorName) - 1, 1) = "_") {
			RealName := SubStr(OperatorName, 1, StrLen(OperatorName) - 2)
			return this.ToString(new Token(Tokens[RealName], Operator.Value, Operator.Context))
		}
	
	
		for Start, Endings in CharacterTokens.Operators {
			for k, EndingToken in Endings {
				if (Operator.Type = EndingToken) {
					return Start (k != "NONE" ? k : "")
				}
			}
		}
		
		Assert.Unreachable(Tokens[Operator.Type])
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
	OperandCount(Operator) {
		if (this.IsPostfix(Operator) || this.IsPrefix(Operator)) {
			return 1
		}
		else {
			return 2
		}
	}
	
	EnsurePrefix(Operator) {
		return this.EnsureXXXfix(Operator, "_L")
	}
	EnsurePostfix(Operator) {
		return this.EnsureXXXfix(Operator, "_R")
	}
	EnsureXXXfix(Operator, Form) {
		if (this.IsPrefix(Operator) && this.IsPostfix(Operator)) {
			return new Token(Tokens[Tokens[Operator.Type] Form], Operator.Value, Operator.Context)
		}
		
		return Operator
	}
	
	IsPostfix(Operator) {
		return Tokens.FIRST_POSTFIX < Operator.Type && Operator.Type < Tokens.LAST_POSTFIX
	}
	IsPrefix(Operator) {
		return Tokens.FIRST_PREFIX < Operator.Type && Operator.Type < Tokens.LAST_PREFIX
	}
}


class Keywords extends Enum {
	static Options := "
	(
		define
		return
		if
		else
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
		EXPRESSIONLINE
		RETURN
		IFGROUP
		IF
		
		IDENTIFER
		GROUPING
		CALL
		UNARY
		BINARY
	)"
}

class ASTNodes {
	class Statements {
		class Define extends ASTNode {
			static Parameters := ["ReturnType", "Name", "Params", "Body"]
			
			Stringify() {
				String := "Define " this.ReturnType.Value " " this.Name.Value "("
			
				for k, Pair in this.Params {
					String .= Pair[1].Value " " Pair[2].Value ", "
				}
			
				if (this.Params.Count()) {
					String := SubStr(String, 1, StrLen(String) - 2)
				}
					
				String .= ") {`n"
				
				for k, Line in this.Body {
					String .= Line.Stringify("`t")
				}
				
				String .= "`n" Indent "};`n"
				return String
			}
		}
		class ExpressionLine extends ASTNode {
			static Parameters := ["Expression"]
			
			Stringify(Indent := "") {
				return Indent this.Expression.Stringify() ";`n"
			}
		}
		class Return extends ASTNode {
			static Parameters := ["Expression"]
			
			Stringify(Indent := "") {
				return Indent "return " this.Expression.Stringify() ";"
			}
		}
		class IfGroup extends ASTNode {
			static Parameters := ["Options"] ; An array of if nodes
		
			Stringify(Indent := "") {
				String := ""
				
				for k, v in this.Options {
					String .= v.Stringify(Indent)
				}
				
				return Indent SubStr(String, StrLen(Indent) + 5 + 1)
			}
		}
		class If extends ASTNode {
			static Parameters := ["Condition", "Body"]
		
			Stringify(Indent := "") {
				String := Indent "else if "
				String .= this.Condition.Stringify()
			
				String .= " {`n"
				
				for k, Line in this.Body {
					String .= Line.Stringify(Indent "`t")
				}
				
				String .= Indent "`n" Indent "};`n"
				
				return String
			}
		}
	}
	
	class Expressions {
		class Grouping extends ASTNode {
			static Parameters := ["Expressions"]
			
			Stringify() {
				String := "("
				
				for k, SubExpression in this.Expressions {
					String .= SubExpression.Stringify() ", "
				}
				
				return SubStr(String, 1, StrLen(String) - 2) ")"
			}
		}
		
		class Unary extends ASTNode {
			static Parameters := ["Operand", "Operator"]
			
			Stringify() {
				return "(" this.Operator.Stringify() this.Operand.Stringify() ")"
			}
		}
		
		class Binary extends ASTNode {
			static Parameters := ["Left", "Operator", "Right"]
			
			Stringify() {
				return "(" this.Left.Stringify() " " this.Operator.Stringify() " " this.Right.Stringify() ")"
			}
		}
		
		class Call extends ASTNode {
			static Parameters := ["Target", "Params"]
			
			Stringify() {
				return this.Target.Stringify() this.Params.Stringify()
			}
		}
	}
}