///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	ReportSettings.DefineFormSettings = True;

	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettings.LongDesc = NStr("en = 'Universal report on catalogs, documents, and registers.';es_CO = 'Informe universal sobre catálogos, documentos y registros.'");
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

Function ImportSettingsOnChangeParameters() Export 
	Parameters = New Array;
	Parameters.Add(New DataCompositionParameter("MetadataObjectType"));
	Parameters.Add(New DataCompositionParameter("MetadataObjectName"));
	Parameters.Add(New DataCompositionParameter("TableName"));
	
	Return Parameters;
EndFunction

// Returns values of special parameters of the Universal report.
//
// Parameters:
//  Settings - DataCompositionSettings
//  UserSettings - DataCompositionUserSettings
//  AvailableValues - Structure
//  Context - Arbitrary
//
// Returns:
//  Structure:
//    * Period - StandardPeriod
//    * MetadataObjectType - String
//    * MetadataObjectName - String
//    * TableName - String
//    * DataSource - CatalogRef.MetadataObjectIDs
// 
Function FixedParameters(Settings, UserSettings, AvailableValues, Context) Export 
	FixedParameters = New Structure("Period, DataSource, MetadataObjectType, MetadataObjectName, TableName, 
		| MetadataObjectTypeName, MetadataObjectTableName");
	AvailableValues = New Structure("MetadataObjectType, MetadataObjectName, TableName");
	
	SetFixedParameter("Period", FixedParameters, Settings, UserSettings);
	SetFixedParameter("DataSource", FixedParameters, Settings, UserSettings);
	
	AvailableValues.MetadataObjectType = AvailableMetadataObjectsTypes();
	SetFixedParameter(
		"MetadataObjectType",
		FixedParameters,
		Settings, UserSettings,
		AvailableValues.MetadataObjectType, Context);
		
	FixedParameters.MetadataObjectTypeName = FixedParameters.MetadataObjectType;
	
	AvailableValues.MetadataObjectName = AvailableMetadataObjects(
		FixedParameters.MetadataObjectType);
	SetFixedParameter(
		"MetadataObjectName",
		FixedParameters,
		Settings,
		UserSettings,
		AvailableValues.MetadataObjectName);
	
	AvailableValues.TableName = AvailableTables(
		FixedParameters.MetadataObjectType, FixedParameters.MetadataObjectName);
	SetFixedParameter(
		"TableName", FixedParameters, Settings, UserSettings, AvailableValues.TableName);
	
	FixedParameters.MetadataObjectTableName = FixedParameters.TableName;
	
	FixedParameters.DataSource = DataSource(
		FixedParameters.MetadataObjectType, FixedParameters.MetadataObjectName);
	
	IDs = StrSplit("MetadataObjectType, MetadataObjectName, TableName", ", ", False);
	DataParameters = Settings.DataParameters.Items;
	For Each Id In IDs Do 
		SettingItem = DataParameters.Find(Id);
		If SettingItem = Undefined
			Or SettingItem.Value = FixedParameters[Id] Then 
			Continue;
		EndIf;
		
		Settings.AdditionalProperties.Insert("ReportInitialized", False);
		Break;
	EndDo;
	
	Return FixedParameters;
EndFunction

Procedure SetFixedParameter(Id, Parameters, Settings, UserSettings, AvailableValues = Undefined, Context = Undefined)
	FixedParameter = Parameters[Id];
	
	If AvailableValues = Undefined Then 
		AvailableValues = New ValueList;
	EndIf;
	
	SettingItem = Settings.DataParameters.Items.Find(Id);
	If SettingItem = Undefined Then 
		If AvailableValues.Count() > 0 Then 
			Parameters[Id] = AvailableValues[0].Value;
		EndIf;
		Return;
	EndIf;
	
	UserSettingItem = Undefined;   
			
	If TypeOf(UserSettings) = Type("DataCompositionUserSettings")
		And (Settings.AdditionalProperties.Property("ReportInitialized")
		Or UserSettings.AdditionalProperties.Property("ReportInitialized")) Then 
		
		UserSettingItem = UserSettings.Items.Find(
		SettingItem.UserSettingID);
	EndIf;     
	
	If UserSettingItem <> Undefined
		And AvailableValues.FindByValue(UserSettingItem.Value) <> Undefined Then 
		FixedParameter = UserSettingItem.Value;
	ElsIf AvailableValues.FindByValue(SettingItem.Value) <> Undefined Then 
		FixedParameter = SettingItem.Value;
	ElsIf Id = "MetadataObjectName"
		And ValueIsFilled(Parameters.DataSource) Then 
		FixedParameter = Common.MetadataObjectByID(Parameters.DataSource).Name;
	ElsIf AvailableValues.Count() > 0 Then 
		FixedParameter = AvailableValues[0].Value;
	ElsIf UserSettingItem <> Undefined
		And ValueIsFilled(UserSettingItem.Value) Then 
		FixedParameter = UserSettingItem.Value;
	ElsIf ValueIsFilled(SettingItem.Value) Then 
		FixedParameter = SettingItem.Value;
	EndIf;
	
	If Id = "MetadataObjectType"
		And ValueIsFilled(Parameters.DataSource)
		And Parameters.DataSource.GetObject() <> Undefined Then 
		
		MetadataObject = DataSourceMetadata(Parameters.DataSource, Context);
		If MetadataObject <> Undefined Then
			MetadataObjectType = Common.BaseTypeNameByMetadataObject(MetadataObject);
			If MetadataObjectType <> FixedParameter Then 
				Parameters.DataSource = Undefined;
			EndIf;
		Else
			Parameters.DataSource = Undefined;
		EndIf;
	EndIf;
	
	Parameters[Id] = FixedParameter;
EndProcedure

// Sets values of special parameters of the Universal report.
//
// Parameters:
//  Report
//  FixedParameters - See FixedParameters
//  Settings - DataCompositionSettings
//  UserSettings - DataCompositionUserSettings
//
Procedure SetFixedParameters(Report, FixedParameters, Settings, UserSettings) Export 
	DataParameters = Settings.DataParameters;
	
	AvailableParameters = DataParameters.AvailableParameters;
	If AvailableParameters = Undefined Then 
		Return;
	EndIf;
	
	For Each Parameter In FixedParameters Do 
		If AvailableParameters.Items.Find(Parameter.Key) = Undefined Then 
			Continue;
		EndIf;
		
		SettingItem = DataParameters.Items.Find(Parameter.Key);
		If SettingItem = Undefined Then 
			SettingItem = DataParameters.Items.Add();
			SettingItem.Parameter = New DataCompositionParameter(Parameter.Key);
			SettingItem.Value = Parameter.Value;
			SettingItem.Use = True;
		Else
			DataParameters.SetParameterValue(Parameter.Key, Parameter.Value);
		EndIf;
		
		UserSettingItem = Undefined;
		If UserSettings <> Undefined Then 
			UserSettingItem = UserSettings.Items.Find(
				SettingItem.UserSettingID);
		EndIf;
		
		If UserSettingItem <> Undefined Then 
			FillPropertyValues(UserSettingItem, SettingItem, "Use, Value");
		EndIf;
	EndDo;
	
	If UserSettings <> Undefined Then 
		UserSettings.AdditionalProperties.Insert("ReportInitialized", True);
	EndIf;
EndProcedure

Function TextOfQueryByMetadata(ReportParameters)
	SourceMetadata = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
	
	SourceName = SourceMetadata.FullName();
	If ValueIsFilled(ReportParameters.TableName) Then 
		SourceName = SourceName + "." + ReportParameters.TableName;
	EndIf;
	
	FilterSource1 = "";
	If ReportParameters.TableName = "BalanceAndTurnovers" Then
		FilterSource1 = "({&BeginOfPeriod}, {&EndOfPeriod}, Auto, RegisterRecords)";
	ElsIf ReportParameters.TableName = "Turnovers" Then
		FilterSource1 = "({&BeginOfPeriod}, {&EndOfPeriod}, Auto)";
	ElsIf ReportParameters.TableName = "Balance"
		Or ReportParameters.TableName = "SliceLast" Then
		FilterSource1 = "({&EndOfPeriod},)";
	ElsIf ReportParameters.TableName = "SliceFirst" Then
		FilterSource1 = "({&BeginOfPeriod},)";
	ElsIf  ReportParameters.TableName = "RecordsWithExtDimensions" Then
		FilterSource1 = "({&BeginOfPeriod}, {&EndOfPeriod})";
	ElsIf ReportParameters.MetadataObjectType = "Documents" 
		Or ReportParameters.MetadataObjectType = "Tasks"
		Or ReportParameters.MetadataObjectType = "BusinessProcesses" Then
		
		If ValueIsFilled(ReportParameters.TableName)
			And CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "TabularSections")
			And CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata.TabularSections, ReportParameters.TableName) Then 
			FilterSource1 = "
				|{WHERE
				|	(Ref.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
		Else
			FilterSource1 = "
				|{WHERE
				|	(DATE BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
		EndIf;
	ElsIf ReportParameters.MetadataObjectType = "InformationRegisters"
		And SourceMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
		FilterSource1 = "
			|{WHERE
			|	(Period BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
	ElsIf ReportParameters.MetadataObjectType = "AccumulationRegisters"
		Or ReportParameters.MetadataObjectType = "AccountingRegisters" Then
		FilterSource1 = "
			|{WHERE
			|	(Period BETWEEN &BeginOfPeriod AND &EndOfPeriod)}";
	ElsIf ReportParameters.MetadataObjectType = "CalculationRegisters" Then
		FilterSource1 = "
			|{WHERE
			|	RegistrationPeriod BETWEEN &BeginOfPeriod AND &EndOfPeriod}";
	EndIf;
	
	QueryText =
	"SELECT ALLOWED
	|	*
	|FROM
	|	&SourceName AS Table";
	
	QueryText = StrReplace(QueryText, "AS Table", "");
	QueryText = StrReplace(QueryText, "&SourceName", SourceName);
	
	If ValueIsFilled(FilterSource1) Then 
		QueryText = QueryText + FilterSource1;
	EndIf;
	
	Return QueryText;
EndFunction

Function AvailableMetadataObjectsTypes()
	AvailableValues = New ValueList;
	
	If HasMetadataTypeObjects(Metadata.Catalogs) Then
		AvailableValues.Add("Catalogs", NStr("en = 'Catalog';es_CO = 'Catálogo'"), , PictureLib.Catalog);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.Documents) Then
		AvailableValues.Add("Documents", NStr("en = 'Document';es_CO = 'Documento'"), , PictureLib.Document);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.InformationRegisters) Then
		AvailableValues.Add("InformationRegisters", NStr("en = 'Information register';es_CO = 'Registro de información'"), , PictureLib.InformationRegister);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.AccumulationRegisters) Then
		AvailableValues.Add("AccumulationRegisters", NStr("en = 'Accumulation register';es_CO = 'Registro de acumulación'"), , PictureLib.AccumulationRegister);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.AccountingRegisters) Then
		AvailableValues.Add("AccountingRegisters", NStr("en = 'Accounting register';es_CO = 'Registro de contabilidad'"), , PictureLib.AccountingRegister);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.CalculationRegisters) Then
		AvailableValues.Add("CalculationRegisters", NStr("en = 'Calculation register';es_CO = 'Registro de cálculos'"), , PictureLib.CalculationRegister);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.ChartsOfCalculationTypes) Then
		AvailableValues.Add("ChartsOfCalculationTypes", NStr("en = 'Charts of calculation types';es_CO = 'Diagramas de los tipos de cálculos'"), , PictureLib.ChartOfCalculationTypes);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.Tasks) Then
		AvailableValues.Add("Tasks", NStr("en = 'Tasks';es_CO = 'Tareas'"), , PictureLib.Task);
	EndIf;
	
	If HasMetadataTypeObjects(Metadata.BusinessProcesses) Then
		AvailableValues.Add("BusinessProcesses", NStr("en = 'Business processes';es_CO = 'Procesos de negocio'"), , PictureLib.BusinessProcess);
	EndIf;
	
	Return AvailableValues;
EndFunction

Function AvailableMetadataObjects(MetadataObjectType)
	AvailableValues = New ValueList;
	
	If Not ValueIsFilled(MetadataObjectType) Then
		Return AvailableValues;
	EndIf;
	
	ValuesToDelete = New ValueList;
	For Each Object In Metadata[MetadataObjectType] Do
		If Not Common.MetadataObjectAvailableByFunctionalOptions(Object)
			Or Not AccessRight("Read", Object) Then
			Continue;
		EndIf;
		
		If StrStartsWith(Upper(Object.Name), "DELETE") Then 
			ValuesToDelete.Add(Object.Name, Object.Synonym);
		Else
			AvailableValues.Add(Object.Name, Object.Synonym);
		EndIf;
	EndDo;
	AvailableValues.SortByPresentation(SortDirection.Asc);
	ValuesToDelete.SortByPresentation(SortDirection.Asc);
	
	For Each RemovableObject In ValuesToDelete Do
		AvailableValues.Add(RemovableObject.Value, RemovableObject.Presentation);
	EndDo;
	
	Return AvailableValues;
EndFunction

Function AvailableTables(MetadataObjectType, MetadataObjectName)
	AvailableValues = New ValueList;
	
	If Not ValueIsFilled(MetadataObjectType)
		Or Not ValueIsFilled(MetadataObjectName) Then 
		Return AvailableValues;
	EndIf;
	
	MetadataObject = Metadata[MetadataObjectType][MetadataObjectName];
	
	AvailableValues.Add("", MainDataTableNamePresentation());
	
	If MetadataObjectType = "Catalogs" 
		Or MetadataObjectType = "Documents" 
		Or MetadataObjectType = "BusinessProcesses"
		Or MetadataObjectType = "Tasks" Then
		
		For Each TabularSection In MetadataObject.TabularSections Do
			AvailableValues.Add(TabularSection.Name, TabularSection.Synonym);
		EndDo;
	ElsIf MetadataObjectType = "InformationRegisters" Then 
		If MetadataObject.InformationRegisterPeriodicity
			<> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
			
			AvailableValues.Add("SliceLast", NStr("en = 'Last values slice';es_CO = 'Segmento de los últimos valores'"));
			AvailableValues.Add("SliceFirst", NStr("en = 'First values slice';es_CO = 'Segmento de primeros valores'"));
		EndIf;
	ElsIf MetadataObjectType = "AccumulationRegisters" Then
		If MetadataObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			AvailableValues.Add("BalanceAndTurnovers", NStr("en = 'Balances and turnovers';es_CO = 'Saldo y facturación'"));
			AvailableValues.Add("Balance", NStr("en = 'Balances';es_CO = 'Saldo'"));
			AvailableValues.Add("Turnovers", NStr("en = 'Turnovers';es_CO = 'Volumenes de negocio'"));
		Else
			AvailableValues.Add("Turnovers", NStr("en = 'Turnovers';es_CO = 'Volumenes de negocio'"));
		EndIf;
	ElsIf MetadataObjectType = "AccountingRegisters" Then
		AvailableValues.Add("BalanceAndTurnovers", NStr("en = 'Balances and turnovers';es_CO = 'Saldo y facturación'"));
		AvailableValues.Add("Balance", NStr("en = 'Balances';es_CO = 'Saldo'"));
		AvailableValues.Add("Turnovers", NStr("en = 'Turnovers';es_CO = 'Volumenes de negocio'"));
		If MetadataObject.Correspondence Then
			AvailableValues.Add("DrCrTurnovers", NStr("en = 'Dr/Cr turnovers';es_CO = 'Volumenes de negocio Dr/Cr'"));
		EndIf;
		AvailableValues.Add("RecordsWithExtDimensions", NStr("en = 'Records with extra dimensions';es_CO = 'Registros con las dimensiones adicionales'"));
	ElsIf MetadataObjectType = "CalculationRegisters" Then 
		If MetadataObject.ActionPeriod Then
			AvailableValues.Add("ScheduleData", NStr("en = 'Chart data';es_CO = 'Datos del gráfico'"));
			AvailableValues.Add("ActualActionPeriod", NStr("en = 'Actual validity period';es_CO = 'Periodo de acción actual'"));
		EndIf;
	ElsIf MetadataObjectType = "ChartsOfCalculationTypes" Then
		If MetadataObject.DependenceOnCalculationTypes
			<> Metadata.ObjectProperties.ChartOfCalculationTypesBaseUse.DontUse Then 
			
			AvailableValues.Add("BaseCalculationTypes", NStr("en = 'Baseline calculation types.';es_CO = 'Tipos de cálculo de línea base.'"));
		EndIf;
		
		AvailableValues.Add("LeadingCalculationTypes", NStr("en = 'Primary calculation types';es_CO = 'Tipos de cálculo principal'"));
		
		If MetadataObject.ActionPeriodUse Then 
			AvailableValues.Add("DisplacingCalculationTypes", NStr("en = 'Overriding calculation types';es_CO = 'Anular tipos de cálculo'"));
		EndIf;
	EndIf;
	
	Return AvailableValues;
EndFunction

Function HasMetadataTypeObjects(MetadataType)
	
	For Each Object In MetadataType Do
		If Common.MetadataObjectAvailableByFunctionalOptions(Object)
			And AccessRight("Read", Object) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Procedure AddTotals(ReportParameters, DataCompositionSchema)
	
	If ReportParameters.MetadataObjectType = "AccumulationRegisters" 
		Or ReportParameters.MetadataObjectType = "InformationRegisters" 
		Or ReportParameters.MetadataObjectType = "AccountingRegisters" 
		Or ReportParameters.MetadataObjectType = "CalculationRegisters" Then
		
		AddRegisterTotals(ReportParameters, DataCompositionSchema);
		
	ElsIf ReportParameters.MetadataObjectType = "Documents" 
		Or ReportParameters.MetadataObjectType = "Catalogs" 
		Or ReportParameters.MetadataObjectType = "BusinessProcesses"
		Or ReportParameters.MetadataObjectType = "Tasks" Then
		
		AddObjectTotals(ReportParameters, DataCompositionSchema);
	EndIf;
	
	AddSubordinateRecordsCountTotals(DataCompositionSchema);
	
EndProcedure

Procedure AddObjectTotals(Val ReportParameters, Val DataCompositionSchema)
	
	MetadataObject = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
	ObjectPresentation = MetadataObject.Presentation();
	
	ReferenceDetails = MetadataObject.StandardAttributes["Ref"];
	If ValueIsFilled(ReferenceDetails.Synonym) And ReferenceDetails.Synonym <> NStr("en = 'Reference';es_CO = 'Referencia'") Then // ACC:1391 - If the synonym of the "Ref" attribute differs from the standard "Ref", the column header displays the object presentation.
		ObjectPresentation = ReferenceDetails.Synonym;
	ElsIf ValueIsFilled(MetadataObject.ObjectPresentation) Then
		ObjectPresentation = Common.ObjectPresentation(MetadataObject);
	EndIf;
	
	AddDataSetField(DataCompositionSchema.DataSets[0], ReferenceDetails.Name, ObjectPresentation);
	
	If ReportParameters.TableName <> "" Then
		TabularSection = MetadataObject.TabularSections.Find(ReportParameters.TableName);
		If TabularSection <> Undefined Then 
			MetadataObject = TabularSection;
		EndIf;
	EndIf;
	
	// Add totals by numeric attributes
	For Each Attribute In MetadataObject.Attributes Do
		If Not Common.MetadataObjectAvailableByFunctionalOptions(Attribute) 
		   Or Attribute.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		
		AddDataSetField(DataCompositionSchema.DataSets[0], Attribute.Name, Attribute.Synonym);
		If Attribute.Type.ContainsType(Type("Number")) Then
			AddTotalField(DataCompositionSchema, Attribute.Name);
		EndIf;
	EndDo;

EndProcedure

Procedure AddRegisterTotals(Val ReportParameters, Val DataCompositionSchema)
	
	MetadataObject = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName]; 
	
	// Add dimensions.
	For Each Dimension In MetadataObject.Dimensions Do
		If Common.MetadataObjectAvailableByFunctionalOptions(Dimension) Then 
			SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Dimension.Name, Dimension.Synonym);
			SetField.Role.Dimension = True;
		EndIf;
	EndDo;
	
	// Add attributes.
	If IsBlankString(ReportParameters.TableName) Then
		For Each Attribute In MetadataObject.Attributes Do
			If Common.MetadataObjectAvailableByFunctionalOptions(Attribute) Then 
				AddDataSetField(DataCompositionSchema.DataSets[0], Attribute.Name, Attribute.Synonym);
			EndIf;
		EndDo;
	EndIf;
	
	ThereIsFieldLogger = False;
	If ReportParameters.TableName = "BalanceAndTurnovers" Then
		
		DataSetField = DataCompositionSchema.DataSets[0].Fields.Add(Type("DataCompositionSchemaDataSetField"));
		DataSetField.Field = "Recorder";
		DataSetField.Title = NStr("en = 'Recorder';es_CO = 'Registrador'");
		DataSetField.DataPath = "Recorder";
		DataSetField.Role.PeriodType = DataCompositionPeriodType.Main;
		DataSetField.Role.IgnoreNULLValues = True;
		
		Order_Period = DataSetField.OrderExpressions.Add();
		Order_Period.Expression = "TimeIntervals_.SecondPeriod";
		Order_Period.OrderType = DataCompositionSortDirection.Asc;
		
		OrderRegistrar = DataSetField.OrderExpressions.Add();
		OrderRegistrar.Expression = "Recorder";
		OrderRegistrar.OrderType = DataCompositionSortDirection.Asc;
		ThereIsFieldLogger = True;
	EndIf;
	
	// Add period fields.
	If ReportParameters.TableName = "BalanceAndTurnovers" 
		Or ReportParameters.TableName = "Turnovers" 
		Or ReportParameters.MetadataObjectType = "AccountingRegisters" And ReportParameters.TableName = "" Then
		AddPeriodFieldsInDataSet(DataCompositionSchema.DataSets[0], ThereIsFieldLogger);
	EndIf;
		
	// For accounting registers, setting up roles is important.
	If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
		
		AccountField = AddDataSetField(DataCompositionSchema.DataSets[0], "Account", NStr("en = 'Account';es_CO = 'Cuenta'"));
		AccountField.Role.AccountTypeExpression = "Account.Type";
		AccountField.Role.Account = True;
		
		ExtDimensionCount = 0;
		If MetadataObject.ChartOfAccounts <> Undefined Then 
			ExtDimensionCount = MetadataObject.ChartOfAccounts.MaxExtDimensionCount;
		EndIf;
		
		For ExtDimensionNumber = 1 To ExtDimensionCount Do
			ExtDimensionField = AddDataSetField(DataCompositionSchema.DataSets[0], "ExtDimension" + ExtDimensionNumber, NStr("en = 'Extra dimension';es_CO = 'Dimensión adicional'") + " " + ExtDimensionNumber);
			ExtDimensionField.Role.Dimension = True;
			ExtDimensionField.Role.IgnoreNULLValues = False;
		EndDo;
		
	EndIf;
	
	// Add resources.
	For Each Resource In MetadataObject.Resources Do
		If Not Common.MetadataObjectAvailableByFunctionalOptions(Resource) Then 
			Continue;
		EndIf;
		
		If ReportParameters.TableName = "Turnovers" Then
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Turnover", Resource.Synonym);
			AddTotalField(DataCompositionSchema, Resource.Name + "Turnover");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr turnover';es_CO = 'volumen de negocio Dr'"), Resource.Name + "TurnoverDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverDr");
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr turnover';es_CO = 'volumen de negocio de Cr'"), Resource.Name + "TurnoverCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverCr");
				
				If Not Resource.Balance Then
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalancedTurnover", Resource.Synonym + " " + NStr("en = 'corr. turnover';es_CO = 'volumen de negocio corresponsal'"), Resource.Name + "BalancedTurnover");
					AddTotalField(DataCompositionSchema, Resource.Name + "BalancedTurnover");
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalancedTurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr corr. turnover';es_CO = 'volumen de negocio corresponsal Dr'"), Resource.Name + "BalancedTurnoverDr");
					AddTotalField(DataCompositionSchema, Resource.Name + "BalancedTurnoverDr");
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalancedTurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr corr. turnover';es_CO = 'volumen de negocio corresponsal Cr'"), Resource.Name + "BalancedTurnoverCr");
					AddTotalField(DataCompositionSchema, Resource.Name + "BalancedTurnoverCr");
				EndIf;
			EndIf;
			
		ElsIf ReportParameters.TableName = "DrCrTurnovers" Then
			
			If Resource.Balance Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Turnover", Resource.Synonym);
				AddTotalField(DataCompositionSchema, Resource.Name + "Turnover");
			Else
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr turnover';es_CO = 'volumen de negocio Dr'"), Resource.Name + "TurnoverDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverDr");
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr turnover';es_CO = 'volumen de negocio de Cr'"), Resource.Name + "TurnoverCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverCr");
			EndIf;
			
		ElsIf ReportParameters.TableName = "RecordsWithExtDimensions" Then
			
			If Resource.Balance Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
				AddTotalField(DataCompositionSchema, Resource.Name);
			Else
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Dr", Resource.Synonym + " " + NStr("en = 'Dr';es_CO = 'Débito'"), Resource.Name + "Dr");
				AddTotalField(DataCompositionSchema, Resource.Name + "Dr");
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Cr", Resource.Synonym + " " + NStr("en = 'Cr';es_CO = 'Cr'"), Resource.Name + "Cr");
				AddTotalField(DataCompositionSchema, Resource.Name + "Cr");
			EndIf;
			
		ElsIf ReportParameters.TableName = "BalanceAndTurnovers" Then
			
			SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningBalance", Resource.Synonym + " " + NStr("en = 'open balance';es_CO = 'saldo inicial'"), Resource.Name + "OpeningBalance");
			AddTotalField(DataCompositionSchema, Resource.Name + "OpeningBalance");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				SetField.Role.AccountField = "Account";
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningBalanceDr", Resource.Synonym + " " + NStr("en = 'Dr open balance';es_CO = 'Dr saldo inicial'"), Resource.Name + "OpeningBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Debit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningBalanceCr", Resource.Synonym + " " + NStr("en = 'Cr open balance';es_CO = 'Cr saldo inicial'"), Resource.Name + "OpeningBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Credit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningBalanceCr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningSplittedBalanceDr", Resource.Synonym + " " + NStr("en = 'Dr open balance detailed';es_CO = 'Dr saldo inicial detallado'"), Resource.Name + "OpeningSplittedBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.BalanceGroup = "DetldBal" + Resource.Name + "Dr";
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningSplittedBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "OpeningSplittedBalanceCr", Resource.Synonym + " " + NStr("en = 'Cr open balance detailed';es_CO = 'Cr saldo inicial detallado'"), Resource.Name + "OpeningSplittedBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.BalanceGroup = "DetldBal" + Resource.Name + "Cr";
				AddTotalField(DataCompositionSchema, Resource.Name + "OpeningSplittedBalanceCr");
				
			ElsIf ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
				
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.OpeningBalance;
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;

			EndIf;
			
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Turnover", Resource.Synonym + " " + NStr("en = 'turnover';es_CO = 'volumen de negocio'"), Resource.Name + "Turnover");
			AddTotalField(DataCompositionSchema, Resource.Name + "Turnover");
			
			If ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Receipt", Resource.Synonym + " " + NStr("en = 'income';es_CO = 'Ingreso'"), Resource.Name + "Receipt");
				AddTotalField(DataCompositionSchema, Resource.Name + "Receipt");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Expense", Resource.Synonym + " " + NStr("en = 'expense';es_CO = 'gasto'"), Resource.Name + "Expense");
				AddTotalField(DataCompositionSchema, Resource.Name + "Expense");
			ElsIf ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr turnover';es_CO = 'volumen de negocio Dr'"), Resource.Name + "TurnoverDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverDr");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr turnover';es_CO = 'volumen de negocio de Cr'"), Resource.Name + "TurnoverCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "TurnoverCr");
			EndIf;
			
			SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingBalance", Resource.Synonym + " " + NStr("en = 'close balance';es_CO = 'saldo final'"), Resource.Name + "ClosingBalance");
			AddTotalField(DataCompositionSchema, Resource.Name + "ClosingBalance");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingBalanceDr", Resource.Synonym + " " + NStr("en = 'Dr close balance';es_CO = 'Dr saldo final'"), Resource.Name + "ClosingBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Debit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingBalanceCr", Resource.Synonym + " " + NStr("en = 'Cr close balance';es_CO = 'Cr saldo final'"), Resource.Name + "ClosingBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.Credit;
				SetField.Role.AccountField = "Account";
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingBalanceCr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingSplittedBalanceDr", Resource.Synonym + " " + NStr("en = 'Dr close balance detailed';es_CO = 'Dr saldo final detallado'"), Resource.Name + "ClosingSplittedBalanceDr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.BalanceGroup = "DetldBal" + Resource.Name + "Dr";
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingSplittedBalanceDr");
				
				SetField = AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "ClosingSplittedBalanceCr", Resource.Synonym + " " + NStr("en = 'Cr close balance detailed';es_CO = 'Cr saldo final detallado'"), Resource.Name + "ClosingSplittedBalanceCr");
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.AccountingBalanceType = DataCompositionAccountingBalanceType.None;
				SetField.Role.BalanceGroup = "DetldBal" + Resource.Name + "Cr";
				AddTotalField(DataCompositionSchema, Resource.Name + "ClosingSplittedBalanceCr");
				
			ElsIf ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
				SetField.Role.Balance = True;
				SetField.Role.BalanceType = DataCompositionBalanceType.ClosingBalance;
				SetField.Role.BalanceGroup = "Bal" + Resource.Name;
			EndIf;
			
		ElsIf ReportParameters.TableName = "Balance" Then
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Balance", Resource.Synonym + " " + NStr("en = 'balance';es_CO = 'saldo'"), Resource.Name + "Balance");
			AddTotalField(DataCompositionSchema, Resource.Name + "Balance");
			
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalanceDr", Resource.Synonym + " " + NStr("en = 'Dr balance';es_CO = 'saldo D'"), Resource.Name + "BalanceDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "BalanceDr");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "BalanceCr", Resource.Synonym + " " + NStr("en = 'Cr balance';es_CO = 'saldo Cr'"), Resource.Name + "BalanceCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "BalanceCr");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "SplittedBalanceDr", Resource.Synonym + " " + NStr("en = 'Dr balance detailed';es_CO = 'Dr saldo detallado'"), Resource.Name + "SplittedBalanceDr");
				AddTotalField(DataCompositionSchema, Resource.Name + "SplittedBalanceDr");
				
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "SplittedBalanceCr", Resource.Synonym + " " + NStr("en = 'Cr balance detailed';es_CO = 'Cr saldo detallado'"), Resource.Name + "SplittedBalanceCr");
				AddTotalField(DataCompositionSchema, Resource.Name + "SplittedBalanceCr");
			EndIf;
		ElsIf ReportParameters.MetadataObjectType = "InformationRegisters" Then
			AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
			If Resource.Type.ContainsType(Type("Number")) Then
				AddTotalField(DataCompositionSchema, Resource.Name);
			EndIf;
		ElsIf ReportParameters.TableName = "" Then
			If ReportParameters.MetadataObjectType = "AccountingRegisters" Then
				If Resource.Balance Then
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
					AddTotalField(DataCompositionSchema, Resource.Name);
				Else
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Dr", Resource.Synonym + " " + NStr("en = 'Dr';es_CO = 'Débito'"), Resource.Name + "Dr");
					AddTotalField(DataCompositionSchema, Resource.Name + "Dr");
					AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name + "Cr", Resource.Synonym + " " + NStr("en = 'Cr';es_CO = 'Cr'"), Resource.Name + "Cr");
					AddTotalField(DataCompositionSchema, Resource.Name + "Cr");
				EndIf;
			Else
				AddDataSetField(DataCompositionSchema.DataSets[0], Resource.Name, Resource.Synonym);
				AddTotalField(DataCompositionSchema, Resource.Name);
			EndIf;
		EndIf;
	EndDo;

EndProcedure

Procedure AddSubordinateRecordsCountTotals(DataCompositionSchema)
	
	FieldToEval = DataCompositionSchema.CalculatedFields.Add();
	FieldToEval.DataPath = "SubordinateRecordsCount";
	FieldToEval.Title = NStr("en = 'Number of records';es_CO = 'Número de registros'");
	FieldToEval.Expression = "1";
	FieldToEval.ValueType = New TypeDescription("Number");
	
	FieldAppearance = FieldToEval.Appearance.Items;
	ParametersIDs = StrSplit("MinimumWidth, MaximumWidth", ", ", False);
	
	For Each Id In ParametersIDs Do 
		Parameter = FieldAppearance.Find(Id);
		Parameter.Value = 12;
		Parameter.Use = True;
	EndDo;
	
	AddTotalField(DataCompositionSchema, "SubordinateRecordsCount");
	
EndProcedure

// Adds a period to data set fields.
// 
// Parameters:
//  DataSet - DataCompositionSchemaDataSetQuery
//  ThereIsFieldLogger - Boolean
//
// Returns:
//  ValueList
//
Function AddPeriodFieldsInDataSet(DataSet, ThereIsFieldLogger)
	
	PeriodsList = New ValueList;
	PeriodsList.Add("SecondPeriod",   NStr("en = 'Period second';es_CO = 'Periodo segundo'"));
	PeriodsList.Add("MinutePeriod",    NStr("en = 'Period minute';es_CO = 'Periodo minuto'"));
	PeriodsList.Add("HourPeriod",       NStr("en = 'Period hour';es_CO = 'Periodo hora'"));
	PeriodsList.Add("DayPeriod",      NStr("en = 'Period day';es_CO = 'Periodo día'"));
	PeriodsList.Add("WeekPeriod",    NStr("en = 'Period week';es_CO = 'Periodo Semana'"));
	PeriodsList.Add("TenDaysPeriod",    NStr("en = 'Period ten-day';es_CO = 'Período de diez días'"));
	PeriodsList.Add("MonthPeriod",     NStr("en = 'Period month';es_CO = 'Periodo mes'"));
	PeriodsList.Add("QuarterPeriod",   NStr("en = 'Period quarter';es_CO = 'Periodo Trimestre'"));
	PeriodsList.Add("HalfYearPeriod", NStr("en = 'Period half-year';es_CO = 'Periodo medio año'"));
	PeriodsList.Add("YearPeriod",       NStr("en = 'Period year';es_CO = 'Periodo Año'"));
	
	FolderName = "TimeIntervals_";
	DataSetFieldsList = New ValueList;
	DataSetFieldsFolder = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetFieldFolder"));
	DataSetFieldsFolder.Title   = NStr("en = 'Periods';es_CO = 'Períodos'");
	DataSetFieldsFolder.DataPath = FolderName;
	
	PeriodType = DataCompositionPeriodType.Main;
	
	For Each Period In PeriodsList Do
		DataSetField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
		DataSetField.Field        = Period.Value;
		DataSetField.Title   = Period.Presentation;
		DataSetField.DataPath = FolderName + "." + Period.Value;
		DataSetField.Role.PeriodType = PeriodType;
		DataSetField.Role.PeriodNumber = ?(ThereIsFieldLogger, PeriodsList.IndexOf(Period) + 2, PeriodsList.IndexOf(Period));
		DataSetFieldsList.Add(DataSetField);
		PeriodType = DataCompositionPeriodType.Additional;
		
		If Period.Value = "SecondPeriod" Then
			DataSetField.Role.PeriodType = DataCompositionPeriodType.Main;
			DataSetField.Role.IgnoreNULLValues = True;
		EndIf;
		
	EndDo;
	
	Return DataSetFieldsList;
	
EndFunction

// Add field to data set.
// 
// Parameters:
//  DataSet - DataCompositionSchemaDataSetQuery
//  Field - String
//  Title - String
//  DataPath - Undefined
//              - String
//
// Returns:
//  DataCompositionSchemaDataSetField
//
Function AddDataSetField(DataSet, Field, Title = "", DataPath = Undefined)
	
	If DataPath = Undefined Then
		DataPath = Field;
	EndIf;
	
	DataSetField = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	DataSetField.Field        = Field;
	DataSetField.Title   = Title;
	DataSetField.DataPath = DataPath;
	Return DataSetField;
	
EndFunction

// Add total field to data composition schema. If the Expression parameter is not specified, Sum(PathToData) is used.
Function AddTotalField(DataCompositionSchema, DataPath, Expression = Undefined)
	
	If Expression = Undefined Then
		Expression = "Sum(" + DataPath + ")";
	EndIf;
	
	TotalField = DataCompositionSchema.TotalFields.Add();
	TotalField.DataPath = DataPath;
	TotalField.Expression = Expression;
	
	Return TotalField;
	
EndFunction

// Adds total fields.
// 
// Parameters:
//  ReportParameters - See FixedParameters
//  DCSettings - DataCompositionSettings
//
Procedure AddIndicators(ReportParameters, DCSettings)
	
	If ReportParameters.TableName = "BalanceAndTurnovers" Then
		SelectedFieldsOpeningBalance = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
		SelectedFieldsOpeningBalance.Title = NStr("en = 'Open balance';es_CO = 'Saldo inicial'");
		SelectedFieldsOpeningBalance.Placement = DataCompositionFieldPlacement.Horizontally;
		If ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
			SelectedFieldsReceipt = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
			SelectedFieldsReceipt.Title = NStr("en = 'Income';es_CO = 'Ingreso'");
			SelectedFieldsReceipt.Placement = DataCompositionFieldPlacement.Horizontally;
			SelectedFieldsExpense = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
			SelectedFieldsExpense.Title = NStr("en = 'Expense';es_CO = 'Gastos'");
			SelectedFieldsExpense.Placement = DataCompositionFieldPlacement.Horizontally;
		ElsIf ReportParameters.MetadataObjectType = "AccountingRegisters" Then
			SelectedFieldsTurnovers = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
			SelectedFieldsTurnovers.Title = NStr("en = 'Turnovers';es_CO = 'Volumenes de negocio'");
			SelectedFieldsTurnovers.Placement = DataCompositionFieldPlacement.Horizontally;
		EndIf;
		SelectedFieldsClosingBalance = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedFieldGroup"));
		SelectedFieldsClosingBalance.Title = NStr("en = 'Close balance';es_CO = 'Saldo final'");
		SelectedFieldsClosingBalance.Placement = DataCompositionFieldPlacement.Horizontally;
	EndIf;
	
	MetadataObject = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName]; // MetadataObjectInformationRegister, MetadataObjectAccumulationRegister
	If ReportParameters.MetadataObjectType = "AccumulationRegisters" Then
		For Each Dimension In MetadataObject.Dimensions Do
			If Not Common.MetadataObjectAvailableByFunctionalOptions(Dimension) Then 
				Continue;
			EndIf;
			
			SelectedFields = DCSettings.Selection;
			ReportsServer.AddSelectedField(SelectedFields, Dimension.Name);
		EndDo;
		For Each Resource In MetadataObject.Resources Do
			If Not Common.MetadataObjectAvailableByFunctionalOptions(Resource) Then 
				Continue;
			EndIf;
			
			SelectedFields = DCSettings.Selection;
			If ReportParameters.TableName = "Turnovers" Then
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "Turnover", Resource.Synonym);
			ElsIf ReportParameters.TableName = "Balance" Then
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "Balance", Resource.Synonym);
			ElsIf ReportParameters.TableName = "BalanceAndTurnovers" Then
				ReportsServer.AddSelectedField(SelectedFieldsOpeningBalance, Resource.Name + "OpeningBalance", Resource.Synonym);
				ReportsServer.AddSelectedField(SelectedFieldsReceipt, Resource.Name + "Receipt", Resource.Synonym);
				ReportsServer.AddSelectedField(SelectedFieldsExpense, Resource.Name + "Expense", Resource.Synonym);
				ReportsServer.AddSelectedField(SelectedFieldsClosingBalance, Resource.Name + "ClosingBalance", Resource.Synonym);
			ElsIf ReportParameters.TableName = "" Then
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name);
			EndIf;
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "InformationRegisters" Or ReportParameters.MetadataObjectType = "CalculationRegisters" Then
		For Each Dimension In MetadataObject.Dimensions Do
			If Not Common.MetadataObjectAvailableByFunctionalOptions(Dimension) Then
				Continue;
			EndIf;
			
			SelectedFields = DCSettings.Selection;
			ReportsServer.AddSelectedField(SelectedFields, Dimension.Name);
		EndDo;
		For Each Resource In MetadataObject.Resources Do
			If Not Common.MetadataObjectAvailableByFunctionalOptions(Resource) 
			   Or Resource.Type.ContainsType(Type("ValueStorage")) Then 
				Continue;
			EndIf;
			
			SelectedFields = DCSettings.Selection;
			ReportsServer.AddSelectedField(SelectedFields, Resource.Name);
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "AccountingRegisters" Then
		For Each Resource In MetadataObject.Resources Do
			If Not Common.MetadataObjectAvailableByFunctionalOptions(Resource) Then 
				Continue;
			EndIf;
			
			SelectedFields = DCSettings.Selection;
			If ReportParameters.TableName = "Turnovers" Then
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr turnover';es_CO = 'volumen de negocio Dr'"));
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr turnover';es_CO = 'volumen de negocio Cr'"));
			ElsIf ReportParameters.TableName = "DrCrTurnovers" Then
				If Resource.Balance Then
					ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "Turnover", Resource.Synonym + " " + NStr("en = 'turnover';es_CO = 'volumen de negocio'"));
				Else
					ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr turnover';es_CO = 'volumen de negocio Dr'"));
					ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr turnover';es_CO = 'volumen de negocio Cr'"));
				EndIf;
			ElsIf ReportParameters.TableName = "Balance" Then
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "BalanceDr", Resource.Synonym + " " + NStr("en = 'Dr balance';es_CO = 'Dr saldo'"));
				ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "BalanceCr", Resource.Synonym + " " + NStr("en = 'Cr balance';es_CO = 'Cr saldo'"));
			ElsIf ReportParameters.TableName = "BalanceAndTurnovers" Then
				ReportsServer.AddSelectedField(SelectedFieldsOpeningBalance, Resource.Name + "OpeningBalanceDr", Resource.Synonym + " " + NStr("en = 'Dr open balance';es_CO = 'Dr saldo inicial'"));
				ReportsServer.AddSelectedField(SelectedFieldsOpeningBalance, Resource.Name + "OpeningBalanceCr", Resource.Synonym + " " + NStr("en = 'Cr open balance';es_CO = 'Cr saldo inicial'"));
				ReportsServer.AddSelectedField(SelectedFieldsTurnovers, Resource.Name + "TurnoverDr", Resource.Synonym + " " + NStr("en = 'Dr turnover';es_CO = 'volumen de negocio Dr'"));
				ReportsServer.AddSelectedField(SelectedFieldsTurnovers, Resource.Name + "TurnoverCr", Resource.Synonym + " " + NStr("en = 'Cr turnover';es_CO = 'volumen de negocio Cr'"));
				ReportsServer.AddSelectedField(SelectedFieldsClosingBalance, Resource.Name + "ClosingBalanceDr", " " + Resource.Synonym + NStr("en = 'Dr close balance';es_CO = 'Dr saldo final'"));
				ReportsServer.AddSelectedField(SelectedFieldsClosingBalance, Resource.Name + "ClosingBalanceCr", " " + Resource.Synonym + NStr("en = 'Cr close balance';es_CO = 'Cr saldo final'"));
			ElsIf ReportParameters.TableName = "RecordsWithExtDimensions" Or ReportParameters.TableName = "" Then
				If Resource.Balance Then
					ReportsServer.AddSelectedField(SelectedFields, Resource.Name, Resource.Synonym);
				Else
					ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "Dr", Resource.Synonym + " " + NStr("en = 'Dr';es_CO = 'Débito'"));
					ReportsServer.AddSelectedField(SelectedFields, Resource.Name + "Cr", Resource.Synonym + " " + NStr("en = 'Cr';es_CO = 'Cr'"));
				EndIf;
			EndIf;
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "Documents" 
		Or ReportParameters.MetadataObjectType = "Tasks"
		Or ReportParameters.MetadataObjectType = "BusinessProcesses"
		Or ReportParameters.MetadataObjectType = "Catalogs" Then
		If ReportParameters.TableName <> "" Then
			MetadataObject = MetadataObject.TabularSections[ReportParameters.TableName];
		EndIf;
		SelectedFields = DCSettings.Selection;
		ReportsServer.AddSelectedField(SelectedFields, "Ref");
		For Each Attribute In MetadataObject.Attributes Do
			If Attribute.Type.ContainsType(Type("ValueStorage")) Then
				Continue;
			EndIf;
			If Common.MetadataObjectAvailableByFunctionalOptions(Attribute) Then 
				ReportsServer.AddSelectedField(SelectedFields, Attribute.Name);
			EndIf;
		EndDo;
	ElsIf ReportParameters.MetadataObjectType = "ChartsOfCalculationTypes" Then
		If ReportParameters.TableName = "" Then
			For Each Attribute In MetadataObject.Attributes Do
				If Not Common.MetadataObjectAvailableByFunctionalOptions(Attribute) 
				   Or Attribute.Type.ContainsType(Type("ValueStorage")) Then 
					Continue;
				EndIf;
				
				SelectedFields = DCSettings.Selection;
				ReportsServer.AddSelectedField(SelectedFields, Attribute.Name);
			EndDo;
		Else
			For Each Attribute In MetadataObject.StandardAttributes Do
				SelectedFields = DCSettings.Selection;
				ReportsServer.AddSelectedField(SelectedFields, Attribute.Name);
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

// Generates the structure of data composition settings
//
// Parameters:
//  ReportParameters - Structure - Description of a metadata object that is a data source
//  Schema - DataCompositionSchema - Main schema of the report data composition.
//  Settings - DataCompositionSettings - Settings whose structure is being generated.
//
Procedure GenerateStructure(ReportParameters, Schema, Settings)
	Settings.Structure.Clear();
	
	Structure = Settings.Structure.Add(Type("DataCompositionGroup"));
	
	FieldsTypes = StrSplit("Dimensions@Resources", "@", False);
	
	SourcesFieldsTypes = New Map();
	SourcesFieldsTypes.Insert("InformationRegisters", FieldsTypes);
	SourcesFieldsTypes.Insert("AccumulationRegisters", FieldsTypes);
	SourcesFieldsTypes.Insert("AccountingRegisters", FieldsTypes);
	SourcesFieldsTypes.Insert("CalculationRegisters", FieldsTypes);
	
	SourceFieldsTypes = SourcesFieldsTypes[ReportParameters.MetadataObjectType];
	If SourceFieldsTypes <> Undefined Then 
		SpecifyFieldsSuffixes = ReportParameters.MetadataObjectType = "AccountingRegisters"
			And (ReportParameters.TableName = ""
				Or ReportParameters.TableName = "DrCrTurnovers"
				Or ReportParameters.TableName = "RecordsWithExtDimensions");
		
		For Each SourceFieldsType In SourceFieldsTypes Do 
			GroupFields = Structure.GroupFields.Items;
			
			SourceMetadata = Metadata[ReportParameters.MetadataObjectType][ReportParameters.MetadataObjectName];
			For Each FieldMetadata In SourceMetadata[SourceFieldsType] Do
				If Not Common.MetadataObjectAvailableByFunctionalOptions(FieldMetadata) Then 
					Continue;
				EndIf;
				
				If ReportParameters.MetadataObjectType = "AccountingRegisters"
					And FieldMetadata.AccountingFlag <> Undefined Then 
					Continue;
				EndIf;
				
				If SourceFieldsType = "Resources"
					And FieldMetadata.Type.ContainsType(Type("Number")) Then 
					Continue;
				EndIf;
				
				If FieldMetadata.Type.ContainsType(Type("ValueStorage")) Then 
					Continue;
				EndIf;
				
				If SpecifyFieldsSuffixes Then
					If FieldMetadata.Balance Or (ReportParameters.MetadataObjectType = "AccountingRegisters"
						And Not SourceMetadata.Correspondence) Then
						FieldsSuffixes = StrSplit("", "@");
					Else
						FieldsSuffixes = StrSplit("Dr@Cr", "@", False);
					EndIf;
				Else
					FieldsSuffixes = StrSplit("", "@");
				EndIf;
				
				For Each Suffix In FieldsSuffixes Do 
					GroupingField = GroupFields.Add(Type("DataCompositionGroupField"));
					GroupingField.Field = New DataCompositionField(FieldMetadata.Name + Suffix);
					GroupingField.Use = True;
				EndDo;
			EndDo;
		EndDo;
	EndIf;
	
	Structure.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	Structure.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with a standard schema set in user settings.

Function DataCompositionSchema(FixedParameters) Export 
	DataCompositionSchema = GetTemplate("MainDataCompositionSchema");
	DataCompositionSchema.TotalFields.Clear();
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	DataSet.Query = TextOfQueryByMetadata(FixedParameters);
	DataSet.AutoFillAvailableFields = True;
	
	AddTotals(FixedParameters, DataCompositionSchema);
	
	If FixedParameters.MetadataObjectType = "Catalogs"
		Or FixedParameters.MetadataObjectType = "ChartsOfCalculationTypes" 
		Or (FixedParameters.MetadataObjectType = "InformationRegisters"
			And Metadata[FixedParameters.MetadataObjectType][FixedParameters.MetadataObjectName].InformationRegisterPeriodicity 
			= Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical) Then
		DataCompositionSchema.Parameters.Period.UseRestriction = True;
	EndIf;
	
	AvailableTables = AvailableTables(FixedParameters.MetadataObjectType, FixedParameters.MetadataObjectName);
	If AvailableTables.Count() < 2 Then
		DataCompositionSchema.Parameters.TableName.UseRestriction = True;
	EndIf;
	
	Return DataCompositionSchema;
EndFunction

// Sets the default settings.
//
// Parameters:
//  Report - ReportObject
//  FixedParameters - See FixedParameters
//  Settings - DataCompositionSettings
//  UserSettings - DataCompositionUserSettings
//
Procedure CustomizeStandardSettings(Report, FixedParameters, Settings, UserSettings) Export 
	ReportInitialized = CommonClientServer.StructureProperty(
		Settings.AdditionalProperties, "ReportInitialized", False);    
		
	If ReportInitialized Then 
		Return;
	EndIf;
	
	FixedParameterDisplayModes = FixedParameterDisplayModes(Settings);
	
	Report.SettingsComposer.LoadSettings(Report.DataCompositionSchema.DefaultSettings);
	
	Settings = Report.SettingsComposer.Settings;
	Settings.Selection.Items.Clear();
	Settings.Structure.Clear();
	
	SetTheDisplayModesOfFixedParameters(Settings, FixedParameterDisplayModes);
	
	AddIndicators(FixedParameters, Settings);
	GenerateStructure(FixedParameters, Report.DataCompositionSchema, Settings);
	
	SetFixedParameters(Report, FixedParameters, Settings, UserSettings);
	
	Settings.AdditionalProperties.Insert("ReportInitialized", True);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with arbitrary schema from a file.

// Returns the data composition schema being imported.
//
// Parameters:
//  ImportedSchema - BinaryData
//
// Returns:
//  DataCompositionSchema
//
Function ExtractSchemaFromBinaryData(ImportedSchema) Export
	
	FullFileName = GetTempFileName();
	ImportedSchema.Write(FullFileName);
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FullFileName);
	
	DCSchema = XDTOSerializer.ReadXML(XMLReader, Type("DataCompositionSchema"));
	
	XMLReader.Close();
	XMLReader = Undefined;
	
	DeleteFiles(FullFileName);
	
	If DCSchema.DefaultSettings.AdditionalProperties.Property("DataCompositionSchema") Then
		DCSchema.DefaultSettings.AdditionalProperties.DataCompositionSchema = Undefined;
	EndIf;
	
	Return DCSchema;
	
EndFunction

Procedure SetStandardImportedSchemaSettings(Report, SchemaBinaryData, Settings, UserSettings) Export 
	If CommonClientServer.StructureProperty(Settings.AdditionalProperties, "ReportInitialized", False) Then 
		Return;
	EndIf;
	
	Settings = Report.DataCompositionSchema.DefaultSettings;
	Settings.AdditionalProperties.Insert("DataCompositionSchema", SchemaBinaryData);
	Settings.AdditionalProperties.Insert("ReportInitialized",  True);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with the data source of a report option.

// Returns the report option settings with the set DataSource parameter.
//
// Parameters:
//  Variant - CatalogObject.ReportsOptions - Report option settings storage.
//
// Returns:
//   DataCompositionSettings, Undefined - Updated settings. If the update failed, Undefined.
//                                            
//
Function OptionSettings(Variant) Export
	Try
		OptionSettings = Variant.Settings.Get(); // DataCompositionSettings
	Except
		// Couldn't deserialize the value storage:
		//  Perhaps, a reference to a non-existent type is found.
		Return Undefined;
	EndTry;
	
	If OptionSettings = Undefined Then 
		Return Undefined;
	EndIf;
	
	DataParameters = OptionSettings.DataParameters.Items;
	
	ParametersRequired = New Structure(
		"MetadataObjectType, FullMetadataObjectName, MetadataObjectName, DataSource");
	For Each Parameter In ParametersRequired Do 
		FoundParameter = DataParameters.Find(Parameter.Key);
		If FoundParameter <> Undefined Then 
			ParametersRequired[Parameter.Key] = FoundParameter.Value;
		EndIf;
	EndDo;
	
	// If option settings contain a parameter with a non-relevant name, the name will be updated.
	If ValueIsFilled(ParametersRequired.FullMetadataObjectName) Then 
		ParametersRequired.MetadataObjectName = ParametersRequired.FullMetadataObjectName;
	EndIf;
	ParametersRequired.Delete("FullMetadataObjectName");
	
	If Not ValueIsFilled(ParametersRequired.DataSource) Then 
		ParametersRequired.DataSource = DataSource(
			ParametersRequired.MetadataObjectType, ParametersRequired.MetadataObjectName);
		If ParametersRequired.DataSource = Undefined Then 
			Return Undefined;
		EndIf;
	EndIf;
	
	ParametersToSet = New Structure("DataSource, MetadataObjectName");
	FillPropertyValues(ParametersToSet, ParametersRequired);
	
	ObjectName = Common.ObjectAttributeValue(ParametersRequired.DataSource, "Name");
	If ObjectName <> ParametersToSet.MetadataObjectName Then 
		ParametersToSet.MetadataObjectName = ObjectName;
	EndIf;
	
	For Each Parameter In ParametersToSet Do 
		FoundParameter = DataParameters.Find(Parameter.Key);
		If FoundParameter = Undefined Then 
			DataParameter = DataParameters.Add();
			DataParameter.Parameter = New DataCompositionParameter(Parameter.Key);
			DataParameter.Value = Parameter.Value;
			DataParameter.Use = True;
		Else
			OptionSettings.DataParameters.SetParameterValue(Parameter.Key, Parameter.Value);
		EndIf;
	EndDo;
	
	Return OptionSettings;
EndFunction

// Returns report data source
//
// Parameters:
//  ManagerType - String - Metadata object manager presentation.
//                 For example, "Catalogs" or "InformationRegisters".
//  ObjectName  - String - Short name of the metadata object.
//                For example, "Currencies" or "ExchangeRates".
//
// Returns:
//   - CatalogRef.MetadataObjectIDs - Reference to the found catalog item.
//   - Undefined
//
Function DataSource(ManagerType, ObjectName)
	ObjectType = ObjectTypeByManagerType(ManagerType);
	FullObjectName = ObjectType + "." + ObjectName;
	If Common.MetadataObjectByFullName(FullObjectName) = Undefined Then 
		WriteLogEvent(NStr("en = 'Report options. Configure universal report data source';es_CO = 'Opciones de informe. Configurar fuente de datos de informe universal'", 
			Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.ReportsOptions,,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot find data source for %1';es_CO = 'No se puede encontrar la fuente de datos para %1'"), 
				FullObjectName));
		Return Undefined;
	EndIf;
	
	Return Common.MetadataObjectID(FullObjectName);
EndFunction

Function DataSourceMetadata(DataSource, Context)
	
	Try
		MetadataObject = Common.MetadataObjectByID(DataSource);
	Except
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot generate the report due to: %1%2';es_CO = 'No se puede generar el informe debido a: %1%2'"),
			ErrorProcessing.BriefErrorDescription(ErrorInfo()),
			NStr("en = 'Select another catalog or document.';es_CO = 'Seleccione otro catálogo o documento.'"));
		WriteLogEvent(NStr("en = 'Generate a universal report option';es_CO = 'Generar una opción del informe universal'", Common.DefaultLanguageCode()),
			EventLogLevel.Warning, Metadata.Reports.UniversalReport,, MessageText);
		If TypeOf(Context) = Type("ClientApplicationForm") Then
			RecommendationText = NStr("en = 'Cannot generate the report. Select another catalog or document.';es_CO = 'No se puede generar el informe. Seleccione otro catálogo o documento.'");
			ReportsClientServer.DisplayReportState(
				Context, RecommendationText);
			Common.MessageToUser(MessageText);
		Else
			Common.MessageToUser(MessageText);
		EndIf;
		Return Undefined;
	EndTry;
	
	Return MetadataObject;
	
EndFunction

// Returns the type of metadata object by the matching manager type
//
// Parameters:
//  ManagerType - String - Metadata object manager presentation.
//                 For example, "Catalogs" or "InformationRegisters".
//
// Returns:
//   String - Metadata object type. For example, "Catalog" or "InformationRegister".
//
Function ObjectTypeByManagerType(ManagerType)
	Types = New Map;
	Types.Insert("Catalogs", "Catalog");
	Types.Insert("Documents", "Document");
	Types.Insert("DataProcessors", "DataProcessor");
	Types.Insert("ChartsOfCharacteristicTypes", "ChartOfCharacteristicTypes");
	Types.Insert("AccountingRegisters", "AccountingRegister");
	Types.Insert("AccumulationRegisters", "AccumulationRegister");
	Types.Insert("CalculationRegisters", "CalculationRegister");
	Types.Insert("InformationRegisters", "InformationRegister");
	Types.Insert("BusinessProcesses", "BusinessProcess");
	Types.Insert("DocumentJournals", "DocumentJournal");
	Types.Insert("Tasks", "Task");
	Types.Insert("Reports", "Report");
	Types.Insert("Constants", "Constant");
	Types.Insert("Enums", "Enum");
	Types.Insert("ChartsOfCalculationTypes", "ChartOfCalculationTypes");
	Types.Insert("ExchangePlans", "ExchangePlan");
	Types.Insert("ChartsOfAccounts", "ChartOfAccounts");
	
	Return ?(Types[ManagerType] = Undefined, "", Types[ManagerType]);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Default title.

// Parameters:
//  Context - ClientApplicationForm
//           - Structure
//  Settings - DataCompositionSettings
//  FixedParameters - Structure
//  AvailableValues - ValueList
//
Procedure SetStandardReportHeader(Context, Settings, FixedParameters, AvailableValues) Export 
	
	If Not SettingTheStandardReportTitleIsAvailable(Context) Then 
		Return;
	EndIf;
	
	ParameterValues = StandardHeaderParametersValues(Context, FixedParameters, AvailableValues);
	
	PeriodPresentation = ReportPeriodView(ParameterValues.Period);
	
	If ParameterValues.MetadataObjectType = Undefined
		And ParameterValues.MetadataObjectName = Undefined
		And ParameterValues.TableName = Undefined Then 
		
		Title = Metadata.Reports.UniversalReport.Presentation();
		
	ElsIf ParameterValues.TableName = Undefined
		And Not ValueIsFilled(PeriodPresentation) Then 
		
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Universal report: %1 ""%2""';es_CO = 'Informe universal: %1 ""%2""'"),
			ParameterValues.MetadataObjectType,
			ParameterValues.MetadataObjectName);
		
	ElsIf ParameterValues.TableName <> Undefined
		And Not ValueIsFilled(PeriodPresentation) Then 
		
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Universal report: %1 ""%2"" - table ""%3""';es_CO = 'Informe universal: %1 ""%2"" - tabla ""%3""'"),
			ParameterValues.MetadataObjectType,
			ParameterValues.MetadataObjectName,
			ParameterValues.TableName);
		
	ElsIf ParameterValues.TableName = Undefined
		And ValueIsFilled(PeriodPresentation) Then 
		
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Universal report: %1 ""%2"" for %3';es_CO = 'Informe universal: %1 ""%2"" para %3'"),
			ParameterValues.MetadataObjectType,
			ParameterValues.MetadataObjectName,
			PeriodPresentation);
	Else
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Universal report: %1 ""%2"" - table ""%3"" for %4';es_CO = 'Informe universal: %1 ""%2"" - tabla ""%3"" para %4'"),
			ParameterValues.MetadataObjectType,
			ParameterValues.MetadataObjectName,
			ParameterValues.TableName,
			PeriodPresentation);
	EndIf;
	
	TitleSetInteractively = CommonClientServer.StructureProperty(
		Settings.AdditionalProperties, "TitleSetInteractively", False);
	
	If Not TitleSetInteractively Then 
		HeaderParameter = Settings.OutputParameters.Items.Find("Title");
		HeaderParameter.Value = Title;
	EndIf;
	
	If TypeOf(Context) = Type("ClientApplicationForm")
		And Context.ReportFormType = ReportFormType.Main Then 
		
		Context.Title = Title;
		Context.ReportCurrentOptionDescription = Title;
	EndIf;
	
EndProcedure

Function SettingTheStandardReportTitleIsAvailable(Context)
	
	If TypeOf(Context) = Type("ClientApplicationForm") Then 
		ReportVariant = Context.ReportSettings.OptionRef;
	Else
		ReportVariant = Context.OptionRef1;
	EndIf;
	
	Return ReportsOptions.IsPredefinedReportOption(ReportVariant);
	
EndFunction

Function StandardHeaderParametersValues(Context, FixedParameters, AvailableValues)
	
	ParameterValues = New Structure("MetadataObjectType, MetadataObjectName, TableName, Period");
	
	If TypeOf(Context) = Type("ClientApplicationForm") Then 
		SchemaURL = CommonClientServer.StructureProperty(Context.ReportSettings, "SchemaURL");
	Else
		SchemaURL = CommonClientServer.StructureProperty(Context, "SchemaURL");
	EndIf;
	
	Schema = GetFromTempStorage(SchemaURL); // DataCompositionSchema
	
	For Each Item In ParameterValues Do 
		
		FoundParameter = Schema.Parameters.Find(Item.Key);
		If FoundParameter = Undefined
			Or FoundParameter.UseRestriction Then 
			
			Continue;
		EndIf;
		
		ParameterValue = FixedParameters[Item.Key];
		
		AvailableParameterValues = CommonClientServer.StructureProperty(
			AvailableValues, Item.Key);
		
		If  ValueIsFilled(ParameterValue)
			And TypeOf(AvailableParameterValues) = Type("ValueList") Then 
			
			ValueFound = AvailableParameterValues.FindByValue(ParameterValue);
			ParameterValues[Item.Key] = ValueFound.Presentation;
		Else
			ParameterValues[Item.Key] = ?(ValueIsFilled(ParameterValue), ParameterValue, Undefined);
		EndIf;
	EndDo;
	
	Return ParameterValues;
	
EndFunction

// Parameters:
//  Period - StandardPeriod
// 
// Returns:
//  String
//
Function ReportPeriodView(Period)
	
	PeriodPresentation = "";
	
	If Period = Undefined
		Or TypeOf(Period) <> Type("StandardPeriod") Then 
		
		Return PeriodPresentation;
	EndIf;
	
	Return StringFunctions.PeriodPresentationInText(Period.StartDate, Period.EndDate);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Subordinate item count in groupings.

Procedure OutputSubordinateRecordsCount(Settings, Schema, StandardProcessing) Export 
	
	If Schema.CalculatedFields.Find("SubordinateRecordsCount") = Undefined Then 
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	OutputRecordsCount = OutputRecordsCount(Settings);
	
	For Each StructureItem In Settings.Structure Do 
		
		If Not StructureItem.Use Then 
			Continue;
		EndIf;
		
		If TypeOf(StructureItem) = Type("DataCompositionGroup") Then 
			
			OutputSubordinateGroupRecordsCount(StructureItem, OutputRecordsCount);
			
		ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then 
			
			OutputSubordinateTableRecordsCount(StructureItem, OutputRecordsCount);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  Settings - DataCompositionSettings
//
// Returns:
//  Boolean
//
Function OutputRecordsCount(Settings)
	
	OutputRecordsCount = Settings.DataParameters.Items.Find("OutputSubordinateRecordsCount1");
	
	Return OutputRecordsCount <> Undefined
		And OutputRecordsCount.Value;
	
EndFunction

Procedure OutputSubordinateGroupRecordsCount(Group, Output)
	
	GroupFields = Group.GroupFields.Items;
	
	If GroupFields.Count() > 0 Then 
		
		SelectedFields = Group.Selection;
		RecordsCountField = SubordinateRecordsCountField(SelectedFields, SelectedFields.Items);
		RecordsCountField.Use = Output;
		
	Else
		HideRecordsCountInDetailedRecords(Group);
	EndIf;
	
	For Each StructureItem In Group.Structure Do 
		
		If Not StructureItem.Use Then 
			Continue;
		EndIf;
		
		If TypeOf(StructureItem) = Type("DataCompositionGroup") Then 
			
			OutputSubordinateGroupRecordsCount(StructureItem, Output);
			
		ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then 
			
			OutputSubordinateTableRecordsCount(StructureItem, Output);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure OutputSubordinateTableRecordsCount(Table, Output)
	
	RecordsCountColumn = Undefined;
	
	For Each Column In Table.Columns Do 
		
		GroupFields = Column.GroupFields.Items;
		
		If GroupFields.Count() = 0 Then 
			
			RecordsCountColumn = Column;
			Break;
		
		EndIf;
		
	EndDo;
	
	If RecordsCountColumn <> Undefined Then 
		Return;
	EndIf;
	
	RecordsCountColumn = Table.Columns.Add();
	
	SelectedFields = RecordsCountColumn.Selection;
	RecordsCountField = SubordinateRecordsCountField(SelectedFields, SelectedFields.Items);
	RecordsCountField.Use = Output;
	
	HideRecordsCountInDetailedTableRecords(Table.Rows);
	
EndProcedure

Function SubordinateRecordsCountField(SelectedFields, Items)
	
	RecordsCountField = Undefined;
	SoughtValue = New DataCompositionField("SubordinateRecordsCount");
	
	For Each Item In Items Do 
		
		If TypeOf(Item) = Type("DataCompositionSelectedField") Then 
			
			If Item.Field = SoughtValue Then 
				
				RecordsCountField = Item;
				Break;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("DataCompositionSelectedFieldGroup") Then 
			
			If Item.Use Then 
				SubordinateRecordsCountField(SelectedFields, Item.Items);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If RecordsCountField = Undefined Then 
		
		RecordsCountField = SelectedFields.Items.Add(Type("DataCompositionSelectedField"));
		RecordsCountField.Field = SoughtValue;
		
	EndIf;
	
	Return RecordsCountField;
	
EndFunction

Procedure HideRecordsCountInDetailedTableRecords(Rows)
	
	For Each String In Rows Do 
		
		GroupFields = String.GroupFields.Items;
		
		If GroupFields.Count() = 0 Then 
			HideRecordsCountInDetailedRecords(String);
		Else
			HideRecordsCountInDetailedTableRecords(String.Structure);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure HideRecordsCountInDetailedRecords(DetailedRecords)
	
	Field = New DataCompositionField("SubordinateRecordsCount");
	
	RecordsCountAppearance = RecordsCountAppearance(DetailedRecords, Field);
	
	FormattedField = RecordsCountAppearance.Fields.Items.Add();
	FormattedField.Field = Field;
	
	AppearanceCondition = RecordsCountAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	AppearanceCondition.LeftValue = Field;
	AppearanceCondition.ComparisonType = DataCompositionComparisonType.NotEqual;
	AppearanceCondition.RightValue = 0;
	AppearanceCondition.Use = True;
	
	RecordsCountAppearance.Appearance.SetParameterValue("Text", "");
	
	UsageOptions = UseCasesForTheDesign();
	For Each UsageOption In UsageOptions Do 
		RecordsCountAppearance[UsageOption] = DataCompositionConditionalAppearanceUse.DontUse;
	EndDo;
	
EndProcedure

// Returns:
//   Array of String - Collection of element property IDs for the conditional appearance 
//                      DataCompositionConditionalAppearanceUse.
//
Function UseCasesForTheDesign()
	
	UsageOptions = New Array;
	UsageOptions.Add("UseInHeader");
	UsageOptions.Add("UseInFieldsHeader");
	UsageOptions.Add("UseInHierarchicalGroup");
	UsageOptions.Add("UseInOverall");
	UsageOptions.Add("UseInFilter");
	UsageOptions.Add("UseInParameters");
	UsageOptions.Add("UseInOverallHeader");
	UsageOptions.Add("UseInResourceFieldsHeader");
	UsageOptions.Add("UseInOverallResourceFieldsHeader");
	
	Return UsageOptions;
	
EndFunction

Function RecordsCountAppearance(DetailedRecords, SoughtValue)
	
	RecordsCountAppearance = Undefined;
	
	AppearanceItems = DetailedRecords.ConditionalAppearance.Items;
	
	For Each AppearanceItem In AppearanceItems Do 
		
		AppearanceFields = AppearanceItem.Fields.Items;
		
		If AppearanceFields.Count() > 0
			And AppearanceFields[0].Field = SoughtValue Then 
			
			RecordsCountAppearance = AppearanceItem;
			Break;
			
		EndIf;
		
	EndDo;
	
	If RecordsCountAppearance = Undefined Then 
		RecordsCountAppearance = AppearanceItems.Add();
	EndIf;
	
	RecordsCountAppearance.Fields.Items.Clear();
	RecordsCountAppearance.Filter.Items.Clear();
	
	Return RecordsCountAppearance;
	
EndFunction

Function FixedParameterDisplayModes(Settings)
	
	DisplayMode = New Structure();
	DisplayMode.Insert("Period", DataCompositionSettingsItemViewMode.QuickAccess);
	DisplayMode.Insert("MetadataObjectType", DataCompositionSettingsItemViewMode.QuickAccess);
	DisplayMode.Insert("MetadataObjectName", DataCompositionSettingsItemViewMode.QuickAccess);
	DisplayMode.Insert("TableName", DataCompositionSettingsItemViewMode.QuickAccess);
	DisplayMode.Insert("OutputSubordinateRecordsCount1", DataCompositionSettingsItemViewMode.Normal);
	
	Parameters = Settings.DataParameters.Items;
	
	For Each ViewMode In DisplayMode Do 
		
		FoundParameter = Parameters.Find(ViewMode.Key);
		
		If FoundParameter <> Undefined Then 
			DisplayMode[ViewMode.Key] = FoundParameter.ViewMode;
		EndIf;
		
	EndDo;
	
	Return DisplayMode;
	
EndFunction

Procedure SetTheDisplayModesOfFixedParameters(Settings, DisplayMode)
	
	Parameters = Settings.DataParameters.Items;
	
	For Each ViewMode In DisplayMode Do 
		
		FoundParameter = Parameters.Find(ViewMode.Key);
		
		If FoundParameter <> Undefined Then 
			FoundParameter.ViewMode = DisplayMode[ViewMode.Key];
		EndIf;
		
	EndDo;
	
EndProcedure

Function PeriodEndDate_2(Period, MetadataObjectType, TableName) Export
	
	If Period = Undefined Then
		Return Date(1, 1, 1);
	EndIf;
	
	EndDate = ?(TypeOf(Period) = Type("StandardPeriod"), Period.EndDate, Period);
	
	If StrFind(Upper(MetadataObjectType), "REGISTER") = 0
	   Or StrCompare(TableName, "Balance") <> 0 Then
		Return EndDate;
	EndIf;
	
	Return New Boundary(EndDate, BoundaryType.Including);
	
EndFunction

Function MainDataTableNamePresentation()
	
	Return NStr("en = 'Main data';es_CO = 'Datos principales'");
	
EndFunction

#EndRegion

#EndIf