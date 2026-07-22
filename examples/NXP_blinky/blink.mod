MODULE blink;

    IMPORT SYSTEM;

    CONST
        (* Clock Control Registers *)
        CLKCTL0      = 40000000H;
        AHBCLKCTRLSET0  = CLKCTL0 + 0220H;
        PRESETCTRL0 = CLKCTL0 + 0100H;

        (* Clock Control Bits *)
        GPIO0CLKBIT    = 19; (* Bit 19 enables clock to GPIO0 *)
        PORT0CLKBIT    = 13; (* Bit 13 enables clock to PORT0 *)
        

        (* Pin Control Registers *)
        PORT0 = 40116000H;
        PCR10 = PORT0 + 0A8H;

        (* GPIO0 Peripheral Registers *)
        GPIO0BASE       = 040096000H;
        GPIO0PCOR       = GPIO0BASE + 048H;
        GPIO0PDDR       = GPIO0BASE + 054H;
        GPIO0PTOR       = GPIO0BASE + 04CH;
        GPIO0PDOR       = GPIO0BASE + 040H;
        
        (* LED Pin Configuration *)
        REDLEDPIN      = 10; (* P0_10 *)

    (* Enables the GPIO0 clock and sets P0_10 as an output *)
    PROCEDURE Init*;
    VAR 
        regVal: SET;
    BEGIN
        (* 1. Un-gate (enable) the clock for GPIO0 *)
        regVal := {PORT0CLKBIT, GPIO0CLKBIT};
        SYSTEM.PUT(AHBCLKCTRLSET0, regVal);

        SYSTEM.GET(PRESETCTRL0, regVal);

        (* 2.Init P0_10 to GPIO0 *)
        regVal := {12};
        SYSTEM.PUT(PCR10, regVal);

        (* 3. Set P0_10 direction to OUTPUT *)
        regVal := {REDLEDPIN};
        SYSTEM.PUT(GPIO0PCOR, regVal);     (* Clear the pin to turn off the LED *)
        SYSTEM.GET(GPIO0PDDR, regVal);
        regVal := regVal + {REDLEDPIN};
        SYSTEM.PUT(GPIO0PDDR, regVal)
    END Init;

    (* Toggles the state of the Red LED *)
    PROCEDURE Toggle*;
    VAR 
        regVal: SET;
    BEGIN
        (* Writing a 1 to the pin's bit position in PTOR toggles it *)
        regVal := {REDLEDPIN};
        SYSTEM.PUT(GPIO0PTOR, regVal);
        SYSTEM.GET(GPIO0PDOR, regVal);
    END Toggle;

    (* A crude loop to block execution for a short duration *)
    PROCEDURE Delay*(count: INTEGER);
    VAR 
        i: INTEGER;
    BEGIN
        i := 0;
        WHILE i < count DO
            INC(i)
        END
    END Delay;


BEGIN
    Init;
    WHILE TRUE DO 
        Toggle;
        Delay(6000000);
    END
END blink.