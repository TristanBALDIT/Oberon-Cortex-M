MODULE Test1;
    CONST constchr = 40X;
        constint = 7;
        constreal = 3.14;
        constset = {1, 2, 3, 4};

    VAR ch: CHAR;
        k: INTEGER;
        x: REAL;
        s: SET;

BEGIN
    ch := "0";
    k := 10;
    x := 1.1;
    s := {0, 4, 8};

    ch := constchr;
    k := constint;
    x := constreal;
END Test1.