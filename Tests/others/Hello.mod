MODULE Hello;

VAR arr: ARRAY 5 OF INTEGER;

i, sum, a, b: INTEGER;

BEGIN
  a := 1;
  b := a * 3 + 1;
  FOR i := 0 TO b DO arr[i] := i + 1 END;
  sum := 0;
  FOR i := 0 TO 4 DO sum := sum + arr[i] END;
END Hello.