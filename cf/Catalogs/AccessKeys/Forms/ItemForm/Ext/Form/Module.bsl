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
	
	ReadOnly = True;
	
	FieldsCompositionDetails = FieldsCompositionDetails(Object.FieldsComposition);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
	ShowMessageBox(,
		NStr("en = 'It is recommended that you do not change the access key as it is mapped to different objects.
		           |To resolve the issue, delete the access key or
		           |delete the mapping between the key and the objects from the registers, and then run the access update.';es_CO = 'Se recomienda que no cambie la clave de acceso ya que está asignada a diferentes objetos.
		           | Para resolver el problema, elimine la clave de acceso o
		           | elimine la asignación entre la clave y los objetos de los registros y luego ejecute la actualización de acceso.'"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function FieldsCompositionDetails(FieldsComposition)
	
	CurrentCount1 = FieldsComposition;
	Details = "";
	
	TabularSectionNumber = 0;
	While CurrentCount1 > 0 Do
		Balance = CurrentCount1 - Int(CurrentCount1 / 16) * 16;
		If TabularSectionNumber = 0 Then
			Details = NStr("en = 'Header';es_CO = 'Encabezado'") + ": " + Balance;
		Else
			Details = Details + ", " + NStr("en = 'Tabular section';es_CO = 'Parte de tabla'") + " " + TabularSectionNumber + ": " + Balance;
		EndIf;
		CurrentCount1 = Int(CurrentCount1 / 16);
		TabularSectionNumber = TabularSectionNumber + 1;
	EndDo;
	
	Return Details;
	
EndFunction

#EndRegion
