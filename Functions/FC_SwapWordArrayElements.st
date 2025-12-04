FUNCTION FC_SwapWordArrayElements : ARRAY [0..1] OF WORD
VAR_INPUT
    awInputArray : ARRAY [0..1] OF WORD;        // Входной массив из двух WORD
END_VAR
VAR
    awOutputArray : ARRAY [0..1] OF WORD;       // Выходной массив
END_VAR
// Меняем местами элементы массива: [0] -> [1], [1] -> [0]
awOutputArray[0] := awInputArray[1];
awOutputArray[1] := awInputArray[0];

// Возвращаем массив с переставленными элементами
FC_SwapWordArrayElements := awOutputArray;

END_FUNCTION