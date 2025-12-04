FUNCTION FC_SwapBytesInWordArray : ARRAY [0..1] OF WORD
VAR_INPUT
    awInputArray : ARRAY [0..1] OF WORD;        // Входной массив из двух WORD
END_VAR
VAR
    uByteConverter : U_ByteToWord;              // Конвертер для работы с байтами
    awOutputArray : ARRAY [0..1] OF WORD;       // Выходной массив
END_VAR

// Обработка первого WORD (индекс 0)
uByteConverter.wTag := awInputArray[0];
// Меняем местами байты и записываем в выходной массив
awOutputArray[0] := SHL(TO_WORD(uByteConverter.bTag[0]), 8) OR TO_WORD(uByteConverter.bTag[1]);

// Обработка второго WORD (индекс 1)
uByteConverter.wTag := awInputArray[1];
// Меняем местами байты и записываем в выходной массив
awOutputArray[1] := SHL(TO_WORD(uByteConverter.bTag[0]), 8) OR TO_WORD(uByteConverter.bTag[1]);

// Возвращаем преобразованный массив
FC_SwapBytesInWordArray := awOutputArray;

END_FUNCTION