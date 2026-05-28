(* BOOLEAN expressions, IF statements: *)

(*
  p & q  = if p then q else FALSE
  p OR q = if p then TRUE else q
*)

MODULE Test5;
    VAR n: INTEGER;
        a, b: BOOLEAN;
        s: SET;
BEGIN
    (* IF statements *)
    IF n = 0 THEN
        n := n + 1
    END;

    IF (n >= 0) & (n < 100) THEN
        n := n - 1
    END;

    IF (n MOD 2 = 1) OR (n IN s) THEN
        n := -1000
    END;

    IF n < 0 THEN
        s := {}
    ELSIF n < 10 THEN
        s := {0}
    ELSIF n < 100 THEN
        s := {1}
    ELSE
        s := {2}
    END
END Test5.