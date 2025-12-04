FUNCTION FC_Bunker_CheckWeight : BOOL
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
END_VAR
VAR
END_VAR
// Проверка веса бункера. True - вес в порядке
FC_Bunker_CheckWeight := Bunker.rWeight > BUNKER_MINIMAL_WEIGHT;

END_FUNCTION