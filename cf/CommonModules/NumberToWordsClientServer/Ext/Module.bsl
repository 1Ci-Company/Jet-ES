
#Region Public

// devuelve el numero en palabras en espanol y se llama igual que numberinwords de la plataforma
// number es el numero que se va a convertir
// formatstring lleva las mismas claves de la plataforma separadas con punto y coma
// l es el idioma sn dice si va el nombre de la moneda fn si va el nombre de los decimales
// y fs si los decimales van en letras
// numerationitemparameters va separado con comas asi singular plural genero
// luego singular plural y genero de los decimales y al final la cantidad de decimales
// por ejemplo peso pesos m centavo centavos m 2 donde el genero es m o f
// tambien se puede sin genero como en ingles peso pesos centavo centavos 2
// si no viene l se toma espanol y si l es otro idioma se usa numberinwords de la plataforma
Function NumberToWords(Val Number, Val FormatString = "", Val NumerationItemParameters = "") Export
	
	FormatString = String(FormatString);
	NumerationItemParameters = String(NumerationItemParameters);
	
	Options = FormatOptions(FormatString);
	
	// otros idiomas los resuelve la plataforma
	If Not IsSpanish(Options.LanguageCode) Then
		Return NumberInWords(Number, FormatString, NumerationItemParameters);
	EndIf;
	
	Item = ItemOptions(NumerationItemParameters);
	
	// se redondea a los decimales pedidos como lo hace la plataforma
	Number = Round(Number, Item.Digits);
	IsNegative = (Number < 0);
	If IsNegative Then
		Number = -Number;
	EndIf;
	
	IntegerPart = Int(Number);
	FractionalPart = Round((Number - IntegerPart) * Multiplier(Item.Digits));
	
	Words = New Array;
	
	// parte entera y nombre de la moneda
	SubjectName = ?(IntegerPart = 1, Item.Singular, Item.Plural);
	ShowSubjectName = Options.SubjectName And Not IsBlankString(SubjectName);
	
	Words.Add(IntegerInWords(IntegerPart, Item.Feminine, ShowSubjectName));
	If ShowSubjectName Then
		If NeedsPreposition(IntegerPart) Then
			Words.Add("de");
		EndIf;
		Words.Add(SubjectName);
	EndIf;
	
	// parte decimal en numero o en letras
	// antes va con igual que el und que pone la plataforma en aleman
	If Item.Digits > 0 Then

		Words.Add("con");

		FractionName = ?(FractionalPart = 1, Item.FractionSingular, Item.FractionPlural);
		ShowFractionName = Options.FractionName And Not IsBlankString(FractionName);
	
		If Options.FractionInWords Then
			Words.Add(IntegerInWords(FractionalPart, Item.FractionFeminine, ShowFractionName));
			If ShowFractionName And NeedsPreposition(FractionalPart) Then
				Words.Add("de");
			EndIf;
		Else
			Words.Add(FractionDigits(FractionalPart, Item.Digits));
		EndIf;
	
		If ShowFractionName Then
			Words.Add(FractionName);
		EndIf;
	
	EndIf;
	
	Result = StrConcat(Words, " ");
	
	// la primera letra en mayuscula como en la plataforma
	Result = Upper(Left(Result, 1)) + Mid(Result, 2);
	
	// el negativo lleva el signo pegado adelante como en la plataforma
	If IsNegative Then
		Result = "-" + Result;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

// lee la cadena de formato con las claves en ingles o en ruso como la plataforma
Function FormatOptions(FormatString)
	
	Result = New Structure;
	Result.Insert("LanguageCode", "");
	Result.Insert("SubjectName", True);
	Result.Insert("FractionName", True);
	Result.Insert("FractionInWords", False);
	
	For Each Part In StrSplit(FormatString, ";", False) Do
	
		Position = StrFind(Part, "=");
		If Position = 0 Then
			Continue;
		EndIf;
	
		OptionName = Upper(TrimAll(Left(Part, Position - 1)));
		OptionValue = WithoutQuotes(TrimAll(Mid(Part, Position + 1)));
	
		If OptionName = "L" Or OptionName = "Л" Then
			Result.LanguageCode = OptionValue;
		ElsIf OptionName = "SN" Or OptionName = "НП" Then
			Result.SubjectName = BooleanValue(OptionValue, True);
		ElsIf OptionName = "FN" Or OptionName = "НД" Then
			Result.FractionName = BooleanValue(OptionValue, True);
		ElsIf OptionName = "FS" Or OptionName = "ДП" Then
			Result.FractionInWords = BooleanValue(OptionValue, False);
		EndIf;
	
	EndDo;
	
	// si no viene el idioma se toma espanol que es para lo que esta el modulo
	If IsBlankString(Result.LanguageCode) Then
		Result.LanguageCode = "es";
	EndIf;
	
	Return Result;
	
EndFunction

// lee los nombres de la moneda el genero y la cantidad de decimales
Function ItemOptions(NumerationItemParameters)
	
	Result = New Structure;
	Result.Insert("Singular", "");
	Result.Insert("Plural", "");
	Result.Insert("Feminine", False);
	Result.Insert("FractionSingular", "");
	Result.Insert("FractionPlural", "");
	Result.Insert("FractionFeminine", False);
	Result.Insert("Digits", 2);
	
	If IsBlankString(NumerationItemParameters) Then
		Return Result;
	EndIf;
	
	Parts = New Array;
	For Each Part In StrSplit(NumerationItemParameters, ",", True) Do
		Parts.Add(TrimAll(Part));
	EndDo;
	
	// con genero son siete datos y sin genero son cinco como en ingles
	WithGender = Parts.Count() >= 6 Or (Parts.Count() >= 3 And IsGender(Parts[2]));
	
	Result.Singular = PartValue(Parts, 0);
	Result.Plural = PartValue(Parts, 1);
	
	If WithGender Then
		Result.Feminine = (Upper(PartValue(Parts, 2)) = "F");
		Result.FractionSingular = PartValue(Parts, 3);
		Result.FractionPlural = PartValue(Parts, 4);
		Result.FractionFeminine = (Upper(PartValue(Parts, 5)) = "F");
		Digits = PartValue(Parts, 6);
	Else
		Result.FractionSingular = PartValue(Parts, 2);
		Result.FractionPlural = PartValue(Parts, 3);
		Digits = PartValue(Parts, 4);
	EndIf;
	
	If OnlyDigits(Digits) Then
		Result.Digits = Number(Digits);
	EndIf;
	
	Return Result;
	
EndFunction

// numero entero en palabras
// feminine es para el genero y beforenoun cuando despues va el nombre
Function IntegerInWords(Val Value, Feminine, BeforeNoun)
	
	If Value = 0 Then
		Return "cero";
	EndIf;
	
	// grupos de seis cifras para millones billones y lo que sigue
	Groups = New Array;
	While Value > 0 Do
		Groups.Add(Value % 1000000);
		Value = Int(Value / 1000000);
	EndDo;
	
	Singulars = StrSplit(",millón,billón,trillón,cuatrillón,quintillón,sextillón", ",");
	Plurals = StrSplit(",millones,billones,trillones,cuatrillones,quintillones,sextillones", ",");
	
	Words = New Array;
	GroupsCount = Groups.Count();
	
	For Counter = 1 To GroupsCount Do
	
		Index = GroupsCount - Counter;
		Group = Groups[Index];
		If Group = 0 Then
			Continue;
		EndIf;
	
		If Index = 0 Then
			Words.Add(BelowMillion(Group, Feminine, BeforeNoun));
		Else
			// millon y los que siguen son masculinos
			Words.Add(BelowMillion(Group, False, True));
			Words.Add(?(Group = 1, Singulars[Index], Plurals[Index]));
		EndIf;
	
	EndDo;
	
	Return StrConcat(Words, " ");
	
EndFunction

// numero de 1 a 999999
Function BelowMillion(Value, Feminine, BeforeNoun)
	
	Thousands = Int(Value / 1000);
	Rest = Value % 1000;
	
	Words = New Array;
	If Thousands = 1 Then
		Words.Add("mil");
	ElsIf Thousands > 1 Then
		Words.Add(BelowThousand(Thousands, Feminine, True));
		Words.Add("mil");
	EndIf;
	
	If Rest > 0 Then
		Words.Add(BelowThousand(Rest, Feminine, BeforeNoun));
	EndIf;
	
	Return StrConcat(Words, " ");
	
EndFunction

// numero de 1 a 999
Function BelowThousand(Value, Feminine, BeforeNoun)
	
	Hundreds = Int(Value / 100);
	Rest = Value % 100;
	
	Words = New Array;
	If Hundreds = 1 Then
		// cien solo cuando es exacto
		Words.Add(?(Rest = 0, "cien", "ciento"));
	ElsIf Hundreds > 1 Then
		Names = StrSplit(",,doscientos,trescientos,cuatrocientos,quinientos,seiscientos,"
			+ "setecientos,ochocientos,novecientos", ",");
		HundredsName = Names[Hundreds];
		If Feminine Then
			HundredsName = Left(HundredsName, StrLen(HundredsName) - 2) + "as";
		EndIf;
		Words.Add(HundredsName);
	EndIf;
	
	If Rest > 0 Then
		Words.Add(BelowHundred(Rest, Feminine, BeforeNoun));
	EndIf;
	
	Return StrConcat(Words, " ");
	
EndFunction

// numero de 1 a 99
Function BelowHundred(Value, Feminine, BeforeNoun)
	
	If Value = 1 Then
		Return OneInWords("", Feminine, BeforeNoun);
	ElsIf Value = 21 Then
		Return OneInWords("veinti", Feminine, BeforeNoun);
	ElsIf Value < 30 Then
		Units = StrSplit(",uno,dos,tres,cuatro,cinco,seis,siete,ocho,nueve,diez,once,doce,trece,catorce,quince,"
			+ "dieciséis,diecisiete,dieciocho,diecinueve,veinte,veintiuno,veintidós,veintitrés,veinticuatro,"
			+ "veinticinco,veintiséis,veintisiete,veintiocho,veintinueve", ",");
		Return Units[Value];
	EndIf;
	
	Tens = StrSplit(",,,treinta,cuarenta,cincuenta,sesenta,setenta,ochenta,noventa", ",");
	Result = Tens[Int(Value / 10)];
	
	If Value % 10 > 0 Then
		Result = Result + " y " + BelowHundred(Value % 10, Feminine, BeforeNoun);
	EndIf;
	
	Return Result;
	
EndFunction

// uno un o una segun el genero y si despues va el nombre
// prefix se usa para veintiuno
Function OneInWords(Prefix, Feminine, BeforeNoun)
	
	If Feminine Then
		Return Prefix + "una";
	ElsIf BeforeNoun Then
		Return ?(Prefix = "", "un", Prefix + "ún");
	EndIf;
	
	Return Prefix + "uno";
	
EndFunction

// va de antes del nombre cuando el numero termina en millon o mas sin nada despues
// por ejemplo un millon de pesos
Function NeedsPreposition(Value)
	
	Return Value >= 1000000 And Value % 1000000 = 0;
	
EndFunction

// decimales en numero con ceros a la izquierda
Function FractionDigits(Value, Digits)
	
	Result = Format(Value, "NZ=0; NG=0");
	While StrLen(Result) < Digits Do
		Result = "0" + Result;
	EndDo;
	
	Return Result;
	
EndFunction

// diez elevado a la cantidad de decimales
Function Multiplier(Digits)
	
	Result = 1;
	For Counter = 1 To Digits Do
		Result = Result * 10;
	EndDo;
	
	Return Result;
	
EndFunction

// quita las comillas simples o dobles del valor
Function WithoutQuotes(Value)
	
	If StrLen(Value) > 1 Then
		FirstChar = Left(Value, 1);
		If (FirstChar = """" Or FirstChar = "'") And Right(Value, 1) = FirstChar Then
			Return Mid(Value, 2, StrLen(Value) - 2);
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

// convierte el texto en booleano y si no lo reconoce deja el valor por defecto
Function BooleanValue(Val Value, DefaultValue)
	
	Value = Upper(Value);
	If Value = "TRUE" Or Value = "ИСТИНА" Or Value = "VERDADERO" Or Value = "1" Then
		Return True;
	ElsIf Value = "FALSE" Or Value = "ЛОЖЬ" Or Value = "FALSO" Or Value = "0" Then
		Return False;
	EndIf;
	
	Return DefaultValue;
	
EndFunction

// revisa si el idioma es espanol por ejemplo es o es co
Function IsSpanish(LanguageCode)
	
	Code = Lower(TrimAll(LanguageCode));
	Separator = Mid(Code, 3, 1);
	
	Return Left(Code, 2) = "es" And (StrLen(Code) = 2 Or Separator = "_" Or Separator = "-");
	
EndFunction

// revisa si el dato es un genero m f o n
Function IsGender(Value)
	
	Gender = Upper(Value);
	Return Gender = "M" Or Gender = "F" Or Gender = "N";
	
EndFunction

// devuelve el dato de la posicion o vacio si no viene
Function PartValue(Parts, Index)
	
	If Index < Parts.Count() Then
		Return Parts[Index];
	EndIf;
	
	Return "";
	
EndFunction

// revisa que el texto tenga solo digitos
Function OnlyDigits(Value)
	
	If Value = "" Then
		Return False;
	EndIf;
	
	For Position = 1 To StrLen(Value) Do
		If StrFind("0123456789", Mid(Value, Position, 1)) = 0 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

#EndRegion
