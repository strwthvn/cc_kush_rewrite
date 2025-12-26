TYPE ST_MotorWithFeedback EXTENDS ST_Motor :
STRUCT
	// == Перегрев статора ==
	// DI:
	fbStatorOverheat : FB_UniversalSignal; // Перегрев статора
END_STRUCT
END_TYPE
