﻿class Tokens extends Enum {
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
		
		AS
		
		FIRST_PREFIX
			BANG
			BITWISE_NOT
			DEREF
			ADDRESS
			NEGATE
			
			FIRST_POSTFIX
				; The overlap here is since ++/-- are both pre/postfix
				PLUS_PLUS
				MINUS_MINUS
		LAST_PREFIX
			LAST_POSTFIX
		
		; Operator variants so they can be told apart
		
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
		MINUS_GREATER
		
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
		
		CONCAT
		
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
						,"-": {"NONE": Tokens.MINUS, "-": Tokens.MINUS_MINUS, "=": Tokens.MINUS_EQUAL, ">": Tokens.MINUS_GREATER}
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
					,",": Tokens.COMMA}
}

class OperatorClasses {
	static Prefix	  := {"Precedence": -1
						, "Associative": "Right"
						, "Tokens": [Tokens.PLUS_PLUS, Tokens.MINUS_MINUS, Tokens.BANG, Tokens.BITWISE_NOT, Tokens.DEREF, Tokens.ADDRESS, Tokens.BITWISE_NOT]}

	static Assignment := {"Precedence": 0
						, "Associative": "Right"
						, "Tokens": [Tokens.COLON_EQUAL, Tokens.PLUS_EQUAL, Tokens.MINUS_EQUAL, Tokens.DOT_EQUAL, Tokens.TIMES_EQUAL]}
	
	static Logic      := {"Precedence": 1
						, "Associative": "Left"
						, "Tokens": [Tokens.LOGICAL_AND, Tokens.LOGICAL_OR]}
	
	static Equality   := {"Precedence": 2
						, "Associative": "Left"
						, "Tokens": [Tokens.BANG_EQUAL, Tokens.EQUAL, Tokens.EQUAL_EQUAL]}
						
	static Comparison := {"Precedence": 3
						, "Associative": "Right"
						, "Tokens": [Tokens.LESS, Tokens.LESS_EQUAL, Tokens.GREATER, Tokens.GREATER_EQUAL]}
						
	static Addition	  := {"Precedence": 4
						, "Associative": "Left"
						, "Tokens": [Tokens.PLUS, Tokens.MINUS]}
						
	static Division	  := {"Precedence": 5
						, "Associative": "Left"
						, "Tokens": [Tokens.DIVIDE, Tokens.TIMES, Tokens.MOD]}
						
	static Bitwise    := {"Precedence": 6
						, "Associative": "Left"
						, "Tokens": [Tokens.BITWISE_AND, Tokens.BITWISE_OR, Tokens.BITWISE_XOR]}
	
	static Access     := {"Precedence": 7
						, "Associative": "Left"
						, "Tokens": [Tokens.DOT, Tokens.MINUS_GREATER]}
						
	static Module     := {"Precedence": 8
						, "Associative": "Left"
						, "Tokens": [Tokens.COLON]}
						
	static BinaryToPrefix := {Tokens.TIMES: Tokens.DEREF
							 ,Tokens.BITWISE_AND: Tokens.ADDRESS
							 ,Tokens.MINUS: Tokens.NEGATE}
							 
	static PrefixPrecedenceOverrides := {Tokens.ADDRESS: 9}
							 
	static WordOperators := {"as": Tokens.AS}
						
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

class Operators {
	Precedence(Operator) {
		for k, v in OperatorClasses {
			for k, FoundOperator in v.Tokens {
				if (Operator.Type = FoundOperator) {
					return v
				}
			}
		}
	}
	GetPrecedence(Operator) {
		try {
			return this.Precedence(Operator).Precedence
		}
		
		if (OperatorClasses.PrefixPrecedenceOverrides.HasKey(Operator.Type)) {
			return OperatorClasses.PrefixPrecedenceOverrides[Operator.Type]
		}
		
		return 0
	}
	GetAssociativity(Operator) {
		try {
			return this.Precedence(Operator).Associative
		}
		
		return "Left"
	}
	
	IsOperator(Value) {
		return Tokens.FIRST_OPERATOR < Tokens[Value] && Tokens[Value] < Tokens.LAST_OPERATOR
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
	
	IsBinaryOrPrefix(Operator) {
		return OperatorClasses.BinaryToPrefix.HasKey(Operator.Type)
	}
	
	; For when an operator is both binary, and prefix, this will get the prefix version of it
	BinaryToPrefix(Operator) {
		if (this.IsBinaryOrPrefix(Operator)) {
			Operator.Type := OperatorClasses.BinaryToPrefix[Operator.Type]
		
			return Operator
		}
		else if (this.IsPrefix(Operator)) {
			return Operator
		}
	
		Throw, Exception("No prefix version of " Operator.Stringify())
	}
	
	; For when an operator is both pre and postfix, these functions will get just the pre/postfix version
	EnsurePrefix(Operator) {
		return this.EnsureXXXfix(Operator, "_L")
	}
	EnsurePostfix(Operator) {
		return this.EnsureXXXfix(Operator, "_R")
	}
	EnsureXXXfix(Operator, Form) {
		if (this.IsPrefix(Operator) && this.IsPostfix(Operator)) {
			return new Token(Tokens[Tokens[Operator.Type] Form], Operator.Value, Operator.Context, Operator.Source)
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

class Token {
	__New(Type, Value, Context, Source) {
		this.Type := Type
		this.Value := Value
		this.Context := Context
		this.Source := Source
	}
	
	IsOperator() {
		return Tokens.FIRST_OPERATOR < this.Type && this.Type < Tokens.LAST_OPERATOR
	}
	CaseIsOperator() {
		if (this.IsOperator()) {
			return this.Type
		}
		else {
			return !this.Type
		}
	}
	IsNotData() {
		if (this.IsOperator()) {
			return True
		}
	
		Switch (this.Type) {
			Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.STRING, Tokens.IDENTIFIER, Tokens.RIGHT_PAREN: {
				return False
			}
		}
		
		return True
	}
	IsData() {
		return !this.IsNotData()
	}
	GetContext() {
		return this.Context
	}
	
	Stringify() {
		if (this.Type = Tokens.KEYWORD) {
			return Keywords[this.Value]
		}
		else if (this.Type = Tokens.STRING) {
			return A_Quote this.Value A_Quote
		}
	
		return this.Value
	}
}
class Context {
	__New(Start, End, Line := 0) {
		this.Start := Start
		this.End := End
		this.Line := Line
	}
	Merge(OtherContext) {
		NewStart := Min(OtherContext.Start, this.Start)
		NewEnd := Max(OtherContext.End, this.End)
		NewLine := Min(OtherContext.Line, this.Line)

		return new Context(NewStart, NewEnd, NewLine)
	}
	ExtractFrom(String) {
		return SubStr(String, this.Start + 1, this.End - this.Start)
	}
}

class Keywords extends Enum {
	static Options := "
	(
		define
		declare
		import
		dllimport
		export
		
		return
		if
		else
		for
		while
		loop
		continue
		break
		
		module
		
		struct
	)"
}



class ASTNode {
	__New(Params*) {
		if (Params.Count() != this.Parameters.Count()) {
			Throw, Exception("INTERNAL: Not enough parameters passed to " this.__Class ".__New, " Params.Count() " != " this.Parameters.Count())
		}
	
		for k, v in this.Parameters {
			if (Params[k].__Class = "Token" || Params[k].HasKey("Source")) {
				this.Source := Params[k].Source
			}
			
			this[v] := Params[k]
		}
		
		ClassNameParts := StrSplit(this.__Class, ".")
		this.Type := ASTNodeTypes[ClassNameParts[ClassNameParts.Count()]] ; Translates ASTNode.Expressions.Identifier into 
		; just 'Identifier', and then gets the enum value for 'Identifier'
		
		this.Context := this.GetContext()
	}
}

class ASTNodeTypes extends Enum {
	static Options := "
	(
		NONE
	
		DEFINE
		DLLIMPORT
		EXPRESSIONLINE
		RETURN
		IFGROUP
		IF
		FORLOOP
		WHILELOOP
		LOOPLOOP
		CONTINUEBREAK
		
		GROUPING
		CALL
		UNARY
		BINARY
		ARRAYACCESS
		
		STRUCT
	)"
}

class ASTNodes {
	class None extends ASTNode {
		static Parameters := []
	
		Stringify() {
			return ""
		}
	}
	
	class Struct extends ASTNode {
		static Parameters := ["NameToken", "Types"]
	}
	
	class Statements {
		class Program extends ASTNode {
			static Parameters := ["Functions", "Globals", "Modules", "Exports", "CustomTypes"]
			
			Stringify() {
				String := "/* " Relax.VERSION " */`n"
				
				for k, GlobalVariable in this.Imports {
					String .= GlobalVariable[1] " " GlobalVariable[2]
				}
				
				for k, FunctionDefine in this.Functions {
					String .= FunctionDefine.Stringify()
				}
				
				return String
			}
		}
		
	
		class DllImport extends ASTNode {
			static Parameters := ["ReturnType", "Name", "Params", "DllName", "FunctionName"]
		
			Stringify() {
				String := "DllImport " this.ReturnType.Value " " this.Name.Value "("
				
				for k, Param in this.Params {
					String .= Param[1].Value ", "
				}
			
				if (this.Params.Count()) {
					String := SubStr(String, 1, StrLen(String) - 2)
				}
				
				String .= ") {" this.DllName ".dll, " this.FunctionName "};`n"
				return String
			}
		}
	
		class Define extends ASTNode {
			static Parameters := ["Keyword", "ReturnType", "Name", "Params", "Body", "Locals", "Strings"]
			
			Stringify() {
				String := Keywords[this.Keyword] " " this.ReturnType.Value " " this.Name.Value "("
			
				for k, Pair in this.Params {
					String .= Pair[1].Value " " Pair[2].Value ", "
				}
			
				if (this.Params.Count()) {
					String := SubStr(String, 1, StrLen(String) - 2)
				}
					
				String .= ") {`n"
				
				for LocalName, LocalType in this.Locals {
					String .= "`t" LocalType[1] " " LocalName ";`n"
				}
				for LocalName, LocalDefault in this.Locals {
					String .= LocalDefault[2].Stringify("`t")
				}
				
				for k, Line in this.Body {
					String .= Line.Stringify("`t")
				}
				
				String .= "`n" Indent "};`n"
				return String
			}
		}
		
		class ForLoop extends ASTNode {
			static Parameters := ["Init", "Condition", "Step", "Body"]
		
			Stringify(Indent := "") {
				String := Indent "For (" this.Init.Stringify() ", " this.Condition.Stringify() ", " this.Step.Stringify() ") {`n"
			
				for k, Line in this.Body {
					String .= Line.Stringify(Indent "`t")
				}
				
				String .= "`n" Indent "};`n"
				return String
			}
		}
		
		class WhileLoop extends ASTNode {
			static Parameters := ["Condition", "Body"]
			
			Stringify(Indent := "") {
				String := Indent "While (" this.Condition.Stringify() ") {`n"
			
				for k, Line in this.Body {
					String .= Line.Stringify(Indent "`t")
				}
				
				String .= "`n" Indent "};`n"
				return String
			}
		
		}
		
		class LoopLoop extends ASTNode {
			static Parameters := ["Count", "Body"]
			
			Stringify(Indent := "") {
				String := Indent "Loop " this.Count.Stringify() " {`n"
			
				for k, Line in this.Body {
					String .= Line.Stringify(Indent "`t")
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
		
		class ContinueBreak extends ASTNode {
			static Parameters := ["Keyword"]
			
			Stringify(Indent := "") {
				return Indent this.Keyword.Stringify()
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

				if (k) {
					String := SubStr(String, 1, StrLen(String) - 2)
				}

				return String ")"
			}
			GetContext() {
				LeftMost := this.Expressions[1].GetContext()
				LeftMost.Start -= 1
				
				RightMost := this.Expressions[this.Expressions.Count()].GetContext()
				RightMost.End += 1
				
				return LeftMost.Merge(RightMost)
			}
		}
		
		class Unary extends ASTNode {
			static Parameters := ["Operand", "Operator"]
			
			Stringify() {
				if (InStr(Tokens[this.Operator.Type], "_R")) {
					return "(" this.Operand.Stringify() this.Operator.Stringify() ")"
				}
				else {
					return "(" this.Operator.Stringify() this.Operand.Stringify() ")"
				}
			}
			GetContext() {
				return this.Operand.GetContext().Merge(this.Operator.GetContext())
			}
		}
		
		class Binary extends ASTNode {
			static Parameters := ["Left", "Operator", "Right"]
			
			Stringify() {
				return "(" this.Left.Stringify() " " this.Operator.Stringify() " " this.Right.Stringify() ")"
			}
			GetContext() {
				return this.Left.GetContext().Merge(this.Right.GetContext())
			}
		}
		
		class Call extends ASTNode {
			static Parameters := ["Target", "Params"]
			
			Stringify() {
				return this.Target.Stringify() this.Params.Stringify()
			}
			GetContext() {
				StartContext := this.Target.GetContext()
				EndContext := this.Params.Expressions[this.Params.Expressions.Count()].GetContext()
				
				if !(IsObject(EndContext)) {
					EndContext := StartContext.Clone()
					EndContext.End += 1
				}
				
				EndContext.End += 1
				
				FullContext := StartContext.Merge(EndContext)
			
				return FullContext
			}
		}
		
		class ArrayAccess extends ASTNode {
			static Parameters := ["Target", "Index"]
			
			Stringify() {
				return this.Target.Stringify() "[" this.Index.Stringify() "]"
			}
			GetContext() {
				TargetContext := this.Target.GetContext()
				IndexContext := this.Index.GetContext()
				
				ThisContext := TargetContext.Merge(IndexContext)
				ThisContext.End += 1
				
				return ThisContext
			}
		}
	}
}