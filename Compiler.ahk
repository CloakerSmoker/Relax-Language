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
		
		if (Index = 0) {
			this.CodeGen.Move(R10, RSI)
		}
		else if (Index = 1) {
			this.CodeGen.Move(R10, RDI)
		}
		else {
			this.CodeGen.SmallMove(R10, Index)
		}
		
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
			
			CG.SmallMove(RSI, 0)
			CG.SmallMove(RDI, 1)
			
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
					this.AddVariable(k - 1, Pair[2].Value)
					
					if (k - 1 = 0) {
						this.CodeGen.Move(R14, RSI)
					}
					else if (k - 1 = 1) {
						this.CodeGen.Move(R14, RDI)
					}
					else {
						this.CodeGen.SmallMove(R14, k - 1)
					}
					
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
	
	CompileIfGroup(Statement) {
		static Index := 0
		
		ThisIndex := Index++
	
		for k, ElseIf in Statement.Options {
			this.CodeGen.Label("__If__" Index)
			this.Compile(ElseIf.Condition)
			this.CodeGen.Pop(RAX)
			this.CodeGen.Cmp(RAX, RSI)
			this.CodeGen.JE("__If__" Index + 1)
			
			for k, Line in ElseIf.Body {
				this.Compile(Line)
			}
			
			this.CodeGen.Jmp("__If__" ThisIndex "__End")
			Index++
		}
	
		this.CodeGen.Label("__If__" Index)
		this.CodeGen.Label("__If__" ThisIndex "__End")
	}
	
	CompileReturn(Statement) {
		this.Compile(Statement.Expression)
		this.CodeGen.Pop(RAX)
		this.CodeGen.JMP("__Return")
	}
	
	CompileBinary(Expression) {
		this.Compile(Expression.Left)
		this.Compile(Expression.Right)
		this.CodeGen.Pop(RAX)
		this.CodeGen.Pop(RBX)
		this.CodeGen.Cmp(RAX, RBX)
	
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.CodeGen.Add(RAX, RBX)
			}
			Case Tokens.MINUS: {
				this.CodeGen.Sub(RAX, RBX)
			}
			Case Tokens.EQUAL: {
				this.CodeGen.Move(RAX, RSI)
				this.CodeGen.C_Move_E_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.Move(RAX, RSI)
				this.CodeGen.C_Move_L_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS_EQUAL: {
				this.CodeGen.Move(RAX, RSI)
				this.CodeGen.C_Move_LE_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER: {
				this.CodeGen.Move(RAX, RSI)
				this.CodeGen.C_Move_G_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER_EQUAL: {
				this.CodeGen.Move(RAX, RSI)
				this.CodeGen.C_Move_GE_R64_R64(RAX, RDI)
			}
			Default: {
				Throw, Exception("Operator '" Expression.Operator.Stringify() "' is not implemented for compiling.")
			}
		}
		
		this.CodeGen.Push(RAX)
	}
	
	CompileCall(Expression) {
		if (Expression.Target.Value = "Deref") {
			return this.CompileDeref(Expression.Params.Expressions)
		}
		else if (Expression.Target.Value = "Put") {
			return this.CompilePut(Expression.Params.Expressions)
		}
		
		Throw, Exception("Function: " Expression.Target.Stringify() " not callable.")
	}
	
	CompileDeref(Params) {
		this.Compile(Params[1])
		this.CodeGen.Pop(RBX)
	
		Switch (Params[2].Value) {
			Case "Byte", "Int8": {
				this.CodeGen.MoveSX_R64_RI8(RAX, RBX)
			}
			Case "Short", "Int16": {
				this.CodeGen.MoveSX_R64_RI16(RAX, RBX)
			}
			Case "Long", "Int32": {
				this.CodeGen.MoveSX_R64_RI32(RAX, RBX)
			}
			Case "LongLong", "Int64": {
				this.CodeGen.Move_R64_RI64(RAX, RBX)
			}
			Default: {
				Throw, Exception("Un-supported deref type: '" Params[2].Stringify() "'.")
			}
		}
		
		this.CodeGen.Push(RAX)
	}
	
	CompilePut(Params) {
		this.Compile(Params[1])
		this.CodeGen.Pop(RAX)
		
		this.Compile(Params[2])
		this.CodeGen.Pop(RBX)
		
		Switch (Params[3].Value) {
			Case "Byte", "Int8": {
				this.CodeGen.Move_RI8_R64(RAX, RBX)
				this.CodeGen.Push(1)
			}
			Case "Short", "Int16": {
				this.CodeGen.Move_RI16_R64(RAX, RBX)
				this.CodeGen.Push(2)
			}
			Case "Long", "Int32": {
				this.CodeGen.Move_RI32_R64(RAX, RBX)
				this.CodeGen.Push(4)
			}
			Case "LongLong", "Int64": {
				this.CodeGen.Move_RI64_R64(RAX, RBX)
				this.CodeGen.Push(8)
			}
		}
	}
}