class ASTOptimizer {
	static DisableDeadCodeElimination := RelaxFlags.Optimization.DisableDeadCodeElimination
	static DisableDeadIfElimination := RelaxFlags.Optimization.DisableDeadIfElimination
	static DisableConstantFolding := RelaxFlags.Optimization.DisableConstantFolding
	
	__New(CodeLexer, CodeParser, CodeFlags) {
		this.Typing := CodeParser.Typing
		this.Flags := CodeFlags
		this.Level := CodeFlags.OptimizationLevel
	}
	
	Optimize(Something) {
		if (Something.__Class = "Token") {
			return Something
		}
		
		MethodName := "Optimize" ASTNodeTypes[Something.Type]
		Base := ObjGetBase(this)
		
		if !(Base.HasKey(MethodName)) {
			return Something
		}
		
		return Base[MethodName].Call(this, Something)
	}
	
	OptimizeProgram(ProgramNode) {
		this.Program := ProgramNode
		
		this.CalledFunctions := {}
		
		for k, Function in ProgramNode.Functions {
			this.OptimizeFunction(Function)
		}
	}
	
	OptimizeFunction(FunctionNode) {
		this.Function := FunctionNode
		this.VariableIsStatic := {}
		
		for LocalName, LocalType in FunctionNode.Locals {
			this.VariableIsConstant[LocalName] := False ; A tracker for if a variable is constant
		}
		
		for ParamName, ParamType in FunctionNode.Params {
			this.VariableIsConstant[ParamName] := False
		}
		
		for k, Line in FunctionNode.Body {
			FunctionNode.Body[k] := this.OptimizeLine(Line)
		}
	}
	OptimizeLine(Statement) {
		NoneNode := (this.Level & this.DisableDeadCodeElimination) ? (Statement.Clone()) : (new ASTNodes.None())
		
		Switch (Statement.Type) {
			Case ASTNodeTypes.IFGROUP: {
				if (this.Level & this.DisableDeadIfElimination) {
					return Statement
				}
				
				NewOptions := []
				
				for k, IfStatement in Statement.Options {
					IfStatement.Condition := this.Optimize(IfStatement.Condition)
					
					if (this.IsConstant(IfStatement.Condition) && !(this.Level & this.DisableDeadCodeElimination)) {
						; If the if statement has a constant condition after optimization, and dead code elimination is enabled
						
						if (IfStatement.Condition.Value != 0) {
							; And if the condition is true, then this will be the final option
							for k, Line in IfStatement.Body {
								IfStatement.Body[k] := this.OptimizeLine(Line)
							}
							
							Log("Found constant true if-statement condition (or else statement) '" IfStatement.Condition.Stringify() "', eliminating all following branches")
							
							NewOptions.Push(IfStatement) ; So push it
							Break ; And break to ignore the rest
						}
						
						Log("Found constant false if-statement condition '" IfStatement.Condition.Stringify() "', removing branch")
						
						; If we haven't broken the loop by now, then the statement has a constant condition, but
						;  the condition is false, so we can just not push it, since it would never run
					}
					else {
						; Non-constant condition, which we can't really do much about, except for optimizing what we can
						;                      (^ or dead code elimination is off)
						IfStatement.Condition := this.OptimizeExpression(IfStatement.Condition)
						
						for k, Line in IfStatement.Body {
							IfStatement.Body[k] := this.OptimizeLine(Line)
						}
						
						NewOptions.Push(IfStatement)
					}
				}
				
				if (NewOptions.Count() > 0) {
					Statement.Options := NewOptions
				}
				else {
					Log("Removed all branches from an if-statement at " Statement.Options[1].Condition.Context.Start )
					return new ASTNodes.None()
				}
			}
			Case ASTNodeTypes.FORLOOP: {
				Statement.Init := this.Optimize(Statement.Init)
				Statement.Condition := this.Optimize(Statement.Condition)
				Statement.Step := this.Optimize(Statement.Step)
				
				for k, Line in Statement.Body {
					Statement.Body[k] := this.OptimizeLine(Line)
				}
				
				; TODO: Come up with an actual way to optimize here
			}
			Case ASTNodeTypes.EXPRESSIONLINE: {
				if (this.ExpressionHasSideEffects(Statement.Expression)) {
					Statement.Expression := this.OptimizeExpression(Statement.Expression)
				}
				else {
					Log("Eliminated useless expression statement '" Statement.Expression.Stringify() "'")
					return new ASTNodes.None()
				}
			}
			Case ASTNodeTypes.RETURN: {
				Statement.Expression := this.OptimizeExpression(Statement.Expression)
			}
		}
		
		return Statement
	}
	
	OptimizeExpression(Expression) {
		return this.Optimize(Expression)
	}
	
	OptimizeGrouping(Expression) {
		NewExpressions := []
		
		for k, SubExpression in Expression.Expressions {
			if (k = 1 || this.ExpressionHasSideEffects(SubExpression)) {
				NewExpressions.Push(this.Optimize(SubExpression))
			}
		}
		
		if (NewExpressions.Count() = 1 && !(this.DisableDeadCodeElimination)) {
			return NewExpressions[1]
		}
		else {
			Expression.Expressions := NewExpressions
			
			return Expression
		}
	}
	
	OptimizeUnary(Expression) {
		return Expression
	}
	OptimizeArrayAccess(Expression) {
		Expression.Index := this.Optimize(Expression.Index)
		
		return Expression
	}
	
	OptimizeBinary(Expression) {
		NewLeft := this.Optimize(Expression.Left) ; Optimize any operands first
		NewRight := this.Optimize(Expression.Right)
		
		if (this.IsConstant(NewLeft) && this.IsConstant(NewRight)) {
			; If both operands were optimized into constants (and should be tokens) then we can manually evaluate them
			
			NewContext := NewLeft.Context.Merge(NewRight.Context) ; Merge contexts so errors don't go haywire
			
			static TokenTypesToRealTypes := {Tokens.INTEGER: "i64", Tokens.DOUBLE: "f64"}
			static TypeFamilyToTokenType := {"Decimal": Tokens.DOUBLE, "Integer": Tokens.INTEGER}
			
			if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
				NewType := Tokens.INTEGER ; When we have a comparison operator, the result type is just integers
			}
			else {
				LeftType := TokenTypesToRealTypes[NewLeft.Type] ; Go from a token type, to a Typing type
				RightType := TokenTypesToRealTypes[NewRight.Type]
				
				NewType := this.Typing.GetType(this.Typing.ResultType(LeftType, RightType)) ; Get the result type for the two token types
				NewType := TypeFamilyToTokenType[NewType.Family] ; And convert it back to a token type
			}
			
			NewLeft := NewLeft.Value
			NewRight := NewRight.Value
			
			Switch (Expression.Operator.Type) {
				Case Tokens.PLUS: {
					NewValue := NewLeft + NewRight
				}
				Case Tokens.MINUS: {
					NewValue := NewLeft - NewRight
				}
				Case Tokens.TIMES: {
					NewValue := NewLeft * NewRight
				}
				Case Tokens.DIVIDE: {
					NewValue := NewLeft / NewRight
				}
				Case Tokens.MOD: {
					NewValue := Mod(NewLeft, NewRight)
				}
				Case Tokens.EQUAL: {
					NewValue := NewLeft = NewRight
				}
				Case Tokens.BANG_EQUAL: {
					NewValue := NewLeft != NewRight
				}
				Case Tokens.LESS: {
					NewValue := NewLeft < NewRight
				}
				Case Tokens.LESS_EQUAL: {
					NewValue := NewLeft <= NewRight
				}
				Case Tokens.GREATER: {
					NewValue := NewLeft > NewRight
				}
				Case Tokens.GREATER_EQUAL: {
					NewValue := NewLeft >= NewRight
				}
				Case Tokens.LOGICAL_AND: {
					NewValue := NewLeft && NewRight
				}
				Case Tokens.LOGICAL_OR: {
					NewValue := NewLeft && NewRight
				}
				Case Tokens.BITWISE_AND: {
					NewValue := NewLeft & NewRight
				}
				Case Tokens.BITWISE_OR: {
					NewValue := NewLeft | NewRight
				}
				Case Tokens.BITWISE_XOR: {
					NewValue := NewLeft ^ NewRight
				}
			}
			
			Log("Optimized expression '" Expression.Stringify() "' to '" NewValue "'")
			
			return new Token(NewType, NewValue, NewContext, NewLeft.Source)
		}
		else {
			; Else one (or both) of the operands aren't static
			
			Expression.Left := NewLeft ; Still update the node, since the operands may have been optimized to some extent
			Expression.Right := NewRight
			; Note: We don't bother updating the context, since the Expression object already has a correct context
			
			return Expression
		}
	}
	
	ExpressionHasSideEffects(Expression) {
		if (this.Level & this.DisableDeadCodeElimination) {
			return True
		}
		
		static OtherSideEffectOperators := {"++": 1, "--": 1, "*": 1}
		
		if (OperatorClasses.IsClass(Expression.Operator, "Assignment") || OtherSideEffectOperators.HasKey(Expression.Operator.Stringify())) {
			return True
		}
		else if (Expression.Type = ASTNodeTypes.BINARY) {
			LeftHasSideEffects := this.ExpressionHasSideEffects(Expression.Left)
			RightHasSideEffects := this.ExpressionHasSideEffects(Expression.Right)
			
			return LeftHasSideEffects || RightHasSideEffects
		}
		else if (Expression.Type = ASTNodeTypes.UNARY) {
			OperandHasSideEffects := this.ExpressionHasSideEffects(Expression.Operand)
			
			return OperandHasSideEffects
		}
		else if (Expression.Type = ASTNodeTypes.CALL || Expression.Type = ASTNodeTypes.ARRAYACCESS) {
			return True
		}
		else {
			return False
		}
	}
	
	IsConstant(Something) {
		if (this.Level & this.DisableConstantFolding) {
			return False
		}
		
		if (Something.__Class = "Token") {
			Switch (Something.Type) {
				Case Tokens.INTEGER, Tokens.DOUBLE, Tokens.STRING: {
					return True
				}
				Case Tokens.IDENTIFIER: {
					return this.VariableIsConstant[Something.Value]
				}
			}
		
		}
		
		Switch (Something.Type) {
			Case ASTNodeTypes.BINARY: {
				if (OperatorClasses.IsClass(Something.Operator, "Assignment")) {
					return this.IsConstant(Something.Right)
				}
				else {
					return this.IsConstant(Something.Left) && this.IsConstant(Something.Right)
				}
			}
			Case ASTNodeTypes.IFGROUP: {
				for k, IfStatement in Something.Options {
					if (this.IsConstant(IfStatement.Condition)) {
						return True
					}
				}
				
				return False
			}
		}
	}
	
	IsConditional(Something) {
		Switch (Something.Type) {
			Case ASTNodeTypes.IFGROUP, ASTNodeTypes.IF, ASTNodeTypes.FORLOOP: {
				return True
			}
			Default: {
				return False
			}
		}
	}
}