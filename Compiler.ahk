class Compiler {
	__New(Tokenizer) {
		this.Tokenizer := Tokenizer
	}
	Compile(Something) {
		if (Something.__Class = "Token") {
			return this.CompileToken(Something)
		}
	
		return this["Compile" ASTNodeTypes[Something.Type]].Call(this, Something)
	}
	
	GetVariable(Name) {
		if !(this.Variables.HasKey(Name)) {
			Throw, Exception("Variable '" Name "' not found.")
		}
		
		Index := this.Variables[Name]
		
		this.CodeGen.Move(R10, Index)
		this.CodeGen.Move(R11, SIB(8, R10, R15))
		this.CodeGen.Push(R11)
	}
	AddVariable(RSPIndex, Name) {
		this.Variables[Name] := RSPIndex
	}
	
	CompileToken(TargetToken) {
		Switch (TargetToken.Type) {
			Case Tokens.INTEGER: {
				this.CodeGen.Push(TargetToken.Value)
			}
			Case Tokens.IDENTIFIER: {
				this.GetVariable(TargetToken.Value)
			}
			Default: {
				Throw, Exception("Token '" TargetToken.Stringify() "' can not be compiled.")
			}
		}
	}
	
	CompileFunction(DefineAST) {
		this.Variables := {}
		; TODO - Add type checking (Duh) and type check .ReturnType against Int64/EAX
		ParamSizes := DefineAST.Params.Count() * 8
		CG := this.CodeGen := new X64CodeGen()
		
	
		CG.Push(RBP)
		CG.Move(RBP, RSP)
			if (ParamSizes != 0) {
				CG.Sub(RSP, ParamSizes)
				CG.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			this.FunctionParameters(DefineAST.Params)
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
		CG.Label("__Return")
		
		if (ParamSizes != 0) {
			CG.Add(RSP, ParamSizes)
		}
		
		this.Leave()
		
		return CG
	}
	Leave() {
		this.CodeGen.Pop(RBP)
		this.CodeGen.Return()
	}
	
	FunctionParameters(Pairs) {
		static FirstFour := [RCX, RDX, R8, R9]
	
		Size := 0
		Count := Pairs.Count()
		
		for k, Pair in Pairs {
			Switch (Pair[1].Value) {
				Case "Int64": {
					this.AddVariable(Count - k, Pair[2].Value)
					this.CodeGen.Move(R14, Count - k)
					this.CodeGen.Move_SIB_R64(SIB(8, R14, R15), FirstFour[k])
					Size += 8
				}
				Default: {
					Throw, Exception("Invalid parameter type: '" Pair[1] "'.")
				}
			}
		}
	
		return Size
	}
	
	CompileReturn(Statement) {
		this.Compile(Statement.Expression)
		this.CodeGen.Pop(RAX)
		this.CodeGen.JMP("__Return")
	}
	
	CompileBinary(Expression) {
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.Compile(Expression.Left)
				this.Compile(Expression.Right)
				this.CodeGen.Pop(RAX)
				this.CodeGen.Pop(RBX)
				this.CodeGen.Add(RAX, RBX)
				this.CodeGen.Push(RAX)
			}
			Default: {
				Throw, Exception("Operator '" Expression.Operator.Stringify() "' is not implemented for compiling.")
			}
		}
	}
}