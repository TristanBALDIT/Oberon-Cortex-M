MODULE Test15a;
  VAR   s0, s1: ARRAY 64 OF CHAR;

    PROCEDURE P(x: ARRAY OF CHAR);
    END P;

BEGIN
    s0 := "ABCDEF";
    s0 := s1;

    P(s1);
    P("012345");
    P("%")

END Test15a.