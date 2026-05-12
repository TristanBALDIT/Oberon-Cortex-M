MODULE ORC;

  IMPORT LibC,ORS, ORB, ORG, ORP, Files, Error, Err, Out;

  TYPE Path = ARRAY 256 OF CHAR;

	
  VAR arg                   : Path;
      arg_num               : INTEGER;

	
  PROCEDURE Compile(VAR filename: ARRAY OF CHAR);
    VAR input: Files.File;
	BEGIN
    input := Files.Old(filename);
    (* give an error if the file does not exist *)
    IF input = NIL THEN
      Error.throw_error(); Err.String(filename); Err.String(": No such file or directory"); Err.Ln();
    ELSE
      Error.throw_info(); Out.String("source text: "); Out.String(filename); Out.Ln();
    	ORS.Init(input, 0); 
    	ORP.Module;
  	END
	END Compile;

BEGIN
  arg_num := 1;
  LibC.getarg(arg_num, arg);

  IF arg # ""
  THEN Compile(arg)
  ELSE Error.throw_error(); Err.String("No source file specified"); Err.Ln()
  END
END ORC.
