MODULE Error;
  IMPORT Out, Err;

  CONST STDOUT = 1;
    STDERR = 2;
    ANSI_RED = 31;
    ANSI_GREEN = 32;
    ANSI_YELLOW = 33;
    ANSI_MAGENTA = 35;
    ANSI_RESET = 0;

  PROCEDURE ansi_escape_sequence(code, output: INTEGER);
  BEGIN
    CASE output OF
      | STDOUT: 
        Out.Char(1BX);
        Out.Char("[");
        Out.Int(code, 1);
        Out.Char("m")
      | STDERR: 
        Err.Char(1BX);
        Err.Char("[");
        Err.Int(code, 1);
        Err.Char("m")
    END
  END ansi_escape_sequence;

  PROCEDURE throw_message(color: INTEGER; message: ARRAY OF CHAR; output: INTEGER);
  BEGIN
    CASE output OF
      | STDOUT: 
        Out.String("oberon: ");
        ansi_escape_sequence(color, STDOUT);
        Out.String(message);
        ansi_escape_sequence(ANSI_RESET, STDOUT);
        Out.String(": ")
      | STDERR: 
        Err.String("oberon: ");
        ansi_escape_sequence(color, STDERR);
        Err.String(message);
        ansi_escape_sequence(ANSI_RESET, STDERR);
        Err.String(": ")
    END
  END throw_message;

  PROCEDURE throw_error*();
  BEGIN
    throw_message(ANSI_RED, "error", STDERR)
  END throw_error;

  PROCEDURE throw_success*();
  BEGIN
    throw_message(ANSI_GREEN, "success", STDOUT)
  END throw_success;

  PROCEDURE throw_warning*();
  BEGIN
    throw_message(ANSI_YELLOW, "warning", STDERR)
  END throw_warning;

  PROCEDURE throw_info*();
  BEGIN
    throw_message(ANSI_MAGENTA, "info", STDOUT)
  END throw_info;

END Error.