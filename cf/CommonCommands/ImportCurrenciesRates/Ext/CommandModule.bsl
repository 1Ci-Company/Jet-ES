///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	NotifyDescription = New NotifyDescription("ImportCurrencyRatesClient", ThisObject);
	ShowQueryBox(NotifyDescription, 
		NStr("en = 'You are about to import a file with full exchange rates data for all the periods from the service manager.
              |The exchange rates that are marked to be imported from the Internet in specific data areas will be replaced in a background job. Do you want to continue?';es_CO = 'Está a punto de importar un archivo con los datos completos de tasas de cambio para todos los períodos desde el gerente de servicios.
              |Las tasas de cambio que estén marcados para ser importados desde Internet en las áreas de datos específicas se reemplazarán como parte de la tarea de fondo. ¿Desea continuar?'"), 
		QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportCurrencyRatesClient(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ImportCurrencyRates();
	
	ShowUserNotification(
		NStr("en = 'The import is scheduled.';es_CO = 'La importación está programada.'"), ,
		NStr("en = 'The exchange rates will soon be imported in background mode.';es_CO = 'Las tasas de cambio pronto se importarán en el modo de fondo.'"),
		PictureLib.DialogInformation);
	
EndProcedure

&AtServer
Procedure ImportCurrencyRates()
	
	CurrencyRateOperationsInternal.ImportCurrencyRates();
	
EndProcedure

#EndRegion
