FUNCTION FC_Get_ErrorCommon : BOOL
VAR_INPUT
	Bunker1 : REFERENCE TO ST_Bunker;
	Bunker2 : REFERENCE TO ST_Bunker;
	Bunker3 : REFERENCE TO ST_Bunker;
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	Dumper : REFERENCE TO ST_Dumper;
END_VAR
VAR
END_VAR
FC_Get_ErrorCommon :=
	FC_Bunker_GetErrorBunker(Bunker := Bunker1) // Получение ошибки бункера 1
	OR FC_Bunker_GetErrorBunker(Bunker := Bunker2) // Получение ошибки бункера 2
	OR FC_Bunker_GetErrorBunker(Bunker := Bunker3) // Получение ошибки бункера 3
	OR FC_Conveyor_GetErrorCommon(Conveyor := Conveyor) // Получение ошибки сборного конвейера
	OR FC_Dumper_GetErrorCommon(Dumper := Dumper) // Получение ошибки отвалообразователя
	OR FC_Bunker_GetErrorWeight(Bunker1 := Bunker1, Bunker2 := Bunker2, Bunker3 := Bunker3); // Проверка заполненности бункеров

END_FUNCTION