#Include C:\Users\Connor\Desktop\X64Gen\X64.ahk

class Compiler {
	__New(Tokenizer) {
		this.Tokenizer := Tokenizer
	}
	CompileFunction(DefineAST) {
		ParamSizes := this.FunctionParameters(DefineAST.Params)
		; TODO - Add type checking (Duh) and type check .ReturnType against Int64/EAX
		
		CG := this.CodeGen := new X64CodeGen()
		
	
		CG.Push(RBP)
		CG.Move(RBP, RSP)
			CG.Sub(RSP, ParamSizes)
			CG.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
			CG.Add(RSP, ParamSizes)
		CG.Pop(RBP)
		CG.Return()
	}
	GetVariable(Register, Name) {
		if !(this.Variables.HasKey(Name)) {
			Throw, Exception("Variable '" Name "' not found.")
		}
		
		Index := this.Variables[Name]
		
		this.CodeGen.Push(R14)
		this.CodeGen.Move(R14, Index)
		this.CodeGen.Move(Register, SIB(8, R14, R15))
		this.CodeGen.Pop(R14)
	}
	AddVariable(RSPIndex, Name) {
		this.Variables[Name] := RSPIndex
	}
	
	FunctionParameters(Pairs) {
		Size := 0
		
		for k, Pair in Pairs {
			Switch (Pair[1]) {
				Case "Int64": {
					this.AddVariable(k, Pair[2])
					Size += 8
				}
				Default: {
					Throw, Exception("Invalid parameter type: '" Pair[1] "'.")
				}
			}
		}
	
		return Size
	}
}