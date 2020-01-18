﻿	StackStrings(DefineAST, StringStartingOffsets) {
		if (this.Features & this.UseStackStrings) {
			this.CodeGen.Move(RBX, RSP)
			
			for k, String in DefineAST.Strings {
				HighAddressOffset := StringStartingOffsets[String.Value]
				
				this.CodeGen.SmallMove(RAX, HighAddressOffset)
				HighAddressSIB := SIB(8, RAX, R15)
				
				this.CodeGen.Lea_R64_SIB(RSP, HighAddressSIB)
				
				Characters := StrSplit(String.Value)
				
				CharacterCountRemainder := Mod(Characters.Count(), 8) ; Gets how many characters the string is over a 8 byte boundry
				
				if (CharacterCountRemainder = 0) {
					; If the string straddles the 8 byte boundry, push an extra character and update how many characters it is over the boundry by
					Characters.Push("") ; Otherwise, the string wouldn't be null-terminated
					CharacterCountRemainder := 1
				}
				
				loop, % 8 - CharacterCountRemainder {
					; For each byte left until the string reaches an 8 byte boundry, push an extra null character on it for padding
					Characters.Push("")
				}
				
				loop {
					CharacterChunk := 0 ; An int64 which holds the current 8 characters being turned into a single movabs
					
					loop 8 {
						; Since we are actually working with big-endian, the number we push will be reversed, so we want 
						;  to have all the terminating null characters (at the end of the string) on the left of the 
						;   first chunk, so by moving the first character we pop all the way left, we align the string
						;    correctly with the start at a low address, which counts up higher until the null characters
						;     are reached
						
						ReversedIndex := 8 - A_Index
						ShiftBy := ReversedIndex * 8
						
						CharacterChunk |= Asc(Characters.Pop()) << ShiftBy
					}
					
					this.CodeGen.Push(I64(CharacterChunk))
				} until (Characters.Count() = 0)
			}
			
			this.CodeGen.Move(RSP, RBX)
		}
	}
	
	
	CompileInline(DefineAST, CallerParams) {
		OldVariables := this.Variables
		OldTypingVariables := this.Typing.Variables
		OldLocals := this.Locals
		OldFunction := this.Function
		OldFunctionIndex := this.FunctionIndex
		OldHasReturn := this.HasReturn
		
		OurVariables := {}
		OurTypingVariables := {}
		
		this.Variables := OurVariables
		this.Typing.Variables := OurTypingVariables
		
		this.FunctionIndex := "__Inline__" DefineAST.Name.Value
		
		ParamCount := DefineAST.Params.Count()
		LocalCount := DefineAST.Locals.Count()
		
		StackSpace := ParamCount + LocalCount
		StackSpace += (Mod(StackSpace, 2) != 1)
		
		StringStartingOffsets := {}

		for k, String in DefineAST.Strings {		
			this.AddVariable(StackSpace, "__String__" String.Value)
			this.Typing.AddVariable("Int8*", "__String__" String.Value)
			
			StackSpace += Ceil((StrLen(String.Value) + 1) / 8)
			StringStartingOffsets[String.Value] := StackSpace
		}
		
		this.CodeGen.Push(R15), this.StackDepth++
		this.CodeGen.SmallSub(RSP, StackSpace * 8), this.StackDepth += StackSpace
		
		this.Variables := OldVariables
		this.Typing.Variables := OldTypingVariables
		
		for k, Param in CallerParams {
			ParamType := this.Compile(Param)
			
			this.CodeGen.SmallMove(RBX, k - 1)
			this.CodeGen.Move_SIB_R64(SIB(8, RBX, RSP), this.PopRegisterStack())
		}
		
		this.CodeGen.Move(R15, RSP)
		
		this.Variables := OurVariables
		this.Typing.Variables := OurVariables
		this.Function := DefineAST
		this.Locals := DefineAST.Locals
		this.HasReturn := False
		
		for LocalName, LocalType in DefineAST.Locals {
			this.AddVariable(ParamCount + (k - 1), LocalName)
			this.Typing.AddVariable(LocalType[1], LocalName)
		}
		
		for k, ParamPair in DefineAST.Params {
			ParamName := ParamPair[2].Value
			
			this.AddVariable(k - 1, ParamName)
			this.Typing.AddVariable(ParamPair[1].Value, ParamName)
		}
		
		this.StackStrings(DefineAST, StringStartingOffsets)
		
		this.Inline := True
			for k, LocalDefault in DefineAST.Locals {
				if (LocalDefault[2].Type != ASTNodeTypes.None) {
					this.Compile(LocalDefault[2])
				}
			}
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
			if !(this.HasReturn) {
				this.CodeGen.SmallMove(RAX, 0)
			}
			
			this.CodeGen.Label("__Return" this.FunctionIndex)
			
			this.CodeGen.SmallAdd(RSP, StackSpace * 8), this.StackDepth -= StackSpace
		this.CodeGen.Pop(R15), this.StackDepth--
		this.Inline := False
		
		this.FunctionIndex := OldFunctionIndex
		this.Variables := OldVariables
		this.Typing.Variables := OldTypingVariables
		this.Function := OldFunction
		this.Locals := OldLocals
		this.HasReturn := OldHasReturn
		
		this.CodeGen.Move(this.PushRegisterStack(), RAX)
		
		return this.Typing.GetType(DefineAST.ReturnType.Value)
	}
	
	CompileDefine(DefineAST) {
		if (DefineAST.Keyword = Keywords.INLINE) {
			return
		}
		
		
		this.FunctionIndex++
		this.Variables := {}
		
		this.Function := DefineAST
		this.Locals := DefineAST.Locals
		
		this.RegisterStackIndex := 0
		this.StackDepth := 0
		this.HasReturn := False
		
		ParamSizes := DefineAST.Params.Count()
		
		for LocalName, LocalType in DefineAST.Locals {
			this.AddVariable(ParamSizes++, LocalName)
			this.Typing.AddVariable(LocalType[1], LocalName)
		}
		
		if (this.Features & this.UseStackStrings) {
			StringStartingOffsets := {}

			for k, String in DefineAST.Strings {
				this.AddVariable(ParamSizes, "__String__" String.Value)
				this.Typing.AddVariable("Int8*", "__String__" String.Value)
			
				ParamSizes += Ceil((StrLen(String.Value) + 1) / 8)
				StringStartingOffsets[String.Value] := ParamSizes
			}
		}
		
		if (Mod(ParamSizes, 2) != 1) {
			ParamSizes++
			; Store a single extra fake local to align the stack (Saved RBP breaks alignment, so any odd number of locals will align the stack again, this just forces an odd number)
		}
		
		this.CodeGen.Label("__Define__" DefineAST.Name.Value)
		
		this.PushA()
			if (ParamSizes != 0) {
				if (ParamSizes <= 3) {
					Loop, % ParamSizes {
						this.CodeGen.Push(RBX), this.StackDepth++
					}
				}
				else {
					this.CodeGen.SmallSub(RSP, ParamSizes * 8), this.StackDepth += ParamSizes
				}
				
				this.CodeGen.Move(R15, RSP) ; Store a dedicated offset into the stack for variables to reference
			}
			
			this.CodeGen.Move_R64_FunctionTable(R14)
			
			this.CodeGen.SmallMove(RSI, 0)
			this.CodeGen.SmallMove(RDI, 1)
			
			this.FunctionParameters(DefineAST.Params)
			
			this.StackStrings(DefineAST, StringStartingOffsets)
			
			for k, LocalDefault in DefineAST.Locals {
				if (LocalDefault[2].Type != ASTNodeTypes.None) {
					this.Compile(LocalDefault[2])
				}
			}
			
			for k, Statement in DefineAST.Body {
				this.Compile(Statement)
			}
			
			if !(this.HasReturn) {
				this.CodeGen.SmallMove(RAX, 0)
			}
			
			this.CodeGen.Label("__Return" this.FunctionIndex)
			
			if (ParamSizes != 0) {
				if (ParamSizes <= 3) {
					Loop, % ParamSizes {
						this.CodeGen.Pop(RBX), this.StackDepth--
					}
				}
				else {
					this.CodeGen.SmallAdd(RSP, ParamSizes * 8), this.StackDepth -= ParamSizes
				}
			}
		this.PopA()
		
		if (this.StackDepth != 0) {
			MsgBox, % "Unbalenced stack ops in " DefineAST.Name.Value ", " this.StackDepth
		}
		
		this.CodeGen.Return()
	}
	
	FunctionParameters(Pairs) {
		static IntFirstFour := [RCX, RDX, R8, R9]
		static XMMFirstFour := [XMM0, XMM1, XMM2, XMM3]
		
		; x64 calling convention has the first four params in RCX(|XMM0), RDX(|XMM1), R8(|XMM2), R9(|XMM3)
		;  and the rest dumped onto the stack before the shadow space, and the return address/saved RBP
		;   so, FunctionEntryRBP aka FunctionEntryRSP + 2 (saved return address + saved RBP) + 4 = Start of stack params.
		;  However, variadic functions are still sort of ???
		
		; Because of these rules, after parameter 4, we need to use RBP as a base, and (ParamNumber - 4) + 2 + 4 as an offset into the stack for the parameter's value
		
		this.CodeGen.Move(RAX, RSI)
		IndexSIB := SIB(8, RAX, R15)
		
		for k, Pair in Pairs {
			Type := Pair[1].Value
			Name := Pair[2].Value

			TrueIndex := k - 1
			
			this.AddVariable(TrueIndex, Name)
			this.Typing.AddVariable(Type, Name)

			if (A_Index <= 4) {
				if (Type = "Double" || Type = "Float") {
					this.CodeGen.Move_SIB_XMM(IndexSIB, XMMFirstFour[TrueIndex + 1])
				}
				else {
					this.CodeGen.Move_SIB_R64(IndexSIB, IntFirstFour[TrueIndex + 1])
				}
			}
			
			if (A_Index = 5) {
				; When A_Index is 5 (aka the first stack-passed param)
				;  Store RBP into RCX, so we can use RBP in the SIB for getting a parameter out of the stack
				
				this.CodeGen.Move(RCX, RBP)
				this.CodeGen.SmallMove(RDX, 6)
			}
			
			if (A_Index > 4) {
				this.CodeGen.Move_R64_SIB(RBX, SIB(8, RDX, RCX)) ; Then fetch the passed value
				
				this.CodeGen.Move_SIB_R64(IndexSIB, RBX) ; And store it into our variable space
				
				if (Pairs.Count() > A_Index) {
					this.CodeGen.Inc_R64(RDX)
				}
			}
			
			if (A_Index != Pairs.Count()) {
				this.CodeGen.Inc_R64(RAX)
			}
		}
	}
	
	CompileCall(Expression) {
		if (this.Typing.IsValidType(Expression.Target.Value) && Expression.Params.Expressions.Count() = 1) {
			this.Compile(Expression.Params.Expressions[1])
			return this.Typing.GetType(Expression.Target.Value)
		}
		else if (Expression.Target.Type = ASTNodeTypes.Binary) {
			if (this.Features & this.DisableModules) {
				new Error("Compile")
					.LongText("Calling functions from modules is disabled by the DisableModules flag.")
					.ShortText("Can't be called")
					.Token(Expression)
					.Source(this.Source)
				.Throw()
			}
			
			ModuleExpression := Expression.Target
			
			if (ModuleExpression.Operator.Type = Tokens.COLON) {
				ModuleName := ModuleExpression.Left.Value
				ModuleFunctionName := ModuleExpression.Right.Value
				
				Try {
					ModuleAST := Module.Find(ModuleName, ModuleFunctionName)
					
					MsgBox, % ModuleAST.Stringify()
						
					for FunctionName, FunctionNode in ModuleAST.Functions {
						if (FunctionNode.Type = ASTNodeTypes.DllImport) {
							this.Program.Functions[FunctionNode.Name.Value] := FunctionNode
						}
					}
					
					FunctionNode := ModuleAST.Functions[ModuleFunctionName]
					
					if (FunctionNode.Keyword != Keywords.Inline) {
						new Error("Module")
							.LongText("All module functions must be inline.")
							.ShortText("Is not inline.")
							.Token(Expression)
							.Source(this.Source)
						.Throw()
					}
				}
				catch {
					new Error("Module")
						.LongText(E.Message)
						.Token(ModuleExpression)
						.Source(this.Source)
					.Throw()
				}
			}
		}
		else {
			FunctionNode := this.Program.Functions[Expression.Target.Value]
		}
		
		if (FunctionNode.Keyword = Keywords.INLINE) {
			return this.CompileInline(FunctionNode, Expression.Params.Expressions)
		}
		
		if (FunctionNode) {
			;static ParamRegisters := [R9, R8, RDX, RCX]
			static ParamRegisters := [RCX, RDX, R8, R9]
			
			OldIndex := this.RegisterStackIndex ; Store the register stack index before calling, so we know what to save, and what to restore
			
			loop, % OldIndex {
				; Store whatever part of the register stack we're using, just in case the function we call doesn't 
				;  save all registers
				this.CodeGen.Push(this.RegisterStack[A_Index]), this.StackDepth++
			}
		
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
			
			StackParamCount := Max(Params.Count() - 4, 0)
			Straddling := False
			
			if (this.RegisterStackIndex = this.RegisterStack.Count()) {
				; If we are straddling a page of the register stack, push a dummy value just to make sure 
				;  the repeated .PopRegisterStack calls in the for loop don't spam pushing/popping the whole stack
				this.PushRegisterStack()
				Straddling := True ; Remember for later so we can remove the dummy
			}
			
			loop, % Abs(Min(0, Params.Count() - 4)) {
				this.CodeGen.Push(RSI), this.StackDepth++
			}
			
			loop, % Params.Count() {
				ReversedIndex := Params.Count() - (A_Index - 1)
				ParamValue := Params[ReversedIndex]
				; Push all parameters onto the stack in reverse order, the top 4 will be popped below to save the register stack
				
				ParamType := this.Compile(ParamValue)
				RequiredType := this.Typing.GetType(FunctionNode.Params[ReversedIndex][1].Value)
				
				try {
					this.Cast(ParamType, RequiredType) ; Ensure the passed parameter is of the correct type
					this.CodeGen.Push(this.PopRegisterStack()), this.StackDepth++
				}
				catch {
					new Error("Compile")
						.LongText("Should be " RequiredType.Name ", not " ParamType.Name ".")
						.Token(ParamValue)
						.Source(this.Source)
					.Throw()
				}
			}
			
			loop, % 4 {
				this.CodeGen.Pop(ParamRegisters[A_Index]), this.StackDepth--
			}
			
			if (Mod(this.StackDepth, 2) != 1) {
				; Break stack alignment if needed, since 0x20 is even, and the push return addr will align the stack
				this.CodeGen.Push(0), this.StackDepth++, StackParamCount++
			}
			
			this.CodeGen.SmallSub(RSP, 0x20), this.StackDepth += 4 ; Allocate shadow space (below the stack parameters)
			
			if (FunctionNode.Type = ASTNodeTypes.DllImport) {
				if (this.Features & this.DisableDllCall) {
					new Error("Compile")
						.LongText("Calling functions from Dlls is disabled by the DisableDllCall flag.")
						.ShortText("Can't be called")
						.Token(Expression)
						.Source(this.Source)
					.Throw()
				}
				
				this.CodeGen.SmallMove(RAX, this.CodeGen.GetFunctionIndex(FunctionNode.FunctionName "@" FunctionNode.DllName))
				this.CodeGen.Call_SIB(SIB(8, RAX, R14))
			}
			else if (FunctionNode.Type = ASTNodeTypes.Define) {
				this.CodeGen.Call_Label("__Define__" Expression.Target.Value)
			}
			
			this.CodeGen.SmallAdd(RSP, (StackParamCount * 8) + 0x20)
			this.StackDepth -= 4, this.StackDepth -= StackParamCount ; Free shadow space + any stack params/dummy space
			
			if (Straddling) {
				this.PopRegisterStack()
			}
			
			loop, % OldIndex {
				ReversedIndex := OldIndex - A_Index + 1
				this.CodeGen.Pop(this.RegisterStack[ReversedIndex]), this.StackDepth--
			}
			
			this.RegisterStackIndex := OldIndex
			
			this.CodeGen.Move(this.PushRegisterStack(), RAX) ; Push the return value
			
			return this.Typing.GetType(FunctionNode.ReturnType.Value) ; Give back the function's return type
		}
		
		new Error("Compile")
			.LongText("Function '" Expression.Target.Stringify() "' is not callable.")
			.Token(Expression.Target)
			.Source(this.Source)
		.Throw()
	}