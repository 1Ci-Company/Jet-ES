///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Handles bunch message writing to the event log.
// The EventsForEventLog variable is cleared after writing.
//
// Parameters:
//  EventsForEventLog - ValueList:
//    * Value - Structure:
//        ** EventName  - String - Name of the logging event.
//        ** LevelPresentation  - String - Presentation of the "EventLogLevel" collection members.
//                                    Valid values are Information, Error, Warning, and Note.
//        ** Comment - String - Event comment.
//        ** EventDate - Date   - Event date. It is added to the comment upon logging.
//     * Presentation - String - Not used.
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export
	
	If TypeOf(EventsForEventLog) <> Type("ValueList") Then
		Return;
	EndIf;
	
	If EventsForEventLog.Count() = 0 Then
		Return;
	EndIf;
	
	For Each LogMessage In EventsForEventLog Do
		MessageValue = LogMessage.Value;
		EventName = MessageValue.EventName;
		EventLevel = EventLevelByPresentation(MessageValue.LevelPresentation);
		EventDate = CurrentSessionDate();
		If MessageValue.Property("EventDate") And ValueIsFilled(MessageValue.EventDate) Then
			EventDate = MessageValue.EventDate;
		EndIf;
		Comment = String(EventDate) + " " + MessageValue.Comment;
		WriteLogEvent(EventName, EventLevel,,, Comment);
	EndDo;
	EventsForEventLog.Clear();
	
EndProcedure

#EndRegion

#Region Internal

// Write the message to the event log.
//
//  Parameters: 
//   EventName       - String - an event name for the event log.
//   Level          - EventLogLevel - events importance level of the log event.
//   MetadataObject - MetadataObject - metadata object that the event refers to.
//   Data           - AnyRef
//                    - Number
//                    - String
//                    - Date
//                    - Boolean
//                    - Undefined
//                    - Type - data that the event is related to.
//                      It is recommended to specify references to the data objects (catalog items, documents that the event
//                      refers to).
//   Comment      - String - the comment to the log event.
//
Procedure AddMessageForEventLog(Val EventName, Val Level,
		Val MetadataObject = Undefined, Val Data = Undefined, Val Comment = "") Export
		
	If IsBlankString(EventName) Then
		EventName = "Event"; // not localized to prevent startup from stopping in a partially translated configuration
	EndIf;

	WriteLogEvent(EventName, Level, MetadataObject, Data, Comment, EventLogEntryTransactionMode.Independent);
	
EndProcedure

// Reads event log message texts taking into account the filter settings.
//
// Parameters:
//
//     ReportParameters - Structure - contains parameters for reading events from the event log. Contains fields:
//      *  Log                  - ValueTable         - contains records of the event log.
//      *  EventLogFilter   - Structure             - filter settings used to read the event log records:
//          ** StartDate - Date - start date of events (optional).
//          ** EndDate - Date - end date of events (optional).
//      *  EventCount1       - Number                   - maximum number of records that can be read from the event log.
//      *  UUID - UUID - a form UUID.
//      *  OwnerManager       - Arbitrary            - event
//                                                             log is displayed in the form of this object. The manager is used to call back appearance
//                                                             functions.
//      *  AddAdditionalColumns - Boolean           - determines whether callback is needed to add
//                                                             additional columns.
//     StorageAddress - String
//                    - UUID - Address of the temporary storage that stores the result.
//
// Result is a structure with the following fields::
//     LogEvents - ValueTable - Selected events.
//
Procedure ReadEventLogEvents(ReportParameters, StorageAddress) Export
	
	EventLogFilterAtClient          = ReportParameters.EventLogFilter;
	EventCount1              = ReportParameters.EventsCountLimit;
	OwnerManager              = ReportParameters.OwnerManager;
	AddAdditionalColumns = ReportParameters.AddAdditionalColumns;
	
	// Verifying the parameters.
	StartDate    = Undefined;
	EndDate = Undefined;
	FilterDatesSpecified = EventLogFilterAtClient.Property("StartDate", StartDate) And EventLogFilterAtClient.Property("EndDate", EndDate)
		And ValueIsFilled(StartDate) And ValueIsFilled(EventLogFilterAtClient.EndDate);
		
	If FilterDatesSpecified And StartDate > EndDate Then
		Raise NStr("en = 'Invalid event log filter settings. The start date is later than the end date.';es_CO = 'Condiciones del filtro del registro de eventos son incorrectas. Fecha inicial es mayor de la fecha final.'");
	EndIf;
	ServerTimeOffset = ServerTimeOffset();
	
	// Prepare the filter.
	Filter = New Structure;
	For Each FilterElement In EventLogFilterAtClient Do
		Filter.Insert(FilterElement.Key, FilterElement.Value);
	EndDo;
	
	FilterTransformation(Filter, ServerTimeOffset);
	
	// Exporting the selected events and generating the table structure.
	LogEvents = New ValueTable;
	UnloadEventLog(LogEvents, Filter, , , EventCount1);
	
	LogEvents.Columns.Date.Name = "DateAtServer";
	LogEvents.Columns.Add("Date", New TypeDescription("Date"));
	
	LogEvents.Columns.Add("PicNumber", New TypeDescription("Number"));
	LogEvents.Columns.Add("DataAsStr", New TypeDescription("String"));
	LogEvents.Columns.Add("EventKey", New TypeDescription("String"));
	
	If Common.SeparatedDataUsageAvailable() Then
		LogEvents.Columns.Add("SessionDataSeparation", New TypeDescription("ValueList"));
		LogEvents.Columns.Add("SessionDataSeparationPresentation", New TypeDescription("String"));
	EndIf;
	LogEvents.Columns.Add("DataArea", New TypeDescription("String"));
	
	If AddAdditionalColumns Then
		OwnerManager.AddAdditionalEventColumns(LogEvents);
	EndIf;
	
	LogEvents.Columns.Add("MetadataList", New TypeDescription("ValueList"));
	LogEvents.Columns.Add("IsDataStringMatchesDataPresentation", New TypeDescription("Boolean"));
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable()
	   And Common.SubsystemExists("CloudTechnology.Core") Then
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		UserAliases    = New Map();
	Else
		ModuleSaaSOperations = Undefined;
		UserAliases    = Undefined;
	EndIf;
	
	KeyStructure1 = New Structure;
	For Each Column In LogEvents.Columns Do
		KeyStructure1.Insert(Column.Name);
	EndDo;
	
	KeysPresentation = StructuresKeysPresentation();
	
	For Each LogEvent In LogEvents Do
		LogEvent.Date = LogEvent.DateAtServer - ServerTimeOffset;
		
		// Filling numbers of row pictures.
		OwnerManager.SetPictureNumber(LogEvent);
		
		If AddAdditionalColumns Then
			// Filling additional fields that are defined for the owner only.
			OwnerManager.FillInAdditionalEventColumns(LogEvent);
		EndIf;
		
		// Converting the array of metadata into a value list.
		If TypeOf(LogEvent.Metadata) = Type("Array") Then
			AddPresentation = TypeOf(LogEvent.MetadataPresentation) = Type("Array")
			   And LogEvent.MetadataPresentation.Count() = LogEvent.Metadata.Count();
			IndexOf = 0;
			For Each FullName In LogEvent.Metadata Do
				LogEvent.MetadataList.Add(FullName,
					?(AddPresentation, LogEvent.MetadataPresentation[IndexOf], ""));
				IndexOf = IndexOf + 1;
			EndDo;
		Else
			LogEvent.MetadataList.Add(LogEvent.Metadata,
				LogEvent.MetadataPresentation);
		EndIf;
		
		// Convert an array of metadata presentations into a string.
		If TypeOf(LogEvent.MetadataPresentation) = Type("Array") Then
			LogEvent.MetadataPresentation = StrConcat(LogEvent.MetadataPresentation, ", ");
		Else
			LogEvent.MetadataPresentation = String(LogEvent.MetadataPresentation);
		EndIf;
		
		// Convert the "SessionDataSeparation" array into a value list.
		If Not Common.SeparatedDataUsageAvailable() Then
			FullSessionDataSeparationPresentation = "";
			SessionDataSeparation = LogEvent.SessionDataSeparation;
			SeparatedDataAttributeList = New ValueList;
			For Each SessionSeparator In SessionDataSeparation Do
				SeparatorPresentation = Metadata.CommonAttributes.Find(SessionSeparator.Key).Presentation();
				SeparatorPresentation = SeparatorPresentation + " = " + SessionSeparator.Value;
				SeparatorValue = SessionSeparator.Key + "=" + SessionSeparator.Value;
				SeparatedDataAttributeList.Add(SeparatorValue, SeparatorPresentation);
				FullSessionDataSeparationPresentation = ?(Not IsBlankString(FullSessionDataSeparationPresentation),
				                                            FullSessionDataSeparationPresentation + "; ", "")
				                                            + SeparatorPresentation;
			EndDo;
			If Not ValueIsFilled(SessionDataSeparation) Then
				LogEvent.DataArea = "-";
				For Each CommonAttribute In Metadata.CommonAttributes Do
					If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.DontUse Then
						Continue;
					EndIf;
					SeparatorPresentation = CommonAttribute.Presentation() + " = " + NStr("en = '<Not set>';es_CO = '<Not set>'");
					SeparatorValue = CommonAttribute.Name + "=";
					SeparatedDataAttributeList.Add(SeparatorValue, SeparatorPresentation);
				EndDo;
			ElsIf Not SessionDataSeparation.Property("DataAreaMainData") Then
				LogEvent.DataArea = "?";
			Else
				LogEvent.DataArea = Format(SessionDataSeparation.DataAreaMainData, "NZ=0; NG=");
			EndIf;
			LogEvent.SessionDataSeparation = SeparatedDataAttributeList;
			LogEvent.SessionDataSeparationPresentation = FullSessionDataSeparationPresentation;
		EndIf;
		
		// Processing special event data.
		If LogEvent.Event = "_$Access$_.Access" Then
			SetDataString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				LogEvent.Data = TableDataPresentation(LogEvent.Data);
			EndIf;
			
		ElsIf LogEvent.Event = "_$Access$_.AccessDenied" Then
			SetDataString(LogEvent);
			
			If LogEvent.Data <> Undefined Then
				If LogEvent.Data.Property("Right") Then
					LogEvent.Data = StructureDataPresentation(LogEvent.Data,
						KeysPresentation);
				Else
					LogEvent.Data = StructureDataPresentation(LogEvent.Data,
						KeysPresentation, True) + "
						|" + TableDataPresentation(LogEvent.Data);
				EndIf;
			EndIf;
			
		ElsIf TypeOf(LogEvent.Data) = Type("Structure")
		      Or TypeOf(LogEvent.Data) = Type("FixedStructure") Then
			
			SetDataString(LogEvent);
			LogEvent.Data = StructureDataPresentation(LogEvent.Data,
				KeysPresentation);
			
		ElsIf TypeOf(LogEvent.Data) = Type("String") Then
			Data = DataFromXMLString(LogEvent.Data);
			If Data <> Undefined Then
				SetDataString(LogEvent);
				LogEvent.Data = StructureDataPresentation(Data, KeysPresentation);
			EndIf;
		EndIf;
		
		SetPrivilegedMode(True);
		// Refine the user name.
		If LogEvent.User = New UUID("00000000-0000-0000-0000-000000000000") Then
			LogEvent.UserName = NStr("en = '<Undefined>';es_CO = '<No definido>'");
			
		ElsIf LogEvent.UserName = "" Then
			LogEvent.UserName = Users.UnspecifiedUserFullName();
			
		ElsIf InfoBaseUsers.FindByUUID(LogEvent.User) = Undefined Then
			LogEvent.UserName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 <Deleted>';es_CO = '%1 <Eliminado>'"), LogEvent.UserName);
		EndIf;
		
		If ModuleSaaSOperations <> Undefined Then
			If UserAliases.Get(LogEvent.User) = Undefined Then
				UserAlias = ModuleSaaSOperations.AliasOfUserOfInformationBase(LogEvent.User);
				UserAliases.Insert(LogEvent.User, UserAlias);
			Else
				UserAlias = UserAliases.Get(LogEvent.User);
			EndIf;
			
			If ValueIsFilled(UserAlias) Then
				LogEvent.UserName = UserAlias;
			EndIf;
		EndIf;
		
		If String(LogEvent.DataPresentation) = String(LogEvent.Data) Then
			LogEvent.IsDataStringMatchesDataPresentation = True;
		EndIf;
		
		LogEvent.Comment = CommonClientServer.ReplaceProhibitedXMLChars(
			LogEvent.Comment);
		
		FillPropertyValues(KeyStructure1, LogEvent);
		Hashing = New DataHashing(HashFunction.SHA256);
		Hashing.Append(ValueToStringInternal(KeyStructure1));
		LogEvent.EventKey = Base64String(Hashing.HashSum);
		
		SetPrivilegedMode(False);
	EndDo;
	
	LogEvents.Columns.Delete("Metadata");
	LogEvents.Columns.MetadataList.Name = "Metadata";
	
	// Completed successfully.
	Result = New Structure;
	Result.Insert("LogEvents", LogEvents);
	
	PutToTempStorage(Result, StorageAddress);
EndProcedure

// Creates a custom event log presentation.
//
// Parameters:
//  FilterPresentation - String - the string that contains custom presentation of the filter.
//  EventLogFilter - Structure - values of the event log filter.
//  DefaultEventLogFilter - Structure - default values of the event log filter 
//     (not included in the user presentation).
//
Procedure GenerateFilterPresentation(FilterPresentation, EventLogFilter, 
		DefaultEventLogFilter = Undefined) Export
	
	FilterPresentation = "";
	// Interval.
	PeriodStartDate    = Undefined;
	PeriodEndDate = Undefined;
	If Not EventLogFilter.Property("StartDate", PeriodStartDate)
		Or PeriodStartDate = Undefined Then
		PeriodStartDate    = '00010101000000';
	EndIf;
	
	If Not EventLogFilter.Property("EndDate", PeriodEndDate)
		Or PeriodEndDate = Undefined Then
		PeriodEndDate = '00010101000000';
	EndIf;
	
	If Not (PeriodStartDate = '00010101000000' And PeriodEndDate = '00010101000000') Then
		FilterPresentation = PeriodPresentation(PeriodStartDate, PeriodEndDate);
	EndIf;
	
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "User");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation,
		"Event", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation,
		"ApplicationName", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Session");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Level");
	
	// All other restrictions are specified by presentations without values.
	For Each FilterElement In EventLogFilter Do
		RestrictionName = FilterElement.Key;
		If Upper(RestrictionName) = Upper("StartDate")
			Or Upper(RestrictionName) = Upper("EndDate")
			Or Upper(RestrictionName) = Upper("Event")
			Or Upper(RestrictionName) = Upper("ApplicationName")
			Or Upper(RestrictionName) = Upper("User")
			Or Upper(RestrictionName) = Upper("Session")
			Or Upper(RestrictionName) = Upper("Level") Then
			Continue; // Interval and special restrictions are already displayed.
		EndIf;
		
		// Changing restrictions for some of presentations.
		If Upper(RestrictionName) = Upper("ApplicationName") Then
			RestrictionName = NStr("en = 'Application';es_CO = 'Aplicación'");
		ElsIf Upper(RestrictionName) = Upper("TransactionStatus") Then
			RestrictionName = NStr("en = 'Transaction status';es_CO = 'Estado de transacción'");
		ElsIf Upper(RestrictionName) = Upper("DataPresentation") Then
			RestrictionName = NStr("en = 'Data presentation';es_CO = 'Presentación de datos'");
		ElsIf Upper(RestrictionName) = Upper("ServerName") Then
			RestrictionName = NStr("en = 'Production server';es_CO = 'Servidor de producción'");
		ElsIf Upper(RestrictionName) = Upper("PrimaryIPPort") Then
			RestrictionName = NStr("en = 'IP port';es_CO = 'Puerto de IP principal'");
		ElsIf Upper(RestrictionName) = Upper("SyncPort") Then
			RestrictionName = NStr("en = 'Auxiliary IP port';es_CO = 'Puerto sincronizado'");
		ElsIf Upper(RestrictionName) = Upper("SessionDataSeparation") Then
			If StandardSeparatorsOnly() Then
				RestrictionName = NStr("en = 'Data area';es_CO = 'Área de datos'");
			Else
				RestrictionName = NStr("en = 'Session data separation';es_CO = 'Sesión separación de datos'");
			EndIf;
		EndIf;
		
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
		FilterPresentation = FilterPresentation + RestrictionName;
		
	EndDo;
	
	If IsBlankString(FilterPresentation) Then
		FilterPresentation = NStr("en = 'Not set';es_CO = 'No definido'");
	EndIf;
	
EndProcedure

// Determines the server time offset relative to the application time.
//
// Returns:
//   Number - time offset, in seconds.
//       Can be used to convert log filters to the server date
//       and also to convert dates obtained from the log to the application dates.
//
Function ServerTimeOffset() Export
	
	ServerTimeOffset = CurrentDate() - CurrentSessionDate(); // ACC:143 - Computer data is required
	If ServerTimeOffset >= -1 And ServerTimeOffset <= 1 Then
		ServerTimeOffset = 0;
	EndIf;
	Return ServerTimeOffset;
	
EndFunction

// Returns the address of the XML file containing the Event log intended for the support.
// Filtered log records in the EventLogFilter parameter align with the UnloadEventLog method.
// If a filter property is missing or set to Undefined, the filter won't apply.
// 
// Parameters:
//  EventLogFilter - Structure:
//   * StartDate - Date
//   * EndDate - Date
//   * Level - EventLogLevel
//   * ApplicationName - String
//                   - Array of String
//                   - ValueList
//   * User - InfoBaseUser
//                  - String
//                  - Array of InfoBaseUser
//                  - ValueList
//   * Computer - String
//               - Array of String
//                - ValueList
//   * Event - String
//             - ValueList
//             - Array of String - See Syntax Assistant for the names of system events.
//   * Metadata - MetadataObject 
//                - Array of MetadataObject
//                - ValueList
//   * Data - AnyRef
//   * DataPresentation - String
//   * Comment - String
//   * TransactionStatus - EventLogEntryTransactionStatus
//   * Transaction - String 
//   * Session - Number
//           - Array of Number
//           - ValueList
//   * ServerName - String
//                   - Array of String
//                   - ValueList
//   * PrimaryIPPort - Number
//                    - Array of Number
//                    - ValueList
//   * SyncPort - Number
//                    - Array of Number
//                    - ValueList
//   * SessionDataSeparation - ValueList - Property names align with common attribute names. 
//                            - Structure
//  EventCount1 - Number
//  UUID - UUID - Intended for creating a temporary storage.
// 
// Returns:
//  String 
//
Function TechnicalSupportLog(EventLogFilter, EventCount1, UUID = Undefined) Export
	
	Filter = New Structure;
	For Each FilterElement In EventLogFilter Do
		Filter.Insert(FilterElement.Key, FilterElement.Value);
	EndDo;
	ServerTimeOffset = ServerTimeOffset();
	FilterTransformation(Filter, ServerTimeOffset);
	
	TempFile = GetTempFileName("xml");
	UnloadEventLog(TempFile, Filter, , , EventCount1);
	BinaryData = New BinaryData(TempFile);
	DeleteFiles(TempFile);
	
	Return PutToTempStorage(BinaryData, UUID);
	
EndFunction

// Returns an infobase user to be passed to the "User" property
// of the Event Log filter.
//
// Parameters:
//  Id - UUID - Infobase user id.
//
// Returns:
//  InfoBaseUser
//  Undefined
//
Function InfobaseUserForFilter(Id) Export
	
	IBUser = InfoBaseUsers.FindByUUID(Id);
	
	If IBUser <> Undefined Then
		Return IBUser;
	EndIf;
	
	Try
		IsEmpty = InfoBaseUsers.FindByName("");
		InfobaseUserString = ValueToStringInternal(IsEmpty);
		InfobaseUserString = StrReplace(InfobaseUserString,
			Lower(IsEmpty.UUID), Lower(Id));
		IBUser = ValueFromStringInternal(InfobaseUserString);
	Except
		IBUser = Undefined;
	EndTry;
	
	Return IBUser;
	
EndFunction

#EndRegion

#Region Private

// Parameters:
//  DataAsStr - String
//
Function EventData(DataAsStr) Export
	
	If Not ValueIsFilled(DataAsStr) Then
		Return Undefined;
	EndIf;
	
	Try
		Result = ValueFromStringInternal(DataAsStr);
	Except
		Result = Undefined;
	EndTry;
	
	Return Result;
	
EndFunction

// Parameters:
//  EventData - String
//
// Returns:
//  Structure - If the conversion is successful.
//  Undefined - If the conversion failed.
//
Function DataFromXMLString(EventData) Export
	
	If TypeOf(EventData) <> Type("String")
	 Or Not StrStartsWith(EventData, "<")
	 Or Not StrEndsWith(EventData, ">") Then
		Return Undefined;
	EndIf;
	
	Try
		Data = Common.ValueFromXMLString(EventData);
	Except
		Data = Undefined;
	EndTry;
	
	If TypeOf(Data) = Type("Structure") Then
		Return Data;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function TableDataPresentation(EventData)
	
	If TypeOf(EventData) <> Type("Structure")
	   And TypeOf(EventData) <> Type("FixedStructure")
	 Or Not EventData.Property("Data")
	 Or TypeOf(EventData.Data) <> Type("ValueTable") Then
		Return "";
	EndIf;
	
	Data = EventData.Data; // ValueTable
	
	RowsCount = Data.Count();
	If RowsCount = 0 Then
		Return "";
	EndIf;
	
	Table = New ValueTable;
	For Each Column In Data.Columns Do
		NewColumn = Table.Columns.Add(Column.Name,
			New TypeDescription("String"), Column.Title);
		If Not ValueIsFilled(NewColumn.Title) Then
			NewColumn.Title = NewColumn.Name;
		EndIf;
	EndDo;
	For Each TableRow In Data Do
		FillPropertyValues(Table.Add(), TableRow);
	EndDo;
	
	Copy = Table.Copy();
	For Each Column In Table.Columns Do
		Copy.Sort(Column.Name);
		Width = StrLen(Copy.Get(RowsCount - 1)[Column.Name]);
		TitleWidth = StrLen(Column.Title);
		Column.Width = ?(Width > TitleWidth, Width, TitleWidth);
	EndDo;
	
	IndentChars = "                                                             ";
	
	Rows = New Array;
	StringParts1 = New Array;
	For Each Column In Table.Columns Do
		StringParts1.Add(Mid(Column.Title + IndentChars, 1, Column.Width));
	EndDo;
	Rows.Add("| " + StrConcat(StringParts1, " | ") + " |");
	
	For Each TableRow In Table Do
		StringParts1 = New Array;
		For Each Column In Table.Columns Do
			StringParts1.Add(Mid(TableRow[Column.Name] + IndentChars, 1, Column.Width));
		EndDo;
		Rows.Add("| " + StrConcat(StringParts1, " | ") + " |");
	EndDo;
	
	Return StrConcat(Rows, Chars.LF);
	
EndFunction

Function StructureDataPresentation(EventData, KeysPresentation, IsDataPropertyExcluded = False)
	
	If TypeOf(EventData) <> Type("Structure")
	   And TypeOf(EventData) <> Type("FixedStructure") Then
		Return "";
	EndIf;
	
	PropertiesToExclude = New Map;
	If IsDataPropertyExcluded Then
		PropertiesToExclude.Insert(Lower("Data"), True);
	EndIf;
	
	EndingPresentation = "";
	
	If EventData.Property("Roles") Then
		PropertyNameAtEnd = Lower("Roles");
	ElsIf EventData.Property("Message") Then
		PropertyNameAtEnd = Lower("Message");
	Else
		PropertyNameAtEnd = "";
	EndIf;
	
	If ValueIsFilled(PropertyNameAtEnd) Then
		PropertiesToExclude.Insert(PropertyNameAtEnd, True);
		
		ValuePresentation = ValuePresentation(PropertyNameAtEnd,
			EventData[PropertyNameAtEnd]);
		
		If ValueIsFilled(ValuePresentation) Then
			KeyPresentation = KeysPresentation.Get(Lower(PropertyNameAtEnd));
			IsKeyPresentationFilled = ValueIsFilled(KeyPresentation);
			If Not IsKeyPresentationFilled Then
				KeyPresentation = PropertyNameAtEnd;
			EndIf;
			
			If StrFind(ValuePresentation, Chars.LF) > 0 Then
				EndingPresentation = KeyPresentation + ":
				|" + ValuePresentation;
			Else
				EndingPresentation = KeyPresentation + ": " + ValuePresentation;
			EndIf;
		EndIf;
	EndIf;
	
	Tree = TreeWithStructureData(EventData,
		KeysPresentation, True, PropertiesToExclude);
	
	Rows = New Array;
	AddTreeRowsPresentations(Rows, Tree.Rows);
	
	If ValueIsFilled(EndingPresentation) Then
		Rows.Add(EndingPresentation);
	EndIf;
	
	Return StrConcat(Rows, Chars.LF);
	
EndFunction

// Intended for function "StructureDataPresentation".
Procedure AddTreeRowsPresentations(Rows, TreeRows, Indent = "")
	
	For Each TreeRow In TreeRows Do
		If TreeRow.ThereIsValue Then
			Rows.Add(Indent + TreeRow.Property + ": " + TreeRow.Value);
		Else
			Rows.Add(Indent + TreeRow.Property);
			AddTreeRowsPresentations(Rows, TreeRow.Rows, Indent + "    ");
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  EventData - Structure, FixedStructure
//  KeysPresentation - See StructuresKeysPresentation
//                      - Undefined - Receive automatically.
//  OnlyFilledValues - Boolean
//  PropertiesToExclude - Map
//                      - Undefined
//
// Returns:
//  ValueTree:
//   * Property - String
//   * Value - String
//   * ThereIsValue - Boolean
//
Function TreeWithStructureData(EventData, KeysPresentation = Undefined,
			OnlyFilledValues = False, PropertiesToExclude = Undefined) Export
	
	If KeysPresentation = Undefined Then
		KeysPresentation = StructuresKeysPresentation();
	EndIf;
	
	Tree = New ValueTree;
	Tree.Columns.Add("Property", New TypeDescription("String"), NStr("en = 'Property';es_CO = 'Propiedad'"));
	Tree.Columns.Add("Value", New TypeDescription("String"), NStr("en = 'Value';es_CO = 'Valor'"));
	Tree.Columns.Add("IsPropertyWithoutPresentation", New TypeDescription("Boolean"));
	Tree.Columns.Add("ThereIsValue", New TypeDescription("Boolean"));
	
	AddPropertiesToTree(Tree.Rows, EventData, KeysPresentation,
		OnlyFilledValues, PropertiesToExclude);
	
	Tree.Columns.Delete("IsPropertyWithoutPresentation");
	
	Return Tree;
	
EndFunction

Procedure AddPropertiesToTree(TreeRows, PropertiesDetails, KeysPresentation,
			OnlyFilledValues, PropertiesToExclude, Val ParentKey = "")
	
	If ParentKey <> "" Then
		ParentKey = ParentKey + ".";
	EndIf;
	
	For Each KeyAndValue In PropertiesDetails Do
		FullKey = ParentKey + KeyAndValue.Key;
		Value = KeyAndValue.Value;
		
		If PropertiesToExclude <> Undefined
		   And PropertiesToExclude.Get(Lower(FullKey)) <> Undefined
		 Or OnlyFilledValues
		   And Not ValueIsFilled(Value)
		   And TypeOf(Value) <> Type("Boolean")
		   And TypeOf(Value) <> Type("Number")
		   And TypeOf(Value) <> Type("Date") Then
			Continue;
		EndIf;
		
		NewRow = TreeRows.Add();
		
		If TypeOf(PropertiesDetails) = Type("Map")
		 Or TypeOf(PropertiesDetails) = Type("FixedMap") Then
			
			NewRow.Property = ValuePresentation("", KeyAndValue.Key);
		Else
			NewRow.Property = KeysPresentation.Get(Lower(KeyAndValue.Key));
			If Not ValueIsFilled(NewRow.Property) Then
				NewRow.Property = KeyAndValue.Key;
				NewRow.IsPropertyWithoutPresentation = True;
			EndIf;
		EndIf;
		
		If TypeOf(Value) = Type("Structure")
		 Or TypeOf(Value) = Type("FixedStructure")
		 Or TypeOf(Value) = Type("Map")
		 Or TypeOf(Value) = Type("FixedMap") Then
			
			AddPropertiesToTree(NewRow.Rows, Value, KeysPresentation,
				OnlyFilledValues, PropertiesToExclude, FullKey);
			
		ElsIf (    TypeOf(Value) = Type("Array")
		           Or TypeOf(Value) = Type("FixedArray"))
		        And Value.Count() > 0
		        And (    TypeOf(Value[0]) = Type("Structure")
		           Or TypeOf(Value[0]) = Type("FixedStructure")
		           Or TypeOf(Value[0]) = Type("Map")
		           Or TypeOf(Value[0]) = Type("FixedMap")) Then
			
			CountOfCharacters = StrLen(XMLString(Value.Count()));
			Number = 1;
			For Each ArrayElement In Value Do
				NewSubstring = NewRow.Rows.Add();
				NewSubstring.Property = Right("         " + XMLString(Number), CountOfCharacters);
				AddPropertiesToTree(NewSubstring.Rows, ArrayElement, KeysPresentation,
					OnlyFilledValues, PropertiesToExclude, FullKey);
				Number = Number + 1;
			EndDo;
		Else
			ValuePresentation = ValuePresentation(FullKey, Value);
			NewRow.Value = ValuePresentation;
			NewRow.ThereIsValue = True;
		EndIf;
		
		If Not OnlyFilledValues Then
			Continue;
		EndIf;
		
		If NewRow.ThereIsValue
		   And Not ValueIsFilled(ValuePresentation)
		 Or Not NewRow.ThereIsValue
		   And Not ValueIsFilled(NewRow.Rows) Then
			
			TreeRows.Delete(NewRow);
		EndIf;
	EndDo;
	
	TreeRows.Sort("IsPropertyWithoutPresentation, Property");
	
EndProcedure

// Parameters:
//   Var_Key - String - Property name
//   Value - Arbitrary
//
// Returns:
//  String
//
Function ValuePresentation(Var_Key, Value)
	
	FormatString = NStr("en = 'NZ=0; DLF=DT; DE=''01.01.0001 00:00:00''';es_CO = 'NZ=0; DLF=DT; DE=''01.01.0001 00:00:00'''");
	
	If TypeOf(Value) <> Type("Array") Then
		If Upper(Var_Key) = Upper("EventName") And StrStartsWith(Value, "_$") Then
			EventPresentation = EventLogEventPresentation(Value);
			If ValueIsFilled(EventPresentation) Then
				Return EventPresentation;
			EndIf;
		EndIf;
		Return CommonClientServer.ReplaceProhibitedXMLChars(
			Format(Value, FormatString));
	EndIf;
	
	If Upper(Var_Key) = Upper("Roles") Then
		Table = RoleTable(Value);
		Rows = Table.UnloadColumn("Presentation");
		Connector = Chars.LF;
	Else
		Rows = New Array;
		For Each CurrentValue In Value Do
			Rows.Add(CommonClientServer.ReplaceProhibitedXMLChars(
				Format(CurrentValue, FormatString)));
		EndDo;
		Connector = ", ";
	EndIf;
	
	If Rows.Count() = 1 Then
		Return Rows[0];
	EndIf;
	
	Return StrConcat(Rows, Connector);
	
EndFunction

// Parameters:
//  Roles - Array of String
//
// Returns:
//  ValueTable:
//   * Presentation - String
//
Function RoleTable(Roles) Export
	
	IBUserRoles1 = New ValueTable;
	IBUserRoles1.Columns.Add("Exists");
	IBUserRoles1.Columns.Add("Presentation",, NStr("en = 'Presentation';es_CO = 'Presentación'"));
	
	For Each FullNameOfTheRole In Roles Do
		NameParts = StrSplit(FullNameOfTheRole, ".", False);
		If NameParts.Count() = 2 Then
			NameOfRole = NameParts[1];
			RoleMetadata = Metadata.Roles.Find(NameOfRole);
		Else
			NameOfRole = FullNameOfTheRole;
		EndIf;
		NewRow = IBUserRoles1.Add();
		NewRow.Exists = RoleMetadata <> Undefined;
		NewRow.Presentation = ?(RoleMetadata = Undefined,
			NameOfRole, RoleMetadata.Presentation());
	EndDo;
	
	IBUserRoles1.Sort("Exists DESC, Presentation");
	IBUserRoles1.Columns.Delete("Exists");
	
	Return IBUserRoles1;
	
EndFunction

// Returns:
//  Map of KeyAndValue:
//   * Key - String - Lower-case name of a structure key.
//   * Value - String - Key presentation.
//
Function StructuresKeysPresentation()
	
	Result = New Map;
	
	// _$Access$_.*
	Result.Insert(Lower("Right"),
		NStr("en = 'Access right';es_CO = 'Derecho de acceso'"));
	
	Result.Insert(Lower("Action"),
		NStr("en = 'Action';es_CO = 'Acción'"));
	
	// _$Debug$_.*
	Result.Insert(Lower("DebuggingServerUser"),
		NStr("en = 'Debug server user';es_CO = 'Usuario del servidor de depuración'"));
	
	Result.Insert(Lower("DebugItemType"),
		NStr("en = 'Debug item type';es_CO = 'Tipo de elemento de depuración'"));
	
	Result.Insert(Lower("Expression"),
		NStr("en = 'Expression';es_CO = 'Expresión'"));
	
	// _$InfoBase$_.AdditionalAuthenticationSettingsUpdate
	Result.Insert(Lower("PasswordRecoveryMethod"),
		NStr("en = 'Password recovery method';es_CO = 'Método de recuperación de contraseña'"));
	
	Result.Insert(Lower("PasswordRecoveryURL"),
		NStr("en = 'Password recovery URL';es_CO = 'Dirección URL de recuperación de contraseña'"));
	
	Result.Insert(Lower("HelpURL"),
		NStr("en = 'Help URL';es_CO = 'Dirección URL de ayuda'"));
	
	Result.Insert(Lower("ShowHelpHyperlink"),
		NStr("en = 'Show Help URL';es_CO = 'Mostrar la URL de ayuda'"));
	
	Result.Insert(Lower("VerificationCodeLength"),
		NStr("en = 'Confirmation code length';es_CO = 'Longitud del código de confirmación'"));
	
	Result.Insert(Lower("MaxUnsuccessfulVerificationCodeValidationAttemptsCount"),
		NStr("en = 'Limit for unsuccessful code entries';es_CO = 'Límite de entradas de código fallidas'"));
	
	Result.Insert(Lower("VerificationCodeRefreshRequestLockDuration"),
		NStr("en = 'Confirmation code cooldown time';es_CO = 'Tiempo de recuperación del código de confirmación'"));
	
	Result.Insert(Lower("SMTPServerAddress"),
		NStr("en = 'SMTP server address';es_CO = 'Dirección del servidor SMTP'"));
	
	Result.Insert(Lower("SMTPUser"),
		NStr("en = 'SMTP user';es_CO = 'Usuario SMTP'"));
	
	Result.Insert(Lower("SMTPPasswordChanged"),
		NStr("en = 'SMTP password changed';es_CO = 'Contraseña SMTP cambiada'"));
	
	Result.Insert(Lower("SMTPPort"),
		NStr("en = 'SMTP port';es_CO = 'Puerto SMTP'"));
	
	Result.Insert(Lower("SenderName"),
		NStr("en = 'Sender name';es_CO = 'Nombre del remitente'"));
	
	Result.Insert(Lower("Title"),
		NStr("en = 'Header';es_CO = 'Encabezado'"));
	
	Result.Insert(Lower("HTMLMessageText"),
		NStr("en = 'HTML message body';es_CO = 'Cuerpo del mensaje HTML'"));
	
	Result.Insert(Lower("UseSSL"),
		NStr("en = 'SSL user';es_CO = 'Usuario SSL'"));
	
	Result.Insert(Lower("AllowSaveCredentialsForReAuthentication"),
		NStr("en = 'Allow save credentials for auto-login';es_CO = 'Permitir guardar las credenciales para el inicio de sesión automático'"));
	
	Result.Insert(Lower("SaveCredentialsForReAuthenticationByDefault"),
		NStr("en = 'Save credentials for auto-login by default';es_CO = 'Guardar las credenciales para el inicio de sesión automático por defecto'"));
	
	Result.Insert(Lower("SavedCredentialsLifetime"),
		NStr("en = 'Credentials lifetime';es_CO = 'Duración de las credenciales'"));
	
	// _$InfoBase$_.AdministrationParametersChange
	Result.Insert(Lower("LockScheduledJobs"),
		NStr("en = 'Scheduled job lock';es_CO = 'Bloqueo de tarea programada'"));
	
	Result.Insert(Lower("SessionsLockEnabled"),
		NStr("en = 'Session startup lock enabled';es_CO = 'Bloqueo de inicio de sesión activado'"));
	
	Result.Insert(Lower("LockBeginTime"),
		NStr("en = 'Lock start time';es_CO = 'Hora de inicio del bloqueo'"));
	
	Result.Insert(Lower("LockEndTime"),
		NStr("en = 'Lock end time';es_CO = 'Hora de finalización del bloqueo'"));
	
	Result.Insert(Lower("DelayConfigurationExportByWorkProcessWithoutActiveUsers"),
		NStr("en = 'Delay for importing configuration by an idle process';es_CO = 'Retraso en la importación de la configuración por un proceso inactivo'"));
	
	Result.Insert(Lower("RestrictLocalSpeechRecognition"),
		NStr("en = 'Restrict local speech recognition';es_CO = 'Restringir el reconocimiento de voz local'"));
	
	Result.Insert(Lower("InfoBaseID"),
		NStr("en = 'Infobase ID';es_CO = 'Identificador de la base de información'"));
	
	Result.Insert(Lower("DataBaseName"),
		NStr("en = 'Database name';es_CO = 'Nombre de la base de datos'"));
	
	Result.Insert(Lower("SessionStartPermissionCode"),
		NStr("en = 'Access code for session startup';es_CO = 'Código de acceso para el inicio de sesión'"));
	
	Result.Insert(Lower("MaxStartupShiftForScheduledJobsWithoutActiveUsers"),
		NStr("en = 'Maximum startup offset for idle scheduled jobs';es_CO = 'Desplazamiento máximo de inicio para las tareas programadas inactivas'"));
	
	Result.Insert(Lower("MaxRuntimeForScheduledJobsWithoutActiveUsers"),
		NStr("en = 'Minimal startup period for idle scheduled jobs';es_CO = 'Período mínimo de inicio para las tareas programadas inactivas'"));
	
	Result.Insert(Lower("ExternalSessionManagementRequired"),
		NStr("en = 'Mandatory external session management';es_CO = 'Gestión obligatoria de sesiones externas'"));
	
	Result.Insert(Lower("LongDesc"),
		NStr("en = 'Details';es_CO = 'Detalles'"));
	
	Result.Insert(Lower("LockParameter"),
		NStr("en = 'Lock parameter';es_CO = 'Parámetro de bloqueo'"));
	
	Result.Insert(Lower("DatabaseUserPassword"),
		NStr("en = 'Database user password';es_CO = 'Contraseña del usuario de la base de datos'"));
	
	Result.Insert(Lower("DatabaseUser"),
		NStr("en = 'Database user';es_CO = 'Usuario de la base de datos'"));
	
	Result.Insert(Lower("SafeModeSecurityProfile"),
		NStr("en = 'Safe mode security profile';es_CO = 'Perfil de seguridad del modo seguro'"));
	
	Result.Insert(Lower("AllowLicenseDistribution"),
		NStr("en = 'Allow issuing licenses';es_CO = 'Permitir la emisión de licencias'"));
	
	Result.Insert(Lower("ReserveWorkingProcesses"),
		NStr("en = 'Working process reservation';es_CO = 'Reserva del proceso de servicio'"));
	
	Result.Insert(Lower("DataBaseServer"),
		NStr("en = 'Database server';es_CO = 'Servidor de la base de datos'"));
	
	Result.Insert(Lower("DateOffset"),
		NStr("en = 'Dates offset';es_CO = 'Fechas de compensación'"));
	
	Result.Insert(Lower("CreateDatabase"),
		NStr("en = 'Create database';es_CO = 'Crear la base de datos'"));
	
	Result.Insert(Lower("LockMessage"),
		NStr("en = 'Lock message';es_CO = 'Mensaje de bloquo'"));
	
	Result.Insert(Lower("ExternalSessionManagementConnectionString"),
		NStr("en = 'String of external session management parameters';es_CO = 'Línea con los parámetros de gestión de sesiones externas'"));
	
	Result.Insert(Lower("DBMS"),
		NStr("en = 'DBMS';es_CO = 'Sistema de gestión de bases de datos (DBMS)'"));
	
	Result.Insert(Lower("ConnectionsSecurityLevel"),
		NStr("en = 'Connection security level';es_CO = 'Nivel de seguridad de la conexión'"));
	
	// _$InfoBase$_.ConfigUpdate*
	Result.Insert(Lower("Vendor"),
		NStr("en = 'Vendor';es_CO = 'Vendedor'"));
	
	// _$InfoBase$_.ConfigExtensionUpdate
	Result.Insert(Lower("Version"),
		NStr("en = 'Version';es_CO = 'Versión'"));
	
	// _$InfoBase$_.DBConfigUpdate
	Result.Insert(Lower("ExclusiveMode"),
		NStr("en = 'Exclusive mode';es_CO = 'Modo exclusivo'"));
	
	// _$InfoBase$_.DBConfigExtension*
	Result.Insert(Lower("Active"),
		NStr("en = 'Active';es_CO = 'Activo'"));
	
	Result.Insert(Lower("SafeMode"),
		NStr("en = 'Safe mode';es_CO = 'Modo seguro'"));
	
	Result.Insert(Lower("SecurityProfile"),
		NStr("en = 'Security profile';es_CO = 'Perfil de seguridad'"));
	
	Result.Insert(Lower("UseDefaultRolesForAllUsers"),
		NStr("en = 'Use main roles for all users';es_CO = 'Utilizar los roles principales para todos los usuarios'"));
	
	Result.Insert(Lower("UsedInDistributedInfoBase"),
		NStr("en = 'Used in a distributed infobase';es_CO = 'Utilizado en la base de información distribuida'"));
	
	Result.Insert(Lower("Purpose"),
		NStr("en = 'Used on';es_CO = 'Usado en'"));
	
	Result.Insert(Lower("Scope"),
		NStr("en = 'Scope';es_CO = 'Alcance'"));
	
	Result.Insert(Lower("DefaultRoles"),
		NStr("en = 'Default roles';es_CO = 'Roles por defecto'"));
	
	Result.Insert(Lower("Synonym"),
		NStr("en = 'Synonym';es_CO = 'Sinónimo'"));
	
	Result.Insert(Lower("UUID"),
		NStr("en = 'UUID';es_CO = 'Identificador único universal (UUID)'"));
	
	Result.Insert(Lower("HashSum"),
		NStr("en = 'Hash';es_CO = 'Hash'"));
	
	// _$InfoBase$_.EventLogReduce
	Result.Insert(Lower("Date"),
		NStr("en = 'Date';es_CO = 'Fecha'"));
	
	// _$InfoBase$_.EventLogSettingsUpdateError
	Result.Insert(Lower("Levels"),
		NStr("en = 'Levels';es_CO = 'Niveles'"));
	
	Result.Insert(Lower("SeparationPeriod"),
		NStr("en = 'Separation period';es_CO = 'Período de separación'"));
	
	Result.Insert(Lower("EventLogFormat"),
		NStr("en = 'Event log format';es_CO = 'Formato del registro de eventos'"));
	
	Result.Insert(Lower("EventName"),
		NStr("en = 'Event name';es_CO = 'Nombre del evento'"));
	
	Result.Insert(Lower("RegistrableEvent"),
		NStr("en = 'Event loggable';es_CO = 'Evento registrable'"));
	
	// _$InfoBase$_.ExclusiveModeChange
	Result.Insert(Lower("AllowTerminationAtSessionStart"),
		NStr("en = 'Allow exit on startup';es_CO = 'Permitir salida al iniciar'"));
	
	// _$InfoBase$_.ParametersUpdate
	Result.Insert(Lower("DataLockTimeout"),
		NStr("en = 'Data lock wait time';es_CO = 'Tiempo de espera para el bloqueo de datos'"));
	
	Result.Insert(Lower("UserPasswordsMaxLifetime"),
		NStr("en = 'Maximum password lifetime';es_CO = 'Duración máxima de la contraseña'"));
	
	Result.Insert(Lower("UserPasswordsMinLifetime"),
		NStr("en = 'Minimum password lifetime';es_CO = 'Duración mínima de la contraseña'"));
	
	Result.Insert(Lower("UserPasswordsMinLength"),
		NStr("en = 'Minimum password length';es_CO = 'Longitud mínima de la contraseña'"));
	
	Result.Insert(Lower("UserPasswordReuseLimit"),
		NStr("en = 'Prevent re-use of recent passwords';es_CO = 'Prevenir la reutilización de contraseñas recientes'"));
	
	Result.Insert(Lower("UserPasswordComplexityCheck"),
		NStr("en = 'Password complexity check';es_CO = 'Comprobación de la complejidad de la contraseña'"));
	
	Result.Insert(Lower("UserPasswordExpirationNotificationPeriod"),
		NStr("en = 'Password expiration notification lead';es_CO = 'Lead con la notificación de expiración de contraseña'"));
	
	Result.Insert(Lower("PassiveSessionHibernateTime"),
		NStr("en = 'Idle session sleep timeout';es_CO = 'Tiempo de espera para suspender una sesión inactiva'"));
	
	Result.Insert(Lower("HibernateSessionTerminateTime"),
		NStr("en = 'Sleeping session termination timeout';es_CO = 'Tiempo de espera para finalizar una sesión suspendida'"));
	
	Result.Insert(Lower("InactiveSessionTerminationTime"),
		NStr("en = 'Inactive session termination timeout';es_CO = 'Tiempo de espera para finalizar una sesión inactiva'"));
	
	Result.Insert(Lower("NotificationLeadTimeBeforeInactiveSessionTermination"),
		NStr("en = 'Lead time for inactive session termination notification';es_CO = 'Plazo de entrega para la notificación de finalización de sesión inactiva'"));
	
	Result.Insert(Lower("TotalRecalcJobCount"),
		NStr("en = 'Number of totals recalculation tasks';es_CO = 'Número de tareas para el recálculo de totales'"));
	
	Result.Insert(Lower("MaxUnsuccessfulAttemptsCount"),
		NStr("en = 'Limit of unsuccessful attempts';es_CO = 'Límite de intentos fallidos'"));
	
	Result.Insert(Lower("LockDuration"),
		NStr("en = 'Lock duration';es_CO = 'Duración del bloqueo'"));
	
	Result.Insert(Lower("UserNameAdditionCodes"),
		NStr("en = 'Username addition codes';es_CO = 'Códigos para añadir el nombre de usuario'"));
	
	// _$InfoBase$_.RegionalSettingsChange
	Result.Insert(Lower("UseCurrentSessionSettings"),
		NStr("en = 'Use current session settings';es_CO = 'Usar la configuración de sesión actual'"));
	
	Result.Insert(Lower("LocalizationCode"),
		NStr("en = 'Localization code';es_CO = 'Código de localización'"));
	
	Result.Insert(Lower("FirstDayOfWeek"),
		NStr("en = 'First day of the week';es_CO = 'Primer día de la semana'"));
	
	Result.Insert(Lower("BooleanTruePresentation"),
		NStr("en = 'Logical ""True"" presentation';es_CO = 'Presentación lógica ""True""'"));
	
	Result.Insert(Lower("BooleanFalsePresentation"),
		NStr("en = 'Logical ""False"" presentation';es_CO = 'Presentación lógica ""False""'"));
	
	Result.Insert(Lower("NegativeNumberPresentation"),
		NStr("en = 'Negative numbers presentation';es_CO = 'Presentación de números negativos'"));
	
	Result.Insert(Lower("NumbersDigitGroupSeparator"),
		NStr("en = 'Digit grouping separator';es_CO = 'Separador de agrupación de dígitos'"));
	
	Result.Insert(Lower("NumbersDecimalSeparator"),
		NStr("en = 'Decimal separator';es_CO = 'Separador decimal'"));
	
	Result.Insert(Lower("NumbersDigitGroupFormat"),
		NStr("en = 'Digit grouping format';es_CO = 'Formato de agrupación de dígitos'"));
	
	Result.Insert(Lower("TimePresentationFormat"),
		NStr("en = 'Time format';es_CO = 'Formato de hora'"));
	
	Result.Insert(Lower("DatePresentationFormat"),
		NStr("en = 'Date format';es_CO = 'Formato de fecha'"));
	
	// _$InfoBase$_.RoleUpdate
	Result.Insert(Lower("Rights"),
		NStr("en = 'Access rights';es_CO = 'Derechos de acceso'"));
	
	Result.Insert(Lower("AccessEnabled"),
		NStr("en = 'Access granted';es_CO = 'Acceso concedido'"));
	
	Result.Insert(Lower("AccessDisabled"),
		NStr("en = 'Access denied';es_CO = 'Acceso denegado'"));
	
	Result.Insert(Lower("Restrictions"),
		NStr("en = 'Restrictions';es_CO = 'Restricciones'"));
	
	Result.Insert(Lower("RestrictionTemplates"),
		NStr("en = 'Restriction templates';es_CO = 'Plantillas de restricción'"));
	
	Result.Insert(Lower("ItemsAdded"),
		NStr("en = 'Added';es_CO = 'Añadido'"));
	
	Result.Insert(Lower("ItemsChanged"),
		NStr("en = 'Modified';es_CO = 'Modificado'"));
	
	Result.Insert(Lower("ItemsDeleted"),
		NStr("en = 'Deleted';es_CO = 'Borrado'"));
	
	Result.Insert(Lower("Description"),
		NStr("en = 'Description';es_CO = 'Descripción'"));
	
	Result.Insert(Lower("TemplateText"),
		NStr("en = 'Template text';es_CO = 'Texto de plantilla'"));
	
	// _$InfoBase$_.SecurityProfileChange
	Result.Insert(Lower("ClusterAdmin"),
		NStr("en = 'Cluster administrator';es_CO = 'Administrador del clúster'"));
	
	Result.Insert(Lower("CryptoAvailable"),
		NStr("en = 'Access to cryptography';es_CO = 'Acceso a la criptografía'"));
	
	Result.Insert(Lower("ModulesAvailableForExtension"),
		NStr("en = 'Extensible modules';es_CO = 'Módulos extensibles'"));
	
	Result.Insert(Lower("ModulesNotAvailableForExtension"),
		NStr("en = 'Non-extensible modules';es_CO = 'Módulos no extensibles'"));
	
	Result.Insert(Lower("COMObjectFullAccess"),
		NStr("en = 'Full access to COM objects';es_CO = 'Acceso completo a los objetos COM'"));
	
	Result.Insert(Lower("AddInFullAccess"),
		NStr("en = 'Full access to add-ins';es_CO = 'Acceso completo a los complementos'"));
	
	Result.Insert(Lower("ExternalModuleFullAccess"),
		NStr("en = 'Full access to external modules';es_CO = 'Acceso completo a los módulos externos'"));
	
	Result.Insert(Lower("ExternalApplicationsFullAccess"),
		NStr("en = 'Unlimited access to external apps';es_CO = 'Acceso ilimitado a las aplicaciones externas'"));
	
	Result.Insert(Lower("InternetResourcesFullAccess"),
		NStr("en = 'Full access to online resources';es_CO = 'Acceso completo a los recursos en línea'"));
	
	Result.Insert(Lower("FileSystemFullAccess"),
		NStr("en = 'Full access to file system';es_CO = 'Acceso completo al sistema de archivos'"));
	
	Result.Insert(Lower("FullPrivilegedMode"),
		NStr("en = 'Unlimited privileged mode';es_CO = 'Modo privilegiado ilimitado'"));
	
	Result.Insert(Lower("SafeModeProfile"),
		NStr("en = 'Security mode profile';es_CO = 'Perfil del modo de seguridad'"));
	
	Result.Insert(Lower("AllowExternalCodeExecutionInUnsafeMode"),
		NStr("en = 'Allow executing external code in unsafe mode';es_CO = 'Permitir la ejecución del código externo en el modo inseguro'"));
	
	Result.Insert(Lower("AllowAccessRightsExtension"),
		NStr("en = 'Allow extension of access rights';es_CO = 'Permitir la extensión de los derechos de acceso'"));
	
	Result.Insert(Lower("AccessRightsExtensionLimitingRoles"),
		NStr("en = 'Roles that restrict extension of access rights';es_CO = 'Roles que restringen la extensión de los derechos de acceso'"));
	
	Result.Insert(Lower("PrivilegedModeRoles"),
		NStr("en = 'Privileged mode roles';es_CO = 'Roles del modo privilegiado'"));
	
	Result.Insert(Lower("AllowedCOMClasses"),
		NStr("en = 'Allowed COM classes';es_CO = 'Clases COM permitidas'"));
	
	Result.Insert(Lower("AllowedVirtualDirs"),
		NStr("en = 'Allowed virtual directories';es_CO = 'Directorios virtuales permitidos'"));
	
	Result.Insert(Lower("WritingAllowed"),
		NStr("en = 'Writing is allowed';es_CO = 'Está permitido escribir'"));
	
	Result.Insert(Lower("Alias"),
		NStr("en = 'Alias';es_CO = 'Alias'"));
	
	Result.Insert(Lower("ReadingAllowed"),
		NStr("en = 'Reading is allowed';es_CO = 'Está permitido leer'"));
	
	Result.Insert(Lower("AllowedAddIns"),
		NStr("en = 'Allowed add-ins';es_CO = 'Complementos permitidos'"));
	
	Result.Insert(Lower("AllowedExternalModules"),
		NStr("en = 'Allowed external modules';es_CO = 'Módulos externos permitidos'"));
	
	Result.Insert(Lower("AllowedExternalApps"),
		NStr("en = 'Allowed external apps';es_CO = 'Aplicaciones externas permitidas'"));
	
	Result.Insert(Lower("AllowedInternetResources"),
		NStr("en = 'Allowed internet resources';es_CO = 'Recursos de Internet permitidos'"));
	
	Result.Insert(Lower("Address"),
		NStr("en = 'Address';es_CO = 'Dirección'"));
	
	Result.Insert(Lower("Port"),
		NStr("en = 'Port';es_CO = 'Puerto'"));
	
	Result.Insert(Lower("Protocol"),
		NStr("en = 'Protocol';es_CO = 'Protocolo'"));
	
	Result.Insert(Lower("PrivilegedModeAllowed"),
		NStr("en = 'Allow setting privileged mode';es_CO = 'Permitir configurar el modo privilegiado'"));
	
	// _$InfoBase$_.SessionLockChange*
	Result.Insert(Lower("KeyCode"),
		NStr("en = 'Access code';es_CO = 'Código de acceso'"));
	
	Result.Insert(Lower("End"),
		NStr("en = 'End';es_CO = 'Fin'"));
	
	Result.Insert(Lower("Parameter"),
		NStr("en = 'Parameter';es_CO = 'Parámetro'"));
	
	Result.Insert(Lower("Message"),
		NStr("en = 'Message';es_CO = 'Mensaje'"));
	
	Result.Insert(Lower("Use"),
		NStr("en = 'Set';es_CO = 'Configurar'"));
	
	// _$InfoBase$_.UserPasswordPolicy*
	Result.Insert(Lower("PasswordMaxEffectivePeriod"),
		NStr("en = 'Maximum password lifetime';es_CO = 'Duración máxima de la contraseña'"));
	
	Result.Insert(Lower("PasswordMinEffectivePeriod"),
		NStr("en = 'Minimum password lifetime';es_CO = 'Duración mínima de la contraseña'"));
	
	Result.Insert(Lower("PasswordMinLength"),
		NStr("en = 'Minimum password length';es_CO = 'Longitud mínima de la contraseña'"));
	
	Result.Insert(Lower("PasswordReuseLimit"),
		NStr("en = 'Prevent re-use of recent passwords';es_CO = 'Prevenir la reutilización de contraseñas recientes'"));
	
	Result.Insert(Lower("PasswordStrengthCheck"),
		NStr("en = 'Password complexity check';es_CO = 'Comprobación de la complejidad de la contraseña'"));
	
	Result.Insert(Lower("PasswordExpirationNotificationPeriod"),
		NStr("en = 'Password expiration notification lead';es_CO = 'Lead con la notificación de expiración de contraseña'"));
	
	Result.Insert(Lower("ActionUponAuthenticationIfPasswordsNonCompliant"),
		NStr("en = 'Action if password doesn''t meet requirements';es_CO = 'Acción si la contraseña no cumple los requisitos'"));
	
	Result.Insert(Lower("PasswordCompromiseCheck"),
		NStr("en = 'Leaked password check';es_CO = 'Comprobación de contraseña fugada'"));
	
	// _$OpenIDProvider$_.*
	Result.Insert(Lower("RelyingPartyURL"),
		NStr("en = 'Relying party URL';es_CO = 'URL de parte confiable'"));
	
	// _$Session$_.Authentication*
	Result.Insert(Lower("CurrentOSUser"),
		NStr("en = 'Current OS user';es_CO = 'Usuario del sistema operativo actual'"));
	
	Result.Insert(Lower("AuthenticationMethod"),
		NStr("en = 'Authentication method';es_CO = 'Método de autentificación'"));
	
	Result.Insert(Lower("UsernameAdditionCode"),
		NStr("en = 'Username addition code';es_CO = 'Código de adición del nombre de usuario'"));
	
	Result.Insert(Lower("UserIDAtOpenIDProvider"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 provider user ID';es_CO = 'Identificador de usuario del proveedor %1'"), "OpenID"));
	
	Result.Insert(Lower("IssuerOfAccessToken"),
		NStr("en = 'Access token emitter';es_CO = 'Emisor del token de acceso'"));
	
	Result.Insert(Lower("AccessTokenID"),
		NStr("en = 'Access token ID';es_CO = 'Identificador del token de acceso'"));
	
	Result.Insert(Lower("OpenIDProviderURL"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 provider URL';es_CO = 'URL del proveedor %1'"), "OpenID"));
	
	// _$Session$_.ExternalDataProcessorConnect*
	Result.Insert(Lower("Path"),
		NStr("en = 'Path';es_CO = 'Ruta'"));
	
	Result.Insert(Lower("LanguageCode"),
		NStr("en = 'Language code';es_CO = 'Código de idioma'"));
	
	// _$Session$_.AddInAttach*
	Result.Insert(Lower("Location"),
		NStr("en = 'Location';es_CO = 'Ubicación'"));
	
	Result.Insert(Lower("Type"),
		NStr("en = 'Type';es_CO = 'Tipo'"));
	
	Result.Insert(Lower("AttachmentType"),
		NStr("en = 'Connection type';es_CO = 'Tipo de conexión'"));
	
	// _$User$_.*
	Result.Insert(Lower("Email"),
		NStr("en = 'Email address';es_CO = 'Correo electrónico'"));
	
	Result.Insert(Lower("OpenIDAuthentication"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 authentication';es_CO = '%1 autenticación'"), "OpenID"));
	
	Result.Insert(Lower("OpenIDConnectAuthentication"),
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 authentication';es_CO = '%1 autenticación'"), "OpenID-Connect"));
	
	Result.Insert(Lower("QRCodeAuthentication"),
		NStr("en = 'QR code authentication';es_CO = 'Autenticación por el código QR'"));
	
	Result.Insert(Lower("OSAuthentication"),
		NStr("en = 'OS authentication';es_CO = 'Autenticación OS'"));
	
	Result.Insert(Lower("StandardAuthentication"),
		NStr("en = '1C:Enterprise authentication';es_CO = 'Autenticación en 1C:Enterprise'"));
	
	Result.Insert(Lower("AccessTokenAuthentication"),
		NStr("en = 'Access token authentication';es_CO = 'Autenticación por el token de acceso'"));
	
	Result.Insert(Lower("PasswordSettingDate"),
		NStr("en = 'Password set date';es_CO = 'Fecha de configuración de la contraseña'"));
	
	Result.Insert(Lower("CannotRecoveryPassword"),
		NStr("en = 'User cannot recover password';es_CO = 'El usuario no puede recuperar la contraseña'"));
	
	Result.Insert(Lower("CannotChangePassword"),
		NStr("en = 'User cannot change password';es_CO = 'El usuario no está autorizado para cambiar la contraseña'"));
	
	Result.Insert(Lower("UnsafeActionProtection"),
		NStr("en = 'Unsafe action protection';es_CO = 'Protección contra las acciones inseguras'"));
	
	Result.Insert(Lower("Name"),
		NStr("en = 'Name';es_CO = 'Nombre'"));
	
	Result.Insert(Lower("PasswordPolicyName"),
		NStr("en = 'Password policy name';es_CO = 'Nombre de la política de contraseñas'"));
	
	Result.Insert(Lower("UserMapKeys"),
		NStr("en = 'User map keys';es_CO = 'Claves del mapa de usuarios'"));
	
	Result.Insert(Lower("SecondAuthenticationFactorSettings"),
		NStr("en = 'Second authentication factor settings';es_CO = 'Configuración del segundo factor de autenticación'"));
	
	Result.Insert(Lower("SecondAuthenticationFactorSettingsProcessing"),
		NStr("en = 'Second authentication factor settings processing';es_CO = 'Procesamiento de la configuración del segundo factor de autenticación'"));
	
	Result.Insert(Lower("PasswordChanged"),
		NStr("en = 'Password is changed';es_CO = 'Contraseña cambiada'"));
	
	Result.Insert(Lower("PasswordNonCompliant"),
		NStr("en = 'Password does not meet requirements';es_CO = 'La contraseña no cumple los requisitos'"));
	
	Result.Insert(Lower("PasswordIsSet"),
		NStr("en = 'Password is set';es_CO = 'La contraseña está configurada'"));
	
	Result.Insert(Lower("ShowInList"),
		NStr("en = 'Show in list';es_CO = 'Mostrar en la lista'"));
	
	Result.Insert(Lower("FullName"),
		NStr("en = 'Full name';es_CO = 'Nombre completo'"));
	
	Result.Insert(Lower("OSUser"),
		NStr("en = 'OS user';es_CO = 'OS Usuario'"));
	
	Result.Insert(Lower("RunMode"),
		NStr("en = 'Run mode';es_CO = 'Modo de ejecución'"));
	
	Result.Insert(Lower("DefaultInterface"),
		NStr("en = 'Main interface';es_CO = 'Interfaz principal'"));
	
	Result.Insert(Lower("Roles"),
		NStr("en = 'Roles';es_CO = 'Roles'"));
	
	Result.Insert(Lower("PasswordHashAlgorithmType"),
		NStr("en = 'Password hashing algorithm type';es_CO = 'Tipo de algoritmo de hash de contraseña'"));
	
	Result.Insert(Lower("Language"),
		NStr("en = 'Language';es_CO = 'Idioma'"));
	
	Result.Insert(Lower("Users"),
		NStr("en = 'Users';es_CO = 'Usuarios'"));
	
	Result.Insert(Lower("DataSeparation"),
		NStr("en = 'Data separation';es_CO = 'Separación de datos'"));
	
	Return Result;
	
EndFunction

// Returns:
//  Boolean
//
Function StandardSeparatorsOnly() Export
	
	If Not Common.SubsystemExists(
			"StandardSubsystems.SaaSOperations.CoreSaaS") Then
		Return False;
	EndIf;
	
	ModuleSaaSSSL = Common.CommonModule("SaaSOperationsSSL");
	
	Return ModuleSaaSSSL.StandardSeparatorsOnly();
	
EndFunction

Function StringDelimitersList(SeparatorLine) Export
	
	List = New ValueList;
	Values = StrSplit(SeparatorLine, ",");
	List.LoadValues(Values);
	
	ListItem = List.FindByValue("");
	If ListItem <> Undefined Then
		ListItem.Presentation = NStr("en = '<Not set>';es_CO = '<Not set>'");
	EndIf;
	
	Return List;
	
EndFunction

// Filter transformation.
//
// Parameters:
//  Filter - Filter - the filter to be passed.
//
Procedure FilterTransformation(Filter, ServerTimeOffset)
	
	For Each FilterElement In Filter Do
		If TypeOf(FilterElement.Value) = Type("ValueList") Then
			FilterItemTransform(Filter, FilterElement);
		ElsIf Upper(FilterElement.Key) = Upper("Transaction") Then
			If StrFind(FilterElement.Value, "(") = 0 Then
				Filter.Insert(FilterElement.Key, "(" + FilterElement.Value);
			EndIf;
		ElsIf ServerTimeOffset <> 0
			And (Upper(FilterElement.Key) = Upper("StartDate") Or Upper(FilterElement.Key) = Upper("EndDate")) Then
			Filter.Insert(FilterElement.Key, FilterElement.Value + ServerTimeOffset);
		EndIf;
	EndDo;
	
EndProcedure

// Filter item transformation.
//
// Parameters:
//  Filter - Filter - the filter to be passed.
//  Filter - FilterElement - an item of the filter to be passed.
//
Procedure FilterItemTransform(Filter, FilterElement)
	
	FilterStructureKey = FilterElement.Key;
	// The procedure is called when the filter item is a value list
	// (the filter should take an array). Convert the list into an array.
	If Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
		NewValue = New Structure;
	Else
		NewValue = New Array;
	EndIf;
	
	FilterStructureKey = FilterElement.Key;
	
	For Each ValueFromList In FilterElement.Value Do
		If Upper(FilterStructureKey) = Upper("Level") Then
			// Message text level is a string, it must be converted into an enumeration.
			NewValue.Add(DataProcessors.EventLog.EventLogLevelValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("TransactionStatus") Then
			// Transaction status is a string, it must be converted into an enumeration.
			NewValue.Add(DataProcessors.EventLog.EventLogEntryTransactionStatusValueByName(ValueFromList.Value));
		ElsIf Upper(FilterStructureKey) = Upper("SessionDataSeparation") Then
			SeparatorValueArray = New Array;
			FilterStructureKey = "SessionDataSeparation";
			DataSeparationArray = StrSplit(ValueFromList.Value, "=", True);
			
			SeparatorValues = StrSplit(DataSeparationArray[1], ",", True);
			For Each SeparatorValue In SeparatorValues Do
				If Not ValueIsFilled(SeparatorValue) Then
					SeparatorValue = Undefined;
				Else
					SeparatorValue = Number(SeparatorValue);
				EndIf;
				SeparatorFilterItem = New Structure("Value, Use",
					SeparatorValue, SeparatorValue <> Undefined);
				SeparatorValueArray.Add(SeparatorFilterItem);
			EndDo;
			
			NewValue.Insert(DataSeparationArray[0], SeparatorValueArray);
			
		ElsIf Upper(FilterStructureKey) = Upper("User") Then
			If StringFunctionsClientServer.IsUUID(ValueFromList.Value) Then
				IBUserID = New UUID(ValueFromList.Value);
				SetPrivilegedMode(True);
				IBUser = InfobaseUserForFilter(IBUserID);
				SetPrivilegedMode(False);
			Else
				IBUser = Undefined;
			EndIf;
			If IBUser = Undefined Then
				NewValue.Add(ValueFromList.Presentation);
			Else
				NewValue.Add(IBUser);
			EndIf;
			
		ElsIf Upper(FilterStructureKey) = Upper("Data") Then
			Value = ValueFromList.Value;
			If Common.IsReference(TypeOf(Value)) Then
				NewValue.Add(ValueToStringInternal(Value));
			ElsIf ValueIsFilled(ValueFromList.Presentation) Then
				EventData = EventData(ValueFromList.Value);
				If EventData <> Undefined Then
					Value = EventData;
				EndIf;
			EndIf;
			NewValue.Add(Value);
		Else
			NewValue.Add(ValueFromList.Value);
		EndIf;
	EndDo;
	
	If TypeOf(NewValue) = Type("Array") And NewValue.Count() = 1 Then
		NewValue = NewValue[0];
	EndIf;
	
	Filter.Insert(FilterElement.Key, NewValue);
	
EndProcedure

// Adds a restriction to the filter presentation.
//
// Parameters:
//  EventLogFilter - Filter - the event log filter.
//  FilterPresentation - String - filter presentation.
//  RestrictionName - String - the name of the restriction.
//  DefaultEventLogFilter - Filter - the default event log filter.
//
Procedure AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, RestrictionName,
	DefaultEventLogFilter = Undefined)
	
	If Not EventLogFilter.Property(RestrictionName) Then
		Return;
	EndIf;
	
	RestrictionList = EventLogFilter[RestrictionName];
	Restriction       = "";
	
	// If filter value is a default value there is no need to get a presentation of it.
	If DefaultEventLogFilter <> Undefined Then
		DefaultRestrictionList = "";
		If DefaultEventLogFilter.Property(RestrictionName, DefaultRestrictionList) Then
			If ValueToStringInternal(DefaultRestrictionList) = ValueToStringInternal(RestrictionList) Then
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	If RestrictionName = "Event" And RestrictionList.Count() > 5 Then
		
		Restriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Events (%1)';es_CO = 'Eventos (%1)'"), RestrictionList.Count());
		
	ElsIf RestrictionName = "Session" And RestrictionList.Count() > 3 Then
		
		Restriction = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Sessions (%1)';es_CO = 'Sesiones (%1)'"), RestrictionList.Count());
		
	Else
		
		For Each ListItem In RestrictionList Do
			If Not IsBlankString(Restriction) Then
				Restriction = Restriction + ", ";
			EndIf;
			
			If Not ValueIsFilled(ListItem.Presentation) Then
				RestrictionValue = ListItem.Value;
			Else
				RestrictionValue = ListItem.Presentation;
			EndIf;
			
			If (Upper(RestrictionName) = Upper("Session")
				Or Upper(RestrictionName) = Upper("Level"))
				And IsBlankString(Restriction) Then
				
				If RestrictionName = "Session" Then
					RestrictionPresentation = NStr("en = 'Session';es_CO = 'Sesión'");
				Else
					RestrictionPresentation = NStr("en = 'Level';es_CO = 'Nivel'");
				EndIf;
				
				Restriction = NStr("en = '%1: %2';es_CO = '%1: %2'");
				Restriction = StringFunctionsClientServer.SubstituteParametersToString(Restriction, RestrictionPresentation, RestrictionValue);
			Else
				Restriction = Restriction + RestrictionValue;
			EndIf;
		EndDo;
		
	EndIf;
	
	If Not IsBlankString(FilterPresentation) Then 
		FilterPresentation = FilterPresentation + "; ";
	EndIf;
	
	FilterPresentation = FilterPresentation + Restriction;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For internal use only.
//
Procedure SetDataString(LogEvent)
	
	DataAsStr = ValueToStringInternal(LogEvent.Data);
	RefinedString = CommonClientServer.ReplaceProhibitedXMLChars(DataAsStr);
	
	If DataAsStr <> RefinedString Then
		Try
			ValueFromStringInternal(RefinedString);
			DataAsStr = RefinedString;
		Except
			DataAsStr = "";
		EndTry;
	EndIf;
	
	LogEvent.DataAsStr = DataAsStr;
	
EndProcedure

Function EventLevelByPresentation(LevelPresentation)
	If LevelPresentation = "Information" Then
		Return EventLogLevel.Information;
	ElsIf LevelPresentation = "Error" Then
		Return EventLogLevel.Error;
	ElsIf LevelPresentation = "Warning" Then
		Return EventLogLevel.Warning; 
	ElsIf LevelPresentation = "Note" Then
		Return EventLogLevel.Note;
	EndIf;	
EndFunction

#EndRegion
