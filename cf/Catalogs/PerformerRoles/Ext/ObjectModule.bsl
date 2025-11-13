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
	
	If Not UsedByAddressingObjects And Not UsedWithoutAddressingObjects Then
		Common.MessageToUser(
			NStr("en = 'The allowed methods for adding assignees to roles are not specified (together with business objects, without them, or both ways).';es_CO = 'No están especificados los métodos permitidos para añadir los responsables a roles (junto con los objetos comerciales, sin ellos o de ambas formas).'"),
		 	ThisObject, "UsedWithoutAddressingObjects",,Cancel);
		Return;
	EndIf;
	
	If Not UsedByAddressingObjects Then
		Return;
	EndIf;
	
	MainAddressingObjectTypesAreSet = MainAddressingObjectTypes <> Undefined And Not MainAddressingObjectTypes.IsEmpty();
	If Not MainAddressingObjectTypesAreSet Then
		Common.MessageToUser(NStr("en = 'Types of the main business object are not specified.';es_CO = 'No están especificados los tipos del objeto comercial principal.'"),
		 	ThisObject, "MainAddressingObjectTypes",,Cancel);
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
		
	If MainAddressingObjectTypes <> Undefined And MainAddressingObjectTypes.IsEmpty() Then
		MainAddressingObjectTypes = Undefined;
	EndIf;
	
	If AdditionalAddressingObjectTypes <> Undefined And AdditionalAddressingObjectTypes.IsEmpty() Then
		AdditionalAddressingObjectTypes = Undefined;
	EndIf;
	
	If Not GetFunctionalOption("UseExternalUsers") Then
		If Purpose.Find(Catalogs.Users.EmptyRef(), "UsersType") = Undefined Then
			// If external users are disconnected, the role must be assigned to users.
			Purpose.Add().UsersType = Catalogs.Users.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure OnReadPresentationsAtServer() Export
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';es_CO = 'Invalidar la llamada de objeto al cliente.'");
#EndIf