PROGRAM PLC_PRG
VAR
	CommC: TenM_COMM.CommManager; // Менеджер обмена данными
	Weight: TenM_COMM.UDT_Weight; // структура данных веса
	ComplexData: TenM_COMM.UDT_ComplexData; // структура комплексных данных
	SpecPar: TenM_COMM.UDT_SpecialPar; // структура специальных параметров
	MainPar: TenM_COMM.UDT_MainPar; // структура основных параметров
	Cmd: TenM_COMM.CMD_LIST := TenM_COMM.CMD_LIST.SpecialPar_Set; // ацикличная команда для отправки в устройство
	DevAdr: INT := 1; // адрес устройства для отправки однократной команды
	Data: ARRAY [0..254] OF BYTE; // массив <Data> для ацикличной команды
	Length: INT := 16; // длина <Data> для ацикличной команды

	SpecialParReq: BOOL := FALSE; // запрос специальных параметров
	MainParReq: BOOL := FALSE; // запрос основных настроек
	SpecialParWrite: BOOL := FALSE; // запрос записи специальных параметров
	
	ControlCommand: BYTE := 0; // тип команды управления устройтсвом (для запроса 0xDF)
	CntrlCmdExec: BOOL := FALSE; // отправка команды управления устройством
	CntAr: ARRAY [0..9] OF REAL; // массив счётчиков устройства
	GetCounters: BOOL; // запрос счётчиков от устройства
	TimeOut: TON; // тайм-аут
	DData: ARRAY [0..254] OF BYTE;
	_pDData: POINTER TO BYTE := ADR(DData);
	
END_VAR

(* Обмен данными с ТВ-011 *)
CommC.CycleDevAdr[0] := 1; // сетевой адрес прибора

// команды для циклического опроса
CommC.CycleCommands[0] := TenM_COMM.CMD_LIST.ComplexData_Get;
CommC.CycleCommands[1] := TenM_COMM.CMD_LIST.DeviceInfo_Get;
CommC.CycleCommands[2] := TenM_COMM.CMD_LIST.NetWeight_Get;

// ФБ для работы с прибором
CommC
(
	PortNo := 3,
	BaudRate := 19200,
	Parity := 2,
	StopBit := 0,
	ByteSize := 8,
	ReqCommand := Cmd,
	ReqDevAdr := TO_BYTE(DevAdr),
	ReqData := Data,
	DataLength := Length
);

(* В данном примере не реализована обработка ошибок связи. В случае ошибки необходимо снимать флаг ExecCommand на входе коммуникационного менеджера, т.к. команда запроса выполняется однократно.
Для упрощения не проверяем флаг ошибки на выходе и просто сбрасываем флаг ExecCommand по тайм-ауту, далее запрошенная команда будет выполнена вновь, т.к. бит запроса будет сброшен только после выполнения запроса. *)
// Сброс команды однократного запроса по тайм-ауту
TimeOut(IN:=CommC.ExecCommand, PT:=T#1S);
IF TimeOut.Q THEN
	CommC.ExecCommand := FALSE;
END_IF

(* обработка полученных данных циклического опроса *)

// обработка полученных данных по весу
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.NetWeight_Get AND CommC.Done THEN
	Weight := TenM_COMM.RawData_TO_Weight(ADR(CommC.DnData));
END_IF
// обработка комплексной посылки
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.ComplexData_Get AND CommC.Done THEN
	ComplexData := TenM_COMM.RawData_TO_ComplexData(ADR(CommC.DnData));
END_IF

(* Единоразовые команды *)

// Запрос специальных параметров при открытии окна 
IF SpecialParReq AND NOT CommC.ExecCommand AND NOT TimeOut.Q THEN
	Cmd := TenM_COMM.CMD_LIST.SpecialPar_Get;
	DevAdr := 1;
	Length := 0;
	CommC.ExecCommand := TRUE;
END_IF
// обработка данных специальных параметров от прибора
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.SpecialPar_Get AND CommC.Done THEN
	SpecPar := TenM_COMM.RawData_TO_SpecPar(InData:=ADR(CommC.DnData), DecPoint:=Weight.DecPointPos);
	SpecialParReq := FALSE;
	CommC.ExecCommand := FALSE;
END_IF

// Запись специальных параметров по нажатию кнопки
IF SpecialParWrite AND NOT CommC.ExecCommand AND NOT TimeOut.Q THEN
	Cmd := TenM_COMM.CMD_LIST.SpecialPar_Set;
	DevAdr := 1;
	Length := 16;
	// приведение данных к BCD
	TenM_COMM.TO_BCD_ARRAY(InValue:=TO_UDINT(SpecPar.DoseWeight*EXPT(10,Weight.DecPointPos)), BCD_Array:=ADR(Data[0]));
	TenM_COMM.TO_BCD_ARRAY(InValue:=TO_UDINT(SpecPar.StableTime*EXPT(10,Weight.DecPointPos)), BCD_Array:=ADR(Data[3]));
	TenM_COMM.TO_BCD_ARRAY(InValue:=TO_UDINT(SpecPar.MaxDoseTime*EXPT(10,Weight.DecPointPos)), BCD_Array:=ADR(Data[5]));
	TenM_COMM.TO_BCD_ARRAY(InValue:=TO_UDINT(SpecPar.EmtptyTankWeight*EXPT(10,Weight.DecPointPos)), BCD_Array:=ADR(Data[7]));
	TenM_COMM.TO_BCD_ARRAY(InValue:=TO_UDINT(SpecPar.CapacityLimit*EXPT(10,Weight.DecPointPos)), BCD_Array:=ADR(Data[10]));
	TenM_COMM.TO_BCD_ARRAY(InValue:=TO_UDINT(SpecPar.LimitDose*EXPT(10,Weight.DecPointPos+1)), BCD_Array:=ADR(Data[13]));
	CommC.ExecCommand := TRUE;
END_IF
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.SpecialPar_Set AND CommC.Done THEN
	SpecialParWrite := FALSE;
	CommC.ExecCommand := FALSE;
END_IF

// Запрос основных параметров при открытии окна 
IF MainParReq AND NOT CommC.ExecCommand AND NOT TimeOut.Q THEN
	Cmd := TenM_COMM.CMD_LIST.MainPar_Get;
	DevAdr := 1;
	Length := 0;
	CommC.ExecCommand := TRUE;
END_IF
// обработка данных основных параметров от прибора
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.MainPar_Get AND CommC.Done THEN
	MainPar := TenM_COMM.RawData_TO_MainPar(InData:=ADR(CommC.DnData));
	MainParReq := FALSE;
	CommC.ExecCommand := FALSE;
END_IF

// Команды управления
IF CntrlCmdExec AND NOT CommC.ExecCommand AND NOT TimeOut.Q THEN
	Cmd := TenM_COMM.CMD_LIST.WeightControl_Set;
	DevAdr := 1;
	Length := 1;
	Data[0] := ControlCommand;
	CommC.ExecCommand := TRUE;
END_IF
// обработка данных от прибора
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.WeightControl_Set AND CommC.Done THEN
	CntrlCmdExec := FALSE;
	CommC.ExecCommand := FALSE;
END_IF

// Запрос счётчиков
IF GetCounters AND NOT CommC.ExecCommand AND NOT TimeOut.Q THEN
	Cmd := TenM_COMM.CMD_LIST.Counter_Get;
	DevAdr := 1;
	Length := 1;
	Data[0] := 9; // номер запрашиваемого счётчика
	Data[0].7 := TRUE; // запрос всех счётчиков до ранее заданного номера
	CommC.ExecCommand := TRUE;
END_IF
// обработка полученных счётчиков
IF CommC.DnDevAdr = 16#01 AND CommC.DnCommand = TenM_COMM.CMD_LIST.Counter_Get AND CommC.Done THEN
	// конвертирование данных из BCD
	CntAr[0] := TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[1]),5);
	CntAr[1] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[6]),5))/EXPT(10,Weight.DecPointPos);
	CntAr[2] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[11]),5))/EXPT(10,Weight.DecPointPos+1);
	CntAr[3] := TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[16]),5);
	CntAr[4] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[21]),5))/EXPT(10,Weight.DecPointPos);
	CntAr[5] := TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[26]),5);
	CntAr[6] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[31]),5))/EXPT(10,Weight.DecPointPos);
	CntAr[7] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[36]),5))/EXPT(10,Weight.DecPointPos);
	CntAr[8] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[41]),5))/EXPT(10,Weight.DecPointPos);
	CntAr[9] := (TenM_COMM.FROM_BCD_ARRAY(ADR(CommC.DnData[46]),5))/EXPT(10,Weight.DecPointPos);
	GetCounters := FALSE;
	CommC.ExecCommand := FALSE;
END_IF

END_PROGRAM