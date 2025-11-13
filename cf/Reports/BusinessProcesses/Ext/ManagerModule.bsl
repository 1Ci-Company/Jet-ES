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
	ReportSettings.LongDesc = NStr("en = 'Business process list and summary.';es_CO = 'Lista y resumen de procesos de negocio.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "BusinessProcessesList");
	OptionSettings.LongDesc = NStr("en = 'Business processes of certain types for the specified period.';es_CO = 'Procesos de negocio de ciertos tipos durante el periodo especificado.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "StatisticsByKinds");
	OptionSettings.LongDesc = NStr("en = 'Pivot chart of all active and completed business processes.';es_CO = 'Gráfico giratorio de todos los procesos de negocio activos y completados.'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf