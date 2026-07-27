MODULE NXPSerial;
    IMPORT SYSTEM;

    CONST
        (*Clock Enable*)
        SYSCOM = 40000000H;
        AHBCLKCTRLSET0 = SYSCOM + 220H;
        AHBCLKCTRLSET1 = SYSCOM + 224H;
        FCCLKSEL4 = SYSCOM + 2C0H;   

        (* Pin Control Registers *)
        PORT1 = 40117000H;
        PCR8 = PORT1 + 0A0H;
        PCR9 = PORT1 + 0A4H;

        (* Base address for LP_FLEXCOMM4 / LPUART4 *)
        LPFLEXCOMM4 = 0400B4000H;
        PSELID = LPFLEXCOMM4 + 0FF8H; (* Peripheral Select ID Register *)
        
        (* LPUART Register Addresses *)
        LPUART4PARAM = LPFLEXCOMM4 + 04H;
        LPUART4GLOBAL = LPFLEXCOMM4 + 08H;
        LPUART4BAUD = LPFLEXCOMM4 + 010H;
        LPUART4STAT = LPFLEXCOMM4 + 014H;
        LPUART4CTRL = LPFLEXCOMM4 + 018H;
        LPUART4DATA = LPFLEXCOMM4 + 01CH;
        

        (* Bit Masks *)
        UART = 0; (* Bit 0: UART mode *)
        TDRE = 23; (* Bit 23: Transmit Data Register Empty *)
        RE = 18; (* Bit 18: Receiver Enable *)
        TE = 19; (* Bit 19: Transmitter Enable *)

    (* initializes the LPUART4 peripheral *)
    PROCEDURE Init*;
    VAR 
        ctrl: SET;
    BEGIN
        ctrl := {14}; SYSTEM.PUT(AHBCLKCTRLSET0, ctrl); (* Enable clock for PORT1 *)
        ctrl := {15}; SYSTEM.PUT(AHBCLKCTRLSET1, ctrl); (* Enable clock for FLEXCOMM4 *)
        ctrl := {1};  SYSTEM.PUT(FCCLKSEL4, ctrl); (* Select clock source for LPUART4 *)

        ctrl := {9, 12}; SYSTEM.PUT(PCR8, ctrl);
        ctrl := {9, 12}; SYSTEM.PUT(PCR9, ctrl);

        SYSTEM.PUT(PSELID, {UART}); (* Select LPUART4 for FLEXCOMM4 *)

        SYSTEM.PUT(LPUART4BAUD, 0C000008H); (* Set baud rate *)
        SYSTEM.PUT(LPUART4CTRL, {TE}); (* Enable receiver and transmitter *)
    END Init;

    (* Outputs a single character via LPUART4 *)
    PROCEDURE Char*(ch: CHAR);
    VAR 
        status: SET;
        byteVal: INTEGER;
    BEGIN
        (* Poll STAT register until TDRE (Bit 23) is 1 (FIFO/Register is empty) *)
        REPEAT
            SYSTEM.GET(LPUART4STAT, status)
        UNTIL TDRE IN status;

        (* Write the character byte to the DATA register *)
        byteVal := ORD(ch) MOD 256;
        SYSTEM.PUT(LPUART4DATA, byteVal)
    END Char;

    (* Outputs a null-terminated string string *)
    PROCEDURE String*(STR: ARRAY OF CHAR);
    VAR 
        i: INTEGER;
    BEGIN
        i := 0;
        WHILE (i < LEN(STR)) & (STR[i] # 0X) DO
            (* Handle Carriage Return automatically for clean terminal printouts *)
            IF STR[i] = CHR(0AH) THEN 
                Char(CHR(0DH)) (* Carriage Return *)
            END;
            Char(STR[i]);
            INC(i)
        END
    END String;

    (* Outputs an Integer converted to ASCII String *)
    PROCEDURE Int*(n: INTEGER);
    VAR
        i, j, digit: INTEGER;
        buf, str: ARRAY 16 OF CHAR;
        neg: BOOLEAN;
    BEGIN
        neg := n < 0; IF neg THEN n := -n END;
        IF n = 0 THEN buf[0] := 30X; i := 1  (* 30X = '0' *)
        ELSE
            i := 0;
            WHILE n > 0 DO
                buf[i] := CHR(ORD(30X) + n MOD 10);
                n := n DIV 10; INC(i)
            END
        END;
        IF neg THEN buf[i] := 2DX; INC(i) END;  (* 2DX = '-' *)
        buf[i] := 0X;
        (* Reverse the string *)
        j := 0;
        WHILE i > 0 DO DEC(i); str[j] := buf[i]; INC(j) END;
        str[j] := 0X;
        String(str)
    END Int;
 
BEGIN
    Init;
    Char("N"); 
    Char("X");
    Char("P");
    String(" UART OK ");
    Int(1234567890);
    WHILE TRUE DO END;
END NXPSerial.