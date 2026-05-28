(* Function PROCEDUREs *)

MODULE Test9;
    VAR x: REAL;      (* 0 *)

    PROCEDURE F(x: REAL): REAL;
    BEGIN
        IF x >= 1.0 THEN
            x := F(F(x))
        END ;
        RETURN x
    END F;

BEGIN
    x := F(x);
END Test9.