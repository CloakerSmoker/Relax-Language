class Compiler {

	; How it works:
	;  Programs:
	;   A program is passed, and each function inside of that program is compiled
	;  Functions:
	;   For each parameter + local, stack space is allocated
	;   For each line in the body, compile the line
	;  Lines:
	;   Expression Statements:
	;    Compile the line's expression, but with a Pop instruction at the end to clear the expression's return value
	;
	;  Expressions:
	;   Expressions are compiled by compiling both sides of the operator, and then compiling the equal instruction for the 
	;    - Operator. Each compiled expression is expected to push it's resulting value back onto the stack
	;    - so the next expression/construct up in the AST can use the return value
	;
	;   The operands of an operator can be tokens (numerical literals), identifiers, or other expressions
	;    Tokens:
	;     If the token is a number, it is just pushed onto the stack, otherwise it is an error
	;    Identifiers:
	;     The identifier is ensured to be a variable name, and then the variable contents are read off of the stack
	;      - By using R15 as a base for all variables, so a constant index can be used to read any given variable
	;    Expressions:
	;     The expressions are simply compiled, which will be a recursive process until a child expression has two 
	;      - Non-Expression operands
	;   Types:
	;    Each expression related CompileXXXX method will return the type of it's output value, in order for type checking to 
	;     - Work
	;   Assignments:
	;	 Assignments are handled seperately, since they function differently. An assignment is compiled by compiling the right
	;     - side value first, and then popping the resulting value from the right side expression into the memory
	;     - where the left-side variable lives
	;
	;  DllImports:
	;   DllImports are just functions with extra steps, all of the same pre-processing happens with a function call, but 
	;    - instead of linking against an offset to a second local function, the calls are linked to a const(ish) pointer
	;    - to the given function, gathered by `GetProcAddress`
	

	__New(CodeLexer, CodeParser) {
		this.Lexer := CodeLexer
		this.Source := CodeLexer.CodeString
		this.Parser := CodeParser
		this.Typing := CodeParser.Typing
	}
	Compile(Something) {
		if (Something.__Class = "Token") {
			return this.CompileToken(Something)
		}
	
		return this["Compile" ASTNodeTypes[Something.Type]].Call(this, Something)
	}
	CompileNone() {
		return
	}
	
	;========================
	; Variable methods
	
	GetVariableSIB(Name) {
		if (this.Variables.HasKey(Name)) {
			Index := this.Variables[Name]
			
			if (Index = 0) {
				IndexRegister := RSI
			}
			else if (Index = 1) {
				IndexRegister := RDI
			}
			else {
				this.CodeGen.SmallMove(R10, Index)
				IndexRegister := R10
			}
			
			return SIB(8, IndexRegister, R15)
		}
		else if (this.Globals.HasKey(Name)) {
			this.CodeGen.Move_R64_Global_Pointer(R10, Name)
			return SIB(8, RSI, R10)
		}
	}
	SetVariable(Name) {
		VariableSIB := this.GetVariableSIB(Name)
		this.CodeGen.Pop_SIB(VariableSIB), this.StackDepth--
	}
	GetVariable(Name) {
		VariableSIB := this.GetVariableSIB(Name)
		
		this.CodeGen.Push_SIB(VariableSIB), this.StackDepth++
		
		return this.GetVariableType(Name)
	}
	GetVariableType(Name) {
		if (this.Globals.HasKey(Name)) {
			return this.Typing.GetType(this.Globals[Name])
		}
		else {
			return this.Typing.GetVariableType(Name)
		}
	}
	GetVariableAddress(Name) {
		VariableSIB := this.GetVariableSIB(Name)
		
		this.CodeGen.Lea(R10, VariableSIB)
		this.CodeGen.Push(R10), this.StackDepth++
	}
	AddVariable(RSPIndex, Name) {
		this.Variables[Name] := RSPIndex
	}
	
	CompileProgram(Program) {
		this.FunctionIndex := 0 ; A unique number to keep different functions from reusing label names
		
		this.CodeGen := new X64CodeGen()
		this.Globals := Program.Globals
		this.Program := Program
		this.Modules := {}
		
		FunctionOffsets := {}
		FunctionOffset := 0
		
		
		for FunctionName, FunctionDefine in Program.Functions {
			FunctionOffsets[FunctionName] := FunctionOffset
			
			this.Compile(FunctionDefine) ; Compile a function starting from FunctionOffset
			
			FunctionOffset := this.CodeGen.Index() ; And store the new offset for the next function
		}
		
		return new CompiledProgram(Program, this.CodeGen, FunctionOffsets, this.Modules)
	}
	
	CompileDefine(DefineAST) {
		this.FunctionIndex++
		this.Variables := {}
		
		this.Function := DefineAST
		this.Locals := DefineAST.Locals
		
		this.StackDepth := 0
		this.HasReturn := False
		
		ParamSizes := DefineAST.Params.Count()
		
		for LocalName, LocalType in DefineAST.Locals {
			this.AddVariable(ParamSizes++, LocalName)
			this.Typing.AddVariable(LocalType[1], LocalName)
		}
		
		if (Mod(ParamSizes, 2) != 1) {
			ParamSizes++
			; Store a single extra fake local to align the stack (Saved RBP breaks alignment, so any odd number of locals will align the stack again, this just forces an odd number)
		}
		
		this.CodeGen.Label("__Define__" DefineAST.Name.Value)
		
		this.PushA()
			if (ParamSizes != 0) {
				this.CodeGen.SmallSub(RSP, ParamSizes * 8), this.StackDepth += ParamSizes
				this.CodeGen.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			this.CodeGen.SmallMove(RSI, 0)
			this.CodeGen.SmallMove(RDI, 1)
			
			this.FunctionParameters(DefineAST.Params)
			
			for k, LocalDefault in DefineAST.Locals {
				if (LocalDefault[2].Type != ASTNodeTypes.None) {
					this.Compile(LocalDefault[2])
				}
			}
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
			if !(HasReturn) {
				this.CodeGen.SmallMove(RAX, 0)
			}
			
			this.CodeGen.Label("__Return" this.FunctionIndex)
		
			if (ParamSizes != 0) {
				this.CodeGen.SmallAdd(RSP, ParamSizes * 8), this.StackDepth -= ParamSizes
			}
		this.PopA()
		
		if (this.StackDepth != 0) {
			Throw, Exception("Unbalenced stack ops in " DefineAST.Name.Value ", " this.StackDepth)
		}
		
		this.CodeGen.Return()
	}

	CompileReturn(Statement) {
		this.HasReturn := True
		
		ResultType := this.Compile(Statement.Expression)
		ReturnType := this.Typing.GetType(this.Function.ReturnType.Value)
		
		if (ResultType.Family != ReturnType.Family || ResultType.Precision > ReturnType.Precision) {
			new Error("Type")
				.LongText("Wrong return type, should be " ReturnType.Name " or smaller.")
				.Token(Statement.Expression)
				.Source(this.Source)
			.Throw()
		}
		
		if (ResultType.Family = "Decimal") {
			this.CodeGen.Move_XMM_SIB(XMM0, SIB(8, RSI, RSP))
		}
		else if (ResultType.Family = "Integer" || ResultType.Family = "Pointer") {
			this.CodeGen.Pop(RAX), this.StackDepth--
		}
		
		this.CodeGen.JMP("__Return" this.FunctionIndex)
	}


	static PushSavedRegisters := [RCX, RDX, RSI, RDI, R8, R9, R10, R11, R12, R13, R14, R15]
	static PopSavedRegisters := [R15, R14, R13, R12, R11, R10, R9, R8, RDI, RSI, RDX, RCX]
	
	PushA() {
		this.CodeGen.Push(RBP), this.StackDepth++
		this.CodeGen.Move(RBP, RSP)
		
		for k, RegisterToPush in this.PushSavedRegisters {
			this.CodeGen.Push(RegisterToPush), this.StackDepth++
		}
	}
	PopA() {
		for k, RegisterToPop in this.PopSavedRegisters {
			this.CodeGen.Pop(RegisterToPop), this.StackDepth--
		}

		this.CodeGen.Pop(RBP), this.StackDepth--
	}
	
	FunctionParameters(Pairs) {
		static IntFirstFour := [RCX, RDX, R8, R9]
		static XMMFirstFour := [XMM0, XMM1, XMM2, XMM3]
		
		; x64 calling convention has the first four params in RCX(|XMM0), RDX(|XMM1), R8(|XMM2), R9(|XMM3)
		;  and the rest dumped onto the stack before the shadow space, and the return address/saved RBP
		;   so, FunctionEntryRBP aka FunctionEntryRSP + 2 (saved return address + saved RBP) + 4 = Start of stack params.
		;  However, variadic functions are still sort of ???
		
		; Because of these rules, after parameter 4, we need to use RBP as a base, and (ParamNumber - 4) + 2 + 4 as an offset into the stack for the parameter's value
		
		for k, Pair in Pairs {
			Type := Pair[1].Value
			Name := Pair[2].Value

			TrueIndex := k - 1
			
			this.AddVariable(TrueIndex, Name)
			this.Typing.AddVariable(Type, Name)
			
			if (TrueIndex = 0) {
				IndexRegister := RSI
			}
			else if (TrueIndex = 1) {
				IndexRegister := RDI
			}
			else {
				this.CodeGen.SmallMove(R14, TrueIndex)
				IndexRegister := R14
			}
			
			IndexSIB := SIB(8, IndexRegister, R15)

			if (Type = "Double" || Type = "Float") {
				this.CodeGen.Move_SIB_XMM(IndexSIB, XMMFirstFour[TrueIndex + 1])
			}
			else {
				this.CodeGen.Move_SIB_R64(IndexSIB, IntFirstFour[TrueIndex + 1])
			}
			
			if (A_Index = 4) {
				Break
			}
		}
		
		if (Pairs.Count() > 4) {
			this.CodeGen.Move(R12, RBP) ; Save RBP into R12, since RBP/13 can't be used as SIB.Base
		
			loop, % Pairs.Count() - 4 {
				Pair := Pairs[A_Index + 4]
				TrueIndex := (A_Index - 1) + 4 ; Get the actual (0 index) parameter number
				
				this.AddVariable(TrueIndex, Pair[2].Value)
				this.Typing.AddVariable(Pair[1].Value, Pair[2].Value) ; Register the variable
				
				this.CodeGen.SmallMove(R11, (TrueIndex - 4) + 2 + 4) ; Store the index into the stack into R11, so we can use it in a SIB
				this.CodeGen.Move_R64_SIB(RBX, SIB(8, R11, R12)) ; Load the parameter value from the stack, into RBX
				this.CodeGen.SmallMove(R11, TrueIndex) ; Load the actual index of the parameter into R11
				this.CodeGen.Move_SIB_R64(SIB(8, R11, R15), RBX) ; Finally store the loaded value of the parameter into this function's parameter space
			}
		}
	}
	
	CompileToken(TargetToken) {
		Switch (TargetToken.Type) {
			Case Tokens.INTEGER: {
				this.CodeGen.Push(TargetToken.Value), this.StackDepth++
				ShortTypeName := this.CodeGen.NumberSizeOf(TargetToken.Value, False)
				FullTypeName := IToInt(ShortTypeName)
				return this.Typing.GetType(FullTypeName)
			}
			Case Tokens.DOUBLE: {
				this.CodeGen.Push(FloatToBinaryInt(TargetToken.Value)), this.StackDepth++
				return this.Typing.GetType("Double")
			}
			Case Tokens.IDENTIFIER: {
				return this.GetVariable(TargetToken.Value)
			}
			Case Tokens.STRING: {
				this.CodeGen.Push_String_Pointer(TargetToken.Value), this.StackDepth++
				return this.Typing.GetType("Int8*")
			}
			Default: {
				new Error("Compile")
					.LongText("This token can not be compiled.")
					.ShortText("Is not implemented in the compiler.")
					.Token(TargetToken)
					.Source(this.Source)
				.Throw()
			}
		}
	}
	
	CompileExpressionLine(Statement) {
		this.Compile(Statement.Expression)
		this.CodeGen.Pop(RAX), this.StackDepth--
	}
	
	CompileIfGroup(Statement) {
		static Index := 0
		
		ThisIndex := Index++
	
		for k, ElseIf in Statement.Options {
			this.CodeGen.Label("__If__" Index)
			this.Compile(ElseIf.Condition)
			this.CodeGen.Pop(RCX), this.StackDepth--
			this.CodeGen.Cmp(RCX, RSI)
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
	
	CompileForLoop(Statement) {
		static Index := 0
		
		ThisIndex := Index++
		
		this.Compile(Statement.Init)
		this.CodeGen.Pop(RCX), this.StackDepth--
		
		this.CodeGen.Label("__For__" ThisIndex)
		
		this.Compile(Statement.Condition)
		this.CodeGen.Pop(RCX), this.StackDepth--
		
		this.CodeGen.Cmp(RCX, RSI)
		this.CodeGen.JE("__For__" ThisIndex "__End")
		
		for k, Line in Statement.Body {
			this.Compile(Line)
		}
		
		this.Compile(Statement.Step)
		this.CodeGen.Pop(RCX), this.StackDepth--
		this.CodeGen.Jmp("__For__" ThisIndex)
		
		this.CodeGen.Label("__For__" ThisIndex "__End")
	}
	
	;========================
	; Binary expression methods
	
	CompileDerefAssign(Expression) {
		LeftType := this.Compile(Expression.Left)
		
		if !(InStr(LeftType.Name, "*")) {
			new Error("Type")
				.LongText("The left operand of '" Expression.Stringify() "' (" LeftType.Name ") must be a pointer type.")
				.Token(Expression.Left)
				.Source(this.Source)
			.Throw()
		}
		
		RightType := this.Compile(Expression.Right)
		
		LeftValueType := this.Typing.GetType(StrReplace(LeftType.Name, "*"))
		this.Cast(RightType, LeftValueType) ; Cast the right side value to the type the left side points to
		
		this.CodeGen.Pop(RBX), this.StackDepth--
		this.CodeGen.Pop(RAX), this.StackDepth--
		this.CodeGen.Push(RBX), this.StackDepth++ ; Store our result back onto the stack
		
		ShortTypeName := IntToI(LeftValueType.Name)
		
		this.CodeGen["Move_R" ShortTypeName "_R64"].Call(this.CodeGen, RAX, RBX)
		
		return RightType
	}
	
	CompileBinary(Expression) {
		if (Expression.Operator.Type = Tokens.TIMES_EQUAL) {
			return this.CompileDerefAssign(Expression)
		}
	
		IsAssignment := OperatorClasses.IsClass(Expression.Operator, "Assignment")
		
		if (IsAssignment) {
			RightType := this.Compile(Expression.Right)
			LeftType := this.GetVariableType(Expression.Left.Value)
		}
		else {
			LeftType := this.Compile(Expression.Left)
			RightType := this.Compile(Expression.Right)
		}
		
		Try {
			ResultType := this.Typing.ResultType(LeftType, RightType)
			
			if (IsAssignment && (Mod(LeftType.Precision, 8) != Mod(RightType.Precision, 8) || (LeftType.Precision < RightType.Precision))) {
				Throw, Exception("Dummy exception")
			}
		}
		Catch E {
			new Error("Type")
				.LongText("The operands of '" Expression.Stringify() "' (" LeftType.Name ", " RightType.Name ") are not compatible.")
				.Token(Expression.Operator)
				.Source(this.Source)
			.Throw()
		}
		
		if (IsAssignment) {
			if (ResultType.Family = "Decimal" && Expression.Operator.Type = Tokens.COLON_EQUAL) {
				this.CodeGen.Push(SIB(8, RSI, RSP)), this.StackDepth++
				; Copy the right side value, which is on top of the stack; since this.SetVariable pops the stack while assigning, and we still need to return a result
				
				this.SetVariable(Expression.Left.Value)
				return RightType
			}
			else if (ResultType.Family = "Integer" || ResultType.Family = "Pointer") {
				return this.CompileIntegerAssignment(Expression, LeftType, RightType)
			}
			else {
				new Error("Compile")
					.LongText("Assigning a " LeftType.Name " with the " Expression.Operator.Value " operator is not implemented.")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
		}
		else {
			if (ResultType.Family = "Decimal") {
				return this.CompileBinaryDecimal(Expression, LeftType, RightType, ResultType)
			}
			else if (ResultType.Family = "Integer" || ResultType.Family = "Pointer") {
				return this.CompileBinaryInteger(Expression, LeftType, RightType, ResultType)
			}
		}
	}
	CompileIntegerAssignment(Expression, VariableType, RightType) {
		Switch (Expression.Operator.Type) {
			Case Tokens.COLON_EQUAL: {
				this.CodeGen.Push(SIB(8, RSI, RSP)), this.StackDepth++
				; Copy the right side value, which is on top of the stack; since this.SetVariable pops the stack while assigning, and we still need to return a result
			
				this.SetVariable(Expression.Left.Value)
			}
			Case Tokens.PLUS_EQUAL, Tokens.MINUS_EQUAL: {
				this.GetVariable(Expression.Left.Value)
				this.CodeGen.Pop(RAX), this.StackDepth--
				this.CodeGen.Pop(RBX), this.StackDepth--
				
				if (Expression.Operator.Type = Tokens.PLUS_EQUAL) {
					this.CodeGen.Add(RAX, RBX)
				}
				else if (Expression.Operator.Type = Tokens.MINUS_EQUAL) {
					this.CodeGen.Sub(RAX, RBX)
				}
				
				this.CodeGen.Push(RAX), this.StackDepth++
				this.CodeGen.Push(SIB(8, RSI, RSP)), this.StackDepth++
				this.SetVariable(Expression.Left.Value)
			}
		}
	}
	
	CompileBinaryDecimal(Expression, LeftType, RightType, ResultType) {
		this.Cast(RightType, ResultType)
		this.CodeGen.FLD_Stack()
		this.CodeGen.Pop(RBX), this.StackDepth--
		
		this.Cast(LeftType, ResultType)
		this.CodeGen.FLD_Stack()
		this.CodeGen.Pop(RAX), this.StackDepth--
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			this.CodeGen.Cmp(RAX, RBX) ; Comparisons are done as integers, since x87 equality checks are a nightmare
		}
	
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.CodeGen.FAddP()
			}
			Case Tokens.MINUS: {
				this.CodeGen.FSubP()
			}
			Case Tokens.TIMES: {
				this.CodeGen.FMulP()
			}
			Case Tokens.DIVIDE: {
				this.CodeGen.FDivP()
			}
			Case Tokens.EQUAL: {
				this.CodeGen.C_Move_E_R64_R64(RAX, RDI)
			}
			Case Tokens.BANG_EQUAL: {
				this.CodeGen.C_Move_NE_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.C_Move_L_R64_R64(RAX, RDI) ; WARNING, ALL COMPARISIONS BELOW HERE MIGHT BE WRONG. Since floats are just used as ints for the comparisons
			}
			Case Tokens.LESS_EQUAL: {
				this.CodeGen.C_Move_LE_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER: {
				this.CodeGen.C_Move_G_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER_EQUAL: {
				this.CodeGen.C_Move_GE_R64_R64(RAX, RDI)
			}
			Default: {
				new Error("Compile")
					.LongText("Floating-point operator '" Expression.Operator.Stringify() "' is not implemented in the compiler.")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
		}
		
		this.CodeGen.Push(RAX), this.StackDepth++
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			ResultType := this.Typing.GetType("Int8")
		}
		else {
			this.CodeGen.FSTP_Stack() ; Use the stack space from pushing RAX to store the actual result
		}
		
		return ResultType
	}
	
	CompileBinaryInteger(Expression, LeftType, RightType, ResultType) {		
		if (OperatorClasses.IsClass(Expression.Operator, "Logic")) {
			this.CodeGen.Pop(RDX), this.StackDepth--
			this.CodeGen.Cmp(RDX, RSI)
			this.CodeGen.SmallMove(RBX, 0)
			this.CodeGen.C_Move_NE_R64_R64(RBX, RDI) ; Convert the two operands on the stack into 0 or 1, based on if they = 0 or not
			
			this.CodeGen.Pop(RCX), this.StackDepth--
			this.CodeGen.Cmp(RCX, RSI)
			this.CodeGen.SmallMove(RAX, 0)
			this.CodeGen.C_Move_NE_R64_R64(RAX, RDI)
			
			ResultType := this.Typing.GetType("Int64")
		}
		else {
			this.Cast(RightType, ResultType)
			this.CodeGen.Pop(RBX), this.StackDepth--
		
			this.Cast(LeftType, ResultType)
			this.CodeGen.Pop(RAX), this.StackDepth--
		}
		
		if (OperatorClasses.IsClass(Expression.Operator, "Equality", "Comparison")) {
			this.CodeGen.Cmp(RAX, RBX) ; All comparison operators have a prelude of a CMP instruction
			this.CodeGen.Move(RAX, RSI) ; And a 0-ing of the output register, so the output defaults to false when the MoveCC fails
			
			ResultType := this.Typing.GetType("Int64")
		}
	
		Switch (Expression.Operator.Type) {
			Case Tokens.PLUS: {
				this.CodeGen.Add(RAX, RBX)
			}
			Case Tokens.MINUS: {
				this.CodeGen.Sub(RAX, RBX)
			}
			Case Tokens.TIMES: {
				this.CodeGen.IMul_R64_R64(RAX, RBX)
			}
			Case Tokens.DIVIDE: {
				this.CodeGen.IDiv_RAX_R64(RBX)
			}
			Case Tokens.MOD: {
				this.CodeGen.IDiv_RAX_R64(RBX)
				this.CodeGen.Move(RAX, RDX)
			}
			Case Tokens.EQUAL: {
				this.CodeGen.C_Move_E_R64_R64(RAX, RDI)
			}
			Case Tokens.BANG_EQUAL: {
				this.CodeGen.C_Move_NE_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS: {
				this.CodeGen.C_Move_L_R64_R64(RAX, RDI)
			}
			Case Tokens.LESS_EQUAL: {
				this.CodeGen.C_Move_LE_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER: {
				this.CodeGen.C_Move_G_R64_R64(RAX, RDI)
			}
			Case Tokens.GREATER_EQUAL: {
				this.CodeGen.C_Move_GE_R64_R64(RAX, RDI)
			}
			Case Tokens.LOGICAL_AND: {
				this.CodeGen.And_R64_R64(RAX, RBX)
			}
			Case Tokens.LOGICAL_OR: {
				this.CodeGen.Or_R64_R64(RAX, RBX)
			}
			Default: {
				new Error("Compile")
					.LongText("Integer operator '" Expression.Operator.Stringify() "' is not implemented in the compiler.")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
		}
		
		this.CodeGen.Push(RAX), this.StackDepth++
		return ResultType
	}
	
	;========================
	; Unary/grouping expression methods
	
	CompileUnary(Expression) {
		Operator := Expression.Operator
		OperatorString := Operator.Stringify()
		
		if (OperatorString = "--" || OperatorString = "++") {
			VariableSIB := this.GetVariableSIB(Expression.Operand.Value)
			
			Switch (Operator.Type) {
				Case Tokens.PLUS_PLUS_L: {
					this.CodeGen.Inc_SIB(VariableSIB)
					this.GetVariable(Expression.Operand.Value)
				}
				Case Tokens.PLUS_PLUS_R: {
					this.GetVariable(Expression.Operand.Value)
					this.CodeGen.Inc_SIB(VariableSIB)
				}
				Case Tokens.MINUS_MINUS_L: {
					this.CodeGen.Dec_SIB(VariableSIB)
					this.GetVariable(Expression.Operand.Value)
				}
				Case Tokens.MINUS_MINUS_R: {
					this.GetVariable(Expression.Operand.Value)
					this.CodeGen.Dec_SIB(VariableSIB)
				}
			}
			
			return this.GetVariableType(Expression.Operand.Value)
		}
		else if (Operator.Type = Tokens.DEREF) {
			OperandType := this.Compile(Expression.Operand)
			
			if !(OperandType.Pointer) {
				new Error("Type")
					.LongText("Unary operator '*' requires an operand of a pointer type, not (" OperandType.Name ").")
					.Token(Expression.Operator)
					.Source(this.Source)
				.Throw()
			}
			
			this.CodeGen.Pop(RAX), this.StackDepth--
			
			Switch (OperandType.Pointer.Precision) {
				Case 8: {
					this.CodeGen.Move_R64_RI8(RAX, RAX)
				}
				Case 16: {
					this.CodeGen.Move_R64_RI16(RAX, RAX)
				}
				Case 32: {
					this.CodeGen.Move_R64_RI32(RAX, RAX)
				}
				Case 64: {
					this.CodeGen.Move_R64_RI64(RAX, RAX)
				}
			}
			
			this.CodeGen.Push(RAX), this.StackDepth++
			return OperandType.Pointer
		}
		else if (Operator.Type = Tokens.ADDRESS) {
			this.GetVariableAddress(Expression.Operand.Value)
			return this.Typing.GetPointerType(this.Typing.GetVariableType(Expression.Operand.Value))
		}
		else if (Operator.Type = Tokens.NEGATE) {
			OperandType := this.Compile(Expression.Operand)
		
			this.CodeGen.Neg_SIB(SIB(8, RSI, RSP))
			return OperandType
		}
		
		new Error("Compile")
			.LongText("Unary operator " OperatorString " is not implemented in the compiler.")
			.ShortText("<")
			.Token(Operator)
			.Source(this.Source)
		.Throw()
	}
	
	CompileGrouping(Expression) {
		for k, v in Expression.Expressions {
			if (k = 1) {
				ResultType := this.Compile(v)
			}
			else {
				this.Compile(v)
				this.CodeGen.Pop(RDX), this.StackDepth--
			}
		}
		
		return ResultType
	}
	
	;========================
	; Cast methods
	
	Cast(TypeOne, TypeTwo, StackLess := False) {
		if (TypeOne.Name = TypeTwo.Name) {
			return
		}
	
		; Parameter should be on the stack
		; RAX is the only register used for casts
		; StackLess param is for when the operand is already in RAX, otherwise RAX is loaded with the first thing on the stack
		
		if !(StackLess) {
			this.CodeGen.Pop(RAX), this.StackDepth--
		}
		
		Base := ObjGetBase(this)
		Path := this.Typing.CastPath(TypeOne, TypeTwo)
		
		for k, Pair in Path {
			Name := "Cast_" IntToI(Pair[1].Name) "_" IntToI(Pair[2].Name)
		
			if (Base.HasKey(Name)) {
				Base[Name].Call(this)
			}
			else {
				Throw, Exception("Invalid cast: " Name)
			}
		}
		
		if !(StackLess) {
			this.CodeGen.Push(RAX), this.StackDepth++
		}
	}
	
	Cast_I8_I16() {
		this.CodeGen.CBWE()
	}
	Cast_I16_I32() {
		this.CodeGen.CWDE()
	}
	Cast_I32_I64() {
		this.CodeGen.CDQE()
	}
	Cast_I64_I8() {
		this.Cast(this.Typing.GetType("Int8"), this.Typing.GetType("Int64"), True)
	}
	Cast_I64_Void() {
	}
	Cast_Void_I64() {
	}
	Cast_I64_Double() {
		this.CodeGen.Push(RAX), this.StackDepth++
		this.CodeGen.FILD_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(RAX), this.StackDepth--
	}
	Cast_Double_I64() {
		this.CodeGen.Push(RAX), this.StackDepth++
		this.CodeGen.FISTP_Stack()
		this.CodeGen.FSTP_Stack()
		this.CodeGen.Pop(RAX), this.StackDepth--
	}
	Cast_I32_Float() {
	}
	Cast_Float_I32() {
	}
	
	;========================
	; Function call methods

	CompileCall(Expression) {
		if (Expression.Target.Type = ASTNodeTypes.Binary) {
			ModuleExpression := Expression.Target
			
			if (ModuleExpression.Operator.Type = Tokens.COLON) {
				ModuleName := ModuleExpression.Left.Value
				FunctionName := ModuleExpression.Right.Value
				
				Try {
					ModuleFunction := Module.Find(ModuleName, FunctionName)
					FunctionNode := ModuleFunction.Define
				}
				Catch E {
					new Error("Module")
						.LongText(E.Message)
						.Token(ModuleExpression)
						.Source(this.Source)
					.Throw()
				}
				
				this.Modules[ModuleName] := ModuleFunction
				IsModuleCall := True
			}
		}
	
	
		if (IsModuleCall || FunctionNode := this.Program.Functions[Expression.Target.Value]) {
			static ParamRegisters := [R9, R8, RDX, RCX]
			
			StackParamSpace := 0 ; Remembers how much stack space to free after the call
			
			if (Mod(this.StackDepth, 1) != 1) {
				; Breaks stack alignment
				this.CodeGen.Push(0), this.StackDepth++, StackParamSpace++
			}
		
			; As of right here, the stack is unaligned, and something like
			
			; RSP + (1 * 8) Garbage Data
			; RSP + (0 * 8) Optional Padding to make Mod(RSP, 16) = 8
		
			; And we need
			
			; RSP + (7 * 8) Garbage Data
			; RSP + (6 * 8) Optional Padding to make Mod(RSP, 16) = 8
			; RSP + (6 * 8) Optional Padding for even numbers of params
			; RSP + (5 * 8) Param 5
			; RSP + (4 * 8) Param N
			; RSP + (3 * 8) Shadow space
			; RSP + (0 * 8) Shadow space (4 bytes total)
			
			; Along with Mod(RSP, 16) = 8. So, below we need to adjust the stack to be like that
		
			Params := Expression.Params.Expressions
		
			if (Params.Count() > FunctionNode.Params.Count()) {
				new Error("Compile")
					.LongText("Too many parameters passed to function.")
					.ShortText("Takes " FunctionNode.Params.Count() " parameters.")
					.Token(Expression.Target)
					.Source(this.Source)
				.Throw()
			}
			else if (Params.Count() < FunctionNode.Params.Count()) {
				new Error("Compile")
					.LongText("Not enough parameters passed to function.")
					.ShortText("Takes " FunctionNode.Params.Count() " parameters.")
					.Token(Expression.Target)
					.Source(this.Source)
				.Throw()
			}
		
			if (Params.Count() > 4) {
				; If we have 4+ params, then some need to be dumped onto the stack
			
				if (Mod(Params.Count(), 2) != 1) {
					StackParamSpace++ ; If we have an even number of params, add an extra to break stack alignment
					this.CodeGen.Push(0), this.StackDepth++
				}
			
				loop, % Params.Count() - 4 {
					ParamNumber := Params.Count() - (A_Index - 1) ; Stack params are passed right to left, so the real index of this param needs to be calculated
				
					ParamType := this.Compile(Params[ParamNumber])
					RequiredType := this.Typing.GetType(FunctionNode.Params[ParamNumber][1].Value)
					
					try {
						this.Cast(ParamType, RequiredType) ; A quick param type check
					}
					catch E {
						new Error("Compile")
							.LongText("Should be " RequiredType.Name ", not " ParamType.Name ".")
							.Token(ParamValue)
							.Source(this.Source)
						.Throw()
					}
					
					StackParamSpace++ ; Increment the number of Int64s to free from the stack
				}
			}
			
			this.CodeGen.SmallSub(RSP, 0x20), this.StackDepth += 4 ; Allocate shadow space (below the stack parameters)
		
			for k, ParamValue in Params {
				if (k > 4) {
					Break ; Only put the first four params into registers, the others are already on the stack
				}
			
				ParamType := this.Compile(ParamValue)
				RequiredType := this.Typing.GetType(FunctionNode.Params[k][1].Value)
				
				try {
					this.Cast(ParamType, RequiredType) ; Another quick type check
				}
				catch E {
					new Error("Compile")
						.LongText("Should be " RequiredType.Name ", not " ParamType.Name ".")
						.Token(ParamValue)
						.Source(this.Source)
					.Throw()
				}
			}
			
			loop, % 4 - (k = "" ? 0 : k) {
				this.CodeGen.Push(0), this.StackDepth++ ; For when we have less than 4 params, push a 0 for each unpassed param
			}
			
			for k, Register in ParamRegisters {
				; Then pop each compiled param into it's specific register
				this.CodeGen.Pop(Register), this.StackDepth--
			}
		
			if (IsModuleCall) {
				this.CodeGen.ModuleCall(ModuleName, FunctionDefine.Name.Value, ModuleFunction.Address)
			}
			else if (FunctionNode.Type = ASTNodeTypes.DllImport) {
				this.CodeGen.DllCall(FunctionNode.DllName, FunctionNode.FunctionName)
			}
			else if (FunctionNode.Type = ASTNodeTypes.Define) {
				this.CodeGen.Call_Label("__Define__" Expression.Target.Value)
			}
			
			this.CodeGen.SmallAdd(RSP, (StackParamSpace * 8) + 0x20), this.StackDepth -= 4, this.StackDepth -= StackParamSpace ; Free shadow space + any stack params
			
			this.CodeGen.Push(RAX), this.StackDepth++ ; Push the return value
			
			return this.Typing.GetType(FunctionNode.ReturnType.Value) ; Give back the function's return type
		}
		
		new Error("Compile")
			.LongText("Function '" Expression.Target.Stringify() "' is not callable.")
			.Token(Expression.Target)
			.Source(this.Source)
		.Throw()
	}
}