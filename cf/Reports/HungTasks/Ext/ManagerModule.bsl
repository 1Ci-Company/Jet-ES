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
	ReportSettings.LongDesc = NStr("en = 'Unassigned tasks analysis (tasks not assigned to any users).';es_CO = 'Análisis de tareas no asignadas (tareas no asignadas a ningún usuario).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UnassignedTasksSummary");
	OptionSettings.LongDesc = NStr("en = 'Unassigned tasks summary (tasks assigned to blank roles).';es_CO = 'Resumen de las tareas no asignadas (tareas asignadas a roles en blanco).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UnassignedTasksByPerformers");
	OptionSettings.LongDesc = NStr("en = 'Unassigned tasks (tasks assigned to blank roles).';es_CO = 'Tareas no asignadas (tareas asignadas a roles en blanco).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UnassignedTasksByAddressingObjects");
	OptionSettings.LongDesc = NStr("en = 'Unassigned tasks by business objects.';es_CO = 'Tareas no asignadas por objetos de negocio.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "OverdueTasks");
	OptionSettings.LongDesc = NStr("en = 'Unassigned and overdue tasks (tasks not assigned to any users).';es_CO = 'Tareas no asignadas y atrasadas (tareas no asignadas a ningún usuario).'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf