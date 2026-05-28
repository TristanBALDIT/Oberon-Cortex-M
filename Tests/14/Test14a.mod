(* RECORD extensions as VAR parameters *)

(*
    Type tests and type guards on VAR-parameters are
    handled in the same way as for variables referenced via
    pointers, with a slight difference, however. Statically
    declared record variables may be used as actual
    parameters, and they are not prefixed by a type tag.
    Therefore, the tag has to be supplied together with the
    variable's address when the procedure is called, i.e.
    when the actual parameter is established.
*)

MODULE Test14a;
    TYPE
        R0 = RECORD a, b, c, x: INTEGER END ;
        R1 = RECORD (R0) d, e: INTEGER END ;
    VAR
        r0: R0;     (* 40 *)
        r1: R1;     (* 52 *)

    PROCEDURE P(VAR r: R0);
    BEGIN
        r.a := 1;
        r(R1).d := 2
    END P;

BEGIN
    P(r0);
    P(r1)
END Test14a.