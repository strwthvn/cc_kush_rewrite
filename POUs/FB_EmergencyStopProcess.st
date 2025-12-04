FUNCTION_BLOCK FB_EmergencyStopProcess
VAR_INPUT
	ixEnable : BOOL;
	ixReset : BOOL;
	
	Bunker : REFERENCE TO ARRAY [1..3] OF ST_Bunker;
	Dumper : REFERENCE TO ST_Dumper;
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR_OUTPUT
	qxStateStopProcess : BOOL;
	qxStateEmergencyStop : BOOL;
	qnCurrentStage : INT;
END_VAR
VAR
	i, j : INT;
	xBunkersStopped : BOOL;
	xConveyorStopped : BOOL;
	xDumperStopped : BOOL;
END_VAR

// Сброс процесса аварийной остановки
IF ixReset THEN
	qxStateStopProcess := FALSE;
	qxStateEmergencyStop := FALSE;
	qnCurrentStage := 0;
	RETURN;
END_IF

// Запуск процесса аварийной остановки
IF ixEnable AND NOT qxStateEmergencyStop AND qnCurrentStage = 0 THEN
	qxStateStopProcess := TRUE;
	qnCurrentStage := 1; // Начинаем с остановки бункеров
END_IF

CASE qnCurrentStage OF

	// === ЭТАП 1: Остановка бункеров ===
	1:
		// Отправляем команды остановки
		FOR i := 1 TO 3 DO
			// Остановка моторов вибраторов (4 шт на бункер)
			FOR j := 1 TO 4 DO
				Bunker[i].MotorVibrator[j].qxKM_Power := FALSE;
				Bunker[i].MotorVibrator[j].VFD.qxStart := FALSE;
				Bunker[i].MotorVibrator[j].VFD.Frequency.rTargetFrequency := 0.0;
				Bunker[i].MotorVibrator[j].VFD.qrOutFrequency := 0.0;
			END_FOR

			// Остановка моторов вибропитателей (2 шт на бункер)
			FOR j := 1 TO 2 DO
				Bunker[i].MotorVibFeeder[j].qxKM_Power := FALSE;
				Bunker[i].MotorVibFeeder[j].VFD.qxStart := FALSE;
				Bunker[i].MotorVibFeeder[j].VFD.Frequency.rTargetFrequency := 0.0;
				Bunker[i].MotorVibFeeder[j].VFD.qrOutFrequency := 0.0;
			END_FOR

			// Установка красного сигнала светофора
			FC_Bunker_SetLightColor(Bunker := Bunker[i], eColor := E_LightColor.RED);
		END_FOR

		// Проверка обратной связи - все моторы бункеров остановлены
		// Используем проверку через прямое вычисление результата
		xBunkersStopped :=
			// Бункер 1
			NOT Bunker[1].MotorVibrator[1].fbStateKM.qxSignal AND NOT Bunker[1].MotorVibrator[1].VFD.xStateIsWorking
			AND NOT Bunker[1].MotorVibrator[2].fbStateKM.qxSignal AND NOT Bunker[1].MotorVibrator[2].VFD.xStateIsWorking
			AND NOT Bunker[1].MotorVibrator[3].fbStateKM.qxSignal AND NOT Bunker[1].MotorVibrator[3].VFD.xStateIsWorking
			AND NOT Bunker[1].MotorVibrator[4].fbStateKM.qxSignal AND NOT Bunker[1].MotorVibrator[4].VFD.xStateIsWorking
			AND NOT Bunker[1].MotorVibFeeder[1].fbStateKM.qxSignal AND NOT Bunker[1].MotorVibFeeder[1].VFD.xStateIsWorking
			AND NOT Bunker[1].MotorVibFeeder[2].fbStateKM.qxSignal AND NOT Bunker[1].MotorVibFeeder[2].VFD.xStateIsWorking
			// Бункер 2
			AND NOT Bunker[2].MotorVibrator[1].fbStateKM.qxSignal AND NOT Bunker[2].MotorVibrator[1].VFD.xStateIsWorking
			AND NOT Bunker[2].MotorVibrator[2].fbStateKM.qxSignal AND NOT Bunker[2].MotorVibrator[2].VFD.xStateIsWorking
			AND NOT Bunker[2].MotorVibrator[3].fbStateKM.qxSignal AND NOT Bunker[2].MotorVibrator[3].VFD.xStateIsWorking
			AND NOT Bunker[2].MotorVibrator[4].fbStateKM.qxSignal AND NOT Bunker[2].MotorVibrator[4].VFD.xStateIsWorking
			AND NOT Bunker[2].MotorVibFeeder[1].fbStateKM.qxSignal AND NOT Bunker[2].MotorVibFeeder[1].VFD.xStateIsWorking
			AND NOT Bunker[2].MotorVibFeeder[2].fbStateKM.qxSignal AND NOT Bunker[2].MotorVibFeeder[2].VFD.xStateIsWorking
			// Бункер 3
			AND NOT Bunker[3].MotorVibrator[1].fbStateKM.qxSignal AND NOT Bunker[3].MotorVibrator[1].VFD.xStateIsWorking
			AND NOT Bunker[3].MotorVibrator[2].fbStateKM.qxSignal AND NOT Bunker[3].MotorVibrator[2].VFD.xStateIsWorking
			AND NOT Bunker[3].MotorVibrator[3].fbStateKM.qxSignal AND NOT Bunker[3].MotorVibrator[3].VFD.xStateIsWorking
			AND NOT Bunker[3].MotorVibrator[4].fbStateKM.qxSignal AND NOT Bunker[3].MotorVibrator[4].VFD.xStateIsWorking
			AND NOT Bunker[3].MotorVibFeeder[1].fbStateKM.qxSignal AND NOT Bunker[3].MotorVibFeeder[1].VFD.xStateIsWorking
			AND NOT Bunker[3].MotorVibFeeder[2].fbStateKM.qxSignal AND NOT Bunker[3].MotorVibFeeder[2].VFD.xStateIsWorking;

		// Переход к следующему этапу
		IF xBunkersStopped THEN
			qnCurrentStage := 2;
		END_IF

	// === ЭТАП 2: Остановка конвейера ===
	2:
		// Отправляем команды остановки
		FOR j := 1 TO 2 DO
			Conveyor.MotorConveyor[j].qxKM_Power := FALSE;
			Conveyor.MotorConveyor[j].VFD.qxStart := FALSE;
			Conveyor.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
			Conveyor.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
		END_FOR

		// Проверка обратной связи - моторы конвейера остановлены и процесс запуска не активен
		xConveyorStopped :=
			NOT Conveyor.MotorConveyor[1].fbStateKM.qxSignal AND NOT Conveyor.MotorConveyor[1].VFD.xStateIsWorking
			AND NOT Conveyor.MotorConveyor[2].fbStateKM.qxSignal AND NOT Conveyor.MotorConveyor[2].VFD.xStateIsWorking
			AND NOT Conveyor.xStateStarting; // Добавлена проверка что процесс запуска остановлен

		// Переход к следующему этапу
		IF xConveyorStopped THEN
			qnCurrentStage := 3;
		END_IF

	// === ЭТАП 3: Остановка отвалообразователя ===
	3:
		// Остановка моторов конвейера (унаследовано от ST_ConveyorBasic)
		FOR j := 1 TO 2 DO
			Dumper.MotorConveyor[j].qxKM_Power := FALSE;
			Dumper.MotorConveyor[j].VFD.qxStart := FALSE;
			Dumper.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
			Dumper.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
		END_FOR

		// Остановка моторов поворота
		FOR j := 1 TO 2 DO
			Dumper.MotorRotation[j].qxKM_Power := FALSE;
			Dumper.MotorRotation[j].VFD.qxStart := FALSE;
			Dumper.MotorRotation[j].VFD.Frequency.rTargetFrequency := 0.0;
			Dumper.MotorRotation[j].VFD.qrOutFrequency := 0.0;
			Dumper.MotorRotation[j].qxVFDReverseStart := FALSE;
		END_FOR

		// Проверка обратной связи - все моторы отвалообразователя остановлены и процесс запуска не активен
		xDumperStopped :=
			// Моторы конвейера
			NOT Dumper.MotorConveyor[1].fbStateKM.qxSignal AND NOT Dumper.MotorConveyor[1].VFD.xStateIsWorking
			AND NOT Dumper.MotorConveyor[2].fbStateKM.qxSignal AND NOT Dumper.MotorConveyor[2].VFD.xStateIsWorking
			// Моторы поворота
			AND NOT Dumper.MotorRotation[1].fbStateKM.qxSignal AND NOT Dumper.MotorRotation[1].VFD.xStateIsWorking
			AND NOT Dumper.MotorRotation[2].fbStateKM.qxSignal AND NOT Dumper.MotorRotation[2].VFD.xStateIsWorking
			// Проверка что процесс запуска остановлен
			AND NOT Dumper.xStateStarting;

		// Переход к завершению
		IF xDumperStopped THEN
			qnCurrentStage := 4;
		END_IF

	// === ЭТАП 4: Завершение ===
	4:
		qxStateStopProcess := FALSE;
		qxStateEmergencyStop := TRUE;
		// Остаёмся в этом состоянии до ресета

END_CASE

END_FUNCTION_BLOCK