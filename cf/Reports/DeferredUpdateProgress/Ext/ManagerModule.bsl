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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	
	ReportSettings.DefineFormSettings = True;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "DeferredUpdateProgress");
	OptionSettings.LongDesc = NStr("en = 'Progress of additional data processing procedures.';es_CO = 'El progreso de realizar los procedimientos adicionales del procesamiento de datos.'");
	OptionSettings.SearchSettings.Keywords = NStr("en = 'Deferred update';es_CO = 'Actualización diferida'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf