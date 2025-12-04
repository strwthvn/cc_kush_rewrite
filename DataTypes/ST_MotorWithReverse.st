TYPE ST_MotorWithReverse EXTENDS ST_MotorWithFeedback :
STRUCT
	// DO
	qxVFDReverseStart : BOOL; // Пуск ПЧ назад

	// DI
	fbRotationStatus : FB_UniversalSignal; // Статус вращения
END_STRUCT
END_TYPE
