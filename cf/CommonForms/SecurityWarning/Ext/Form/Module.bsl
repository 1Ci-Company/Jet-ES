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
	
	If Not ValueIsFilled(Parameters.Key) Then
		ErrorText =
			NStr("en = 'The common form ""Security warning"" is auxiliary; it is meant to be opened by the internal application algorithms.';es_CO = 'El formulario común ""Advertencias de seguridad"" es adicional y se abre de los mecanismos de servicio del programa.'");
		Raise ErrorText;
	EndIf;
	
	If Not UsersInternalClientServer.SecurityWarningKinds().Property(Parameters.Key) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid security warning specified: %1.';es_CO = 'Está especificada una advertencia de seguridad no válida: %1.'"),
			Parameters.Key);
		Raise(ErrorText, ErrorCategory.ConfigurationError);
	EndIf;
	
	PurposeUseKey = Parameters.Key;
	WindowOptionsKey = Parameters.Key;
	
	CurrentPage = Items.Find(Parameters.Key);
	For Each Page In Items.Pages.ChildItems Do
		Page.Visible = (Page = CurrentPage);
	EndDo;
	Items.Pages.CurrentPage = CurrentPage;
	
	If CurrentPage = Items.AfterUpdate Then
		Items.DenyOpeningExternalReportsAndDataProcessors.DefaultButton = True;
		
	ElsIf CurrentPage = Items.AfterObtainRight Then
		Items.IAgree.DefaultButton = True;
		
	ElsIf CurrentPage = Items.BeforeOpenFile Then
		If ValueIsFilled(Parameters.AdditionalParameter) Then
			Items.WarningOnOpenFile.Title =
				StringFunctionsClientServer.SubstituteParametersToString(
					Items.WarningOnOpenFile.Title,
					Parameters.AdditionalParameter);
		EndIf;
	
	ElsIf CurrentPage = Items.BeforeDeleteExtensionWithData
	      Or CurrentPage = Items.BeforeDeleteExtensionWithoutData
	      Or CurrentPage = Items.BeforeDisableExtensionWithData Then
		
		If Common.DataSeparationEnabled() Then 
			Items.WarningBeforeDeleteExtensionWithDataBackup.Visible = False;
			Items.WarningBeforeDeleteExtensionWithoutDataBackup.Visible = False;
			
		ElsIf Common.SubsystemExists("StandardSubsystems.IBBackup") Then
			ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
			Items.WarningBeforeDeleteExtensionWithDataBackup.Title = 
				StringFunctions.FormattedString(NStr("en = 'It is recommended that you 
					|<a href=""%1"">back up the infobase</a> before deleting the extension.';es_CO = 'Se recomienda que 
					|<a href=""%1"">haga una copia de respaldo de la base de información</a> antes de eliminar la extensión.'"),
				ModuleIBBackupServer.BackupDataProcessorURL());
			Items.WarningBeforeDeleteExtensionWithoutDataBackup.Title =
				Items.WarningBeforeDeleteExtensionWithDataBackup.Title;
		EndIf;
		
		If Parameters.AdditionalParameter = True Then
			Items.WarningBeforeDeleteExtensionWithDataTextDelete.Title =
				NStr("en = 'Do you want to delete the selected extensions?';es_CO = '¿Eliminar las extensiones seleccionadas?'");
		Else
			Items.WarningBeforeDeleteExtensionWithDataTextDelete.Title =
				NStr("en = 'Do you want to delete the extension?';es_CO = '¿Eliminar la extensión?'");
		EndIf;
		Items.WarningBeforeDeleteExtensionWithoutDataTextDelete.Title = 
			Items.WarningBeforeDeleteExtensionWithDataTextDelete.Title;
		
		Title = NStr("en = 'Warning';es_CO = 'Advertencia'");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WarningBeforeDeleteExtensionBackupURLProcessing(Item, 
	FormattedStringURL, StandardProcessing)
	
	Close(DialogReturnCode.Cancel);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandContinue(Command)
	SelectedButtonName = Command.Name;
	CloseFormAndReturnResult();
EndProcedure

&AtClient
Procedure DenyOpeningExternalReportsAndDataProcessors(Command)
	AllowInteractiveOpening = False;
	ManageRoleAtClient(Command);
EndProcedure

&AtClient
Procedure AllowOpeningExternalReportsAndDataProcessors(Command)
	AllowInteractiveOpening = True;
	ManageRoleAtClient(Command);
EndProcedure

&AtClient
Procedure IAgree(Command)
	SelectedButtonName = Command.Name;
	IAgreeAtServer();
	CloseFormAndReturnResult();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ManageRoleAtClient(Command)
	SelectedButtonName = Command.Name;
	ManageRoleAtServer();
	RefreshReusableValues();
	ProposeRestart();
EndProcedure

&AtServer
Procedure ManageRoleAtServer()
	If Not AccessRight("Administration", Metadata) Then
		Return;
	EndIf;
	OpeningRole = Metadata.Roles.InteractiveOpenExtReportsAndDataProcessors;
	AdministratorRole = Metadata.Roles.SystemAdministrator;
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	AdministrationParameters.Insert("OpenExternalReportsAndDataProcessorsDecisionMade", True);
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
	
	RefreshReusableValues();
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each IBUser In IBUsers Do
		If AllowInteractiveOpening Then
			If IBUser.Roles.Contains(AdministratorRole)
				And Not IBUser.Roles.Contains(OpeningRole) Then
				IBUser.Roles.Add(OpeningRole);
				IBUser.Write();
			EndIf;
		Else
			If IBUser.Roles.Contains(OpeningRole) Then
				IBUser.Roles.Delete(OpeningRole);
				IBUser.Write();
			EndIf;
		EndIf;
	EndDo;
	
	If AllowInteractiveOpening Then
		RestartRequired = Not AccessRight("InteractiveOpenExtDataProcessors", Metadata);
	Else
		RestartRequired = AccessRight("InteractiveOpenExtDataProcessors", Metadata);
	EndIf;
	
	IAgreeAtServer();
	
	// In SaaS mode, the right to open external reports and date processors
	// is not supported for data area users.
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetExternalReportsAndDataProcessorsOpenRight(AllowInteractiveOpening);
	EndIf;
	
EndProcedure

&AtServer
Procedure IAgreeAtServer()
	Common.CommonSettingsStorageSave("SecurityWarning", "UserAccepts", True);
EndProcedure

&AtClient
Procedure CloseFormAndReturnResult()
	If IsOpen() Then
		NotifyChoice(SelectedButtonName);
	EndIf;
EndProcedure

&AtClient
Procedure ProposeRestart()
	If Not RestartRequired Then
		CloseFormAndReturnResult();
		Return;
	EndIf;
	
	Handler = New NotifyDescription("RestartApplication", ThisObject);
	Buttons = New ValueList;
	Buttons.Add("Restart", NStr("en = 'Restart';es_CO = 'Reiniciar'"));
	Buttons.Add("DoNotRestart", NStr("en = 'Do not restart';es_CO = 'No reiniciar'"));
	QueryText = NStr("en = 'To apply the changes, restart the application.';es_CO = 'Para aplicar los cambios se requiere reiniciar el programa.'");
	ShowQueryBox(Handler, QueryText, Buttons);
EndProcedure

&AtClient
Procedure RestartApplication(Response, ExecutionParameters) Export
	CloseFormAndReturnResult();
	If Response = "Restart" Then
		Exit(False, True);
	EndIf;
EndProcedure

#EndRegion
