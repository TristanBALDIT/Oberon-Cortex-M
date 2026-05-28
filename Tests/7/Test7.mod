MODULE Test7;
    VAR i, m, n: INTEGER;
BEGIN
    FOR i := 0 TO n - 1 DO
        m := 2 * m
    END;

    FOR i := n TO 0 DO
        m := -i
    END;

    FOR i := 3 TO 18 BY 2 DO
        m := 0
    END;

    FOR i := 42 TO -3 BY -1 DO
        m := 0
    END
END Test7.