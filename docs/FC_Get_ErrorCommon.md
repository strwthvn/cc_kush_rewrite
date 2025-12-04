# FC_Get_ErrorCommon

Функция агрегирует все ошибки системы и возвращает `TRUE` при наличии любой из них.

## Входные параметры

| Параметр | Тип | Описание |
|----------|-----|----------|
| Bunker1 | REFERENCE TO ST_Bunker | Ссылка на бункер 1 |
| Bunker2 | REFERENCE TO ST_Bunker | Ссылка на бункер 2 |
| Bunker3 | REFERENCE TO ST_Bunker | Ссылка на бункер 3 |
| Conveyor | REFERENCE TO ST_ConveyorPrefabricated | Ссылка на сборный конвейер |
| Dumper | REFERENCE TO ST_Dumper | Ссылка на отвалообразователь |
| xStateEmergencyStop | BOOL | Состояние аварийной остановки |
| ICUR_PRECENT | REAL | Текущий КИУМ (коэффициент использования установленной мощности), % |

## Возвращаемое значение

| Тип | Описание |
|-----|----------|
| BOOL | `TRUE` - есть хотя бы одна ошибка; `FALSE` - ошибок нет |

---

## Полное дерево ошибок

### 1. FC_Bunker_GetErrorBunker (Bunker1, Bunker2, Bunker3)

Вызывается для каждого из трёх бункеров.

#### 1.1. FC_Bunker_GetErrorMotorVibFeeder

Ошибки вибропитателей бункера (MotorVibFeeder[1] и MotorVibFeeder[2]):

| Переменная | Описание |
|------------|----------|
| `MotorVibFeeder[n].VFD.xStateFailure` | Ошибка ЧРП, полученная по дискретному входу |
| `MotorVibFeeder[n].VFD.xStateFailureLocal` | Ошибка ЧРП, полученная программным путём |
| `MotorVibFeeder[n].VFD.fbRangeDiagnostic.qxCriticalActive` | Критическое значение тока электродвигателя |
| `MotorVibFeeder[n].fbStatorOverheat.qxSignal` | Перегрев статора |
| `MotorVibFeeder[n].fbRangeDiagnostic[1].qxCriticalActive` | Критический уровень нагрева подшипникового узла 1 |
| `MotorVibFeeder[n].fbRangeDiagnostic[2].qxCriticalActive` | Критический уровень нагрева подшипникового узла 2 |

**Где n = 1, 2**

#### 1.2. FC_Bunker_GetErrorMotorVibrator

Ошибки вибраторов бункера (MotorVibrator[1..4]):

| Переменная | Описание |
|------------|----------|
| `MotorVibrator[n].VFD.xStateFailure` | Ошибка ЧРП, полученная по дискретному входу |
| `MotorVibrator[n].VFD.xStateFailureLocal` | Ошибка ЧРП, полученная программным путём |
| `MotorVibrator[n].VFD.fbRangeDiagnostic.qxCriticalActive` | Критическое значение тока электродвигателя |

**Где n = 1, 2, 3, 4**

---

### 2. FC_Conveyor_GetErrorCommon (Conveyor)

Ошибки сборного конвейера.

#### 2.1. FC_Conveyor_GetErrorSensors

Ошибки датчиков конвейера:

##### Контроль схода ленты (ZQ)
| Переменная | Описание |
|------------|----------|
| `Conveyor.fbZQAlarm[1].qxSignal` | Сработал датчик схода ленты 1 |
| `Conveyor.fbZQAlarm[2].qxSignal` | Сработал датчик схода ленты 2 |
| `Conveyor.fbZQAlarm[3].qxSignal` | Сработал датчик схода ленты 3 |
| `Conveyor.fbZQAlarm[4].qxSignal` | Сработал датчик схода ленты 4 |

##### Кабель-тросовый выключатель (HQ)
| Переменная | Описание |
|------------|----------|
| `NOT Conveyor.fbHQ_IsOk[1].qxSignal` | Сработал кабель-тросовый выключатель 1 (норма = 1) |
| `NOT Conveyor.fbHQ_IsOk[2].qxSignal` | Сработал кабель-тросовый выключатель 2 (норма = 1) |
| `NOT Conveyor.fbHQ_IsOk[3].qxSignal` | Сработал кабель-тросовый выключатель 3 (норма = 1) |
| `NOT Conveyor.fbHQ_IsOk[4].qxSignal` | Сработал кабель-тросовый выключатель 4 (норма = 1) |

##### Контроль ограждения барабана (SQ)
| Переменная | Описание |
|------------|----------|
| `NOT Conveyor.fbSQ_IsOk[1].qxSignal` | Отсутствует ограждение барабана 1 (норма = 1) |
| `NOT Conveyor.fbSQ_IsOk[2].qxSignal` | Отсутствует ограждение барабана 2 (норма = 1) |

##### Прочие датчики
| Переменная | Описание |
|------------|----------|
| `NOT Conveyor.fbGS1.qxSignal` | Заштыбовка (норма = 1) |
| `NOT Conveyor.fbYS1.qxSignal` | Продольный разрыв ленты (норма = 1) |
| `Conveyor.fbYE1.qxSignal` | Обнаружен металл (норма = 0) |

#### 2.2. FC_Conveyor_GetErrorMotor

Ошибки двигателей конвейера (MotorConveyor[1] и MotorConveyor[2]):

| Переменная | Описание |
|------------|----------|
| `MotorConveyor[n].VFD.xStateFailure` | Ошибка ЧРП, полученная по дискретному входу |
| `MotorConveyor[n].VFD.xStateFailureLocal` | Ошибка ЧРП, полученная программным путём |
| `MotorConveyor[n].VFD.fbRangeDiagnostic.qxCriticalActive` | Критическое значение тока электродвигателя |
| `MotorConveyor[n].fbStatorOverheat.qxSignal` | Перегрев статора |

**Где n = 1, 2**

---

### 3. FC_Dumper_GetErrorCommon (Dumper)

Ошибки отвалообразователя.

#### 3.1. FC_Dumper_GetErrorSensors

Ошибки датчиков отвалообразователя:

##### Контроль схода ленты (ZQ)
| Переменная | Описание |
|------------|----------|
| `Dumper.fbZQAlarm[1].qxSignal` | Сработал датчик схода ленты 1 |
| `Dumper.fbZQAlarm[2].qxSignal` | Сработал датчик схода ленты 2 |
| `Dumper.fbZQAlarm[3].qxSignal` | Сработал датчик схода ленты 3 |
| `Dumper.fbZQAlarm[4].qxSignal` | Сработал датчик схода ленты 4 |

##### Кабель-тросовый выключатель (HQ)
| Переменная | Описание |
|------------|----------|
| `NOT Dumper.fbHQ_IsOk[1].qxSignal` | Сработал кабель-тросовый выключатель 1 (норма = 1) |
| `NOT Dumper.fbHQ_IsOk[2].qxSignal` | Сработал кабель-тросовый выключатель 2 (норма = 1) |
| `NOT Dumper.fbHQ_IsOk[3].qxSignal` | Сработал кабель-тросовый выключатель 3 (норма = 1) |
| `NOT Dumper.fbHQ_IsOk[4].qxSignal` | Сработал кабель-тросовый выключатель 4 (норма = 1) |

##### Контроль ограждения барабана (SQ)
| Переменная | Описание |
|------------|----------|
| `NOT Dumper.fbSQ_IsOk[1].qxSignal` | Отсутствует ограждение барабана 1 (норма = 1) |
| `NOT Dumper.fbSQ_IsOk[2].qxSignal` | Отсутствует ограждение барабана 2 (норма = 1) |

##### Прочие датчики
| Переменная | Описание |
|------------|----------|
| `NOT Dumper.fbGS1.qxSignal` | Заштыбовка (норма = 1) |
| `NOT Dumper.fbYS1.qxSignal` | Продольный разрыв ленты (норма = 1) |

#### 3.2. FC_Conveyor_GetErrorMotor (двигатели конвейера)

Ошибки двигателей конвейера отвалообразователя (MotorConveyor[1] и MotorConveyor[2]):

| Переменная | Описание |
|------------|----------|
| `MotorConveyor[n].VFD.xStateFailure` | Ошибка ЧРП, полученная по дискретному входу |
| `MotorConveyor[n].VFD.xStateFailureLocal` | Ошибка ЧРП, полученная программным путём |
| `MotorConveyor[n].VFD.fbRangeDiagnostic.qxCriticalActive` | Критическое значение тока электродвигателя |
| `MotorConveyor[n].fbStatorOverheat.qxSignal` | Перегрев статора |

**Где n = 1, 2**

#### 3.3. FC_Conveyor_GetErrorMotor (двигатели поворота)

Ошибки двигателей поворота отвалообразователя (MotorRotation[1] и MotorRotation[2]):

| Переменная | Описание |
|------------|----------|
| `MotorRotation[n].VFD.xStateFailure` | Ошибка ЧРП, полученная по дискретному входу |
| `MotorRotation[n].VFD.xStateFailureLocal` | Ошибка ЧРП, полученная программным путём |
| `MotorRotation[n].VFD.fbRangeDiagnostic.qxCriticalActive` | Критическое значение тока электродвигателя |
| `MotorRotation[n].fbStatorOverheat.qxSignal` | Перегрев статора |

**Где n = 1, 2**

---

### 4. FC_Bunker_GetErrorWeight (Bunker1, Bunker2, Bunker3)

Проверка заполненности бункеров.

#### 4.1. FC_Bunker_CheckWeight

Проверяет вес каждого бункера. Возвращает `TRUE`, если вес в норме.

| Переменная | Условие ошибки |
|------------|----------------|
| `Bunker1.rWeight` | Вес меньше `BUNKER_MINIMAL_WEIGHT` |
| `Bunker2.rWeight` | Вес меньше `BUNKER_MINIMAL_WEIGHT` |
| `Bunker3.rWeight` | Вес меньше `BUNKER_MINIMAL_WEIGHT` |

**Ошибка возникает, если 2 или более бункеров пусты** (вес ниже минимального).

---

### 5. Флаги состояния системы

| Переменная | Описание |
|------------|----------|
| `xStateEmergencyStop` | Активна аварийная остановка |
| `ICUR_PRECENT >= 100` | КИУМ достиг 100% (установка полностью загружена) |

---

## Сводная таблица всех ошибок

| Категория | Количество проверок | Описание |
|-----------|---------------------|----------|
| Бункеры (x3) | 54 | Вибропитатели, вибраторы |
| Сборный конвейер | 21 | Датчики, двигатели |
| Отвалообразователь | 28 | Датчики, двигатели конвейера и поворота |
| Вес бункеров | 3 | Минимальный уровень заполнения |
| Системные флаги | 2 | Аварийная остановка, КИУМ |

**Итого: ~108 условий ошибки**

---

## Пример использования

```iecst
xHasError := FC_Get_ErrorCommon(
    Bunker1 := stBunker1,
    Bunker2 := stBunker2,
    Bunker3 := stBunker3,
    Conveyor := stConveyor,
    Dumper := stDumper,
    xStateEmergencyStop := xEmergencyStop,
    ICUR_PRECENT := rCurrentKIUM
);

IF xHasError THEN
    // Переход в состояние ошибки
    AUTO_STEP := ERROR;
END_IF
```

---

## Связанные функции

| Функция | Файл | Описание |
|---------|------|----------|
| FC_Bunker_GetErrorBunker | Functions/FC_Bunker_GetErrorBunker.st | Агрегация ошибок бункера |
| FC_Bunker_GetErrorMotorVibFeeder | Functions/FC_Bunker_GetErrorMotorVibFeeder.st | Ошибки вибропитателей |
| FC_Bunker_GetErrorMotorVibrator | Functions/FC_Bunker_GetErrorMotorVibrator.st | Ошибки вибраторов |
| FC_Bunker_GetErrorWeight | Functions/FC_Bunker_GetErrorWeight.st | Проверка веса бункеров |
| FC_Bunker_CheckWeight | Functions/FC_Bunker_CheckWeight.st | Проверка веса одного бункера |
| FC_Conveyor_GetErrorCommon | Functions/FC_Conveyor_GetErrorCommon.st | Агрегация ошибок конвейера |
| FC_Conveyor_GetErrorSensors | Functions/FC_Conveyor_GetErrorSensors.st | Ошибки датчиков конвейера |
| FC_Conveyor_GetErrorMotor | Functions/FC_Conveyor_GetErrorMotor.st | Ошибки двигателя конвейера |
| FC_Dumper_GetErrorCommon | Functions/FC_Dumper_GetErrorCommon.st | Агрегация ошибок отвалообразователя |
| FC_Dumper_GetErrorSensors | Functions/FC_Dumper_GetErrorSensors.st | Ошибки датчиков отвалообразователя |
