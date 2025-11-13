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
	
	PreviousValue2 = Constants.UseUserGroups.Get();
	
	If Value = PreviousValue2 Then
		Return;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ErrorText =
			NStr("en = 'To change the usage of user groups, go to the app in the service.';es_CO = 'Para cambiar el uso de los grupos de usuarios vaya a la aplicación en el servicio.'");
		Raise ErrorText;
		
	ElsIf Common.IsSubordinateDIBNode() Then
		ErrorText =
			NStr("en = 'User groups can only be customized in the master node.';es_CO = 'Solo se puede personalizar los grupos de usuarios en el nodo maestro.'");
		Raise ErrorText;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Constants.UseExternalUserGroups.Refresh();
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';es_CO = 'Invalidar la llamada de objeto al cliente.'");
#EndIf