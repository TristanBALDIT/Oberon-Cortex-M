(* Dynamic ARRAY parameters *)

(*
    use of a descriptor passed onto the stack regardless of
    their parameter types, i.e. value or VAR

    the descriptor holds the base address and the length of
    the ARRAY
*)

MODULE Test10a;
    VAR a: ARRAY 12 OF INTEGER;

    PROCEDURE P(x: ARRAY OF INTEGER): INTEGER;
    BEGIN
      RETURN x[5]
    END P;

    PROCEDURE Q(VAR x: ARRAY OF INTEGER);
      VAR i, n: INTEGER;
    BEGIN
        n := P(x);
        x[4] := 5
    END Q;

BEGIN
    Q(a);
END Test10a.