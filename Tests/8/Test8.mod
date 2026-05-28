(* Proper PROCEDUREs *)

MODULE Test8;
    TYPE T = ARRAY 10 OF INTEGER;
    VAR i: INTEGER;
        tab: T;

    PROCEDURE ByValue     (    x: INTEGER); BEGIN x := 1    END ByValue;
    PROCEDURE ByVariable  (VAR x: INTEGER); BEGIN x := 2    END ByVariable;
    PROCEDURE ByValueArray(    t: T      ); BEGIN i := t[1] END ByValueArray;
    PROCEDURE ByVarArray  (VAR t: T      ); BEGIN t[2] := 1 END ByVarArray;

    PROCEDURE P(x: INTEGER; VAR y: INTEGER; t1: T; VAR t2: T);
        VAR z: INTEGER;
            tab: T;
            rec: RECORD x,y: INTEGER END;
    BEGIN
        z := x;
        y := z;

        ByValue(3);
        ByValue(i);
        ByValue(z);
        ByValue(x);
        ByValue(y);
        ByValue(i+1);

        ByVariable(i);
        ByVariable(z);
        ByVariable(x);
        ByVariable(y);
        ByVariable(tab[i]);
        ByVariable(rec.y);

        ByValueArray(t1);
        ByValueArray(t2);

        ByVarArray(t2);
    END P;

BEGIN
    P(i, i, tab, tab)
END Test8.