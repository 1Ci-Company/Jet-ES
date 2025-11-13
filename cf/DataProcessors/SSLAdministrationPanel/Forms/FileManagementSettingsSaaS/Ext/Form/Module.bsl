///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

// If the "FileOperations" subsystem is not integrated, delete the form from the configuration.
// 

#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MaxFileSize = FilesOperations.MaxFileSizeCommon() / (1024*1024);

	MetadataNamesArray = New Array();
	MetadataNamesArray.Add("InformationRegister.DeleteFilesBinaryData");
	DeleteFilesBinaryDataTableSize = 
		GetDatabaseDataSize(Undefined, MetadataNamesArray) / (1024*1024);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit Then
		RefreshApplicationInterface();
	EndIf;
	
EndProcedure

#EndRegion 

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MaxFileSizeOnChange(Item)
	
	If MaxFileSize = 0 Then
		
		MessageText = NStr("en = 'File size limit is required.';es_CO = 'Se requiere el límite de tamaño del archivo.'");
		CommonClient.MessageToUser(MessageText, ,"MaxFileSize");
		Return;
		
	EndIf;
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure DeniedExtensionsListOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure FilesExtensionsListOpenDocumentOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Async Procedure StartDeduplication(Command)
	
	QuestionTitle = NStr("en = 'File deduplication';es_CO = 'Desduplicación de archivos'");
	QueryText = NStr("en = 'With file deduplication, you can save up to 30% of infobase space by removing duplicate files stored in the application (the ""Infobase"" storage option). The process takes minutes to hours, depending on the number of files, and can be paused and resumed at any time. All newly added files are automatically stored as a single instance.
						|
						|During deduplication, the infobase size may increase significantly. Therefore, before initiating the process, ensure that the device hosting the infobase has at least %1 MB of free space and back up the infobase. After completion, compress the infobase for the deduplication to take effect.
						|
						|Do you want to create deduplication jobs for each data area?';es_CO = 'Con la deduplicación de archivos se puede ahorrar hasta un 30% de espacio en la base de información borrando los archivos duplicados que se almacenan en la aplicación (la opción de almacenamiento ""Base de información""). El proceso lleva de minutos a horas, según el número de archivos, y puede pausarse y reanudarse en cualquier momento. Todos los archivos recién añadidos se guardan automáticamente como un solo ejemplar.
						|
						|Durante la deduplicación el tamaño de la base de información puede aumentar significativamente. Así que antes de iniciar el proceso, asegúrese de que el dispositivo que aloja la base de información tenga al menos %1 MB de espacio libre y haga una copia de respaldo de la base de información. Después de la finalización comprima la base de información para que surta efecto la deduplicación.
						|
						|¿Desea crear las tareas de deduplicación para cada área de datos?'");
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, Format(DeleteFilesBinaryDataTableSize, "NFD=2;"));
	
	Response = Await DoQueryBoxAsync(QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.No, QuestionTitle);
	If Response = DialogReturnCode.Yes Then
		RunDeduplicationAtServer();
	EndIf;

EndProcedure

#EndRegion

#Region Private 

&AtClient
Procedure Attachable_OnChangeAttribute(Item, ShouldRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();
	AfterChangeAttribute(ConstantName, ShouldRefreshInterface);
	
EndProcedure

&AtClient
Procedure AfterChangeAttribute(ConstantName, ShouldRefreshInterface = True)
	
	If ShouldRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		
		If DataPathAttribute = "MaxFileSize" Then
			ConstantsSet.MaxFileSize = MaxFileSize * (1024*1024);
			ConstantName = "MaxFileSize";
		EndIf;
		
	Else
		ConstantName = NameParts[1];
	EndIf;
	
	If IsBlankString(ConstantName) Then
		Return "";
	EndIf;
	
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServerNoContext
Procedure RunDeduplicationAtServer()
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.FilesOperationsSaaS") Then
		
		ModuleFilesOperationsInternalSaaS = Common.CommonModule("FilesOperationsInternalSaaS");
		ModuleFilesOperationsInternalSaaS.StartDeduplication();
		
	EndIf;
	
EndProcedure

#EndRegion
