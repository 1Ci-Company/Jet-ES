///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Title = NStr("en = 'Update handler';es_CO = 'Manipulador de actualización'") + " " + Record.HandlerName;
	
	If ValueIsFilled(Record.Comment) Then
		Items.GroupComment.Title = NStr("en = 'Comment';es_CO = 'Comentario'") + " *";
	Else
		Items.GroupComment.Title = NStr("en = 'Comment';es_CO = 'Comentario'");
	EndIf;
	
	If ValueIsFilled(Record.ErrorInfo) Then
		Items.GroupErrorInfo.Title = NStr("en = 'Error details';es_CO = 'Detalles del error'") + " *";
	Else
		Items.GroupErrorInfo.Title = NStr("en = 'Error details';es_CO = 'Detalles del error'");
	EndIf;
	
	DataToProcess = NStr("en = 'Open';es_CO = 'Abrir'");
	
	Data = FormAttributeToValue("Record").DataToProcess;
	ProcessedDataStorage = PutToTempStorage(Data, UUID);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_UpdateHandlers", WriteParameters);
EndProcedure

#EndRegion
