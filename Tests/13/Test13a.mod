(* RECORD extensions with POINTERs *)

(*
    Use of type descriptors again.

    A type test of the form p IS T then, consists of a
    comparison of the type tag of p^ at address p - 8 with
    the tag held in the descriptor of T at the extension
    level of the type of p^.

    A type guard p(T) is synonymous to the statement:

    IF ~(p IS T) THEN abort END
*)

MODULE Test13a;
    TYPE
        P0 = POINTER TO R0;
        P1 = POINTER TO R1;
        P2 = POINTER TO R2;
        R0 = RECORD x: INTEGER END ;
        R1 = RECORD (R0) y: INTEGER END ;
        R2 = RECORD (R1) z: INTEGER END ;
    VAR
        p0: P0;
        p1: P1;
        p2: P2;
BEGIN
    p0.x := 0;
    p1.y := 1;

    p0(P1).y := 3;

    IF p1 IS P2 THEN
        p0 := p2
    END
END Test13a.