///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var ProcessingEndOfRecording, ContinuationHandlerOnWriteError, CancelOnWrite;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	NewPassedParametersStructure();
	
	If PassedFormParameters.SelectSharedProperty
		Or PassedFormParameters.SelectAdditionalValuesOwner
		Or PassedFormParameters.CopyWithQuestion Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		WizardMode               = True;
		If PassedFormParameters.CopyWithQuestion Then
			Items.WIzardCardPages.CurrentPage = Items.ActionChoice;
			FillActionListOnAddAttribute();
		Else
			FillChoicePage();
		EndIf;
		RefreshFormItemsContent();
		
		If Common.IsWebClient() Then
			Items.AttributeCard.Visible = False;
		EndIf;
	Else
		FillPropertyCard();
		// Object attribute lock subsystem handler.
		ObjectAttributesLock.LockAttributes(ThisObject);
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DuplicateObjectsDetection") Then
		Items.FormDuplicateObjectsDetection.Visible = False;
	EndIf;
	
	Items.MultilineGroup.Representation          = UsualGroupRepresentation.NormalSeparation;
	If Not PropertyManagerInternal.ValueTypeContainsPropertyValues(Object.ValueType) Then
		Items.PropertiesAndDependenciesGroup.Representation = UsualGroupRepresentation.NormalSeparation;
		Items.OtherAttributes.Representation         = UsualGroupRepresentation.NormalSeparation;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.PropertiesSets.InitialTreeView = InitialTreeView.ExpandAllLevels;
		Items.AdditionalInformationGroup.Representation = UsualGroupRepresentation.NormalSeparation;
		Items.Close.Visible = False;
		Items.AttributeDescriptionGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.AttributeValueType.ItemsAndTitlesAlign        = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
	EndIf;
	
	Items.FillIDForFormulas.Enabled = Not Items.IDForFormulas.ReadOnly;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnCreateAtServer(ThisObject, Object);
	EndIf;
	
	CurrentTitle = Object.Title;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
		Close();
		
		// Open the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", ValueSelected);
		FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
			FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not WriteParameters.Property("DescriptionChangeConfirmed") Then
		If ValueIsFilled(CurrentTitle) And CurrentTitle <> Object.Title Then
			QueryText = NStr("en = 'If you change the attribute''s description, you have to configure its view
				                      |in all of the lists, reports, and filters
				                      |that include the attribute.';es_CO = 'Si cambia la descripción del atributo, debe configurar su vista 
				                      | en todas las listas, informes y filtros 
				                      | que incluyen el atributo.'");
			QueryText = StrReplace(QueryText, Chars.LF, " ");
			
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("en = 'Rename';es_CO = 'Renombrar'"));
			Buttons.Add("ReturnDescription", NStr("en = 'Cancel';es_CO = 'Cancelar'"));
			
			CancelOnWrite = True;
			Cancel = True;
			
			ShowQueryBox(
				New NotifyDescription("AfterResponseToDescriptionChangeQuestion", ThisObject, WriteParameters),
				QueryText, Buttons, , "ReturnDescription");
			Return;
		EndIf;
	EndIf;
	
	If Not WriteParameters.Property("WhenDescriptionAlreadyInUse") Then
	
		// Fill the description from the property set and check if
		// there's a property with the same description.
		If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			QueryText = DescriptionAlreadyUsed(
				Object.Title, Object.Ref, CurrentPropertiesSet, Object.Description, Object.TitleLanguage1, Object.TitleLanguage2);
		Else
			QueryText = DescriptionAlreadyUsed(
				Object.Title, Object.Ref, CurrentPropertiesSet, Object.Description, "", "");
		EndIf;
		
		If ValueIsFilled(QueryText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("en = 'Save';es_CO = 'Guardar'"));
			Buttons.Add("BackToDescriptionInput", NStr("en = 'Edit description';es_CO = 'Editar descripción'"));
			
			CancelOnWrite = True;
			Cancel = True;
			
			ShowQueryBox(
				New NotifyDescription("AfterResponseOnQuestionWhenDescriptionIsAlreadyUsed", ThisObject, WriteParameters),
				QueryText, Buttons, , "BackToDescriptionInput");
			Return;
		EndIf;
	EndIf;
	
	If Not WriteParameters.Property("WhenNameAlreadyInUse")
		And ValueIsFilled(Object.Name) Then
		// Check whether there is a property with the same name.
		QueryText = NameAlreadyUsed(
			Object.Name, Object.Ref, Object.Description);
		
		If ValueIsFilled(QueryText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("en = 'Continue';es_CO = 'Continuar'"));
			Buttons.Add("BackToNameInput", NStr("en = 'Cancel';es_CO = 'Cancelar'"));
			
			CancelOnWrite = True;
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("AfterResponseOnQuestionWhenNameIsAlreadyUsed", ThisObject, WriteParameters),
				QueryText, Buttons, , "ContinueWrite");
			Return;
		EndIf;
	EndIf;
	
	If Not WriteParameters.Property("WhenIDForFormulasIsAlreadyUsed")
		And ValueIsFilled(Object.IDForFormulas) Then
		// Fill formula ID and check if there's a property with the same ID.
		// 
		QueryText = IDForFormulasAlreadyUsed(
			Object.IDForFormulas, Object.Ref);
		
		If ValueIsFilled(QueryText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",              NStr("en = 'Continue';es_CO = 'Continuar'"));
			Buttons.Add("BackToIDInput", NStr("en = 'Cancel';es_CO = 'Cancelar'"));
			
			CancelOnWrite = True;
			Cancel = True;
			
			ShowQueryBox(
				New NotifyDescription("AfterResponseOnQuestionWhenIDForFormulasIsAlreadyUsed", ThisObject, WriteParameters),
				QueryText, Buttons, , "ContinueWrite");
			Return;
			
		Else
			WriteParameters.Insert("IDCheckForFormulasCompleted");
		EndIf;
	EndIf;
	
	FillMultilingualRequisites();
	
	If WriteParameters.Property("ContinuationHandler") Then
		ContinuationHandlerOnWriteError = WriteParameters.ContinuationHandler;
		AttachIdleHandler("AfterWriteError", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If PropertyManagerInternal.ValueTypeContainsPropertyValues(Object.ValueType) Then
		CurrentObject.AdditionalValuesUsed = True;
	Else
		CurrentObject.AdditionalValuesUsed = False;
		CurrentObject.ValueFormTitle = "";
		CurrentObject.ValueChoiceFormTitle = "";
	EndIf;
	
	If Object.IsAdditionalInfo
	 Or Not (    Object.ValueType.ContainsType(Type("Number" ))
	         Or Object.ValueType.ContainsType(Type("Date"  ))
	         Or Object.ValueType.ContainsType(Type("Boolean")) )Then
		
		CurrentObject.FormatProperties = "";
	EndIf;
	
	CurrentObject.MultilineInputField = 0;
	
	If Not Object.IsAdditionalInfo
	   And Object.ValueType.Types().Count() = 1
	   And Object.ValueType.ContainsType(Type("String")) Then
		
		If AttributeRepresentation = "MultilineInputField" Then
			CurrentObject.MultilineInputField   = MultilineInputFieldNumber;
			CurrentObject.OutputAsHyperlink = False;
		EndIf;
	EndIf;
	
	// Generating additional attribute or info name.
	If Not ValueIsFilled(CurrentObject.Name)
		Or WriteParameters.Property("WhenNameAlreadyInUse") Then
		CurrentObject.Name = "";
		ObjectTitle = CurrentObject.Title;
		PropertyManagerInternal.DeleteDisallowedCharacters(ObjectTitle);
		ObjectTitleInParts = StrSplit(ObjectTitle, " ", False);
		For Each TitlePart In ObjectTitleInParts Do
			CurrentObject.Name = CurrentObject.Name + Upper(Left(TitlePart, 1)) + Mid(TitlePart, 2);
		EndDo;
		
		If PropertyManagerInternal.TheNameStartsWithANumber(CurrentObject.Name) Then
			CurrentObject.Name = "_" + CurrentObject.Name;
		EndIf;
		
		UID = New UUID();
		UIDString = StrReplace(String(UID), "-", "");
		CurrentObject.Name = CurrentObject.Name + "_" + UIDString;
	EndIf;
	
	// Generate ID for additional attribute (information record) formulas.
	If Not ValueIsFilled(CurrentObject.IDForFormulas)
		Or WriteParameters.Property("WhenIDForFormulasIsAlreadyUsed") Then
			
		ObjectTitle = CurrentObject.Title;
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
			If ValueIsFilled(CurrentLanguageSuffix) And ValueIsFilled(CurrentObject["Title" + CurrentLanguageSuffix]) Then
				ObjectTitle = CurrentObject["Title" + CurrentLanguageSuffix];
			EndIf;
		EndIf;
		
		CurrentObject.IDForFormulas = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.UUIDForFormulas(
			ObjectTitle, CurrentObject.Ref);
		
		WriteParameters.Insert("IDCheckForFormulasCompleted");
	EndIf;
	If WriteParameters.Property("IDCheckForFormulasCompleted") Then
		CurrentObject.AdditionalProperties.Insert("IDCheckForFormulasCompleted");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.BeforeWriteAtServer(CurrentObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(CurrentPropertiesSet) Then
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem.SetValue("Ref", CurrentPropertiesSet);
		Block.Lock();
		LockDataForEdit(CurrentPropertiesSet);
		
		ObjectPropertySet = CurrentPropertiesSet.GetObject();
		If CurrentObject.IsAdditionalInfo Then
			TabularSection = ObjectPropertySet.AdditionalInfo;
		Else
			TabularSection = ObjectPropertySet.AdditionalAttributes;
		EndIf;
		FoundRow = TabularSection.Find(CurrentObject.Ref, "Property");
		If FoundRow = Undefined Then
			NewRow = TabularSection.Add();
			NewRow.Property = CurrentObject.Ref;
			ObjectPropertySet.Write();
			CurrentObject.AdditionalProperties.Insert("ChangedSet", CurrentPropertiesSet);
		EndIf;
		
	EndIf;
	
	If WriteParameters.Property("ClearEnteredWeightCoefficients") Then
		ClearEnteredWeightCoefficients();
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	If AttributeAddMode = "CreateByCopying" Then
		WriteAdditionalAttributeValuesOnCopy(CurrentObject);
	EndIf;
	
	// Object attribute lock subsystem handler.
	ObjectAttributesLock.LockAttributes(ThisObject);
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
	RefreshFormItemsContent();
	
	If CurrentObject.AdditionalProperties.Property("ChangedSet") Then
		WriteParameters.Insert("ChangedSet", CurrentObject.AdditionalProperties.ChangedSet);
	EndIf;
	
	CurrentTitle = Object.Title;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_AdditionalAttributesAndInfo",
		New Structure("Ref", Object.Ref), Object.Ref);
	
	If WriteParameters.Property("ChangedSet") Then
		
		Notify("Write_AdditionalAttributesAndInfoSets",
			New Structure("Ref", WriteParameters.ChangedSet), WriteParameters.ChangedSet);
	EndIf;
	
	If WriteParameters.Property("ContinuationHandler") Then
		ContinuationHandlerOnWriteError = Undefined;
		DetachIdleHandler("AfterWriteError");
		ExecuteNotifyProcessing(
			New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
				ThisObject, WriteParameters.ContinuationHandler.Parameters),
			False);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If WizardMode Then
		SetWizardSettings();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "PropertiesAttributeDependencySet" Then
		Modified = True;
		ValueAdded = False;
		For Each DependenceCondition In AttributeDependencyConditions Do
			Value = Undefined;
			If Parameter.Property(DependenceCondition.Presentation, Value) Then
				ValueInStorage = PutToTempStorage(Value, UUID);
				DependenceCondition.Value = ValueInStorage;
				ValueAdded = True;
			EndIf;
		EndDo;
		If Not ValueAdded Then
			For Each PassedParameter In Parameter Do
				ValueInStorage = PutToTempStorage(PassedParameter.Value, UUID);
				AttributeDependencyConditions.Add(ValueInStorage, PassedParameter.Key);
			EndDo;
		EndIf;
		
		SetAdditionalAttributeDependencies();
	EndIf;
	
	If EventName = "AfterInputStringsInDifferentLanguages"
		And Parameter = ThisObject Then
		If Not ValueIsFilled(Object.Ref) Then
			UpdateSuggestedIDValue();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		ModuleNationalLanguageSupportServer.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PropertyKindOnChange(Item)
	
	Object.PropertyKind = PropertyKind;
	If Object.PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalInfo") Then
		Object.IsAdditionalInfo = True;
	EndIf;
	
	RefreshFormItemsContent();
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentCommentClick(Item)
	
	FollowUpHandler = New NotifyDescription("ValueListAdjustmentCommentClickCompletion", ThisObject);
	WriteObject("GoToValueList", FollowUpHandler);
	
EndProcedure

&AtClient
Procedure SetsAdjustmentCommentClick(Item)
	
	FollowUpHandler = New NotifyDescription("SetAdjustmentCommentClickFollowUp", ThisObject);
	WriteObject("GoToValueList", FollowUpHandler);
	
EndProcedure

&AtClient
Procedure ValueTypeOnChange(Item)
	
	WarningText = "";
	RefreshFormItemsContent(WarningText);
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
	   And Not Object.AdditionalValuesWithWeight Then
		
		QueryText =
			NStr("en = 'Do you want to clear the weight coefficients?
			           |
			           |The data will be saved.';es_CO = '¿Desea borrar los coeficientes de peso?
			           |
			           | Los datos se guardarán.'");
		
		Buttons = New ValueList;
		Buttons.Add("ClearAndWrite", NStr("en = 'Clear and save';es_CO = 'Eliminar y cerrar'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel';es_CO = 'Cancelar'"));
		
		ShowQueryBox(
			New NotifyDescription("AfterConfirmClearWeightCoefficients", ThisObject),
			QueryText, Buttons, , "ClearAndWrite");
	Else
		QueryText = NStr("en = 'Do you want to save the data?';es_CO = '¿Desea guardar los datos?'");
		
		Buttons = New ValueList;
		Buttons.Add("Write", NStr("en = 'Save';es_CO = 'Guardar'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel';es_CO = 'Cancelar'"));
		
		ShowQueryBox(
			New NotifyDescription("AfterConfirmEnableWeightCoefficients", ThisObject),
			QueryText, Buttons, , "Write");
	EndIf;
	
EndProcedure

&AtClient
Procedure MultilineInputFieldNumberOnChange(Item)
	
	AttributeRepresentation = "MultilineInputField";
	
EndProcedure

&AtClient
Procedure CommentOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure RequiredToFillOnChange(Item)
	Items.ChooseItemRequiredOption.Enabled = Object.RequiredToFill;
EndProcedure

&AtClient
Procedure ChooseAvailabilityOptionClick(Item)
	OpenDependenceSettingForm("Available");
EndProcedure

&AtClient
Procedure SetConditionClick(Item)
	OpenDependenceSettingForm("RequiredToFill");
EndProcedure

&AtClient
Procedure ChooseVisibilityOptionClick(Item)
	OpenDependenceSettingForm("isVisible");
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
EndProcedure

&AtClient
Procedure AttributeKindOnChange(Item)
	Items.OutputAsHyperlink.Enabled    = (AttributeRepresentation = "SingleLineInputField");
	Items.MultilineInputFieldNumber.Enabled = (AttributeRepresentation = "MultilineInputField");
EndProcedure

&AtClient
Procedure Attachable_Opening(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportClient = CommonClient.CommonModule("NationalLanguageSupportClient");
		ModuleNationalLanguageSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPropertiesSets

&AtClient
Procedure PropertiesSetsOnActivateRow(Item)
	AttachIdleHandler("OnChangeCurrentSet", 0.1, True)
EndProcedure

&AtClient
Procedure PropertiesSetsBeforeRowChange(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPropertiesSelection

&AtClient
Procedure PropertiesSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	NextCommand(Undefined);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersValues

&AtClient
Procedure ValuesOnChange(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		EventName = "Write_ObjectsPropertiesValues";
	Else
		EventName = "Write_ObjectPropertyValueHierarchy";
	EndIf;
	
	Notify(EventName,
		New Structure("Ref", Item.CurrentData.Ref),
		Item.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ValuesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Copy", Copy);
	AdditionalParameters.Insert("Parent", Parent);
	AdditionalParameters.Insert("Group", Var_Group);
	
	FollowUpHandler = New NotifyDescription("ValuesBeforeAddRowCompletion", ThisObject);
	WriteObject("GoToValueList", FollowUpHandler, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ValuesBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	If Items.AdditionalValues.ReadOnly Then
		Return;
	EndIf;
	
	FollowUpHandler = New NotifyDescription("ValuesBeforeRowChangeCompletion", ThisObject);
	WriteObject("GoToValueList", FollowUpHandler);
	
EndProcedure

&AtClient
Procedure TitleOnChange(Item)
	If Not ValueIsFilled(Object.Ref) Then
		UpdateSuggestedIDValue();
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure NextCommand(Command)
	
#If WebClient Then
	If Not Items.AttributeCard.Visible Then
		Items.AttributeCard.Visible = True;
	EndIf;
#EndIf
	
	If AttributeAddMode = "AddCommonAttributeToSet" Then
		Result = New Structure;
		Result.Insert("CommonProperty", PassedFormParameters.AdditionalValuesOwner);
		If PassedFormParameters.Drag Then
			Result.Insert("Drag", True);
		EndIf;
		NotifyChoice(Result);
		Return;
	EndIf;
	
	BasicPage = Items.WIzardCardPages;
	PageIndex = BasicPage.ChildItems.IndexOf(BasicPage.CurrentPage);
	If PageIndex = 0
		And Items.Properties.CurrentData = Undefined Then
		WarningText = NStr("en = 'Please select an item.';es_CO = 'Por favor, seleccione un artículo.'");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	If PageIndex = 2 Then
		
		FillMultilingualRequisites();
		
		If Not CheckFilling() Then
			Return;
		EndIf;
		
		If AttributeAddMode = "CreateByCopying" Then
			Items.AttributeValuePages.CurrentPage = Items.AdditionalValues;
		EndIf;
		
		Write();
		If CancelOnWrite <> True Then
			Close();
		EndIf;
		Return;
	EndIf;
	CurrentPage = BasicPage.ChildItems.Get(PageIndex + 1);
	SetWizardSettings(CurrentPage);
	
	OnCurrentPageChange("GoForward", BasicPage, CurrentPage);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	BasicPage = Items.WIzardCardPages;
	PageIndex = BasicPage.ChildItems.IndexOf(BasicPage.CurrentPage);
	If PageIndex = 1 Then
		AttributeAddMode = "";
	EndIf;
	CurrentPage = BasicPage.ChildItems.Get(PageIndex - 1);
	SetWizardSettings(CurrentPage);
	
	OnCurrentPageChange("Back", BasicPage, CurrentPage);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure EditValueFormat(Command)
	
	Designer = New FormatStringWizard(Object.FormatProperties);
	
	Designer.AvailableTypes = Object.ValueType;
	
	Designer.Show(
		New NotifyDescription("EditValueFormatCompletion", ThisObject));
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentChange(Command)
	
	FollowUpHandler = New NotifyDescription("ValueListAdjustmentChangeCompletion", ThisObject);
	WriteObject("AttributeKindEdit", FollowUpHandler);
	
EndProcedure

&AtClient
Procedure SetsAdjustmentChange(Command)
	
	FollowUpHandler = New NotifyDescription("SetsAdjustmentChangeCompletion", ThisObject);
	WriteObject("AttributeKindEdit", FollowUpHandler);
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributeEdit(Command)
	
	LockedAttributes = ObjectAttributesLockClient.Attributes(ThisObject);
	
	If LockedAttributes.Count() > 0 Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Ref", Object.Ref);
		FormParameters.Insert("IsAdditionalAttribute", Not Object.IsAdditionalInfo);
		FormParameters.Insert("PropertyKind", Object.PropertyKind);
		
		Notification = New NotifyDescription("AfterAttributesToUnlockChoice", ThisObject);
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.AttributeUnlocking",
			FormParameters, ThisObject,,,, Notification);
	Else
		ObjectAttributesLockClient.ShowAllVisibleAttributesUnlockedWarning();
	EndIf;
	
EndProcedure

&AtClient
Procedure DuplicateObjectsDetection(Command)
	ModuleDuplicateObjectsDetectionClient = CommonClient.CommonModule("DuplicateObjectsDetectionClient");
	DuplicateObjectsDetectionFormName = ModuleDuplicateObjectsDetectionClient.DuplicateObjectsDetectionDataProcessorFormName();
	OpenForm(DuplicateObjectsDetectionFormName);
EndProcedure

&AtClient
Procedure Change(Command)
	
	If Items.Properties.CurrentData <> Undefined Then
		// Open the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", Items.Properties.CurrentData.Property);
		FormParameters.Insert("CurrentPropertiesSet", SelectedPropertiesSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
			FormParameters, Items.Properties,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowUnusedAttributes(Command)
	NewValue = Not Items.UnusedAttributes.Check;
	ShowUnusedAttributes = NewValue;
	Items.UnusedAttributes.Check = NewValue;
	If NewValue Then
		Items.PropertiesSetsPages.CurrentPage = Items.SharedSetsPage;
	Else
		Items.PropertiesSetsPages.CurrentPage = Items.AllSetsPage;
	EndIf;
	
	UpdateCurrentSetPropertiesList();
	
EndProcedure

&AtClient
Procedure SetClearDeletionMark(Command)
	FollowUpHandler = New NotifyDescription("SetClearDeletionMarkFollowUp", ThisObject);
	WriteObject("DeletionMarkEdit", FollowUpHandler);
EndProcedure

&AtClient
Procedure FillIDForFormulas(Command)
	FillIDForFormulasAtServer();
EndProcedure

&AtClient
Procedure PropertyGray(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Gray");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyLightBlue(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.LightBlue");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyYellow(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Yellow");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyGreen(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Green");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyBrown(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.GreenLime");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyRed(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Red");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyOrange(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Orange");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyPink(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Pink");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyBlue(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.B");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

&AtClient
Procedure PropertyPurple(Command)
	
	Object.PropertiesColor = PredefinedValue("Enum.PropertiesColors.Violet");
	SetLabelColor(ThisObject, Object.PropertiesColor);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateSuggestedIDValue()
	
	SuggestedID = "";
	If Not Items.IDForFormulas.ReadOnly Then
		
		Presentation = Object.Title;
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
			If ValueIsFilled(CurrentLanguageSuffix) And ValueIsFilled(Object["Title" + CurrentLanguageSuffix]) Then
				Presentation = Object["Title" + CurrentLanguageSuffix];
			EndIf;
		EndIf;
		
		SuggestedID = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.UUIDForFormulas(
			Presentation, Object.Ref);
		If SuggestedID <> Object.IDForFormulas Then
			Object.IDForFormulas = SuggestedID;
			Modified = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillIDForFormulasAtServer()
	
	TitleForID = Object.Title;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		If ValueIsFilled(CurrentLanguageSuffix) And ValueIsFilled(Object["Title" + CurrentLanguageSuffix]) Then
			TitleForID = Object["Title" + CurrentLanguageSuffix];
		EndIf;
	EndIf;
	
	Object.IDForFormulas = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.UUIDForFormulas(
		TitleForID, Object.Ref);
EndProcedure

&AtServer
Procedure SetAdditionalAttributeDependencies()
	
	If AttributeDependencyConditions.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentObject = FormAttributeToValue("Object");
	
	AdditionalAttributesDependencies = CurrentObject.AdditionalAttributesDependencies;
	
	For Each DependenceCondition In AttributeDependencyConditions Do
		RowFilter = New Structure;
		RowFilter.Insert("DependentProperty", DependenceCondition.Presentation);
		RowFilter.Insert("PropertiesSet", CurrentPropertiesSet);
		RowsArray = AdditionalAttributesDependencies.FindRows(RowFilter);
		For Each LineOfATabularSection In RowsArray Do
			AdditionalAttributesDependencies.Delete(LineOfATabularSection);
		EndDo;
		
		ValueFromStorage = GetFromTempStorage(DependenceCondition.Value);
		If ValueFromStorage = Undefined Then
			Continue;
		EndIf;
		For Each NewDependence In ValueFromStorage.Get() Do
			FillPropertyValues(CurrentObject.AdditionalAttributesDependencies.Add(), NewDependence);
		EndDo;
	EndDo;
	
	ValueToFormAttribute(CurrentObject, "Object");
	
	SetHyperlinkTitles();
	
EndProcedure

&AtServer
Procedure FillChoicePage()
	
	If PassedFormParameters.PropertyKind <> Undefined Then
		PropertyKind = PassedFormParameters.PropertyKind;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Sets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets
	|WHERE
	|	Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)";
	
	Sets = Query.Execute().Unload().UnloadColumn("Ref");
	
	AvailableSets = New Array;
	For Each Ref In Sets Do
		SetPropertiesTypes = PropertyManagerInternal.SetPropertiesTypes(Ref, False);
		
		If PropertyKind = Enums.PropertiesKinds.AdditionalInfo And SetPropertiesTypes.AdditionalInfo
			Or PropertyKind = Enums.PropertiesKinds.AdditionalAttributes And SetPropertiesTypes.AdditionalAttributes
			Or PropertyKind = Enums.PropertiesKinds.Labels And SetPropertiesTypes.Labels Then
			AvailableSets.Add(Ref);
		EndIf;
	EndDo;
	
	CurrentSetParent = Common.ObjectAttributeValue(
		PassedFormParameters.CurrentPropertiesSet, "Parent");
	SetsToExclude = New Array;
	SetsToExclude.Add(PassedFormParameters.CurrentPropertiesSet);
	If ValueIsFilled(CurrentSetParent) Then
		PredefinedSets = PropertyManagerCached.PredefinedPropertiesSets();
		SetProperties = PredefinedSets.Get(CurrentSetParent); // See Catalogs.AdditionalAttributesAndInfoSets.SetProperties
		If SetProperties = Undefined Then
			PredefinedDataName = Common.ObjectAttributeValue(CurrentSetParent, "PredefinedDataName");
		Else
			PredefinedDataName = SetProperties.Name;
		EndIf;
		ReplacedCharacterPosition = StrFind(PredefinedDataName, "_");
		FullObjectName = Left(PredefinedDataName, ReplacedCharacterPosition - 1)
			             + "."
			             + Mid(PredefinedDataName, ReplacedCharacterPosition + 1);
		Manager         = Common.ObjectManagerByFullName(FullObjectName);
		
		If StrStartsWith(FullObjectName, "Document") Then
			NewObject = Manager.CreateDocument();
		ElsIf StrStartsWith(FullObjectName, "BusinessProcess") Then
			NewObject = Manager.CreateBusinessProcess();
		ElsIf StrStartsWith(FullObjectName, "Task") Then
			NewObject = Manager.CreateTask();
		ElsIf StrStartsWith(FullObjectName, "ChartOfAccounts") Then
			NewObject = Manager.CreateAccount();
		ElsIf StrStartsWith(FullObjectName, "ChartOfCalculationTypes") Then
			NewObject = Manager.CreateCalculationType();
		ElsIf StrStartsWith(FullObjectName, "ExchangePlan") Then
			NewObject = Manager.CreateNode();
		Else
			NewObject = Manager.CreateItem();
		EndIf;
		ObjectSets = PropertyManagerInternal.GetObjectPropertySets(NewObject);
		
		FilterParameters = New Structure;
		FilterParameters.Insert("SharedSet", True);
		FoundRows = ObjectSets.FindRows(FilterParameters);
		For Each FoundRow In FoundRows Do
			If PassedFormParameters.CurrentPropertiesSet = FoundRow.Set Then
				Continue;
			EndIf;
			SetsToExclude.Add(FoundRow.Set);
		EndDo;
	EndIf;
	
	If PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		Items.UnusedAttributes.Title = NStr("en = 'Unused additional information records';es_CO = 'Registros de información adicional no utilizados'");
	ElsIf PropertyKind = Enums.PropertiesKinds.Labels Then
		Items.UnusedAttributes.Title = NStr("en = 'Unused labels';es_CO = 'Etiquetas no utilizadas'");
	Else
		Items.UnusedAttributes.Title = NStr("en = 'Unused additional attributes';es_CO = 'Atributos adicionales no utilizados'");
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "Sets", AvailableSets, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "SetsToExclude", SetsToExclude, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "PropertyKind", PropertyKind, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "IsMainLanguage", Common.IsMainLanguage(), True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertiesSets, "LanguageCode", CurrentLanguage().LanguageCode, True);
	
	CommonClientServer.SetDynamicListParameter(
		CommonPropertySets, "PropertyKind", PropertyKind, True);
	
	ListPresentation = "";
	If PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalInfo") Then
		ListPresentation = NStr("en = 'Unused additional information records';es_CO = 'Registros de información adicional no utilizados'");
	ElsIf PropertyKind = PredefinedValue("Enum.PropertiesKinds.AdditionalAttributes") Then
		ListPresentation = NStr("en = 'Unused additional attributes';es_CO = 'Atributos adicionales no utilizados'");
	ElsIf PropertyKind = PredefinedValue("Enum.PropertiesKinds.Labels") Then
		ListPresentation = NStr("en = 'Unused labels';es_CO = 'Etiquetas no utilizadas'");
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		CommonPropertySets, "ListPresentation", ListPresentation, True);
	
	SetConditionalListAppearance(AvailableSets);
	
EndProcedure

&AtServer
Procedure SetConditionalListAppearance(AvailableSetsList)
	
	ConditionalAppearanceItem = PropertiesSets.ConditionalAppearance.Items.Add();
	
	VisibilityItem = ConditionalAppearanceItem.Appearance.Items.Find("Visible");
	VisibilityItem.Value = False;
	VisibilityItem.Use = True;
	
	DataFilterItemsGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataFilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataFilterItemsGroup.Use = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataFilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Parent");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use  = True;
	
EndProcedure

&AtServer
Procedure FillAdditionalAttributesValues(ValuesOwner)
	
	ValueTree = FormAttributeToValue("AdditionalAttributesValues");
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	ObjectsPropertiesValues.Ref AS Ref,
		|	ObjectsPropertiesValues.Owner AS Owner,
		|	0 AS PictureCode,
		|	ObjectsPropertiesValues.Weight,
		|	PRESENTATION(ObjectsPropertiesValues.Ref) AS Description
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.DeletionMark = FALSE
		|	AND ObjectsPropertiesValues.Owner = &Owner
		|
		|UNION ALL
		|
		|SELECT
		|	ObjectPropertyValueHierarchy.Ref,
		|	ObjectPropertyValueHierarchy.Owner,
		|	0,
		|	ObjectPropertyValueHierarchy.Weight,
		|	PRESENTATION(ObjectPropertyValueHierarchy.Description) AS Description
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
		|WHERE
		|	ObjectPropertyValueHierarchy.DeletionMark = FALSE
		|	AND ObjectPropertyValueHierarchy.Owner = &Owner
		|
		|ORDER BY
		|	Ref HIERARCHY";
	Query.SetParameter("Owner", ValuesOwner);
	Result = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	ValueTree = Result.Copy();
	ValueToFormAttribute(ValueTree, "AdditionalAttributesValues");
	
EndProcedure

&AtServer
Procedure FillPropertyCard()
	
	If ValueIsFilled(PassedFormParameters.CopyingValue) Then
		AttributeAddMode = "CreateByCopying";
	EndIf;
	
	CreateAttributeByCopying = (AttributeAddMode = "CreateByCopying");
	
	CurrentPropertiesSet = PassedFormParameters.CurrentPropertiesSet;
	
	If ValueIsFilled(Object.Ref) Then
		Items.PropertyKind.Enabled = False;
		ShowSetAdjustment = PassedFormParameters.ShowSetAdjustment;
	Else
		Object.Available = True;
		Object.isVisible  = True;
		
		Object.AdditionalAttributesDependencies.Clear();
		If ValueIsFilled(CurrentPropertiesSet) Then
			Object.PropertiesSet = CurrentPropertiesSet;
		EndIf;
		
		If CreateAttributeByCopying Then
			Object.AdditionalValuesOwner = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef();
		ElsIf ValueIsFilled(PassedFormParameters.AdditionalValuesOwner) Then
			Object.AdditionalValuesOwner = PassedFormParameters.AdditionalValuesOwner;
		EndIf;
		
		If PassedFormParameters.PropertyKind <> Undefined Then
			Object.PropertyKind = PassedFormParameters.PropertyKind;
			If Object.PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
				Object.IsAdditionalInfo = True;
			EndIf;
		ElsIf Not ValueIsFilled(PassedFormParameters.CopyingValue) Then
			Items.PropertyKind.Visible = True;
		EndIf;
	EndIf;
	
	If Object.Predefined And Not ValueIsFilled(Object.Title) Then
		Object.Title = Object.Description;
	EndIf;
	
	PropertyKind = Object.PropertyKind;
	
	If CreateAttributeByCopying Then
		// For cases when the attribute is copied from its card using the Copy command.
		If Not ValueIsFilled(PassedFormParameters.AdditionalValuesOwner) Then
			PassedFormParameters.AdditionalValuesOwner = PassedFormParameters.CopyingValue;
		EndIf;
		
		OwnerProperties = Common.ObjectAttributesValues(
			PassedFormParameters.AdditionalValuesOwner, "ValueType, AdditionalValuesWithWeight, FormatProperties");
		
		Object.ValueType    = OwnerProperties.ValueType;
		Object.FormatProperties = OwnerProperties.FormatProperties;
		
		OwnerValuesWithWeight                                = OwnerProperties.AdditionalValuesWithWeight;
		Object.AdditionalValuesWithWeight                    = OwnerValuesWithWeight;
		Items.AdditionalAttributeValues.Header        = OwnerValuesWithWeight;
		Items.AdditionalAttributeValuesWeight.Visible = OwnerValuesWithWeight;
		Items.AttributeValuePages.CurrentPage     = Items.ValueTreePage;
		
		FillAdditionalAttributesValues(PassedFormParameters.AdditionalValuesOwner);
	EndIf;
	
	RefreshFormItemsContent();
	
	If Object.MultilineInputField > 0 Then
		AttributeRepresentation = "MultilineInputField";
		MultilineInputFieldNumber = Object.MultilineInputField;
	Else
		AttributeRepresentation = "SingleLineInputField";
	EndIf;
	
	Items.OutputAsHyperlink.Enabled    = (AttributeRepresentation = "SingleLineInputField");
	Items.MultilineInputFieldNumber.Enabled = (AttributeRepresentation = "MultilineInputField");
	
EndProcedure

&AtClient
Procedure FillMultilingualRequisites()
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		Return;
	EndIf;
	
	If IsBlankString(Object.TitleLanguage1) Then
		Object.TitleLanguage1 = Object.Title;
	EndIf;
	
	If IsBlankString(Object.TitleLanguage2) Then
		Object.TitleLanguage2 = Object.Title;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAttributesToUnlockChoice(AttributesToUnlock, Context) Export
	
	If TypeOf(AttributesToUnlock) <> Type("Array") Then
		Return;
	EndIf;
	
	ObjectAttributesLockClient.SetFormItemEnabled(ThisObject,
		AttributesToUnlock);
	Items.FillIDForFormulas.Enabled = Not Items.IDForFormulas.ReadOnly;
	
EndProcedure

&AtClient
Procedure AfterResponseOnQuestionWhenDescriptionIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		CurrentItem = Items.Title;
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenDescriptionAlreadyInUse");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterResponseToDescriptionChangeQuestion(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		Object.Title = CurrentTitle;
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("DescriptionChangeConfirmed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterResponseOnQuestionWhenNameIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		CurrentItem = Items.Title;
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenNameAlreadyInUse");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterResponseOnQuestionWhenIDForFormulasIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenIDForFormulasIsAlreadyUsed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterConfirmClearWeightCoefficients(Response, Context) Export
	
	If Response <> "ClearAndWrite" Then
		Object.AdditionalValuesWithWeight = Not Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("ClearEnteredWeightCoefficients");
	
	FollowUpHandler = New NotifyDescription("AdditionalValuesWithWeightOnChangeCompletion", ThisObject);
	WriteObject("WeightUsageEdit", FollowUpHandler,, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterConfirmEnableWeightCoefficients(Response, Context) Export
	
	If Response <> "Write" Then
		Object.AdditionalValuesWithWeight = Not Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	FollowUpHandler = New NotifyDescription("AdditionalValuesWithWeightOnChangeCompletion", ThisObject);
	WriteObject("WeightUsageEdit", FollowUpHandler);
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChangeCompletion(Cancel, Context) Export
	
	If Cancel Then
		Object.AdditionalValuesWithWeight = Not Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		Notify(
			"ChangeValueIsCharacterizedByWeightCoefficient",
			Object.AdditionalValuesWithWeight,
			Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentCommentClickCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowSetAdjustment", True);
	FormParameters.Insert("Key", Object.AdditionalValuesOwner);
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, FormOwner);
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClickFollowUp(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If SetsList.Count() > 1 Then
		ShowChooseFromList(
			New NotifyDescription("SetsAdjustmentCommentClickCompletion", ThisObject),
			SetsList, Items.SetsAdjustmentComment);
	Else
		SetsAdjustmentCommentClickCompletion(Undefined, SetsList[0].Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetsAdjustmentCommentClickCompletion(SelectedElement, SelectedSet) Export
	
	If SelectedElement <> Undefined Then
		SelectedSet = SelectedElement.Value;
	EndIf;
	
	If Not ValueIsFilled(CurrentPropertiesSet) Then
		Return;
	EndIf;
	
	If SelectedSet <> Undefined Then
		SelectionValue = New Structure;
		SelectionValue.Insert("Set", SelectedSet);
		SelectionValue.Insert("Property", Object.Ref);
		SelectionValue.Insert("PropertyKind", Object.PropertyKind);
		NotifyChoice(SelectionValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesBeforeAddRowCompletion(Cancel, ProcessingParameters) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If AttributeAddMode = "CreateByCopying" Then
		Items.AttributeValuePages.CurrentPage = Items.AdditionalValues;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ValueTableName = "Catalog.ObjectsPropertiesValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	FillingValues = New Structure;
	FillingValues.Insert("Parent", ProcessingParameters.Parent);
	FillingValues.Insert("Owner", Object.Ref);
	
	FormParameters = New Structure;
	FormParameters.Insert("HideOwner", True);
	FormParameters.Insert("FillingValues", FillingValues);
	
	If ProcessingParameters.Group Then
		FormParameters.Insert("IsFolder", True);
		
		OpenForm(ValueTableName + ".FolderForm", FormParameters, Items.Values);
	Else
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		
		If ProcessingParameters.Copy Then
			FormParameters.Insert("CopyingValue", Items.Values.CurrentRow);
		EndIf;
		
		OpenForm(ValueTableName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesBeforeRowChangeCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ValueTableName = "Catalog.ObjectsPropertiesValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	If Items.Values.CurrentRow <> Undefined Then
		// Opening a value form or a value set.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.Values.CurrentRow);
		
		OpenForm(ValueTableName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentChangeCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("AdditionalValuesOwner", Object.AdditionalValuesOwner);
	FormParameters.Insert("IsAdditionalInfo", Object.IsAdditionalInfo);
	FormParameters.Insert("PropertyKind", Object.PropertyKind);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.EditPropertySettings",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SetsAdjustmentChangeCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("AdditionalValuesOwner", Object.AdditionalValuesOwner);
	FormParameters.Insert("IsAdditionalInfo", Object.IsAdditionalInfo);
	FormParameters.Insert("PropertyKind", Object.PropertyKind);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.EditPropertySettings",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure WriteObject(QuestionTextVariant, FollowUpHandler, AdditionalParameters = Undefined, WriteParameters = Undefined)
	
	If WriteParameters = Undefined Then
		WriteParameters = New Structure;
	EndIf;
	
	If QuestionTextVariant = "DeletionMarkEdit" Then
		If Modified Then
			If Object.DeletionMark Then
				QueryText = NStr("en = 'Save the changes before clearing the deletion mark. Do you want to save the changes?';es_CO = 'Guarde los cambios antes de borrar la marca de borrado. ¿Desea guardar los cambios?'");
			Else
				QueryText = NStr("en = 'Save the changes before marking for deletion. Do you want to save the changes?';es_CO = 'Guarde los cambios antes de activar la marca de borrado. ¿Desea guardar los cambios?'");
			EndIf;
		Else
			QueryText = NStr("en = 'Do you want to mark ""%1"" for deletion?';es_CO = '¿Desea marcar ""%1"" para su eliminación?'");
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, Object.Description);
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription(
				FollowUpHandler.ProcedureName, FollowUpHandler.Module, WriteParameters),
			QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Ref) And Not Modified Then
		ExecuteNotifyProcessing(New NotifyDescription(
			FollowUpHandler.ProcedureName, FollowUpHandler.Module, AdditionalParameters), False);
		Return;
	EndIf;
	
	ContinuationHandler = New Structure;
	ContinuationHandler.Insert("ProcedureName", FollowUpHandler.ProcedureName);
	ContinuationHandler.Insert("Parameters", AdditionalParameters);
	WriteParameters.Insert("ContinuationHandler", ContinuationHandler);
	
	If ValueIsFilled(Object.Ref) Then
		ProcessingEndOfRecording = New NotifyDescription("WriteObjectContinuation", ThisObject, WriteParameters);
		AttachIdleHandler("Attachable_EndOfObjectRecording", 0.1, True);
		Return;
	EndIf;
	
	If QuestionTextVariant = "GoToValueList" Then
		QueryText = NStr("en = 'Do you want to save the data and open the list of values?';es_CO = '¿Desea guardar los datos y abrir la lista de valores?'");
	Else
		QueryText = NStr("en = 'Do you want to save the data?';es_CO = '¿Desea guardar los datos?'")
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Write", NStr("en = 'Save';es_CO = 'Guardar'"));
	Buttons.Add("Cancel", NStr("en = 'Cancel';es_CO = 'Cancelar'"));
	
	ShowQueryBox(
		New NotifyDescription(
			"WriteObjectContinuation", ThisObject, WriteParameters),
		QueryText, Buttons, , "Write");
	
EndProcedure

&AtClient
Procedure Attachable_EndOfObjectRecording()
	
	ExecuteNotifyProcessing(ProcessingEndOfRecording, "Write");
	
EndProcedure

&AtClient
Procedure SetClearDeletionMarkFollowUp(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		Object.DeletionMark = Not Object.DeletionMark;
	EndIf;
	WriteObjectContinuation(Response, WriteParameters);
	
EndProcedure


&AtClient
Procedure WriteObjectContinuation(Response, WriteParameters) Export
	
	If Response = "Write"
		Or Response = DialogReturnCode.Yes Then
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWriteError()
	
	If ContinuationHandlerOnWriteError <> Undefined Then
		ExecuteNotifyProcessing(
			New NotifyDescription(ContinuationHandlerOnWriteError.ProcedureName,
				ThisObject, ContinuationHandlerOnWriteError.Parameters),
			True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditValueFormatCompletion(Text, Context) Export
	
	If Text <> Undefined Then
		Object.FormatProperties = Text;
		SetFormatButtonTitle(ThisObject);
		
		WarningText = NStr("en = 'The following format settings are not applied automatically in most cases:';es_CO = 'Las siguientes configuracíon de formato no se aplican automáticamente en la mayoría de los casos:'");
		Array = StrSplit(Text, ";", False);
		
		For Each Substring In Array Do
			If StrFind(Substring, "ДП=") > 0 Or StrFind(Substring, "DE=") > 0 Then // @Non-NLS
				WarningText = WarningText + Chars.LF
					+ " - " + NStr("en = 'Blank date presentation';es_CO = 'Presentación de la fecha en blanco'");
				Continue;
			EndIf;
			If StrFind(Substring, "ЧН=") > 0 Or StrFind(Substring, "NZ=") > 0 Then // @Non-NLS
				WarningText = WarningText + Chars.LF
					+ " - " + NStr("en = 'Blank number presentation';es_CO = 'Presentación del número en blanco'");
				Continue;
			EndIf;
			If StrFind(Substring, "ДФ=") > 0 Or StrFind(Substring, "DF=") > 0 Then // @Non-NLS
				If StrFind(Substring, "ддд") > 0 Or StrFind(Substring, "ddd") > 0 Then // @Non-NLS
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("en = 'Short weekday name';es_CO = 'Nombre corto del día de semana'");
				EndIf;
				If StrFind(Substring, "дддд") > 0 Or StrFind(Substring, "dddd") > 0 Then // @Non-NLS
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("en = 'Full weekday name';es_CO = 'Nombre completo del día de semana'");
				EndIf;
				If StrFind(Substring, "МММ") > 0 Or StrFind(Substring, "MMM") > 0 Then // @Non-NLS
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("en = 'Short month name';es_CO = 'Nombre corto del mes'");
				EndIf;
				If StrFind(Substring, "ММММ") > 0 Or StrFind(Substring, "MMMM") > 0 Then // @Non-NLS
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("en = 'Full month name';es_CO = 'Nombre completo del mes'");
				EndIf;
			EndIf;
			If StrFind(Substring, "ДЛФ=") > 0 Or StrFind(Substring, "DLF=") > 0 Then // @Non-NLS
				If StrFind(Substring, "ДД") > 0 Or StrFind(Substring, "DD") > 0 Then // @Non-NLS
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("en = 'Long date (month in words)';es_CO = 'Fecha larga (mes en palabras)'");
				EndIf;
			EndIf;
		EndDo;
		
		If StrLineCount(WarningText) > 1 Then
			ShowMessageBox(, WarningText);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetWizardSettings(CurrentPage = Undefined)
	
	If CurrentPage = Undefined Then
		CurrentPage = Items.WIzardCardPages.CurrentPage;
	EndIf;
	
	If CurrentPage = Items.SelectAttribute Then
		
		If PassedFormParameters.PropertyKind =
			PredefinedValue("Enum.PropertiesKinds.AdditionalInfo") Then
			Title = NStr("en = 'Add additional information record';es_CO = 'Añadir el registro de información adicional'");
			ListHeaderTemplate =
				NStr("en = 'Select an additional information record to include in the ""%1"" set';es_CO = 'Seleccione el registro de información adicional para incluirlo en el conjunto ""%1""'");
			RadioButtonHeaderTemplate =
				NStr("en = 'Select an option to add the ""%1"" additional information record to the ""%2"" set';es_CO = 'Seleccione una opción para añadir el registro de información adicional ""%1"" al conjunto ""%2""'");
		ElsIf PassedFormParameters.PropertyKind =
			PredefinedValue("Enum.PropertiesKinds.Labels") Then
			Title = NStr("en = 'Add label';es_CO = 'Añadir una etiqueta'");
			ListHeaderTemplate =
				NStr("en = 'Select a label to include in the ""%1"" set';es_CO = 'Seleccione una etiqueta para incluirla en el conjunto ""%1""'");
			RadioButtonHeaderTemplate =
				NStr("en = 'Select an option to add the ""%1"" label to the ""%2"" set';es_CO = 'Seleccione una opción para añadir la etiqueta ""%1"" al conjunto ""%2""'");
		Else
			Title = NStr("en = 'Add additional attribute';es_CO = 'Añadir el requisito adicional'");
			ListHeaderTemplate =
				NStr("en = 'Select an additional attribute to include in the ""%1"" set';es_CO = 'Seleccione un atributo adicional para incluirlo en el conjunto ""%1""'");
			RadioButtonHeaderTemplate =
				NStr("en = 'Select an option to add the ""%1"" additional attribute to the ""%2"" set';es_CO = 'Seleccione una opción para añadir el atributo adicional ""%1"" al conjunto ""%2""'");
		EndIf;
		
		Items.CommandBarLeft.Enabled = False;
		Items.NextCommand.Title = NStr("en = 'Next >';es_CO = 'Siguiente >'");
		
		
		Items.TitleDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			ListHeaderTemplate,
			String(PassedFormParameters.CurrentPropertiesSet));
		
	ElsIf CurrentPage = Items.ActionChoice Then
		
		If PassedFormParameters.CopyWithQuestion Then
			Items.CommandBarLeft.Enabled = False;
			AdditionalValuesOwner = PassedFormParameters.AdditionalValuesOwner;
		Else
			Items.CommandBarLeft.Enabled = True;
			SelectedElement = Items.Properties.CurrentData;
			If SelectedElement = Undefined Then
				AdditionalValuesOwner = PassedFormParameters.AdditionalValuesOwner;
			Else
				AdditionalValuesOwner = Items.Properties.CurrentData.Property;
			EndIf;
		EndIf;
		Items.NextCommand.Title = NStr("en = 'Next >';es_CO = 'Siguiente >'");
		
		Items.AttributeAddMode.Title = StringFunctionsClientServer.SubstituteParametersToString(
			RadioButtonHeaderTemplate,
			String(AdditionalValuesOwner),
			String(PassedFormParameters.CurrentPropertiesSet));
		
		If PassedFormParameters.PropertyKind =
			PredefinedValue("Enum.PropertiesKinds.AdditionalInfo") Then
			Title = NStr("en = 'Add additional information record';es_CO = 'Añadir el registro de información adicional'");
		ElsIf PassedFormParameters.PropertyKind =
			PredefinedValue("Enum.PropertiesKinds.Labels") Then
			Title = NStr("en = 'Add label';es_CO = 'Añadir una etiqueta'");
		Else
			Title = NStr("en = 'Add additional attribute';es_CO = 'Añadir el requisito adicional'");
		EndIf;
		
	Else
		Items.NextCommand.Title = NStr("en = 'Finish';es_CO = 'Finalizar'");
		Items.CommandBarLeft.Enabled = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshFormItemsContent(WarningText = "")
	
	If WizardMode Then
		CommandBarLocation = FormCommandBarLabelLocation.None;
		Items.NextCommand.DefaultButton    = True;
	Else
		Items.WizardCommandBar.Visible = False;
		Items.WIzardCardPages.CurrentPage = Items.AttributeCard;
	EndIf;
	
	SetFormHeader();
	
	If Not Object.ValueType.ContainsType(Type("Number"))
	   And Not Object.ValueType.ContainsType(Type("Date"))
	   And Not Object.ValueType.ContainsType(Type("Boolean")) Then
		
		Object.FormatProperties = "";
	EndIf;
	
	SetFormatButtonTitle(ThisObject);
	
	If Object.IsAdditionalInfo
	 Or Not (    Object.ValueType.ContainsType(Type("Number" ))
	         Or Object.ValueType.ContainsType(Type("Date"  ))
	         Or Object.ValueType.ContainsType(Type("Boolean")) )Then
		Items.EditValueFormat.Visible = False;
	Else
		Items.EditValueFormat.Visible = True;
	EndIf;
	
	If Object.IsAdditionalInfo
		And Object.ValueType.ContainsType(Type("String"))
		And Object.ValueType.StringQualifiers.Length = 0 Then
		Items.ValueTypeNoteGroup.Visible = True;
	Else
		Items.ValueTypeNoteGroup.Visible = False;
	EndIf;
	
	If Not Object.IsAdditionalInfo Then
		Items.MultilineGroup.Visible = True;
		SwitchAttributeDisplaySettings(Object.ValueType);
	Else
		Items.MultilineGroup.Visible = False;
	EndIf;
	
	If Object.PropertyKind = Enums.PropertiesKinds.Labels Then
		Object.ValueType = New TypeDescription("Boolean");
		Items.ValueTypeGroup.Visible = False;
		Items.GroupPropertiesColors.Visible = True;
		Items.OutputAsHyperlink.Visible = False;
		Items.ItemVisibilityGroup.Visible = False;
		Items.ItemAvailabilityGroup.Visible = False;
		Items.PropertyGray.Check = True;
		Items.Title.TypeRestriction = New TypeDescription("String",, New StringQualifiers(15));
		If Not ValueIsFilled(Object.PropertiesColor) Then
			Object.PropertiesColor = Enums.PropertiesColors.Gray;
		EndIf;
		SetLabelColor(ThisObject, Object.PropertiesColor);
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		OldValueType = Common.ObjectAttributeValue(Object.Ref, "ValueType");
	Else
		OldValueType = New TypeDescription;
	EndIf;
	
	If Object.IsAdditionalInfo Then
		Object.RequiredToFill = False;
		Items.PropertiesAndDependenciesGroup.Visible = False;
	Else
		AttributeBoolean = (Object.ValueType = New TypeDescription("Boolean"));
		Items.RequiredToFill.Visible    = Not AttributeBoolean;
		Items.ChooseItemRequiredOption.Visible = Not AttributeBoolean;
		Items.PropertiesAndDependenciesGroup.Visible = True;
		
		Items.ChooseItemRequiredOption.Enabled  = Object.RequiredToFill;
		Items.ChooseAvailabilityOption.Enabled = True;
		Items.ChooseVisibilityOption.Enabled   = True;
		
		SetHyperlinkTitles();
	EndIf;
	
	If ValueIsFilled(Object.AdditionalValuesOwner) Then
		
		OwnerProperties = Common.ObjectAttributesValues(
			Object.AdditionalValuesOwner, "ValueType, AdditionalValuesWithWeight");
		
		If OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectPropertyValueHierarchy",
				"CatalogRef.ObjectsPropertiesValues");
		Else
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectsPropertiesValues",
				"CatalogRef.ObjectPropertyValueHierarchy");
		EndIf;
		
		ValuesOwner = Object.AdditionalValuesOwner;
		ValuesWithWeight   = OwnerProperties.AdditionalValuesWithWeight;
	Else
		// Checking possibility to delete an additional value type.
		If PropertyManagerInternal.ValueTypeContainsPropertyValues(OldValueType) Then
			Query = New Query;
			Query.SetParameter("Owner", Object.Ref);
			
			If OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
				|WHERE
				|	ObjectPropertyValueHierarchy.Owner = &Owner";
			Else
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
				|WHERE
				|	ObjectsPropertiesValues.Owner = &Owner";
			EndIf;
			
			If Not Query.Execute().IsEmpty() Then
				
				If OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
				   And Not Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot delete the ""%1"" type
						           |as additional values are already entered.
						           |Please delete the additional values first.
						           |
						           |The deletion is canceled.';es_CO = 'No se puede eliminar el tipo ""%1""
						           | porque ya se han ingresado valores adicionales.
						           | Elimine primero los valores adicionales.
						           |
						           | Se cancela la eliminación.'"),
						String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectPropertyValueHierarchy",
						"CatalogRef.ObjectsPropertiesValues");
				
				ElsIf OldValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
				        And Not Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot delete the ""%1"" type
						           |as additional values are already entered.
						           |Please delete the additional values first.
						           |
						           |The deletion is canceled.';es_CO = 'No se puede eliminar el tipo ""%1""
						           | porque ya se han ingresado valores adicionales.
						           | Elimine primero los valores adicionales.
						           |
						           | Se cancela la eliminación.'"),
						String(Type("CatalogRef.ObjectsPropertiesValues")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectsPropertiesValues",
						"CatalogRef.ObjectPropertyValueHierarchy");
				EndIf;
			EndIf;
		EndIf;
		
		// Checking that not more than one additional value type is set.
		If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
		   And Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
			
			If Not OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				
				WarningText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot use both
					           |""%1"" and
					           |""%2"" value types at the same time.
					           |
					           |The second type is deleted.';es_CO = 'No se pueden usar los tipos de valor 
					           |""%1"" y 
					           |""%2"" al mismo tiempo.
					           |
					           | El segundo tipo se elimina.'"),
					String(Type("CatalogRef.ObjectsPropertiesValues")),
					String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
				
				// Deletion of the second type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectPropertyValueHierarchy");
			Else
				WarningText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot use both
					           |""%1"" and
					           |""%2"" value types at the same time.
					           |
					           |The first type is deleted.';es_CO = 'No se pueden usar los tipos de valor 
					           |""%1"" y 
					           |""%2"" al mismo tiempo.
					           |
					           | El primer tipo se elimina.'"),
					String(Type("CatalogRef.ObjectsPropertiesValues")),
					String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
				
				// Deletion of the first type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectsPropertiesValues");
			EndIf;
		EndIf;
		
		ValuesOwner = Object.Ref;
		ValuesWithWeight   = Object.AdditionalValuesWithWeight;
	EndIf;
	
	If PropertyManagerInternal.ValueTypeContainsPropertyValues(Object.ValueType) Then
		Items.ValueFormsHeadersGroup.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
		Items.ValuePage.Visible = True;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	Else
		Items.ValueFormsHeadersGroup.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		Items.ValuePage.Visible = False;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	Items.Values.Header        = ValuesWithWeight;
	Items.ValuesWeight.Visible = ValuesWithWeight;
	
	CommonClientServer.SetDynamicListFilterItem(
		Values, "Owner", ValuesOwner, , , True);
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.QueryText =
			"SELECT
			|	Values.Ref,
			|	Values.DataVersion,
			|	Values.DeletionMark,
			|	Values.Predefined,
			|	Values.Owner,
			|	Values.Parent,
			|	Values.Description AS Description,
			|	Values.Weight
			|FROM
			|	Catalog.ObjectsPropertiesValues AS Values";
		ListProperties.MainTable = "Catalog.ObjectsPropertiesValues";
		
		CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
		If CurrentLanguageSuffix = Undefined Then
			
			ListProperties.QueryText = ListProperties.QueryText + "
			|	LEFT JOIN Catalog.ObjectsPropertiesValues.Presentations AS PresentationValues
			|		ON (PresentationValues.Ref = Values.Ref)
			|		AND PresentationValues.LanguageCode = &LanguageCode";
			
			ListProperties.QueryText  = StrReplace(ListProperties.QueryText, "Values.Description AS Description", 
				"CAST(ISNULL(PresentationValues.Description, Values.Description) AS STRING(150)) AS Description");
			
		ElsIf ValueIsFilled(CurrentLanguageSuffix) 
				And Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
					ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
					ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(ListProperties.QueryText, "Values.Description");
		EndIf;
		
		Common.SetDynamicListProperties(Items.Values,
			ListProperties);
	Else
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.QueryText =
			"SELECT
			|	Values.Ref,
			|	Values.DataVersion,
			|	Values.DeletionMark,
			|	Values.Predefined,
			|	Values.Owner,
			|	Values.Parent,
			|	Values.Description AS Description,
			|	Values.Weight
			|FROM
			|	Catalog.ObjectPropertyValueHierarchy AS Values";
		ListProperties.MainTable = "Catalog.ObjectPropertyValueHierarchy";
		
		CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
		If CurrentLanguageSuffix = Undefined Then
			
			ListProperties.QueryText = ListProperties.QueryText + "
			|	LEFT JOIN Catalog.ObjectPropertyValueHierarchy.Presentations AS PresentationValues
			|		ON (PresentationValues.Ref = Values.Ref)
			|		AND PresentationValues.LanguageCode = &LanguageCode";
			
			ListProperties.QueryText  = StrReplace(ListProperties.QueryText, "Values.Description AS Description", 
				"CAST(ISNULL(PresentationValues.Description, Values.Description) AS STRING(150)) AS Description");
			
		ElsIf ValueIsFilled(CurrentLanguageSuffix) 
			And Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
				ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
				ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(ListProperties.QueryText, "Values.Description");
		EndIf;
		
		Common.SetDynamicListProperties(Items.Values, ListProperties);
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		Values, "LanguageCode", CurrentLanguage().LanguageCode, True);
	
	If Not ValueIsFilled(Object.AdditionalValuesOwner) Then
		Items.ValueListAdjustment.Visible = False;
		Items.AdditionalValues.ReadOnly = False;
		Items.ValuesEditingCommandBar.Visible = True;
		Items.ValuesEditingContextMenu.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
	Else
		Items.ValueListAdjustment.Visible = True;
		Items.AdditionalValues.ReadOnly = True;
		Items.ValuesEditingCommandBar.Visible = False;
		Items.ValuesEditingContextMenu.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		
		Items.ValueListAdjustmentComment.Hyperlink = ValueIsFilled(Object.Ref);
		Items.ValueListAdjustmentChange.Enabled    = ValueIsFilled(Object.Ref);
		
		OwnerProperties = Common.ObjectAttributesValues(
			Object.AdditionalValuesOwner, "Title, PropertyKind");
		
		If OwnerProperties.PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
			AdjustmentTemplate = NStr("en = 'The value list is shared with the ""%1"" information record';es_CO = 'La lista de valores se comparte con el registro de información ""%1""'");
		ElsIf OwnerProperties.PropertyKind = Enums.PropertiesKinds.Labels Then
			AdjustmentTemplate = NStr("en = 'The value list is shared with the ""%1"" label';es_CO = 'La lista de valores se comparte con la etiqueta ""%1""'");
		Else
			AdjustmentTemplate = NStr("en = 'The value list is shared with the ""%1"" attribute';es_CO = 'La lista de valores se comparte con el atributo ""%1""'");
		EndIf;
		
		Items.ValueListAdjustmentComment.Title =
			StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, OwnerProperties.Title);
	EndIf;
	
	RefreshSetsList();
	
	If Not ShowSetAdjustment And SetsList.Count() < 2 Then
		
		Items.SetsAdjustment.Visible = False;
	Else
		Items.SetsAdjustment.Visible = True;
		Items.SetsAdjustmentComment.Hyperlink = True;
		
		Items.SetsAdjustmentChange.Enabled = ValueIsFilled(Object.Ref);
		
		If SetsList.Count() < 2 Then
			
			Items.SetsAdjustmentChange.Visible = False;
		
		ElsIf ValueIsFilled(CurrentPropertiesSet) Then
			Items.SetsAdjustmentChange.Visible = True;
		Else
			Items.SetsAdjustmentChange.Visible = False;
		EndIf;
		
		If SetsList.Count() = 0 Then
			Items.SetsAdjustmentComment.Hyperlink = False;
			Items.SetsAdjustmentChange.Visible = False;
			
			If Object.PropertyKind = Enums.PropertiesKinds.AdditionalInfo
				Or Object.IsAdditionalInfo Then
				CommentText1 = NStr("en = 'The information record is not included in any sets';es_CO = 'El registro de información no está incluido en ningún conjunto'");
			ElsIf Object.PropertyKind = Enums.PropertiesKinds.Labels Then
				CommentText1 = NStr("en = 'The label is not included in any sets';es_CO = 'La etiqueta no está incluida en ningún conjunto'");
			Else
				CommentText1 = NStr("en = 'The attribute is not included in any sets';es_CO = 'El atributo no está incluido en ningún conjunto'");
			EndIf;
		ElsIf SetsList.Count() < 2 Then
			If Object.PropertyKind = Enums.PropertiesKinds.AdditionalInfo
				Or Object.IsAdditionalInfo Then
				AdjustmentTemplate = NStr("en = 'The information record is included in the set: %1';es_CO = 'El registro de información está incluido en el conjunto: %1'");
			ElsIf Object.PropertyKind = Enums.PropertiesKinds.Labels Then
				AdjustmentTemplate = NStr("en = 'The label is included in the set: %1';es_CO = 'La etiqueta está incluida en el conjunto: %1'");
			Else
				AdjustmentTemplate = NStr("en = 'The attribute is included in the set: %1';es_CO = 'El atributo está incluido en el conjunto: %1'");
			EndIf;
			CommentText1 = StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, TrimAll(SetsList[0].Presentation));
		Else
			If Object.PropertyKind = Enums.PropertiesKinds.AdditionalInfo
				Or Object.IsAdditionalInfo Then
				AdjustmentTemplate = NStr("en = 'The information record is included in %1 %2';es_CO = 'El registro de información está incluido en %1 %2'");
			ElsIf Object.PropertyKind = Enums.PropertiesKinds.Labels Then
				AdjustmentTemplate = NStr("en = 'The label is included in %1 %2';es_CO = 'La etiqueta está incluida en %1 %2'");
			Else
				AdjustmentTemplate = NStr("en = 'The attribute is included in %1 %2';es_CO = 'El atributo está incluido en el conjunto %1 %2'");
			EndIf;
			
			StringSets = UsersInternalClientServer.IntegerSubject(SetsList.Count(),
				"", NStr("en = 'set,sets,,,0';es_CO = 'conjunto,conjuntos,,,0'"));
			
			CommentText1 = StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, Format(SetsList.Count(), "NG="), StringSets);
		EndIf;
		
		Items.SetsAdjustmentComment.Title = CommentText1 + " ";
		
		If Items.SetsAdjustmentComment.Hyperlink Then
			Items.SetsAdjustmentComment.ToolTip = NStr("en = 'Go to set.';es_CO = 'Ir al conjunto.'");
		Else
			Items.SetsAdjustmentComment.ToolTip = "";
		EndIf;
	EndIf;
	
	Items.FillIDForFormulas.Enabled = Not Items.IDForFormulas.ReadOnly;
	
EndProcedure

&AtServer
Procedure SwitchAttributeDisplaySettings(ValueType)
	
	AllowMultilineFieldChoice = (Object.ValueType.Types().Count() = 1)
		And (Object.ValueType.ContainsType(Type("String")));
	AllowDisplayAsHyperlink   = AllowMultilineFieldChoice
		Or (Not Object.ValueType.ContainsType(Type("String"))
			And Not Object.ValueType.ContainsType(Type("Date"))
			And Not Object.ValueType.ContainsType(Type("Boolean"))
			And Not Object.ValueType.ContainsType(Type("Number")));
	
	Items.SingleLineKind.Visible                       = AllowMultilineFieldChoice;
	Items.MultilineInputFieldGroupSettings.Visible = AllowMultilineFieldChoice;
	Items.OutputAsHyperlink.Visible              = AllowDisplayAsHyperlink;
	
EndProcedure

&AtServer
Procedure ClearEnteredWeightCoefficients()
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ValueTableName = "Catalog.ObjectsPropertiesValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	Block = New DataLock;
	Block.Add(ValueTableName);
	
	BeginTransaction();
	Try
		Block.Lock();
		Query = New Query;
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref
		|FROM
		|	Catalog.ObjectsPropertiesValues AS CurrentTable
		|WHERE
		|	CurrentTable.Weight <> 0";
		Query.Text = StrReplace(Query.Text , "Catalog.ObjectsPropertiesValues", ValueTableName);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ValueObject = Selection.Ref.GetObject();// CatalogObject.ObjectsPropertiesValues
			ValueObject.Weight = 0;
			ValueObject.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure RefreshSetsList()
	
	SetsList.Clear();
	
	If ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT
		|	AdditionalAttributes.Ref AS Set,
		|	AdditionalAttributes.Ref.Description
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Property = &Property
		|	AND NOT AdditionalAttributes.Ref.IsFolder
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalInfo.Ref,
		|	AdditionalInfo.Ref.Description
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS AdditionalInfo
		|WHERE
		|	AdditionalInfo.Property = &Property
		|	AND NOT AdditionalInfo.Ref.IsFolder");
		
		Query.SetParameter("Property", Object.Ref);
		
		BeginTransaction();
		Try
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				SetsList.Add(Selection.Set, Selection.Description + "         ");
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCurrentPageChange(Direction, BasicPage, CurrentPage)
	
	BasicPage.CurrentPage = CurrentPage;
	If CurrentPage = Items.ActionChoice Then
		If Direction = "GoForward" Then
			SelectedElement = Items.Properties.CurrentData;
			PassedFormParameters.AdditionalValuesOwner = SelectedElement.Property;
			FillActionListOnAddAttribute();
		EndIf;
	ElsIf CurrentPage = Items.AttributeCard Then
		FillPropertyCard();
	EndIf;
	
EndProcedure

&AtServer
Function AttributeWithAdditionalValuesList()
	
	AttributeWithAdditionalValuesList = True;
	OwnerProperties = Common.ObjectAttributesValues(
		PassedFormParameters.AdditionalValuesOwner, "ValueType");
	If Not OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
		And Not OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		AttributeWithAdditionalValuesList = False;
	EndIf;
	
	Return AttributeWithAdditionalValuesList;
EndFunction

&AtServer
Procedure FillActionListOnAddAttribute()
	
	AttributeWithAdditionalValuesList = AttributeWithAdditionalValuesList();
	
	If PassedFormParameters.PropertyKind = Enums.PropertiesKinds.AdditionalInfo Then
		AddCommon = NStr("en = 'Add the information record ""as is"" (recommended)
			|
			|You can use this information record to filter data of different types in lists and reports.';es_CO = 'Añada el registro de información ""tal cual"" (recomendado)
			|
			|Se puede utilizar este registro de información para filtrar los datos de diferentes tipos en las listas e informes.'");
		MakeBySample = NStr("en = 'Copy the information record from a master record (with a shared value list)
			|
			|Both records will share a value list.
			|This option is recommended to configure values for similar information records.
			|You can edit the record description and some other properties.';es_CO = 'Copie el registro de información desde el registro maestro (con una lista de valores compartida)
			|
			|Ambos registros compartirán una lista de valores.
			|Se recomienda esta opción para configurar los valores para los registros de información similares.
			|Se puede editar la descripción del registro y algunas otras propiedades.'");
		If AttributeWithAdditionalValuesList Then
			CreateByCopying = NStr("en = 'Copy the information record
				|
				|A copy of the information record and all its values will be created.';es_CO = 'Copie el registro de información
				|
				|Se creará una copia del registro de información y todos sus valores.'")
		Else
			CreateByCopying = NStr("en = 'Copy the information record
				|
				|A copy of the information record will be created.';es_CO = 'Copie el registro de información
				|
				|Se creará una copia del registro de información.'");
		EndIf;
	ElsIf PassedFormParameters.PropertyKind = Enums.PropertiesKinds.Labels Then
		AddCommon = NStr("en = 'Add the label ""as is"" (recommended)
			|
			|You can use this label to filter data of different types in lists and reports.';es_CO = 'Añada la etiqueta ""tal cual"" (recomendado)
			|
			|Se puede utilizar esta etiqueta para filtrar los datos de diferentes tipos en las listas e informes.'");
		CreateByCopying = NStr("en = 'Copy the label
			|
			|A copy of the label will be created.';es_CO = 'Copie la etiqueta
			|
			|Se creará una copia de la etiqueta.'");
	Else
		AddCommon = NStr("en = 'Add the attribute ""as is"" (recommended)
			|
			|You can use this attribute to filter data of different types in lists and reports.';es_CO = 'Añada el atributo ""tal cual"" (recomendado)
			|
			|Se puede utilizar este atributo para filtrar los datos de diferentes tipos en las listas e informes.'");
		MakeBySample = NStr("en = 'Copy the attribute from a master attribute (with a shared value list)
			|
			|Both attributes will share a value list.
			|This option is recommended to configure values for similar attributes.
			|You can edit the attribute description and some other properties.';es_CO = 'Copie el atributo desde el atributo maestro (con una lista de valores compartida)
			|
			|Ambos atributos compartirán una lista de valores.
			|Se recomienda esta opción para configurar los valores para los atributos similares.
			|Se puede editar la descripción del atributo y algunas otras propiedades.'");
		If AttributeWithAdditionalValuesList Then
			CreateByCopying = NStr("en = 'Copy the attribute
				|
				|A copy of the attribute and all its values will be created.';es_CO = 'Copie el atributo
				|
				|Se creará una copia del atributo y todos sus valores.'");
		Else
			CreateByCopying = NStr("en = 'Copy the attribute
				|
				|A copy of the attribute will be created.';es_CO = 'Copie el atributo
				|
				|Se creará una copia del atributo.'");
		EndIf;
	EndIf;
	
	ChoiceList = Items.AttributeAddMode.ChoiceList;
	ChoiceList.Clear();
	
	ChoiceList.Add("AddCommonAttributeToSet", AddCommon);
	If AttributeWithAdditionalValuesList Then
		ChoiceList.Add("CreateBySample", MakeBySample);
	EndIf;
	ChoiceList.Add("CreateByCopying", CreateByCopying);
	
	AttributeAddMode = "AddCommonAttributeToSet";
	
EndProcedure

&AtServer
Procedure WriteAdditionalAttributeValuesOnCopy(CurrentObject)
	
	If CurrentObject.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		Parent = Catalogs.ObjectPropertyValueHierarchy.EmptyRef();
	Else
		Parent = Catalogs.ObjectsPropertiesValues.EmptyRef();
	EndIf;
	
	Owner = CurrentObject.Ref;
	TreeRow = AdditionalAttributesValues.GetItems();
	WriteAdditionalAttributeValuesOnCopyRecursively(Owner, TreeRow, Parent);
	TreeRow.Clear();
	Items.AttributeValuePages.CurrentPage = Items.AdditionalValues;
	
EndProcedure

&AtServer
Procedure WriteAdditionalAttributeValuesOnCopyRecursively(Owner, TreeRow, Parent)
	
	For Each TreeItem In TreeRow Do
		ObjectCopy = TreeItem.Ref.GetObject().Copy();
		ObjectCopy.Owner = Owner;
		ObjectCopy.Parent = Parent;
		ObjectCopy.Write(); // ACC:1327 New object record.
		
		SubordinateItems = TreeItem.GetItems();
		WriteAdditionalAttributeValuesOnCopyRecursively(Owner, SubordinateItems, ObjectCopy.Ref)
	EndDo;
	
EndProcedure

&AtServer
Procedure SetHyperlinkTitles()
	
	AvailabilityDependenceDefined              = False;
	RequiredFillingDependenceDefined = False;
	VisibilityDependenceDefined                = False;
	
	FilterBySet = New Structure;
	FilterBySet.Insert("PropertiesSet", CurrentPropertiesSet);
	FoundDependencies = Object.AdditionalAttributesDependencies.FindRows(FilterBySet);
	
	For Each PropertyDependence In FoundDependencies Do
		If PropertyDependence.DependentProperty = "Available" Then
			AvailabilityDependenceDefined = True;
		ElsIf PropertyDependence.DependentProperty = "RequiredToFill" Then
			RequiredFillingDependenceDefined = True;
		ElsIf PropertyDependence.DependentProperty = "isVisible" Then
			VisibilityDependenceDefined = True;
		EndIf;
	EndDo;
	
	TemplateDependenceDefined = NStr("en = 'conditionally';es_CO = 'condicionalmente'");
	TemplateDependenceNotDefined = NStr("en = 'always';es_CO = 'siempre'");
	
	Items.ChooseAvailabilityOption.Title = ?(AvailabilityDependenceDefined,
		TemplateDependenceDefined,
		TemplateDependenceNotDefined);
	
	Items.ChooseItemRequiredOption.Title = ?(RequiredFillingDependenceDefined,
		TemplateDependenceDefined,
		TemplateDependenceNotDefined);
	
	Items.ChooseVisibilityOption.Title = ?(VisibilityDependenceDefined,
		TemplateDependenceDefined,
		TemplateDependenceNotDefined);
	
EndProcedure

&AtClient
Procedure OpenDependenceSettingForm(PropertyToConfigure)
	
	FormParameters = New Structure;
	FormParameters.Insert("AdditionalAttribute", Object.Ref);
	FormParameters.Insert("AttributesDependencies", Object.AdditionalAttributesDependencies);
	FormParameters.Insert("Set", CurrentPropertiesSet);
	FormParameters.Insert("PropertyToConfigure", PropertyToConfigure);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.AttributesDependency", FormParameters);
	
EndProcedure

&AtServer
Procedure SetFormHeader()
	
	If ValueIsFilled(Object.Ref) Then
		If Object.PropertyKind = Enums.PropertiesKinds.AdditionalInfo
			Or Object.IsAdditionalInfo Then
			Title = String(Object.Title) + " " + NStr("en = '(Additional information record)';es_CO = '(Registro de información adicional)'");
		ElsIf Object.PropertyKind = Enums.PropertiesKinds.Labels Then
			Title = String(Object.Title) + " " + NStr("en = '(Label)';es_CO = 'Etiqueta'");
		Else
			Title = String(Object.Title) + " " + NStr("en = '(Additional attribute)';es_CO = '(Atributo adicional)'");
		EndIf;
	Else
		If Object.PropertyKind = Enums.PropertiesKinds.AdditionalInfo
			Or Object.IsAdditionalInfo Then
			Title = NStr("en = 'Additional information record (Create)';es_CO = 'Registro de información adicional (Crear)'");
		ElsIf Object.PropertyKind = Enums.PropertiesKinds.Labels Then
			Title = NStr("en = 'Label (Create)';es_CO = 'Etiqueta (creación)'");
		Else
			Title = NStr("en = 'Additional attribute (Create)';es_CO = 'Atributo adicional (Crear)'");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeCurrentSet()
	
	If Items.PropertiesSets.CurrentData = Undefined Then
		If ValueIsFilled(SelectedPropertiesSet) Then
			SelectedPropertiesSet = Undefined;
			OnChangeCurrentSetAtServer();
		EndIf;
		
	ElsIf Items.PropertiesSets.CurrentData.Ref <> SelectedPropertiesSet Then
		SelectedPropertiesSet = Items.PropertiesSets.CurrentData.Ref;
		CurrentSetIsFolder = Items.PropertiesSets.CurrentData.IsFolder;
		OnChangeCurrentSetAtServer(CurrentSetIsFolder);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeCurrentSetAtServer(CurrentSetIsFolder = Undefined)
	
	If ValueIsFilled(SelectedPropertiesSet)
		And Not CurrentSetIsFolder Then
		UpdateCurrentSetPropertiesList();
	Else
		Properties.Clear();
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCurrentSetPropertiesList()
	
	PropertyManagerInternal.UpdateCurrentSetPropertiesList(ThisObject, 
			SelectedPropertiesSet,
			PropertyKind);
	
EndProcedure

&AtServer
Procedure NewPassedParametersStructure()
	PassedFormParameters = New Structure;
	PassedFormParameters.Insert("AdditionalValuesOwner");
	PassedFormParameters.Insert("ShowSetAdjustment", True);
	PassedFormParameters.Insert("CurrentPropertiesSet");
	PassedFormParameters.Insert("PropertyKind");
	PassedFormParameters.Insert("SelectSharedProperty");
	PassedFormParameters.Insert("SelectedValues");
	PassedFormParameters.Insert("SelectAdditionalValuesOwner");
	PassedFormParameters.Insert("CopyingValue");
	PassedFormParameters.Insert("CopyWithQuestion");
	PassedFormParameters.Insert("Drag", False);
	
	FillPropertyValues(PassedFormParameters, Parameters, , "ShowSetAdjustment");
	
	ValuesOwner = PassedFormParameters.AdditionalValuesOwner;
	If ValueIsFilled(ValuesOwner) Then
		ValuesOwner = Common.ObjectAttributeValue(ValuesOwner, "AdditionalValuesOwner");
		If ValueIsFilled(ValuesOwner) Then
			PassedFormParameters.AdditionalValuesOwner = ValuesOwner;
		EndIf;
	EndIf;
EndProcedure

&AtServerNoContext
Function DescriptionAlreadyUsed(Val Title, Val CurrentProperty, Val PropertiesSet, NewDescription, Val TitleLanguage1, Val TitleLanguage2)
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		
		If ModuleNationalLanguageSupportServer.FirstAdditionalInfobaseLanguageCode() = CurrentLanguage().LanguageCode Then
			Title = TitleLanguage1;
		ElsIf ModuleNationalLanguageSupportServer.SecondAdditionalInfobaseLanguageCode() = CurrentLanguage().LanguageCode Then
			Title = TitleLanguage2;
		EndIf;
	
	EndIf;
	
	NewDescription = Title;
	
	Return PropertyManagerInternal.DescriptionAlreadyUsed(CurrentProperty, PropertiesSet, NewDescription);
	
EndFunction

&AtServerNoContext
Function NameAlreadyUsed(Val Name, Val CurrentProperty, NewDescription)
	
	Return PropertyManagerInternal.NameAlreadyUsed(Name, CurrentProperty);
	
EndFunction

&AtServerNoContext
Function IDForFormulasAlreadyUsed(Val IDForFormulas, Val CurrentProperty)
	
	QueryText = PropertyManagerInternal.IDForFormulasAlreadyUsed(IDForFormulas, CurrentProperty);
	If Not ValueIsFilled(QueryText) Then
		Return "";
	EndIf;
	
	Refinement = NStr("en = 'Do you want to create a new ID for formulas and continue saving?';es_CO = '¿Desea crear un nuevo identificador para las fórmulas y continuar guardando?'");
	QueryText = QueryText + Chars.LF + Chars.LF + Refinement;
	Return QueryText;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetFormatButtonTitle(Form)
	
	If IsBlankString(Form.Object.FormatProperties) Then
		TitleText = NStr("en = 'Default format';es_CO = 'Formato predeterminado'");
	Else
		TitleText = NStr("en = 'Custom format';es_CO = 'Formato personalizado'");
	EndIf;
	
	Form.Items.EditValueFormat.Title = TitleText;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetLabelColor(Form, ColorOfLabel)
	
	Items = Form.Items;
	Items.PropertyGray.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.EmptyRef")
								Or ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Gray"));
	Items.PropertyLightBlue.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.LightBlue"));
	Items.PropertyYellow.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Yellow"));
	Items.PropertyGreen.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Green"));
	Items.PropertyLime.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.GreenLime"));
	Items.PropertyRed.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Red"));
	Items.PropertyOrange.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Orange"));
	Items.PropertyPink.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Pink"));
	Items.PropertyBlue.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.B"));
	Items.PropertyPurple.Check = (ColorOfLabel = PredefinedValue("Enum.PropertiesColors.Violet"));
	
EndProcedure

#EndRegion