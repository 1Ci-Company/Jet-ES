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

	SetConditionalAppearance();
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateRegisterData(Command)
	
	HasChanges = False;
	
	UpdateRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'Updated successfully.';es_CO = 'Actualizado con éxito.'");
	Else
		Text = NStr("en = 'No update required.';es_CO = 'No se requiere actualización.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	ApplyDataGroupAppearance(0, NStr("en = 'Standard Access Values';es_CO = 'Valores de acceso estándar'"));
	ApplyDataGroupAppearance(1, NStr("en = 'Regular or external users';es_CO = 'Usuarios estándar/externos'"));
	ApplyDataGroupAppearance(2, NStr("en = 'Regular or external user groups';es_CO = 'Grupos de usuarios estándar/externos'"));
	ApplyDataGroupAppearance(3, NStr("en = 'Assignee groups';es_CO = 'Grupos de responsables'"));
	ApplyDataGroupAppearance(4, NStr("en = 'Authorization objects';es_CO = 'Objetos de autorización'"));
	
EndProcedure

&AtServer
Procedure ApplyDataGroupAppearance(DataGroup, Text)
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("DataGroup");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DataGroup");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = DataGroup;
	
	AppearanceItem.Appearance.SetParameterValue("Text", Text);
	
EndProcedure

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessValuesGroups.UpdateRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
