TYPE E_ScadaStatesDevice :
(
	NOT_READY,
	READY,
	STARTING,
	WORK,
	WORK_WITH_WARNING,
	WORK_WITH_ERROR,
	WARNING,
	ERROR
);
END_TYPE

// TODO : Включить в алгоритм FB_DumperControl и FB_ConveyorControl