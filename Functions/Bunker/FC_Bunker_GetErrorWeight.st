FUNCTION FC_Bunker_GetErrorWeight : BOOL
VAR_INPUT
	Bunker1 : REFERENCE TO ST_Bunker;
	Bunker2 : REFERENCE TO ST_Bunker;
	Bunker3 : REFERENCE TO ST_Bunker;
END_VAR
VAR
END_VAR
// Если 2 или больше бункеров являются пустыми, мы получаем ошибку
FC_Bunker_GetErrorWeight :=
	2 > BOOL_TO_INT(FC_Bunker_CheckWeight(Bunker := Bunker1))
	  + BOOL_TO_INT(FC_Bunker_CheckWeight(Bunker := Bunker2))
	  + BOOL_TO_INT(FC_Bunker_CheckWeight(Bunker := Bunker3));

END_FUNCTION