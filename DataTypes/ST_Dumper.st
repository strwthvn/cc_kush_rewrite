TYPE ST_Dumper EXTENDS ST_ConveyorBasic :
STRUCT
	(*
	*	5ZQ1-4 		: Контроль схода ленты
	*	5HQ1-4 		: Кабель-тросовый выключатель
	*	5SQ1-2 		: Контроль ограждения барабана
	*	5GS1 		: Контроль заштыбовки
	*	5QR1-2 		: Измерение скорости вращения барабана
	*	5YS1		: Контроль продольного разрыва ленты
	*	5SQ3-4		: Концевой выключатель крайнего положения
	*	5HA1		: Светозвуковой оповещатель
	*)

	// == Двигатели ==
	// Эл.двиг привода поворота, 3кВт
	MotorRotation : ARRAY [1..2] OF ST_MotorWithReverse; // Эл.двиг привода поворота, 3кВт

	// DI
	// Концевой выключатель крайнего положения
	fbEndSwitchRight, fbEndSwitchLeft : FB_UniversalSignal; // Концевой выключатель крайнего положения

	// == ПМУ ==
	fbBtnStart, fbBtnStop, fbBtnEmergencyStop : FB_UniversalSignal; // Кнопки ПМУ
	fbBtnTurnLeft, fbBtnTurnRight : FB_UniversalSignal; // Кнопки поворота
	fbBtnRemoteMode : FB_UniversalSignal; // Кнопка режима

	// == АСУТП ==
	cmdEmergencyStop, cmdTurnLeft, cmdTurnRight, cmdReset, cmdStopRotation : BOOL;

	// == Генерация состояний ==
	xStateWarning : BOOL; // Программное предупреждение
	xStateFailure : BOOL; // Программная ошибка
	xStateEnable : BOOL; // Отвалообразователь полностью запущен
	xStateStarting : BOOL; // Процесс запуска (вместе с ППЗ)
	
	// Объекты структуры
	fbPreStartAlarm : FB_PreStartAlarm;
END_STRUCT
END_TYPE
