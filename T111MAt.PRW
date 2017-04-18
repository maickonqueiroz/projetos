#Include 'Protheus.ch'

/*/{Protheus.doc} T111MAt
Ponto de entrada executado após a inclusão das minutas no apontador de AS.
@type function
@author Douglas Telles
@since 05/04/2017
@version 1.0
/*/
User Function T111MAt()
	Local cProjeto	:= PARAMIXB[1]
	Local cAS		:= PARAMIXB[2]
	Local aArea		:= GetArea()

	If AceiteAuto(cProjeto)
		AceitMinut(cProjeto, cAS)
	EndIf

	RestArea(aArea)
Return

/*/{Protheus.doc} AceiteAuto
Verifica se as minutas deverão ser aceitas automaticamente.
@type function
@author Douglas Telles
@since 05/04/2017
@version 1.0
@param cProjeto, caracter, Código do projeto da minuta.
@return lRet, Indica se a minuta deve ser aprovada automaticamente.
/*/
Static Function AceiteAuto(cProjeto)
	Local lRet := SuperGetMv("LC_ACAUTO", .F., .F.)

	Default cProjeto := ""

	If lRet
		lRet := ReceitaOk()
	EndIf

	If lRet
		lRet := Renovacao(cProjeto)
	EndIf
Return lRet

/*/{Protheus.doc} ReceitaOk
Verifica se o tipo de receita da minuta permite o aceite automático.
@type function
@author Douglas Telles
@since 05/04/2017
@version 1.0
@return lRet, Indica se o tipo de receita permite o aceite automático.
/*/
Static Function ReceitaOk()
	Local aAreaZA0 := ZA0->(GetArea())
	Local cReceita := 'P'
	Local lRet := .F.

	lRet := ZA0->ZA0_RECEIT $ cReceita

	RestArea(aAreaZA0)
Return lRet

/*/{Protheus.doc} Renovacao
Verifica se a minuta gerada é uma renovação de locação.
@type function
@author Douglas Telles
@since 05/04/2017
@version 1.0
@param cProjeto, caracter, Código do projeto da minuta.
@return lRet, Indica se a minnuta é uma renovação de locação.
/*/
Static Function Renovacao(cProjeto)
	Local lRet := .F.
	Local cQuery := ""
	Local cTmpAlias := GetNextAlias()

	Default cProjeto := ""

	cQuery := "SELECT COUNT(*) QUANT " + CRLF
	cQuery += "FROM " + RetSqlName("ZAG") + " ZAG " + CRLF
	cQuery += "WHERE " + CRLF
	cQuery += "	ZAG.ZAG_FILIAL = '" + xFilial("ZAG") + "' " + CRLF
	cQuery += "	AND ZAG.ZAG_PROJET = '" + cProjeto + "' " + CRLF
	cQuery += "	AND ZAG.D_E_L_E_T_ <> '*' " + CRLF

	FechaAlias(cTmpAlias)
	DbUseArea(.T., "TOPCONN", TCGenQry(,,ChangeQuery(cQuery)), cTmpAlias, .F., .T.)

	If !((cTmpAlias)->(Eof()))
		lRet := (cTmpAlias)->QUANT > 1
	EndIf

	FechaAlias(cTmpAlias)
Return lRet

/*/{Protheus.doc} AceitMinut
Efetua o aceite automático das minutas.
@type function
@author Douglas Telles
@since 05/04/2017
@version 1.0
@param cProjeto, caracter, Código do projeto da minuta.
@param cAS, caracter, Código da AS da minuta.
/*/
Static Function AceitMinut(cProjeto, cAS)
	Local cTmpAlias	:= GetNextAlias()
	Local aAreaZBX	:= ZBX->(GetArea())
	Local cQuery	:= ""

	Default cProjeto	:= ""
	Default cAS			:= ""

	cQuery := "SELECT * " + CRLF
	cQuery += "FROM " + RetSqlName("ZBX") + " ZBX " + CRLF
	cQuery += "WHERE " + CRLF
	cQuery += "	ZBX.ZBX_FILIAL = '" + xFilial("ZBX") + "' " + CRLF
	cQuery += "	AND ZBX.ZBX_PROJET = '" + cProjeto + "' " + CRLF
	cQuery += "	AND ZBX.ZBX_AS = '" + cAS + "' " + CRLF
	cQuery += "	AND ZBX.D_E_L_E_T_ <> '*' " + CRLF

	FechaAlias(cTmpAlias)
	DbUseArea(.T., "TOPCONN", TCGenQry(,,ChangeQuery(cQuery)), cTmpAlias, .F., .T.)

	DbSelectArea("ZBX")
	DbsetOrder(4) //ZBX_FILIAL+ZBX_AS+ZBX_MINUTA

	Begin Transaction
		While !((cTmpAlias)->(Eof()))
			If ZBX->(MsSeek((cTmpAlias)->ZBX_FILIAL + (cTmpAlias)->ZBX_AS + (cTmpAlias)->ZBX_MINUTA))
				RecLock("ZBX", .F.)
					ZBX->ZBX_STATUS := "2"
					ZBX->ZBX_DTOCOR := ZBX->ZBX_EMISSA
				MsUnlock()
			EndIf

			(cTmpAlias)->(DbSkip())
		EndDo
	End Transaction

	FechaAlias(cTmpAlias)
	RestArea(aAreaZBX)
Return

/*/{Protheus.doc} FechaAlias
Fecha um Alias ativo no ambiente.
@type function
@author Douglas Telles
@since 05/04/2017
@version 1.0
@param cFecAlias, caracter, Alias a ser fechado.
/*/
Static Function FechaAlias(cFecAlias)
	Default cFecAlias := ""

	If Select(cFecAlias) > 0
		(cFecAlias)->(DbCloseArea())
	EndIf
Return