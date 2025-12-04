FUNCTION FC_SwapBytesInWord : WORD
VAR_INPUT
    wInputValue : WORD;                         // Входное значение WORD
END_VAR
VAR
    uByteConverter : U_ByteToWord;              // Конвертер для работы с байтами
END_VAR

// Загружаем входное значение в конвертер
uByteConverter.wTag := wInputValue;

// Меняем местами байты: младший байт становится старшим, старший - младшим
FC_SwapBytesInWord := SHL(TO_WORD(uByteConverter.bTag[0]), 8) OR TO_WORD(uByteConverter.bTag[1]);

END_FUNCTION