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

Procedure BeforeWrite(Cancel)

	If DataExchange.Load Then
		Return;	
	EndIf;
	
	If ValueIsFilled(PerformerRole) Then
		
		Description = String(PerformerRole);
		
		If ValueIsFilled(MainAddressingObject) Then
			Description = Description + ", " + String(MainAddressingObject);
		EndIf;
		
		If ValueIsFilled(AdditionalAddressingObject) Then
			Description = Description + ", " + String(AdditionalAddressingObject);
		EndIf;
	Else
		Description = NStr("en = 'Without role-based assignment';es_CO = 'Sin la asignación basada en roles'");
	EndIf;
	
	// Check for duplicates.
	Query = New Query(
		"SELECT TOP 1
		|	TaskPerformersGroups.Ref
		|FROM
		|	Catalog.TaskPerformersGroups AS TaskPerformersGroups
		|WHERE
		|	TaskPerformersGroups.PerformerRole = &PerformerRole
		|	AND TaskPerformersGroups.MainAddressingObject = &MainAddressingObject
		|	AND TaskPerformersGroups.AdditionalAddressingObject = &AdditionalAddressingObject
		|	AND TaskPerformersGroups.Ref <> &Ref");
	Query.SetParameter("PerformerRole", PerformerRole);
	Query.SetParameter("MainAddressingObject", MainAddressingObject);
	Query.SetParameter("AdditionalAddressingObject", AdditionalAddressingObject);
	Query.SetParameter("Ref", Ref);
	
	If Not Query.Execute().IsEmpty() Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'There is already the task assignee group for which
			           |business role ""%1"",
			           |main business object ""%2"",
			           |and additional business object ""%3"" are set.';es_CO = 'Ya existe el grupo de responsables de tareas para el cual están configurados el
			           |rol de negocio ""%1"", el 
			           |objeto de negocio principal ""%2"" 
			           |y el objeto de negocio adicional ""%3"".'"),
			String(PerformerRole),
			String(MainAddressingObject),
			String(AdditionalAddressingObject)));
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';es_CO = 'Invalidar la llamada de objeto al cliente.'");
#EndIf