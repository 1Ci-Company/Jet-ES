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

&AtClient
Procedure OnOpen(Cancel)
	Cancel = True;
	ShowMessageBox(, NStr("en = 'The data processor cannot be opened manually.';es_CO = 'El procesador de datos no se puede abrir manualmente.'"));
EndProcedure

#EndRegion