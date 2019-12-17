class Typing {
	class TypeSet {
		class Integer {
			static Weight := 0
		
			class Int64 {
				static Precision := 64
				static Decimal := "Double"
			}
			class Int32 {
				static Precision := 32
				static Decimal := "Float"
			}
			class Int16 {
				static Precision := 16
			}
			class Int8 {
				static Precision := 8
			}
		}
		class Decimal {
			static Weight := 1
		
			class Double {
				static Precision := 64
				static Integer := "Int64"
			}
			class Float {
				static Precision := 32
				static Integer := "Int32"
			}
		}
		class Pointer {
			static Weight := 2
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
				Precisions[Type.Precision] := Type
			}
			
			TypesInSizeOrder := []
			
			for k, Type in Precisions {
				Type.Index := A_Index
				TypesInSizeOrder.Push(Type)
			}
			
			TypeFamily.Types := TypesInSizeOrder
		}
	}
	
	GetPointerType(Type) {
		return {"Name": Type.Name "*", "Precision": Type.Precision + 64, "Pointer": Type, "Family": "Pointer", "Weight": this.TypeSet.Pointer.Weight}
	}
	
	GetType(TypeName) {
		if (InStr(TypeName, "*")) {
			Pointer := True
			TypeName := StrReplace(TypeName, "*")
		}
		
		for k, TypeFamily in this.TypeSet {
			if (TypeFamily.HasKey(TypeName)) {
				FoundType := TypeFamily[TypeName]
			}
		}
		
		if !(FoundType) {
			Throw, Exception("Invalid Type")
		}
		else if (Pointer) {
			return this.GetPointerType(FoundType)
		}
		else {
			return FoundType
		}
	}

	ResultType(LeftType, RightType) {
		UsePrecision := False
	
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
			IntegerBridgeType := this.GetType("Int64")
			DoubleBridgeType := this.GetType("Double")
			
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

T := new Typing()
LT := T.GetType("Int8")
RT := T.GetType("Double")

RST := T.ResultType(LT, RT)
P := T.CastPath(LT, RT)