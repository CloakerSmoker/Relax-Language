class Typing {
	class TypeSet {
		class Integer {
			static Weight := 0
		
			class i64 {
				static Precision := 64
				static Decimal := "f64"
			}
			class Void {
				static Precision := 64
			}
			class i32 {
				static Precision := 32
				static Decimal := "f32"
			}
			class i16 {
				static Precision := 16
			}
			class i8 {
				static Precision := 8
			}
		}
		class Decimal {
			static Weight := 1
		
			class f64 {
				static Precision := 64
				static Integer := "i64"
			}
			class f32 {
				static Precision := 32
				static Integer := "i32"
			}
		}
		class Pointer {
			static Weight := 2
		}
		class Custom {
			static Weight := 3
		}
	}
	
	__New() {
		this.Variables := {}
		
		this.TypeSet := Typing.TypeSet
		
		for TypeFamilyName, TypeFamily in this.TypeSet {
			Precisions := []
			
			for TypeName, Type in TypeFamily {
				if (TypeName = "__Class" || TypeName = "Weight") {
					Continue
				}
			
				Type.Family := TypeFamilyName
				Type.Name := TypeName
				Type.Weight := TypeFamily.Weight
				
				if !(IsObject(Precisions[Type.Precision])) {
					Precisions[Type.Precision] := []
				}
				
				Precisions[Type.Precision].Push(Type)
			}
			
			TypesInSizeOrder := []
			
			for k, Types in Precisions {
				for k, Type in Types {
					Type.Index := A_Index
					TypesInSizeOrder.Push(Type)
				}
			}
			
			TypeFamily.Types := TypesInSizeOrder
		}
	}
	
	GetPointerType(Type) {
		return {"Name": Type.Name "*", "Precision": 64, "Pointer": Type, "Family": "Pointer", "Weight": this.TypeSet.Pointer.Weight}
	}
	AddCustomType(Name, Info) {
		Info.Family := "Custom"
		Info.Name := Name
		Info.Weight := 3
		this.TypeSet.Custom[Name] := Info
	}
	
	GetType(TypeName) {
		if (InStr(TypeName, "*")) {
			TypeName := StrReplace(TypeName, "*", "", PointerDepth)
		}
		
		for k, TypeFamily in this.TypeSet {
			if (TypeFamily.HasKey(TypeName)) {
				FoundType := TypeFamily[TypeName]
			}
		}
		
		if !(FoundType) {
			Throw, Exception("Invalid Type: '" TypeName "'")
		}
		
		loop, % PointerDepth {
			FoundType := this.GetPointerType(FoundType)
		}
		
		return FoundType
	}

	ResultType(LeftType, RightType) {
		UsePrecision := False
		
		if (LeftType.Family = "Custom" || RightType.Family = "Custom") {
			Throw, Exception("No result type")
		}
		
		if (LeftType.Family = RightType.Family) {
			if !(LeftType.Family = "Pointer" && LeftType.Name != RightType.Name) {
				; If both types are pointers, but not pointers to the same thing, then there is no cast
			
				UsePrecision := True
			}
		}
		else if (LeftType.Pointer && RightType.Family = "Integer") {
			return LeftType ; If the left type is a pointer, and the right type is an int, then this is pointer math, and should work (and will return the pointer type)
		}
		else if (RightType.Pointer && LeftType.Family = "Integer") {
			return RightType ; Same as above, but with the operands switched
		}
		else if (LeftType.Family = "Decimal" && RightType.Family = "Integer") {
			UsePrecision := True
		}
		else if (LeftType.Family = "Integer" && RightType.Family = "Decimal") {
			UsePrecision := True
		}
		
		if (UsePrecision) {
			if (LeftType.Precision = RightType.Precision) {
				; If the two types are double/int64 or float/int32, then pick whichever one is the decimal
			
				if (LeftType.Weight > RightType.Weight) {
					return LeftType
				}
				else {
					return RightType
				}
			}
			else if (LeftType.Precision > RightType.Precision) {
				return LeftType ; Otherwise, if they are different precisions, just pick the most precise one
			}
			else {
				return RightType
			}
		}
		
		Throw, Exception("No result type")
	}
	
	GetVariableType(Name) {
		if !(this.Variables.HasKey(Name)) {
			Throw, Exception("Variable not found")
		}
		
		return this.Variables[Name]
	}
	
	AddVariable(Type, Name) {
		this.Variables[Name] := this.GetType(Type)
	}
	
	IsValidType(Name) {
		try {
			this.GetType(Name)
			return True
		}
		catch {
			return False
		}
	}
	
	CastPath(FromType, ToType, PathArray := False) {		
		FromFamily := this.TypeSet[FromType.Family]
		ToFamily := this.TypeSet[ToType.Family]
		
		if (FromType.Family = "Pointer" && ToType.Family = "Custom") {
			return []
		}
		else if (FromType.Family = "Custom" || ToType.Family = "Custom") {
			Throw, Exception("No cast possible")
		}
		
		if (PathArray) {
			Path := PathArray
		}
		else {
			Path := []
		}
		
		if (FromFamily.Weight = ToFamily.Weight) {			
			FoundFromType := False
			Last := FromType
			
			for k, Type in FromFamily.Types {
				if (Type.Name = FromType.Name) {
					FoundFromType := True
				}
				else if (FoundFromType) {
					Path.Push([Last, Type])
					Last := Type
				}
				
				if (Type.Name = ToType.Name) {
					Break
				}
			}
			
			if (Type.Name != ToType.Name) {
				Path.Push([Type, ToType])
			}
			
			return Path
		}
		else if (FromType[ToType.Family] = ToType.Name) {
			Path.Push([FromType, ToType])
			return Path
		}
		else if (FromType.Family = "Integer" && ToType.Family = "Pointer") {
			return this.CastPath(FromType, ToType.Pointer)
		}
		else if (FromType.Family != "Pointer" && ToType.Family != "Pointer") {
			IntegerBridgeType := this.GetType("i64")
			DoubleBridgeType := this.GetType("f64")
			
			if (FromType.Family = "Integer") {
				FirstBridge := IntegerBridgeType
				SecondBridge := DoubleBridgeType
			}
			else if (FromType.Family = "Decimal") {
				FirstBridge := DoubleBridgeType
				SecondBridge := IntegerBridgeType
			}
			
			ToBridge := this.CastPath(FromType, FirstBridge)
			BetweenBridge := this.CastPath(FirstBridge, SecondBridge, ToBridge)
			ToTarget := this.CastPath(SecondBridge, ToType, ToBridge)
			
			return ToBridge
		}
		
		Throw, Exception("No cast possible")
	}
}