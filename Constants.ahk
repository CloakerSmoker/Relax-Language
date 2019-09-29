class Tokens extends Enum {
	static Options := "
	(
		IDENTIFIER
		KEYWORD
		
		NUMBER
		STRING
		
		LEFT_PAREN
		RIGHT_PAREN
		
		LEFT_BRACE
		RIGHT_BRACE
		
		LEFT_BRACKET
		RIGHT_BRACKET
		
		COMMA
		POUND

		
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