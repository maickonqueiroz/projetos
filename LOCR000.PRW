#Include 'Protheus.ch'

/*/{Protheus.doc} LOCR000
//TODO: Taxa de ocupação de equipamentos (Locações e serviços)
@type function
@author Douglas Telles
@since 06/04/2017
@version 1.0
/*/
User Function LOCR000()
	Local cPerg		:= "TXOCUPA"
	Local cTitle	:= "Taxa de Ocupação de Equipamentos"
	Local lEnd		:= .F.
	Local bAction	:= {|lEnd| IIF(FilDados(@lEnd), (Consolidar(@lEnd), Imprimir(@lEnd)), Nil)}

	Private cTmpAlias	:= GetNextAlias()
	Private oProcess	:= Nil

	AjustaSx1(@cPerg)

	If Pergunte(cPerg, .T.)
		oProcess := MsNewProcess():New(bAction, cTitle, "[1/3] - " + cTitle, .T.)
		oProcess:Activate()
	EndIf

	If MsFile(cTmpAlias, '', "TOPCONN")
		FechaAlias(cTmpAlias)
		TCDelFile(cTmpAlias)
	EndIf
Return

/*/{Protheus.doc} FilDados
//TODO: (long_description)
@type function
@author Douglas Telles
@since 07/04/2017
@version 1.0
@param lEnd, ${param_type}, (Descrição do parâmetro)
@return lRet, ${return_description}
/*/
Static Function FilDados(lEnd)
	Local lRet		:= .F.
	Local cQuery	:= ""

	If lEnd
		Return lRet
	EndIf

	oProcess:SetRegua1(3)
	oProcess:SetRegua2(-1)

	oProcess:IncRegua1("[1/3] - " + oProcess:cTitle)
	oProcess:IncRegua2("Filtrando Dados Para Apresentação...")

	cQuery := "SELECT ZBX.ZBX_FROTA " + CRLF
	cQuery += "	,COUNT(ZBX.ZBX_FROTA) QTDMIN " + CRLF
	cQuery += "	,ZBX.ZBX_DATA " + CRLF
	cQuery += "	,ST9.T9_CODFAMI " + CRLF
	cQuery += "	,ST9.T9_NOME " + CRLF
	cQuery += "FROM " + RetSqlName("ZBX") + " ZBX " + CRLF
	cQuery += "INNER JOIN " + RetSqlName("ST9") + " ST9 " + CRLF
	cQuery += "	ON ST9.T9_CODBEM = ZBX.ZBX_FROTA " + CRLF
	cQuery += "	AND ST9.T9_CODFAMI BETWEEN '" + MV_PAR05 + "' AND '" + MV_PAR06 + "' " + CRLF
	cQuery += "	AND ST9.T9_STATUS <> '06' " + CRLF
	cQuery += "	AND ST9.D_E_L_E_T_ <> '*' " + CRLF
	cQuery += "WHERE ZBX.ZBX_FILIAL BETWEEN '" + MV_PAR01 + "' AND '" + MV_PAR02 + "' " + CRLF
	cQuery += "	AND ZBX.ZBX_STATUS IN('2', '3') " + CRLF
	cQuery += "	AND ZBX.ZBX_DATA BETWEEN '" + DTOS(MV_PAR03) + "' AND '" + DTOS(MV_PAR04) + "' " + CRLF
	cQuery += "	AND ZBX.D_E_L_E_T_ <> '*' " + CRLF
	cQuery += "GROUP BY ZBX.ZBX_FROTA, ZBX.ZBX_DATA, ST9.T9_CODFAMI, ST9.T9_NOME " + CRLF
	cQuery += "ORDER BY ST9.T9_CODFAMI, ZBX.ZBX_FROTA " + CRLF

	FechaAlias(cTmpAlias)
	DbUseArea(.T., "TOPCONN", TCGenQry(,,ChangeQuery(cQuery)), cTmpAlias, .F., .T.)
	TCSetField(cTmpAlias, "ZBX_DATA","D" ,8 ,0)

	If (cTmpAlias)->(Eof())
		Aviso(oProcess:cTitle, "Nenhum dado encontrado para o filtro informado!", {"Ok"}, 2)
	Else
		lRet := .T.
	EndIf
Return lRet

/*/{Protheus.doc} Consolidar
//TODO: (long_description)
@type function
@author Douglas Telles
@since 07/04/2017
@version 1.0
@param lEnd, ${param_type}, (Descrição do parâmetro)
/*/
Static Function Consolidar(lEnd)
	Local aMes		:= {"JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"}
	Local cAuxTab	:= GetNextAlias()
	Local cAuxInd	:= GetNextAlias()
	Local aTamCpo	:= {}
	Local aEstrut	:= {}
	Local cEquipAnt	:= ""
	Local nX		:= 0

	aTamCpo := TamSx3("T9_NOME")
	Aadd(aEstrut, {"DESCRI", "C", aTamCpo[1], aTamCpo[2]}); aTamCpo := TamSx3("T9_CODFAMI")
	Aadd(aEstrut, {"CODIGO", "C", aTamCpo[1], aTamCpo[2]});	aTamCpo := {12, 0}
	Aadd(aEstrut, {"QTDFAM", "N", aTamCpo[1], aTamCpo[2]})
	Aadd(aEstrut, {"QTDMIN", "N", aTamCpo[1], aTamCpo[2]})

	For nX := 1 To Len(aMes)
		Aadd(aEstrut, {aMes[nX], "N" ,aTamCpo[1], aTamCpo[2]})
	Next nX

	If lEnd
		Return
	EndIf

	oProcess:IncRegua1("[2/3] - " + oProcess:cTitle)
	oProcess:IncRegua2("Consolidando Informações...")

	FechaAlias(cAuxTab)

	DBCreate(cAuxTab, aEstrut, __LOCALDRIVER)
	DbUseArea(.T., __LOCALDRIVER, cAuxTab, cAuxTab, .F., .F.)
	DBCreateIndex(cAuxInd, "CODIGO", {|| "CODIGO"}, .F.)

	While !((cTmpAlias)->(Eof()))
		If lEnd
			Return
		EndIf

		If (cAuxTab)->(DbSeek((cTmpAlias)->T9_CODFAMI))
			RecLock(cAuxTab, .F.)
				(cAuxTab)->QTDMIN += (cTmpAlias)->QTDMIN
				If cEquipAnt != (cTmpAlias)->ZBX_FROTA
					(cAuxTab)->QTDFAM += 1
				EndIf

				For nX := 1 To Len(aMes)
					&(cAuxTab + "->" + aMes[nX]) += IIF(Month((cTmpAlias)->ZBX_DATA) == nX, (cTmpAlias)->QTDMIN, 0)
				Next nX
			MsUnlock()
		Else
			RecLock(cAuxTab, .T.)
				(cAuxTab)->DESCRI := (cTmpAlias)->T9_NOME
				(cAuxTab)->CODIGO := (cTmpAlias)->T9_CODFAMI
				(cAuxTab)->QTDFAM := 1
				(cAuxTab)->QTDMIN := (cTmpAlias)->QTDMIN

				For nX := 1 To Len(aMes)
					&(cAuxTab + "->" + aMes[nX]) += IIF(Month((cTmpAlias)->ZBX_DATA) == nX, (cTmpAlias)->QTDMIN, 0)
				Next nX
			MsUnlock()
		EndIf

		cEquipAnt := (cTmpAlias)->ZBX_FROTA
		(cTmpAlias)->(DbSkip())
	EndDo

	FechaAlias(cTmpAlias)
	cTmpAlias := cAuxTab
Return

/*/{Protheus.doc} Imprimir
//TODO: (long_description)
@type function
@author Douglas Telles
@since 07/04/2017
@version 1.0
@param lEnd, ${param_type}, (Descrição do parâmetro)
@see (links_or_references)
/*/
Static Function Imprimir(lEnd)
	Local aMes			:= {"JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"}
	Local cArqXML	 	:= IIf(IsSrvUnix(), "/","\")
	Local cPlanilha		:= OEMToANSI("Utilização de Frota")
	Local cNomeArq		:= OEMToANSI("utilizacao_de_frota_" + DTOS(Date()) + "_" + Replace(Time(),":",""))
	Local cTabela		:= OEMToANSI(oProcess:cTitle)
	Local aCols			:= {}
	Local aLinha		:= {}
	Local aTotais		:= {}
	Local aTotUtil		:= {}
	Local lTotal		:= .T.
	Local oExcel		:= Nil
	Local oExcelApp		:= Nil
	Local nTotQtd		:= 0
	Local nX			:= 0
	Local nAux			:= 0
	Local nAlignL		:= 1
	Local nAlignC		:= 2
	Local nAlignR		:= 3
	Local nFormGeral	:= 1
	Local nFormNum		:= 2
	Local nFormMoeda	:= 3
	Local nFormData		:= 4

	If lEnd
		Return
	EndIf

	cArqXML := cGetFile("*.XLS", "Selecione o diretório para salvar o arquivo",;
						0, IIf(IsSrvUnix(), "/SPOOL/","\SPOOL\"), .F.,;
						GETF_RETDIRECTORY+GETF_LOCALHARD+GETF_NETWORKDRIVE+GETF_LOCALFLOPPY,;
						.F., .F.)

	If Empty(cArqXML)
		Return
	Else
		cArqXML += cNomeArq
	EndIf

	oProcess:IncRegua1("[3/3] - " + oProcess:cTitle)
	oProcess:IncRegua2("Iniciando a Impressão...")

	oExcel := FWMsExcel():New()

	oExcel:AddWorkSheet(cPlanilha)
	oExcel:AddTable(cPlanilha, cTabela)

	Aadd(aCols, {OEMToANSI("Descrição")	, nAlignL, nFormGeral	, !(lTotal)	})
	Aadd(aCols, {OEMToANSI("Código")	, nAlignL, nFormGeral	, !(lTotal)	})
	Aadd(aCols, {"Quantidade"			, nAlignR, nFormNum		, !(lTotal)	})

	For nX := 1 To Len(aMes)
		If lEnd
			Return
		EndIf

		Aadd(aCols, {Capital(aMes[nX]), nAlignR, nFormNum, !(lTotal)})
	Next nX

	Aadd(aCols, {OEMToANSI("Média"), nAlignR, nFormNum, !(lTotal)})

	For nX := 1 To Len(aCols)
		If lEnd
			Return
		EndIf

		oExcel:AddColumn(cPlanilha, cTabela, aCols[nX, 1], aCols[nX, 2], aCols[nX, 3], aCols[nX, 4])
	Next nX

	aTotUtil := Array(Len(aMes))

	(cTmpAlias)->(DbGoTop())
	While !((cTmpAlias)->(Eof()))
		If lEnd
			Return
		EndIf

		aLinha	:= {}
		nTotQtd	+= (cTmpAlias)->QTDFAM

		Aadd(aLinha, (cTmpAlias)->DESCRI)
		Aadd(aLinha, (cTmpAlias)->CODIGO)
		Aadd(aLinha, (cTmpAlias)->QTDFAM)

		For nX := 1 To Len(aMes)
			If lEnd
				Return
			EndIf

			nAux := 0

			If aTotUtil[nX] == Nil
				aTotUtil[nX] := 0
			EndIf

			If DiasLocav(StrZero(nX, 2)) > 0 .And. &(cTmpAlias + "->" + aMes[nX]) > 0
				nAux := (&(cTmpAlias + "->" + aMes[nX]) * 100) / DiasLocav(StrZero(nX, 2))
			EndIf

			aTotUtil[nX] += &(cTmpAlias + "->" + aMes[nX])

			Aadd(aLinha, Transform(Round(nAux, 2), "@E 999.99%"))
		Next nX

		Aadd(aLinha, Transform(Round(MediaReal(), 2), "@E 999.99%"))

		oExcel:AddRow(cPlanilha, cTabela, aLinha)

		(cTmpAlias)->(DbSkip())
	EndDo

	aTotais		:= Array(Len(aTotUtil) + 2)
	aTotais[1]	:= nTotQtd

	For nX := 1 To Len(aTotUtil)
		If lEnd
			Return
		EndIf

		nAux := 0

		If DiasLocav(StrZero(nX, 2), nTotQtd) > 0 .And. aTotUtil[nX] > 0
			nAux := (aTotUtil[nX] * 100 / DiasLocav(StrZero(nX, 2), nTotQtd))
		EndIf

		aTotais[nX + 1] := Transform(Round(nAux, 2), "@E 999.99%")
	Next nX

	aTotais[Len(aTotais)] := Transform(Round(MediaReal(aTotais, nTotQtd), 2), "@E 999.99%")

	aLinha := {}
	Aadd(aLinha, "")
	Aadd(aLinha, "Total")

	For nX := 1 To Len(aTotais)
		If lEnd
			Return
		EndIf

		aAdd(aLinha, aTotais[nX])
	Next nX

	oExcel:AddRow(cPlanilha, cTabela, aLinha)

	oExcel:Activate()
	oExcel:GetXMLFile(cArqXML + ".xls")

	If ApOleClient('MsExcel')
		If MessageBox("Relatório gerado com sucesso!" + CRLF + CRLF +;
					"Deseja abrir o relatório agora?", oProcess:cTitle, 4) == 6

			oExcelApp:= MsExcel():New()
			oExcelApp:WorkBooks:Open(cArqXML + ".xls")
			oExcelApp:SetVisible(.T.)
		EndIf
	Else
		MessageBox("Relatório gerado com sucesso!" + CRLF + CRLF +;
			"O Excel não foi encontrado, o relatório se encontra em " + cArqXML, oProcess:cTitle, 0)
	EndIf
Return

/*/{Protheus.doc} DiasLocav
//TODO: (long_description)
@type function
@author Douglas Telles
@since 07/04/2017
@version 1.0
@param cMes, character, (Descrição do parâmetro)
@param nQtd, numeric, (Descrição do parâmetro)
@return nRet, ${return_description}
/*/
Static Function DiasLocav(cMes, nQtd)
	Local nRet		:= 0
	Local nQtdDias	:= 0
	Local dDataAux	:= Nil

	Default cMes	:= "01"
	Default nQtd	:= -1

	dDataAux := CTOD("01/" + cMes + "/" + cValToChar(Year(dDatabase)))
	nQtdDias := Last_Day(dDataAux)

	If nQtd > 0
		nRet := (nQtd * nQtdDias)
	Else
		nRet := ((cTmpAlias)->QTDFAM * nQtdDias)
	EndIf
Return nRet

/*/{Protheus.doc} MediaReal
(long_description)
@type function
@author Douglas Telles
@since 08/04/2017
@version 1.0
@param aTotais, array, (Descrição do parâmetro)
@param nTotQtd, numeric, (Descrição do parâmetro)
@return nRet, ${return_description}
/*/
Static Function MediaReal(aTotais, nTotQtd)
	Local aMes	:= {"JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"}
	Local nX	:= 0
	Local nRet	:= 0
	Local nSoma	:= 0
	Local nQtd	:= 0
	Local nAux	:= 0

	Default aTotais	:= {}
	Default nTotQtd	:= {}

	For nX := 1 To Len(aMes)
		If Len(aTotais) > 0
			If DiasLocav(StrZero(nX, 2), nTotQtd) > 0 .And. Val(aTotais[nX + 1]) > 0
				//nAux := (Val(aTotais[nX + 1]) * 100) / DiasLocav(StrZero(nX, 2), nTotQtd)
				nAux := Val(aTotais[nX + 1])
			EndIf
		Else
			If DiasLocav(StrZero(nX, 2)) > 0 .And. &(cTmpAlias + "->" + aMes[nX]) > 0
				nAux := (&(cTmpAlias + "->" + aMes[nX]) * 100) / DiasLocav(StrZero(nX, 2))
			EndIf
		EndIf

		If nAux > 0
			nSoma += nAux
			nQtd++
		EndIf

		nAux := 0
	Next nX

	nRet := nSoma / nQtd
Return nRet

/*/{Protheus.doc} FechaAlias
Fecha um Alias ativo no ambiente.
@type function
@author Douglas Telles
@since 07/04/2017
@version 1.0
@param cFecAlias, caracter, Alias a ser fechado.
/*/
Static Function FechaAlias(cFecAlias)
	Default cFecAlias := ""

	If Select(cFecAlias) > 0
		(cFecAlias)->(DbCloseArea())
	EndIf
Return

/*/{Protheus.doc} AjustaSx1
//TODO: (long_description)
@type function
@author Douglas Telles
@since 06/04/2017
@version 1.0
@param cPerg, character, (Descrição do parâmetro)
/*/
Static Function AjustaSx1(cPerg)
	Local aArea	:= GetArea()
	Local aPerg	:= {}
	Local nX	:= 0
	Local nY	:= 0

	DbSelectArea("SX1")
	DbSetOrder(1) //X1_GRUPO+X1_ORDEM
	cPerg := PadR(cPerg, Len(SX1->X1_GRUPO))

	AAdd(aPerg, {cPerg, "01", "De Filial?", "De Filial?", "De Filial?", "mv_ch1", "C", 04, 0, 0,;
				"C", "", "mv_par01", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",;
				"", "", "", "", "", "", "", "", "", "SM0", "S", "", "", ""})
	AAdd(aPerg, {cPerg, "02", "Até Filial?", "Até Filial?", "Até Filial?", "mv_ch2", "C", 04, 0, 0,;
				"C", "", "mv_par02", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",;
				"", "", "", "", "", "", "", "", "SM0", "S", "", "", ""})
	AAdd(aPerg, {cPerg, "03", "De Data?", "De Data?", "De Data?", "mv_ch3", "D", 08, 0, 0, "C", "",;
				"mv_par03", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",;
				"", "", "", "", "", "", "", "S", "", "", ""})
	AAdd(aPerg, {cPerg, "04", "Até Data?", "Até Data?", "Até Data?", "mv_ch4", "D", 08, 0, 0, "C",;
				"", "mv_par04", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",;
				"", "", "", "", "", "", "", "", "S", "", "", ""})
	AAdd(aPerg, {cPerg, "05", "De Família?", "De Família?", "De Família?", "mv_ch5", "C", 06, 0, 0,;
				"C", "", "mv_par05", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",;
				"", "", "", "", "", "", "", "", "ST6", "S", "", "", ""})
	AAdd(aPerg, {cPerg, "06", "Até Família?", "Até Família?", "Até Família?", "mv_ch6", "C", 06, 0,;
				0, "C", "", "mv_par06", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",;
				"", "", "", "", "", "", "", "", "", "ST6", "S", "", "", ""})

	For nX := 1 To Len(aPerg)
		If !(SX1->(DbSeek(cPerg + aPerg[nX,2])))
			RecLock("SX1",.T.)
			For nY := 1 To FCount()
				If nY <= Len(aPerg[nX])
					FieldPut(nY, aPerg[nX, nY])
				Endif
			Next nY
			MsUnlock()
		Endif
	Next nX

	RestArea(aArea)
Return
