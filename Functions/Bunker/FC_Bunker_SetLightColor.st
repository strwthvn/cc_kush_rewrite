FUNCTION FC_Bunker_SetLightColor : BOOL
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	eColor : E_LightColor;
END_VAR
VAR
END_VAR
// Сброс всех сигналов
Bunker.qxLightRed := FALSE;
Bunker.qxLightYellow := FALSE;
Bunker.qxLightGreen := FALSE;

// Установка нужного цвета
CASE eColor OF
	E_LightColor.RED:
		Bunker.qxLightRed := TRUE;
		Bunker.eLightColor := E_LightColor.RED;

	E_LightColor.YELLOW:
		Bunker.qxLightYellow := TRUE;
		Bunker.eLightColor := E_LightColor.YELLOW;

	E_LightColor.GREEN:
		Bunker.qxLightGreen := TRUE;
		Bunker.eLightColor := E_LightColor.GREEN;

	E_LightColor.OFF:
		// Все уже выключены
		Bunker.eLightColor := E_LightColor.OFF;
END_CASE;

FC_Bunker_SetLightColor := TRUE;

END_FUNCTION