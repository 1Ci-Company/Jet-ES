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

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		
		ModuleSafeModeManager   = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
		
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipBasicFillingCheck") Then
	
		If Not SequenceNumberUnique(FillOrder, Ref) Then
			ErrorText = NStr("en = 'The filling order is not unique. A volume with this order already exists.';es_CO = 'El orden de llenado no es único. Ya existe un volumen con este orden.'");
			Common.MessageToUser(ErrorText, , "FillOrder", "Object", Cancel);
		EndIf;
		
		If MaximumSize <> 0 Then
			CurrentSizeInBytes = 0;
			If Not Ref.IsEmpty() Then
				CurrentSizeInBytes = FilesOperationsInVolumesInternal.VolumeSize(Ref);
			EndIf;
			ActualSize = CurrentSizeInBytes / (1024 * 1024);
			
			If MaximumSize < ActualSize Then
				ErrorText = NStr("en = 'The volume size limit is less than the current size.';es_CO = 'El límite de tamaño del volumen es menor que el tamaño actual.'");
				Common.MessageToUser(ErrorText, , "MaximumSize", "Object", Cancel);
			EndIf;
		EndIf;
		
		If IsBlankString(FullPathWindows) And IsBlankString(FullPathLinux) Then
			ErrorText = NStr("en = 'The full path is required.';es_CO = 'Se requiere la ruta completa.'");
			Common.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
			Common.MessageToUser(ErrorText, , "FullPathLinux",   "Object", Cancel);
			Return;
		EndIf;
		
		PathsToVolumes = Common.ObjectAttributesValues(Ref, "FullPathLinux, FullPathWindows");
		CheckTheUniquenessOfPaths = PathsToVolumes.FullPathLinux <> FullPathLinux 
										Or PathsToVolumes.FullPathWindows <> FullPathWindows;
		If CheckTheUniquenessOfPaths Then
			CheckTheUniquenessOfThePathToTheVolumes(Cancel); 
		EndIf;
		
		If Not UseSecurityProfiles
		   And Not IsBlankString(FullPathWindows)
		   And (    Left(FullPathWindows, 2) <> "\\"
		      Or StrFind(FullPathWindows, ":") <> 0 ) Then
			
			ErrorText = NStr("en = 'The volume path must be in the UNC format (\\servername\resource).';es_CO = 'La ruta del volumen debe estar en el formato UNC (\\servername\resource).'");
			Common.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
			Return;
		EndIf;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipDirectoryAccessCheck") Then
		
		FullPathFieldName = ?(Common.IsWindowsServer(), "FullPathWindows", "FullPathLinux");
		If Common.DataSeparationEnabled() Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			SeparatorValue = ?(ModuleSaaSOperations.SessionSeparatorUsage(),
				ModuleSaaSOperations.SessionSeparatorValue(), "");
		Else
			SeparatorValue = "";
		EndIf;
		
		FullVolumePath = StrReplace(ThisObject[FullPathFieldName], "%z", SeparatorValue);
		TestDirectoryName = FullVolumePath + "CheckAccess" + GetPathSeparator();
		
		Try
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			ErrorInfo = ErrorInfo();
			
			If UseSecurityProfiles Then
				ErrorTemplate =
					NStr("en = 'The volume path is invalid or the server with the volume is currently unavailable.
					           |Check if the path to the shared folder is correct and the server is available.
					           |Security profile permissions might not be configured,
					           |or an account on whose behalf
					           |1C:Enterprise server is running might have no access rights to the volume directory.
					           |
					           |%1';es_CO = 'La ruta del volumen no es válida o el servidor con el volumen no está disponible actualmente.
					           | Compruebe si la ruta a la carpeta compartida es correcta y si el servidor está disponible.
					           | Es posible que los permisos del perfil de seguridad no estén configurados,
					           | o una cuenta en cuyo nombre se está ejecutando el servidor 
					           | 1C: Enterprise es posible que no tenga derechos de acceso al catálogo del volumen.
					           |
					           |%1'");
			Else
				ErrorTemplate =
					NStr("en = 'The volume path is invalid or the server with the volume is currently unavailable.
					           |Check if the path to the shared folder is correct and the server is available.
					           |An account on whose behalf 1C:Enterprise server is running
					           |might have no access rights to the volume directory.
					           |
					           |%1';es_CO = 'La ruta del volumen no es válida o el servidor con el volumen no está disponible actualmente.
					           | Compruebe si la ruta a la carpeta compartida es correcta y si el servidor está disponible.
					           | Una cuenta en cuyo nombre se ejecuta el servidor 1C:Enterprise 
					           | podría no tener derechos de acceso al catálogo del volumen.
					           |
					           |%1'");
			EndIf;
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorTemplate, ErrorProcessing.BriefErrorDescription(ErrorInfo));
			
			Common.MessageToUser(
				ErrorText, , FullPathFieldName, "Object", Cancel);
		EndTry;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns False if there is a volume of the same order.
Function SequenceNumberUnique(FillOrder, VolumeRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(Volumes.FillOrder) AS Count
	|FROM
	|	Catalog.FileStorageVolumes AS Volumes
	|WHERE
	|	Volumes.FillOrder = &FillOrder
	|	AND Volumes.Ref <> &VolumeRef";
	
	Query.Parameters.Insert("FillOrder", FillOrder);
	Query.Parameters.Insert("VolumeRef", VolumeRef);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Count = 0;
	EndIf;
	
	Return True;
	
EndFunction

Procedure CheckTheUniquenessOfThePathToTheVolumes(Cancel)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileStorageVolumes.Ref AS Ref,
		|	PRESENTATION(FileStorageVolumes.Ref) AS Presentation,
		|	FileStorageVolumes.FullPathWindows AS FullPathWindows,
		|	FileStorageVolumes.FullPathLinux AS FullPathLinux
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes
		|WHERE
		|	NOT FileStorageVolumes.DeletionMark";
		
	QueryResult = Query.Execute();
	ResultTable2 = QueryResult.Unload();
	ResultTable2.Indexes.Add("FullPathLinux");
	ResultTable2.Indexes.Add("FullPathWindows");
	
	ErrorTemplate = NStr("en = 'The volume path must be unique. The directory is specified in the %1 volume.';es_CO = 'La ruta del volumen debe ser única. El catálogo se especifica en el %1 volumen.'");
	If ValueIsFilled(FullPathLinux) Then
		For Each Volume In ResultTable2.FindRows(New Structure("FullPathLinux", FullPathLinux)) Do
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, Volume.Presentation);
			Common.MessageToUser(ErrorText, , "FullPathLinux", "Object", Cancel);
		EndDo;
	EndIf;
	
	If ValueIsFilled(FullPathWindows) Then
		For Each Volume In ResultTable2.FindRows(New Structure("FullPathWindows", FullPathWindows)) Do
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, Volume.Presentation);
			Common.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
		EndDo;
	EndIf;
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';es_CO = 'Invalidar la llamada de objeto al cliente.'");
#EndIf