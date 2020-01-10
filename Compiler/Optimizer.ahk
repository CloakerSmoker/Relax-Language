class ASTOptimizer {
	Optimize(Something) {
		if (Something.__Class = "Token") {
			return Something
		}
	
		return this["Optimize" ASTNodeTypes[Something.Type]].Call(this, Something)
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
		
		for LocalName, LocalTypeAndDefaultValue in FunctionNode.Locals {
			this.VariableIsConstant[LocalName] := False ; A tracker for if a variable is constant
			LocalTypeAndDefaultValue[2] := this.OptimizeLine(LocalTypeAndDefaultValue[2])
		}
		
		for ParamName, ParamType in FunctionNode.Params {
			this.VariableIsConstant[ParamName] := False
		}
		
		for k, Line in FunctionNode.Body {
			FunctionNode.Body[k] := this.OptimizeLine(Line)	
		}
	}
	OptimizeLine(Statement) {
		Switch (Statement.Type) {
			Case ASTNodeTypes.IFGROUP: {
				NewOptions := []
				
				for k, IfStatement in Statement.Options {
					if (this.IsConstant(IfStatement.Condition)) {
						; If the if statement has a constant condition
						
						if (this.Evaluate(IfStatement.Condition)) {
							; And if the condition is true, then this will be the final option
							
							NewOptions.Push(IfStatement) ; So push it
							Break ; And break to ignore the rest
						}
						
						; If we haven't broken the loop by now, then the statement has a constant condition, but
						;  the condition is false, so we can just not push it, since it would never run
					}
					else {
						; Non-constant condition, which we can't really do much about, except for optimizing what we can
						IfStatement.Condition := this.OptimizeExpression(IfStatement.Condition)
						NewOptions.Push(IfStatement)
					}
				}
				
				Statement.Options := NewOptions
				
				return Statement
			}
			Case ASTNodeTypes.EXPRESSIONLINE: {
				if (this.ExpressionHasSideEffects(Statement.Expression)) {
					Statement.Expression := this.OptimizeExpression(Statement.Expression)
					
					return Statement
				}
			}
		}
		
		return new ASTNodes.None()
	}
	
	OptimizeExpression(Expression) {
		return this.Optimize(Expression)
	}
	
	OptimizeBinary(Expression) {
		NewLeft := this.Optimize(Expression.Left) ; Optimize any operands first
		NewRight := this.Optimize(Expression.Right)
		
		if (this.IsConstant(NewLeft) && this.IsConstant(NewRight)) {
			; If both operands were optimized into constants (and should be tokens) then we can manually evaluate them
			
			NewContext := NewLeft.Context.Merge(NewRight.Context) ; Merge contexts so errors don't go haywire
			NewType := Tokens.INTEGER ; TODO: Dynamically figure out the type, maybe even move typing in here
			
			Switch (Expression.Operator.Type) {
				Case Tokens.EQUAL_EQUAL: {
					NewValue := NewLeft.Value = NewRight.Value
				}
				Case Tokens.PLUS: {
					NewValue := NewLeft.Value + NewRight.Value
				}
				; TODO: Implement other operators
			}
			
			return new Token(NewType, NewValue, NewContext)
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
		else {
			return False
		}
	}
	
	IsConstant(Something) {
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