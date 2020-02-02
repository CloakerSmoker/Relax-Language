; God do I fucking wish I could have left this feature out

BoilerPlate := "
(
_CompiledCodeAddressOf(FunctionName) {
	static Offsets := {$OffsetMap}
	
	static pMemory
	static ImportTable
	static GlobalTable
	
	static _ := _CompiledCodeAddressOf({})
	
	if !(IsObject(FunctionName)) {
		return pMemory + Offsets[FunctionName]
	}
	else {
		VarSetCapacity(ImportTable, $ImportCount * 8, 0)
		VarSetCapacity(GlobalTable, $GlobalCount * 8, 0)
		
$ImportSetup
		
$BytesSetup
		
		pMemory := DllCall(""VirtualAlloc"", ""UInt64"", 0, ""Ptr"", $CodeSize, ""Int"", 0x00001000 | 0x00002000, ""Int"", 0x04)
		OnExit(Func(""DllCall"").Bind(""VirtualFree"", ""Ptr"", pMemory, ""Ptr"", 0, ""UInt"", 0x00008000))
	
		Skip := 0
		
		for k, Byte in Bytes {
			if (Skip) {
				Skip--
				Continue
			}
			
			if (IsObject(Byte)) {
				if (Byte[1] = ""IAT"") {
					NumPut(&ImportTable + Byte[2], pMemory + 0, k - 1, ""Ptr"")
				}
				else if (Byte[1] = ""GT"") {
					NumPut(&GlobalTable + Byte[2], pMemory + 0, k - 1, ""Ptr"")
				}
				
				Skip := 7
			}
			else {
				NumPut(Byte, pMemory + 0, k - 1, ""UChar"")
			}
		}
		
		DllCall(""VirtualProtect"", ""Ptr"", pMemory, ""Ptr"", $CodeSize, ""UInt"", 0x20, ""UInt*"", OldProtection)
	}
}

$CallerFunctions

)"

Build(CodeCompiler) {
	global BoilerPlate
	
	Bytes := CodeCompiler.CodeGen.Link(True, True)
	
	FunctionOffsetsString := ""
	
	for FunctionName, FunctionOffset in CodeCompiler.FunctionOffsets {
		FunctionOffsetsString .= """" FunctionName """:" FunctionOffset ","
	}
	
	FunctionOffsetsString := SubStr(FunctionOffsetsString, 1, -1)
	
	BytesString := "`t`tBytes := []`n"
	BytesString .= "`t`tBytes.Push("
	SkipBytes := 0
	
	Globals := {}
	
	ImportSources := []
	ImportFunctions := []
	
	ImportOffsets := {}
	
	for k, Byte in Bytes {
		if (SkipBytes) {
			SkipBytes--
			Continue
		}
		
		if (Mod(k, 200) = 0) {
			BytesString := SubStr(BytesString, 1, -1) ")`n"
			BytesString .= "`t`tBytes.Push("
		}
		
		if (IsObject(Byte)) {
			BytesString .= "["
			
			if (Byte[1] = "Global") {
				GlobalName := Byte[2]
				
				if !(Globals.HasKey(GlobalName)) {
					Globals[GlobalName] := Globals.Count() * 8
				}
				
				BytesString .= """GT""," Globals[GlobalName]
			}
			else if (Byte[1] = "Dll") {
				FunctionName := Byte[3]
				DllName := Byte[2]
				
				if !(ImportOffsets.HasKey(DllName)) {
					ImportOffsets[DllName] := {}
					ImportSources.Push(DllName)
				}
				
				if !(ImportOffsets[DllName].HasKey(FunctionName)) {
					ImportOffsets[DllName][FunctionName] := ImportFunctions.Count() * 8
					ImportFunctions.Push([FunctionName, DllName])
				}
				
				BytesString .= """IAT""," ImportOffsets[DllName][FunctionName]
			}
			
			BytesString .= "],"
		}
		else {
			BytesString .= Byte ","
		}
	}
	
	BytesString := SubStr(BytesString, 1, -1) ")"
	
	ImportSetup := ""
	
	for k, DllName in ImportSources {
		ImportSetup .= "`t`t"
		ImportSetup .= "h" DllName " := DllCall(""GetModuleHandle"", ""Str"", """ DllName """, ""Ptr"")"
		ImportSetup .= "`n"
	}
	
	for k, Function in ImportFunctions {
		FunctionName := Function[1]
		DllName := Function[2]
		
		FunctionOffset := (k - 1) * 8
		
		ImportSetup .= "`t`t"
		ImportSetup .= "`n`t`t"
		ImportSetup .= "NumPut(DllCall(""GetProcAddress"", ""Ptr"", h" DllName ", ""AStr"", """ FunctionName """, ""Ptr"")" ", &ImportTable + 0, " FunctionOffset ", ""Ptr"")"
		ImportSetup .= "`n"
	}
	
	Template := BoilerPlate
	Template := StrReplace(Template, "$OffsetMap", FunctionOffsetsString)
	Template := StrReplace(Template, "$ImportCount", ImportFunctions.Count())
	Template := StrReplace(Template, "$GlobalCount", Globals.Count())
	Template := StrReplace(Template, "$ImportSetup", ImportSetup)
	Template := StrReplace(Template, "$BytesSetup", BytesString)
	Template := StrReplace(Template, "$CodeSize", Bytes.Count())
	
	Callers := ""
	
	for FunctionName, FunctionNode in CodeCompiler.Program.Functions {
		if (FunctionNode.Type != ASTNodeTypes.Define || CodeCompiler.ModuleFunctions.HasKey(FunctionName)) {
			Continue
		}
		
		Callers .= FunctionName "("
		ParametersString := ""
		
		for k, Param in FunctionNode.Params {
			ParamType := Param[1].Value
			ParamName := Param[2].Value
			
			ParametersString .= """" GetAHKType(ParamType) """, " ParamName ", "
			Callers .= ParamName ", "
		}
		
		HasParameters := FunctionNode.Params.Count()
		
		ParametersString := (HasParameters ? SubStr(ParametersString, 1, -2) ", " : ParametersString) """" GetAHKType(FunctionNode.ReturnType.Value) """)`n"
		Callers := (HasParameters ? SubStr(Callers, 1, -2) : Callers) ") {`n"
		
		Callers .= "`t"
		Callers .= "static pThisFunction := _CompiledCodeAddressOf(""" FunctionName """)"
		Callers .= "`n`t"
		Callers .= "return DllCall(pThisFunction, " ParametersString
		Callers .= "}`n"
	}
	
	Template := StrReplace(Template, "$CallerFunctions", Callers)
	
	return Template
}
GetAHKType(TypeName) {
	; Converts types that don't exist in the eyes of DllCall into regular DllCall types

	static AHKTypes := {"i8": "Char", "i16": "Short", "i32": "Int", "i64": "Int64", "void": "Int64", "f32": "float", "f64": "double"}

	if (AHKTypes.HasKey(TypeName)) {
		return AHKTypes[TypeName]
	}
	else if (InStr(TypeName, "*")) {
		return "Ptr"
	}
	else {
		return TypeName
	}
}