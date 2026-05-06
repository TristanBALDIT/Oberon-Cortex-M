MODULE ORG; (* N.Wirth, 16.4.2016 / 4.4.2017 / 31.5.2019  Oberon compiler; code generator for RISC*)
  IMPORT SYSTEM, Files, ORS, ORB;
  (*Code generator for Oberon compiler for Armv6 M Thumb processor.
     Procedural interface to Parser ORP; result in array "code".
     Procedure Close writes code-files*)

  CONST WordSize* = 4; dPC = 2; appendix = ".arm"; version = 3X;
    minR = 0; TR = 12; SP = 13; RA = 14; PC = 15;  (*dedicated registers*)
    TrapArray=1; TrapTypeGuard=2; TrapCopyOV=3; TrapNIL=4; TrapIllProc=5; TrapDivZero=6; TrapAssert=7;
    maxCode = 12000; maxStrx = 3500; maxTD = 160; maxSet = WordSize*8;
    Reg = 10; RegI = 11; Cond = 12;  (*internal item modes*)

    EQ = 0; NE = 1; CC = 3; MI = 4; PL = 5; VS = 6; HI = 8; LS = 9; GE = 10; LT = 11; GT = 12; LE = 13; AL = 14;  (*condition codes*)

    (* Opcodes Thumb - 16-bits *)
    i16_ADDS_imm8 = 3000H;  (* ADDS Rdn, #imm8 *)
    i16_ADDS_imm3 = 1C00H;  (* ADDS Rd, Rn, #imm3 *)
    i16_ADD_reg = 1800H;    (* ADDS Rd, Rn, Rm *) 

    i16_SUB_imm8 = 3800H;   (* SUB Rd, #imm8 *)
    i16_SUB_imm3 = 1E00H;   (* SUB Rd, Rn, #imm3 *)
    i16_SUB_reg = 1A00H;    (* SUB Rd, Rn, Rm *)

    i16_CMP_imm8 = 2800H;   (* CMP Rn, #imm8 *)
    i16_CMP_reg = 4280H;    (* CMP Rn, Rm *)

    i16_MOV_imm8 = 2000H;   (* MOV Rd, #imm8 *)
    i16_MOV_reg = 4600H;    (* MOV Rd, Rm *)
    i16_MOVS_reg = 0000H;   (* MOVS Rd, Rm *)
    
    
    i16_LDR_pc  = 4800H;   (* LDR Rt, [PC, #off] *)
    i16_LDR_reg = 6800H;   (* LDR Rd, [Rn, #off] *)
    i16_LDR_sp_imm8 = 9100H;  (* LDR Rd, [SP, #imm8] *)

    i16_STR_reg = 6000H;   (* STR Rd, [Rn, #off] *)

    i16_B_cond_imm8 = 0D000H;         (* B label *)
    i16_BX = 4700H;              (* BX Rm *)
    i16_BLX = 4780H;             (* BLX Rm *)

    i16_ADR = 0A000H;       (* ADR Rd, label *)

    i16_NOP = 0BF00H;  

    i16_IT = 0BF00H;        (* IT{x{y{z}}} cond *)

    (* Opcodes - 32-bits *)
    
    i32_ADDS_exp12 = 0F1100000H;  (* ADDS Rd, Rn, #imm12 *)
    i32_ADD_exp12 = 0F1000000H;   (* ADD Rd, Rn, #imm12 *)
    i32_ADD_imm12 = 0F2000000H;   (* ADD Rd, Rn, #imm12 *)
    i32_ADD_reg = 0EB000000H;     (* ADD Rd, Rn, Rm *)
    i32_ADDS_reg = 0EB100000H;     (* ADDS Rd, Rn, Rm *)

    i32_SUBS_reg = 0EBB00000H;     (* SUBS Rd, Rn, Rm *)
    i32_SUB_reg = 0EBA00000H;     (* SUB Rd, Rn, Rm *)
    i32_SUBS_exp12 = 0F1B00000H;   (* SUB Rd, Rn, #imm12 *)
    i32_SUB_exp12 = 0F1A00000H;   (* SUB Rd, Rn, #imm12 *)
    i32_SUB_imm12 = 0F2A00000H;   (* SUB Rd, Rn, #imm12 *)

    i32_ORR_exp12 = 0F0400000H;   (* ORR Rd, Rn, #imm12 *)
    i32_ORR_reg = 0EA400000H;     (* ORR Rd, Rn, Rm *)
    i32_BIC_exp12 = 0F0200000H;   (* BIC Rd, Rn, #imm12 *)
    i32_BIC_reg = 0EA200000H;     (* BIC Rd, Rn, Rm *)
    i32_AND_exp12 = 0F0000000H;   (* AND Rd, Rn, #imm12 *)
    i32_ANDS_exp12 = 0F0100000H;   (* ANDS Rd, Rn, #imm12 *)
    i32_AND_reg = 0EA000000H;     (* AND Rd, Rn, Rm *)
    i32_EOR_exp12 = 0F0800000H;   (* EOR Rd, Rn, #imm12 *)
    i32_EOR_reg = 0EA800000H;     (* EOR Rd, Rn, Rm *)

    i32_RSB_exp12 = 0F1C00000H;   (* RSB Rd, Rn, #imm12 *)

    i32_B_cond_imm21 = 0F0008000H; (* B label *)
    i32_B_imm25 = 0F0008000H;   (* B label *)
    i32_BL_imm25 = 0F000D000H;   (* BL label *)

    i32_MOV_exp12 = 0F04F0000H;   (* MOV Rd, #const *)
    i32_MOVS_exp12 = 0F05F0000H;   (* MOVS Rd, #const *)
    i32_MOV_reg = 0EA4F0000H;     (* MOV Rd, Rm *)
    i32_MVN_exp12 = 0F06F0000H;   (* MVN Rd, #const *)
    i32_MVN_reg = 0E26F0000H;     (* MVN Rd, Rm *)

    i32_MOVW = 0F2400000H;   (* MOVW Rd, #imm16 *)
    i32_MOVT = 0F2C00000H;   (* MOVT Rd, #imm16 *)

    i32_VMOVA = 0EE100A10H;  (* VMOV Rt, Sn *)
    i32_VMOVV = 0EE000A10H;  (* VMOV Sn, Rt *)
    i32_VCVTM = 0FEBF0A40H;  (* VCVTM Sd, Sm *)
    i32_VCVT_if_s = 0EEB80AC0H;  (* VCVT F32 S32 Sd, Sm *)

    i32_VADD = 0EE300A00H;   (* VADD Sd, Sn, Sm *)
    i32_VSUB = 0EE300A40H;   (* VSUB Sd, Sn, Sm *)
    i32_VMUL = 0EE200A00H;   (* VMUL Sd, Sn, Sm *)
    i32_VDIV = 0EE800A00H;   (* VDIV Sd, Sn, Sm *)
    i32_VNEG = 0EEB10A40H;   (* VNEG Sd, Sm *)
    i32_VABS = 0EEB00AC0H;   (* VABS Sd, Sm *)

    i32_VCMP = 0EEB40A40H;    (* VCMP Sd, Sm *)
    i32_VCMPZ = 0EEB50A40H;  (* VCMPZ Sd, #0 *)
    i32_VMRS = 0EEF00A10H;   (* VMRS Rn, spec_reg *)

    i32_LDR_pc_imm12 = 0F85F0000H;  (* LDR Rt, [PC, #imm12] *)
    i32_LDR_imm8_i = 0F8500C00H;  (* LDR Rt, [Rn, #imm8] *)
    i32_LDR_imm8_w = 0F8500900H;  (* LDR Rt, [Rn, #imm8] *)
    i32_LDRB_imm8_i = 0F8100C00H;  (* LDRB Rt, [Rn, #imm8] *)
    i32_LDRB_imm8_w = 0F8100900H;  (* LDRB Rt, [Rn, #imm8] *)
    i32_STRB_imm8_i = 0F8000C00H;  (* STRB Rt, [Rn, #imm8] *)
    i32_STRB_imm8_w = 0F8000900H;  (* STRB Rt, [Rn, #imm8] *)
    i32_STR_imm8_i = 0F8400C00H;  (* STR Rt, [Rn, #imm8] *)
    i32_STR_imm8_w = 0F8400900H;  (* STR Rt, [Rn, #imm8] *)

    i32_LDMIA_w = 0E8B00000H;  (* LDMIA Rn!, {Rlist} *)
    i32_STMDB_w = 0E9200000H;  (* STMDB Rn!, {Rlist} *)
    i32_STMIA_i = 0E8800000H;  (* STMIA Rn!, {Rlist} *)

    i32_VLDR = 0ED100A00H;  (* VLDR Sd, [Rn, #imm8] *)
    i32_VSTR = 0ED000A00H;  (* VSTR Sd, [Rn, #imm8] *)

    i32_CMP_exp12 = 0F1B00F00H;   (* CMP Rn, #const *)
    i32_CMP_reg = 0EBB00F00H;     (* CMP Rn, Rm *)
    i32_CMN_exp12 = 0F1100F00H;   (* CMN Rn, #const *)
    i32_CMN_reg = 0EB100F00H;     (* CMN Rn, Rm *)

    i32_LSL_imm5 = 0EA4F0000H;  (* LSL Rd, Rn, #imm5 *)
    i32_LSL_reg = 0FA00F000H;   (* LSL Rd, Rn, Rm *)
    i32_ASR_imm5 = 0EA4F0020H;  (* ASR Rd, Rn, #imm5 *)
    i32_ASRS_imm5 = 0EA5F0020H;  (* ASRS Rd, Rn, #imm5 *)
    i32_ASR_reg = 0FA40F000H;   (* ASR Rd, Rn, Rm *)
    i32_ROR_imm5 = 0EA4F0030H;  (* RORS Rd, Rn, #imm5 *)
    i32_ROR_reg = 0FA60F000H;   (* RORS Rd, Rn, Rm *)
    i32_RORS_imm5 = 0EA5F0030H;  (* RORS Rd, Rn, #imm5 *)
    i32_RORS_reg = 0FA70F000H;   (* RORS Rd, Rn, Rm *)

    i32_ADC_reg = 0EB400000H;     (* ADC Rd, Rn, Rm *)
    i32_SBC_reg = 0EB600000H;     (* SBC Rd, Rn, Rm *)

    i32_UMUL_reg = 0FBA00000H;     (* UMULL Rd, Rn, Rm *)

    i32_MUL_reg = 0FB00F000H;     (* MUL Rd, Rn, Rm *)
    i32_SDIV_reg = 0FB90F0F0H;    (* SDIV Rd, Rn, Rm *)
    i32_MLS_reg = 0FB000010H;     (* MLS Rd, Rn, Rm, Ra *)

    i32_UBFX = 0F3C00000H;    (* UBFX Rd, Rn, #lsb, #width *)

    C1 = 2H;     (* Constante pour les décalages de 1 bit *)
    C2 = 4H;     (* Constante pour les décalages de 2 bits *)
    C3 = 8H;    (* Constante pour les décalages de 3 bits *)
    C4 = 10H;   (* Constante pour les décalages de 4 bits *)
    C5 = 20H;   (* Constante pour les décalages de 5 bits *)
    C6 = 40H;   (* Constante pour les décalages de 6 bits *)
    C7 = 80H;   (* Constante pour les décalages de 7 bits *)
    C8 = 100H;  (* Constante pour les décalages de 8 bits *)
    C10 = 400H;  (* Constante pour les décalages de 10 bits *)
    C11 = 800H;  (* Constante pour les décalages de 11 bits *)
    C12 = 1000H; (* Constante pour les décalages de 12 bits *)
    C13 = 2000H; (* Constante pour les décalages de 13 bits *)
    C14 = 4000H; (* Constante pour les décalages de 14 bits *)
    C15 = 8000H; (* Constante pour les décalages de 15 bits *)
    C16 = 10000H; (* Constante pour les décalages de 16 bits *)
    C17 = 20000H; (* Constante pour les décalages de 17 bits *)
    C18 = 40000H; (* Constante pour les décalages de 18 bits *)
    C19 = 80000H; (* Constante pour les décalages de 19 bits *)
    C20 = 100000H; (* Constante pour les décalages de 20 bits *)
    C22 = 400000H; (* Constante pour les décalages de 22 bits *)
    C23 = 800000H; (* Constante pour les décalages de 23 bits *)
    C24 = 1000000H; (* Constante pour les décalages de 24 bits *)

    TYPE Item* = RECORD
      mode*: INTEGER;
      type*: ORB.Type;
      obj* : ORB.Object;
      a*, b*, r: INTEGER;
      rdo*: BOOLEAN  (*read only*)
    END ;
    LabelRange* = RECORD low*, high*, label*: INTEGER END;

  (* Item forms and meaning of fields:
    mode    r      a       b
    --------------------------------
    Const   -     value (proc adr)  (immediate value)
    Var     base   off     -               (direct adr)
    Par      -     off0     off1         (indirect adr)
    Reg    regno
    RegI   regno   off     -
    Cond  cond   Fchain  Tchain  *)

  VAR pc*, varx: INTEGER;   (*program counter, data index*)
    tdw, strx: INTEGER;
    entry: INTEGER;   (*main entry point*)
    RH: INTEGER;  (*available registers R[0] ... R[H-1]*)
    frame: INTEGER;  (*frame offset changed in SaveRegs and RestoreRegs*)
    fixorgP, fixorgD, fixorgT: INTEGER;   (*origins of lists of locations to be fixed up by loader*)
    check: BOOLEAN;  (*emit run-time checks*)
    
    relmap: ARRAY 6 OF INTEGER;  (*condition codes for relations*)
    code: ARRAY maxCode OF INTEGER;
    td: ARRAY maxTD OF INTEGER;  (*type descriptors*)
    str: ARRAY maxStrx OF CHAR;

    literals: ARRAY 128 OF INTEGER;  (*table of constants for literal pool*)
    ldrAddr: ARRAY 128 OF INTEGER;   (*addresses of LDR instructions referring to literal pool*)
    litCount: INTEGER;
    modid: ORS.Ident;  (*for test*)

  PROCEDURE IntToStr(n: INTEGER; VAR s: ARRAY OF CHAR);
    VAR i, j: INTEGER; neg: BOOLEAN; buf: ARRAY 16 OF CHAR;
  BEGIN
    neg := n < 0; IF neg THEN n := -n END;
    IF n = 0 THEN buf[0] := 30X; i := 1  (* 30X = '0' *)
    ELSE
      i := 0;
      WHILE n > 0 DO
        buf[i] := CHR(ORD(30X) + n MOD 10);  (* 30X = '0' *)
        n := n DIV 10; INC(i)
      END
    END;
    IF neg THEN buf[i] := 2DX; INC(i) END;  (* 2DX = '-' *)
    buf[i] := 0X;
    (* Reverse the string *)
    j := 0;
    WHILE i > 0 DO DEC(i); s[j] := buf[i]; INC(j) END;
    s[j] := 0X
  END IntToStr;

  (*instruction assemblers according to formats*)

  PROCEDURE incR;
  BEGIN
    IF RH < TR-1 THEN INC(RH) ELSE ORS.Raise("register stack overflow") END
  END incR;

  PROCEDURE GetIns(adr: INTEGER): INTEGER;
    VAR word, res: INTEGER;
  BEGIN
    (* On va chercher le mot de 32 bits qui contient nos deux instructions *)
    word := code[adr DIV 2];
    
    IF adr MOD 2 = 0 THEN
      (* Cas pair : on veut les 16 bits de POIDS FAIBLE *)
      res := word MOD 10000H
    ELSE
      (* Cas impair : on veut les 16 bits de POIDS FORT *)
      res := word DIV 10000H
    END
    RETURN res
  END GetIns;

  PROCEDURE PutAt(ins, adr: INTEGER);
    VAR current, i: INTEGER;
  BEGIN
    i := ins MOD C16;
    current := code[adr DIV 2];
    IF adr MOD 2 = 0 THEN
      (* On veut modifier les 16 bits de POIDS FAIBLE *)
      code[adr DIV 2] := ((current DIV C16) * C16) + i;
    ELSE
      (* On veut modifier les 16 bits de POIDS FORT *)
      code[adr DIV 2] := (current MOD C16) + ROR(i, 16);
    END;
  END PutAt;

  PROCEDURE PutIns(ins: INTEGER);
  BEGIN
    PutAt(ins, pc);
    INC(pc)
  END PutIns;

  PROCEDURE GetMSB(x: INTEGER): INTEGER;
    VAR bit: INTEGER;
  BEGIN
    x := x MOD C8;
    IF x = 0 THEN bit := -1 END;
    IF x >= C4 THEN
      IF x >= C6 THEN 
        IF x >= C7 THEN bit := 7 ELSE bit := 6 END;
      ELSE
        IF x >= C5 THEN bit := 5 ELSE bit := 4 END;
      END;
    ELSE 
      IF x >= C2 THEN 
        IF x >= C3 THEN bit := 3 ELSE bit := 2 END;
      ELSE
        IF x >= C1 THEN bit := 1 ELSE bit := 0 END;
      END;
    END;
    RETURN bit
  END GetMSB;

  PROCEDURE PutR16(op, rd, rn, rm: INTEGER);
  BEGIN
    PutIns(op + rd + rn MOD C3 + rm * C3 + (rn DIV C4) * C7)
  END PutR16;

  PROCEDURE PutR32_1(op, rd, rn, rm: INTEGER);
  BEGIN
    PutIns(op DIV C16 + rd);
    PutIns(op MOD C16 + rn * C12 + rm)
  END PutR32_1;

  PROCEDURE PutR32_2(op, rd, rn, rm: INTEGER);
  BEGIN
    PutIns(op DIV C16 + rn);
    PutIns(op MOD C16 + rd * C8  + rm)
  END PutR32_2;

  PROCEDURE PutI8(op, rdn, imm8: INTEGER);
  BEGIN
    PutIns(op + imm8 + rdn * 100H)
  END PutI8;

  PROCEDURE PutI3(op, rd, rn, imm3: INTEGER);
  BEGIN
    PutIns(op + (imm3 MOD C3) * C6 + rn * C3 + rd)
  END PutI3;

  PROCEDURE PutI5(op, rt, rn, imm5: INTEGER);
  BEGIN
    PutIns(op + (imm5 MOD C5) * C6 + rn * C3 + rt)
  END PutI5;

  PROCEDURE PutB16(op, cond, imm8: INTEGER);
  BEGIN
    PutIns(op + cond * C8 + imm8 MOD C8)
  END PutB16;

  PROCEDURE PutB32(op, cond, imm: INTEGER);
  BEGIN
    PutIns(op DIV C16 + (imm DIV C19) * C10 + cond * C6 + (imm DIV C11) MOD C10);
    PutIns(op MOD C16 + ((imm DIV C17) MOD 4) * C13  + ((imm DIV C18) MOD 2) * C11 + imm MOD C11)
  END PutB32;

  PROCEDURE PutB32_2(op, imm: INTEGER);
    VAR s, j1, j2: INTEGER;
  BEGIN
    s := imm DIV C24;
    j1 := ABS((1 - (imm DIV C23) MOD 2) - s);
    j2 := ABS((1 - (imm DIV C22) MOD 2) - s);
    PutIns(op DIV C16 + s* C10 + (imm DIV C11) MOD C10);
    PutIns(op MOD C16 + j1 * C13  + j2 * C11 + imm MOD C11)
  END PutB32_2;

  PROCEDURE DecodeB32(ins1, ins2: INTEGER) : INTEGER;
    VAR s, j1, j2: INTEGER;
  BEGIN
    s := ins1 DIV C10 MOD 2;
    j1 := ins2 DIV C13 MOD 2;
    j2 := ins2 DIV C11 MOD 2;
    RETURN  s * C20 + j2 * C19 + j1 * C17 + (ins1 MOD C6) * C11 + (ins2 MOD C11)
  END DecodeB32;

  PROCEDURE PutMOV16(rd, rm: INTEGER);
    VAR d: INTEGER;
  BEGIN
    IF rd > 7 THEN d := 1; rd := rd - 8  ELSE d := 0 END;  
    PutIns(i16_MOV_reg + d * C7 + rm * C3 + rd MOD C3)
  END PutMOV16;

  PROCEDURE PutMUL(op, rd, rn, rm, ra: INTEGER);
  BEGIN 
    PutIns(op DIV C16 + rn);
    PutIns(op MOD C16 + ra * C12 + rd * C8 + rm)
  END PutMUL;

  PROCEDURE PutI12(op, rd, rn, imm12: INTEGER);
  BEGIN
    PutIns(op DIV C16 + ((imm12 DIV C11) MOD 2) * C10 + rn);
    PutIns(op MOD C16 + (imm12 DIV C8) MOD 8 * C12 + rd * C8 + imm12 MOD C8)
  END PutI12;

  PROCEDURE PutI16(op, rd, imm16: INTEGER);
  BEGIN
    PutIns(op DIV C16 + ((imm16 DIV C15) MOD 2) * C10 + imm16 DIV C12 MOD C4);
    PutIns(op MOD C16 + (imm16 DIV C8) MOD C3 * C12 + rd * C8 + imm16 MOD C8)
  END PutI16;

  PROCEDURE DecomposeConst(const : INTEGER; VAR imm: INTEGER): BOOLEAN;
    VAR rot: INTEGER; ret: BOOLEAN; msg: ARRAY 32 OF CHAR;
  BEGIN
    imm := const; rot := 0; ret := TRUE;
    IF ((imm < 0) OR (imm > 255)) THEN
      rot := 8;
      imm := ROR(imm, 32 - 8);
      WHILE (rot<32) & ((imm < 128) OR (imm > 255)) DO 
        imm := ROR(imm, 31); INC(rot) 
      END;
      ret := (imm >= 128) & (imm <= 255);
      imm := imm MOD C7 + rot * C7;
    END;
    RETURN ret
  END DecomposeConst;

  PROCEDURE PutMOVI(r, im: INTEGER);
    VAR i: INTEGER;
  BEGIN
    IF DecomposeConst(im, i) THEN PutI12(i32_MOV_exp12, r, 0, i);
    ELSIF DecomposeConst( -1-im , i) THEN PutI12(i32_MVN_exp12, r, 0, i);
    ELSE
      PutI16(i32_MOVW, r, im MOD C16);
      IF (im DIV C16) # 0 THEN
        PutI16(i32_MOVT, r, im DIV C16)
      END;
    END;
  END PutMOVI;

  PROCEDURE PutI32(op, rd, rn, im, op2: INTEGER);
  VAR c: INTEGER;
  BEGIN
    IF DecomposeConst(im, c) THEN PutI12(op, rd, rn, c);
    ELSE PutMOVI(TR, im);
      PutR32_2(op2, rd, rn, TR)
    END
  END PutI32;

  PROCEDURE PutLS(op, rt, rn, off: INTEGER);
    VAR off_high, i, j: INTEGER;
  BEGIN
    IF off < 0 THEN off := -off;
    ELSE 
      INC(op, 200H);
      IF off >= C16 THEN ORS.Raise("PutLS offset too big") END;
      IF off >= C8 THEN
      off_high := off DIV C8;
      i := GetMSB(off_high);
      j := LSL(off_high, 7-i) MOD C7 + (24 + 7 - i)* C7;
      PutI12(i32_ADD_exp12, RH, rn, j);
      rn := RH
      END;
    END;
    PutIns(op DIV C16 + rn);
    PutIns(op MOD C16 + off MOD C8 + rt * C12)
  END PutLS;


  PROCEDURE PutVLS(op, rt, rn, off: INTEGER);
    VAR off_high, i, j: INTEGER;
  BEGIN
    INC(op, 800000H);
    IF off < 0 THEN ORS.Raise("PutVLS negative offset"); (* Maybe add neg offset ?*)
    ELSIF off >= C8  THEN
      IF off >= C16 THEN ORS.Raise("PutVLS offset too big")
      ELSE 
        off_high := off DIV C8;
        i := GetMSB(off_high);
        j := LSL(off_high, 7-i) MOD C7 + (24 + 7 - i)* C7;
        PutI12(i32_ADD_exp12, RH, rn, j);
        rn := RH
      END;
    END;
    PutIns(op DIV C16 + rn);
    PutIns(op MOD C16 + off MOD C8 + rt * C12)
  END PutVLS;

  PROCEDURE PutLSM(op, rn : INTEGER; list: SET);
  BEGIN
    PutIns(op DIV C16 + rn);
    PutIns(op MOD C16 + ORD(list) MOD C12 + ORD(list) DIV C12 * C14)
  END PutLSM;

  PROCEDURE CheckRegs*;
  BEGIN
    IF RH # 0 THEN ORS.Raise("Reg Stack"); RH := 0 END ;
    IF pc >= maxCode - 40 THEN ORS.Raise("program too long") END ;
    IF frame # 0 THEN ORS.Raise("frame error"); frame := 0 END
  END CheckRegs;

  PROCEDURE SetCC(VAR x: Item; n: INTEGER);
  BEGIN x.mode := Cond; x.a := 0; x.b := 0; x.r := n
  END SetCC;

  PROCEDURE negated(cond: INTEGER): INTEGER;
  BEGIN
    cond := cond + 1 - (cond MOD 2) * 2
    RETURN cond
  END negated;

  PROCEDURE Trap(cond, num: INTEGER);
  VAR i, offset: INTEGER;
  BEGIN 
    i := ORS.Pos();
    PutMOVI(TR, i);
    offset := (7 - num - pc - dPC);
    IF (offset < -128) OR (offset > 127) THEN
      PutB32(i32_B_cond_imm21, cond, offset);
    ELSE
      PutB16(i16_B_cond_imm8, cond, offset);
    END; 
  END Trap;

  PROCEDURE NilCheck(r: INTEGER);
  BEGIN 
    IF check THEN
      IF r < 8 THEN PutI8(i16_CMP_imm8, r, 0); 
      ELSE PutI12(i32_CMP_exp12, 0, r, 0); 
      END;
      Trap(EQ, TrapNIL)
    END;
  END NilCheck;

  (*handling of forward reference, fixups of branch addresses and constant tables*)

  PROCEDURE fixcode(mno, pno : INTEGER);
  BEGIN
    IF pc - fixorgP >= 2000H THEN ORS.Raise("fixcode displacement") 
    ELSIF mno < - 0FFH THEN ORS.Raise("fixcode mno") 
    ELSIF (mno # 0 ) & (pno > 0FFH) THEN ORS.Raise("fixcode pno") 
    ELSE 
      PutIns( - mno * C8 + pno);
      PutIns(ORD(mno # 0) * C15 + (pc - fixorgP - 1));  (* TODO: Verify the offset calculation with the linker*)
      fixorgP := pc - 1;
    END
  END fixcode;

  PROCEDURE fixvar(mno, vno: INTEGER);
  BEGIN
    IF (pc - fixorgD >= 4000H) THEN ORS.Raise("fixvar displacement")
    ELSIF mno < -0FFH THEN ORS.Raise("fixvar mno")
    ELSIF (mno # 0) & (vno > 0FFH) THEN ORS.Raise("fixvar vno")
    ELSIF (vno > 0FFFFH) THEN ORS.Raise("fixvar vno > 64K")
    ELSE
      PutIns( - mno * C8 + vno);
      PutIns(ORD(mno # 0) * C15 + (pc - fixorgD - 1));  (* TODO: Verify the offset calculation with the linker*)
      fixorgD := pc - 1;
    END
  END fixvar;

  PROCEDURE fixI(at, with: INTEGER);
  BEGIN 
    IF (with < 0) OR (with > 255) THEN ORS.Raise("fixI out of range") END;
    PutAt(at, GetIns(at) DIV C8 * C8 + (with MOD C8))     (* fix imm for a 16 bits instruction *)
  END fixI;

  PROCEDURE fixB(at, with: INTEGER);
    VAR imm, ins: INTEGER;
  BEGIN
    imm := with - dPC;  (*PC is already advanced by 2 when the branch is executed*)
    ins := GetIns(at);
    PutAt(ins + ((imm DIV 20) MOD 2 - (ins DIV C10) MOD 2) * C10 + imm DIV C11 MOD C6 - ins MOD C6, at); 
    ins := GetIns(at+1);
    PutAt(ins + ((imm DIV 18) MOD 2 - (ins DIV C13) MOD 2) * C13 + ((imm DIV C19) MOD 2 - (ins DIV C11) MOD 2) * C11 + imm MOD C11 - ins MOD C11, at+1);
  END fixB;

  PROCEDURE FixOne*(at: INTEGER);
  BEGIN fixB(at, pc-at)
  END FixOne;

  PROCEDURE FixLinkWith(L, dst: INTEGER);
    VAR L1: INTEGER;
  BEGIN (* fix chain of branch instructions *)
    WHILE L # 0 DO
      L1 := DecodeB32(GetIns(L), GetIns(L+1));  (* decode the next addr in the chain *)
      fixB(L, dst - L);                         (* fix the actual branch *)
      L := L1;
    END
  END FixLinkWith;

  PROCEDURE FixLinkPair(L, adr: INTEGER);
    VAR q1, q2: INTEGER;
  BEGIN (*fix chain of instruction, 0 <= adr <= C16*)
    IF adr >= C16 THEN ORS.Raise("FixLinkPair") END;
    WHILE L # 0 DO q1 := GetIns(L); q2 := GetIns(L+1);
      PutAt(adr, L);
      PutAt(q2, L+1);
      L := q1
    END
  END FixLinkPair;

  PROCEDURE FixLink*(L: INTEGER);
  BEGIN FixLinkWith(L, pc)
  END FixLink;
  
  (* merge of AND & OR chains *)
  PROCEDURE merged(L0, L1: INTEGER): INTEGER;
    VAR L2, L3, L4, ins: INTEGER;
  BEGIN 
    IF L0 # 0 THEN L3 := L0;
      REPEAT 
        L2 := L3; 
        L3 := GetIns(L2);
        L4 := GetIns(L2 + 1);
        L3 := DecodeB32(L3, L4);
      UNTIL L3 = 0;
      (*  replace the immediate value in the 32 bits Branch *)
      ins := GetIns(L2);
      PutAt(ins + ((L3 DIV 20) MOD 2 - (ins DIV 10) MOD 2) * C10 + L3 MOD C6 - ins MOD C6, L2);
      ins := GetIns(L2 + 1);
      PutAt(ins + ((L3 DIV 18) MOD 2 - (ins DIV 13) MOD 2) * C13 + ((L3 DIV 19) MOD 2 - (ins DIV 11) MOD 2) * C11 + L3 MOD C11 - ins MOD C11  , L2+1);
      L1 := L0;
    END ;
    RETURN L1
  END merged;

  (* loading of operands and addresses into registers *)

  PROCEDURE load(VAR x: Item);
    VAR op, c, c_high, i, j: INTEGER;
  BEGIN
    IF (x.type = ORB.realType) THEN
      IF (x.mode = Reg) THEN PutR32_1(i32_VMOVA, x.r, x.r, 0) END;
    END;
    IF x.mode # Reg THEN
      IF x.type.size = 1 THEN op := i32_LDRB_imm8_i ELSE op := i32_LDR_imm8_i END;
      IF x.mode = ORB.Const THEN
        IF x.type.form = ORB.Proc THEN
          IF x.r > 0 THEN (*local*) ORS.Raise("not allowed")
          ELSIF x.r = 0 THEN (*global*) 
            c := pc - x.a DIV 2 + dPC;
            IF c >= C12 THEN
              PutI12(i32_SUB_imm12, RH, PC, c MOD C12);  (* sub the lower part *)
              c_high := (c DIV C12) MOD C8;
              i := GetMSB(c_high);
              j := LSL(c_high, 7-i) MOD C7 + (20 + 7 - i - 1 )* C7;
              PutI12(i32_SUB_exp12, RH, RH, j);
            ELSE
              PutI12(i32_SUB_imm12, RH, PC, c);
            END;
          ELSE (*imported*) fixvar(x.r + 80H, x.a); PutI12(i32_MOVT, RH, 0, 0); 
          END
        ELSE PutMOVI(RH, x.a);
        END;
        x.r := RH; incR
      ELSIF x.mode = ORB.Var THEN
        IF x.r > 0 THEN (*local*) PutLS(op, RH, SP, x.a + frame)
        ELSE fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0); PutLS(op, RH, RH, 0)
        END ;
        x.r := RH; incR
      ELSIF x.mode = ORB.Par THEN 
        PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame); 
        PutLS(i32_LDR_imm8_i, RH, RH, x.b);
        x.r := RH; incR
      ELSIF x.mode = RegI THEN PutLS(op, x.r, x.r, x.a)
      ELSIF x.mode = Cond THEN 
        PutB32(i32_B_cond_imm21, negated(x.r), 3 - dPC); 
        FixLink(x.b); PutI8(i16_MOV_imm8, RH, 1); PutB16(i16_B_cond_imm8, AL, 2 - dPC);
        FixLink(x.a); PutI8(i16_MOV_imm8, RH, 0); x.r := RH; incR
      END;
    END;
  END load;

  PROCEDURE loadAdr(VAR x: Item);
  BEGIN
    IF x.mode = ORB.Var THEN
      IF x.r > 0 THEN (*local*) PutI32(i32_ADD_exp12, RH, SP, x.a + frame, i32_ADD_reg);
      ELSE fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0);
      END ;
      x.r := RH; incR
    ELSIF x.mode = ORB.Par THEN PutLS(i32_LDR_pc_imm12, RH, SP, x.a + frame);
      IF x.b # 0 THEN PutI32(i32_ADD_exp12, RH, RH, x.b, i32_ADD_reg) END ;
      x.r := RH; incR
    ELSIF x.mode = RegI THEN
      IF x.a # 0 THEN PutI32(i32_ADD_exp12, x.r, x.r, x.a, i32_ADD_reg) END
    ELSE ORS.Raise("address error")
    END ;
    x.mode := Reg
  END loadAdr;


  PROCEDURE loadf(VAR x: Item);
    CONST op = i32_VLDR;
  BEGIN
    IF (x.type # ORB.realType) THEN ORS.Raise("loadf 0") END;
    IF x.mode # Reg THEN
      IF x.mode = ORB.Const THEN
        IF x.type.form = ORB.Proc THEN ORS.Raise("loadf 1")
        ELSE PutMOVI(RH, x.a); PutR32_1(i32_VMOVV, RH, RH, 0);
        END;
        x.r := RH; incR
      ELSIF x.mode = ORB.Var THEN
        IF x.r > 0 THEN (*local*) PutVLS(op, RH, SP, x.a + frame)
        ELSE fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0); PutVLS(op, RH, RH, 0);
        END ;
        x.r := RH; incR
      ELSIF x.mode = ORB.Par THEN PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame); PutVLS(op, RH, RH, x.b); x.r := RH; incR
      ELSIF x.mode = RegI THEN PutVLS(op, x.r, x.r, x.a)
      ELSIF x.mode = Cond THEN ORS.Raise("loadf 2")
      END ;
    x.mode := Reg
    END;
  END loadf;

  PROCEDURE loadCond(VAR x: Item);
  BEGIN
    IF x.mode # Cond THEN 
      IF x.type.form = ORB.Bool THEN
        IF x.mode = ORB.Const THEN x.r := 15 - x.a
        ELSE load(x);
          PutI8(i16_CMP_imm8, x.r, 0);
          x.r := NE; DEC(RH)
        END ;
        x.mode := Cond; x.a := 0; x.b := 0
      ELSE ORS.Raise("not Boolean?")
      END
    END
  END loadCond;

  PROCEDURE loadTypTagAdr(T: ORB.Type);
  BEGIN 
    IF T.mno <= 0 THEN fixvar(0, T.len); T.len := pc - 1 (*insert fixorgD chain, fixed up in Close*)
    ELSE (*imported*) fixvar(- T.mno, 0);
    END;
    PutI16(i32_MOVT, RH, 0);
    incR;
  END loadTypTagAdr;

  PROCEDURE loadStringAdr(VAR x: Item);
  BEGIN
    IF x.r >= 0 THEN  fixvar(0, varx + x.a); 
    ELSE (*imported*) fixvar(- x.r, x.a);
    END;
    PutI16(i32_MOVT, RH, 0);
    x.mode := Reg; x.r := RH; incR
  END loadStringAdr;

  (* Items: Conversion from constants or from Objects on the Heap to Items on the Stack*)

  PROCEDURE MakeConstItem*(VAR x: Item; typ: ORB.Type; val: INTEGER);
  BEGIN x.mode := ORB.Const; x.type := typ; x.a := val
  END MakeConstItem;

  PROCEDURE MakeRealItem*(VAR x: Item; val: REAL);
  BEGIN x.mode := ORB.Const; x.type := ORB.realType; x.a := SYSTEM.VAL(INTEGER, val)
  END MakeRealItem;

  PROCEDURE MakeStringItem*(VAR x: Item; len: INTEGER); (*copies string from ORS-buffer to ORG-string array*)
    VAR i: INTEGER;
  BEGIN x.mode := ORB.Const; x.type := ORB.strType; x.a := strx; x.b := len; i := 0;
    IF strx + len + 4 < maxStrx THEN
      WHILE len > 0 DO str[strx] := ORS.str[i]; INC(strx); INC(i); DEC(len) END ;
      WHILE strx MOD 4 # 0 DO str[strx] := 0X; INC(strx) END
    ELSE ORS.Raise("too many strings")
    END
  END MakeStringItem;

  PROCEDURE MakeItem*(VAR x: Item; y: ORB.Object; curlev: INTEGER);
  BEGIN x.mode := y.class; x.type := y.type; x.a := y.val; x.rdo := y.rdo; x.obj := y;
    IF y.class = ORB.Par THEN x.b := 0
    ELSIF (y.class = ORB.Const) & (y.type.form = ORB.String) THEN x.b := y.lev;
    ELSE x.r := y.lev
    END ;
    IF (y.lev > 0) & (y.lev # curlev) & (y.class # ORB.Const) THEN ORS.Raise("not accessible") END
  END MakeItem;

  (* Code generation for Selectors, Variables, Constants *)

  PROCEDURE Field*(VAR x: Item; y: ORB.Object);   (* x := x.y *)
  BEGIN
    IF x.mode = ORB.Var THEN
      IF x.r >= 0 THEN x.a := x.a + y.val
      ELSE (*imported*) loadAdr(x); x.mode := RegI; x.a := y.val
      END
    ELSIF x.mode = RegI THEN x.a := x.a + y.val
    ELSIF x.mode = ORB.Par THEN x.b := x.b + y.val
    END
  END Field;

  PROCEDURE Index*(VAR x, y: Item);   (* x := x[y] *)
    VAR s, lim: INTEGER;
  BEGIN s := x.type.base.size; lim := x.type.len;
    IF (y.mode = ORB.Const) & (y.a < 0) THEN ORS.Raise("bad index") END;
    IF (y.mode = ORB.Const) & (lim >= 0) THEN
      IF y.a >= lim THEN ORS.Raise("bad index") END ;
      IF x.mode = ORB.Var THEN
        IF x.r >= 0 THEN x.a := y.a * s + x.a
        ELSE (*imported*) loadAdr(x); x.mode := RegI; x.a := y.a * s
        END
      ELSIF x.mode = RegI THEN x.a := y.a * s + x.a
      ELSIF x.mode = ORB.Par THEN x.b := y.a * s + x.b
      END
    ELSE load(y);
      IF check THEN  (*check array bounds*)
        IF lim >= 0 THEN PutI32(i32_CMP_exp12, 0, y.r, lim, i32_CMP_reg)
        ELSIF x.mode IN {ORB.Var, ORB.Par} THEN (*open array param*) PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame); PutR16(i16_CMP_reg, 0, y.r, RH)
        ELSIF x.mode = RegI THEN (*dynamic open array*) PutLS(i32_LDR_imm8_i, RH, x.r, -16); (*len*) PutR16(i16_CMP_imm8, 0, y.r, RH)
        ELSE ORS.Raise("error in Index")
        END ;
        Trap(GE, 1)  
      END ;
      (*TODO : continue modifications*)
      IF s = 4 THEN PutR32_2(i32_LSL_imm5, y.r, 0, y.r + LSL(2,7)) ELSIF s > 1 THEN PutMOVI(RH, s); PutR32_2(i32_MUL_reg, y.r, y.r, RH) END ;
      IF x.mode = ORB.Var THEN
        IF x.r > 0 THEN (*local*) PutR32_2(i32_ADD_reg, y.r, SP, y.r); INC(x.a, frame)
        ELSIF x.r = 0 THEN (*global*) fixvar(0, 0); PutI16(i32_MOVT, RH, 0); PutR32_2(i32_ADD_reg, y.r, y.r, RH)
        ELSE (*imported*) fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0); PutR32_2(i32_ADD_reg, y.r, y.r, RH);
          x.a := 0
        END ;
        x.r := y.r; x.mode := RegI
      ELSIF x.mode = ORB.Par THEN
        PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame);
        PutR32_2(i32_ADD_reg, y.r, RH, y.r); x.mode := RegI; x.r := y.r; x.a := x.b
      ELSIF x.mode = RegI THEN PutR32_2(i32_ADD_reg, x.r, x.r, y.r); DEC(RH)
      END
    END
  END Index;

  PROCEDURE DeRef*(VAR x: Item);
  BEGIN
    IF x.mode = ORB.Var THEN
      IF x.r > 0 THEN (*local*) PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame) 
      ELSE fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0); PutLS(i32_LDR_imm8_i, RH, RH, 0) END ;
      NilCheck(RH); x.r := RH; incR
    ELSIF x.mode = ORB.Par THEN
      PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame); PutLS(i32_LDR_imm8_i, RH, RH, x.b); NilCheck(RH); x.r := RH; incR
    ELSIF x.mode = RegI THEN PutLS(i32_LDR_imm8_i, x.r, x.r, x.a); NilCheck(x.r)
    ELSIF x.mode # Reg THEN ORS.Raise("bad mode in DeRef")
    END ;
    IF x.type.base.form = ORB.Array THEN PutI8(i16_ADDS_imm8, x.r, 16) END ; (*point to array*)
    x.mode := RegI; x.a := 0; x.b := 0
  END DeRef;

  (* PROCEDURE Method*(VAR x: Item; m: ORB.Object; super: BOOLEAN);
  BEGIN loadAdr(x); (receiver) x.super := super;
    IF super THEN x.a := y.val; (mthadr/exno) x.b := -y.type.mno
    ELSE x.a := y.lev (mthno) 
      IF x.deref THEN x.b := ORB.Var ELSE x.b := ORB.Par END
    END
  END Method; 
  *)

  PROCEDURE Q(T: ORB.Type; VAR tdw: INTEGER);
  BEGIN (*one entry of type descriptor extension table*)
    IF T.base # NIL THEN
      Q(T.base, tdw); td[tdw] := (T.mno*1000H + T.len) * 1000H + tdw - fixorgT;
      fixorgT := tdw; INC(tdw)
    END
  END Q;

  PROCEDURE FindRefFlds(typ: ORB.Type; off: INTEGER; VAR tdw: INTEGER);
    VAR fld: ORB.Object; i, s: INTEGER;
  BEGIN
    IF (typ.form = ORB.Pointer) OR (typ.form = ORB.NilTyp) THEN td[tdw] := off; INC(tdw)
    ELSIF typ.form = ORB.Record THEN
      fld := typ.dsc;
      WHILE fld # NIL DO FindRefFlds(fld.type, fld.val + off, tdw); fld := fld.next END
    ELSIF typ.form = ORB.Array THEN
      s := typ.base.size;
      FOR i := 0 TO typ.len-1 DO FindRefFlds(typ.base, i*s + off, tdw) END
    END
  END FindRefFlds;

  PROCEDURE BuildTD(T: ORB.Type; VAR tdw: INTEGER);
    VAR k, s: INTEGER; (* fld, bot: ORB.Object; t: ORB.Type; *)
  BEGIN 

    (* /(type descriptors of base types of T already built)
    k := ORB.NofMethods(T); td[tdw] := -k-1; INC(tdw); s := tdw;
    WHILE k > 0 DO td[tdw] := -1; INC(tdw); DEC(k) END ; 
    t := T; fld := NIL; (build method table)
    WHILE t # NIL DO fld := t.dsc;
      IF t.base # NIL THEN bot := t.base.dsc ELSE bot := NIL END ;
      WHILE fld # bot DO
        IF (fld.class = ORB.Const) & (td[tdw-fld.lev-1] = -1) & ((t.mno = 0) OR (fld.name[0] # 0X) )THEN 
          td[tdw-fld.lev-1] := (t.mno*C16 + fld.val ) * 400H 
          END ;
        fld := fld.next
      END ;
      t := t.base
    END ;
    FOR k := s TO tdw-1 DO /(insert displacement in ascending order)
      IF td[k] # -1 THEN td[k] := td[k] + k - fixorgM; fixorgM := k ELSE td[k] := 0 END 
    END ;
    *)

    s := T.size; (*convert size for heap allocation*)
    IF s <= 24 THEN s := 32 ELSIF s <= 56 THEN s := 64 ELSIF s <= 120 THEN s := 128
    ELSE s := (s+263) DIV 256 * 256
    END ;
    T.len := tdw*4; td[tdw] := s; INC(tdw);  (*len used as type descriptor offset in bytes relative to tdx*)
    k := T.nofpar;   (*extension level!*)
    IF k > 3 THEN ORS.Raise("ext level too large")
    ELSE Q(T, tdw);
      WHILE k < 3 DO td[tdw] := -1; INC(tdw); INC(k) END
    END ;
    FindRefFlds(T, 0, tdw); td[tdw] := -1; INC(tdw); 
    IF tdw >= maxTD THEN ORS.Raise("too many record types"); tdw := 0 END
  END BuildTD;

  PROCEDURE TypeTest*(VAR x: Item; T: ORB.Type; varpar, isguard: BOOLEAN);
    VAR pc0: INTEGER;
  BEGIN
    IF T = NIL THEN
      IF x.mode >= Reg THEN DEC(RH) END ;
      SetCC(x, 7)
    ELSE (*fetch tag into RH*)
      IF varpar THEN PutLS(i32_LDR_imm8_i, RH, SP, x.a+4+frame)
      ELSE load(x);
        pc0 := pc; PutB32(i32_B_cond_imm21, EQ, 0);  (*NIL belongs to every pointer type*)
        PutLS(i32_LDR_imm8_i, RH, x.r, -8)
      END ;
      PutLS(i32_LDR_imm8_i, RH, RH, T.nofpar*4); incR;
      loadTypTagAdr(T);  (*tag of T*)
      PutR32_2(i32_CMP_reg, 0, RH-1, RH-2); DEC(RH, 2);
      IF ~varpar THEN fixB(pc0, pc - pc0) END ;
      IF isguard THEN
        IF check THEN Trap(NE, 2) END
      ELSE SetCC(x, EQ);
        IF ~varpar THEN DEC(RH) END
      END
    END
  END TypeTest;

  (* Code generation for Boolean operators *)

  PROCEDURE Not*(VAR x: Item);   (* x := ~x *)
    VAR t: INTEGER;
  BEGIN loadCond(x); x.r := negated(x.r); t := x.a; x.a := x.b; x.b := t
  END Not;

  PROCEDURE And1*(VAR x: Item);   (* x := x & *)
  BEGIN loadCond(x); PutB32(i32_B_cond_imm21, negated(x.r), x.a); x.a := pc-1; FixLink(x.b); x.b := 0
  END And1;

  PROCEDURE And2*(VAR x, y: Item);
  BEGIN loadCond(y); x.a := merged(y.a, x.a); x.b := y.b; x.r := y.r
  END And2;

  PROCEDURE Or1*(VAR x: Item);   (* x := x OR *)
  BEGIN loadCond(x); PutB32(i32_B_cond_imm21, x.r, x.b);  x.b := pc-1; FixLink(x.a); x.a := 0
  END Or1;

  PROCEDURE Or2*(VAR x, y: Item);
  BEGIN loadCond(y); x.a := y.a; x.b := merged(y.b, x.b); x.r := y.r
  END Or2;

  (* Code generation for arithmetic operators *)

  PROCEDURE Neg*(VAR x: Item);   (* x := -x *)
  BEGIN
    IF x.type.form = ORB.Int THEN
      IF x.mode = ORB.Const THEN x.a := -x.a
      ELSE load(x); PutI12(i32_RSB_exp12, x.r, x.r, 0);
      END
    ELSIF x.type.form = ORB.Real THEN
      IF x.mode = ORB.Const THEN x.a := x.a + 7FFFFFFFH + 1
      ELSE load(x); PutR32_1(i32_VNEG, 0, x.r, x.r);
      END
    ELSE (*form = Set*)
      IF x.mode = ORB.Const THEN x.a := -x.a-1 
      ELSE load(x); PutR32_2(i32_MVN_reg, x.r, 0, x.r)
      END
    END
  END Neg;

  PROCEDURE AddOp*(op: INTEGER; VAR x, y: Item);   (* x := x +- y *)
  BEGIN
    IF op = ORS.plus THEN
      IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN x.a := x.a + y.a
      ELSIF y.mode = ORB.Const THEN load(x);
        IF y.a # 0 THEN PutI32(i32_ADD_exp12, x.r, x.r, y.a, i32_ADD_reg) END
      ELSE load(x); load(y); PutR32_2(i32_ADD_reg, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = ORS.minus*)
      IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN x.a := x.a - y.a
      ELSIF y.mode = ORB.Const THEN load(x);
        IF y.a # 0 THEN PutI32(i32_SUB_exp12, x.r, x.r, y.a, i32_SUB_reg) END
      ELSE load(x); load(y); PutR32_2(i32_SUB_reg, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    END
  END AddOp;

  PROCEDURE log2(m: INTEGER; VAR e: INTEGER): INTEGER;
  BEGIN e := 0;
    WHILE ~ODD(m) DO m := m DIV 2; INC(e) END ;
    RETURN m
  END log2;
  
  PROCEDURE MulOp*(VAR x, y: Item);   (* x := x * y *)
    VAR e: INTEGER;
  BEGIN
    IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN x.a := x.a * y.a
    ELSIF (y.mode = ORB.Const) & (y.a >= 1) & (log2(y.a, e) = 1) THEN load(x);
      IF e # 0 THEN PutR32_2(i32_LSL_imm5, x.r, 0, x.r + LSL(e MOD C2,6) + LSL(e DIV C2,12)) END
    ELSIF (x.mode = ORB.Const) & (x.a >= 1) & (log2(x.a, e) = 1)  THEN load(y); 
      IF e # 0 THEN PutR32_2(i32_LSL_imm5, x.r, 0, x.r + LSL(e MOD C2,6) + LSL(e DIV C2,12)) END; x.mode := Reg; x.r := y.r
    ELSE 
      IF (x.mode = ORB.Const) & (x.a = 0) THEN 
      ELSIF (y.mode = ORB.Const) & (y.a = 0) THEN x.mode := ORB.Const; x.a := 0;
      ELSE load(x); load(y); PutR32_2(i32_MUL_reg, RH-2, x.r, y.r); DEC(RH); x.r := RH-1 
      END
    END
  END MulOp;

  PROCEDURE DivOp*(op: INTEGER; VAR x, y: Item);   (* x := x op y *)
    VAR e: INTEGER; yc: BOOLEAN;
  BEGIN
    yc := y.mode = ORB.Const;
    IF op = ORS.div THEN
      IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
        IF y.a > 0 THEN x.a := x.a DIV y.a ELSE ORS.Raise("bad divisor") END
      ELSIF yc & (y.a >= 1) & (log2(y.a, e) = 1) THEN load(x); 
        IF e # 0 THEN PutR32_2(i32_ASR_imm5, x.r, 0, x.r + LSL(e MOD C2,6) + LSL(e DIV C2,12)) END
      ELSE
        IF yc & (y.a <= 0) THEN ORS.Raise("bad divisor")
        ELSE load(x); load(y);
          PutR32_2(i32_SUB_reg, RH, x.r, y.r + 64 + LSL(7,7) + LSL(24,12)); 
          PutR32_2(i32_SDIV_reg, RH, RH, y.r);
          IF ~yc & check THEN PutI8(i16_CMP_imm8, y.r, 0); Trap(LE, TrapDivZero) END;
          PutR32_2(i32_ADD_reg, RH-2, x.r, y.r + 64 + LSL(7,7) + LSL(24,12)); 
          DEC(RH); x.r := RH-1
        END;
      END
    ELSE (*op = ORS.mod*)
      IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
        IF y.a > 0 THEN x.a := x.a MOD y.a ELSE ORS.Raise("bad modulus") END
      ELSIF yc & (y.a >= 1) & (log2(y.a, e) = 1) THEN load(x);
        IF e = 0 THEN x.mode := ORB.Const; x.a := 0
        ELSE PutR32_2(i32_UBFX, x.r, x.r, e-1)
        END
      ELSE
        IF yc & (y.a <= 0) THEN ORS.Raise("bad modulus")
        ELSE load(x); load(y);
          PutR32_2(i32_SUB_reg, RH, x.r, y.r + 64 + LSL(7,7) + LSL(24,12)); 
          PutR32_2(i32_SDIV_reg, RH, RH, y.r);
          IF ~yc & check THEN PutI8(i16_CMP_imm8, y.r, 0); Trap(LE, TrapDivZero) END;
          PutR32_2(i32_ADD_reg, RH-1, RH, y.r + 64 + LSL(7,7) + LSL(24,12));
          PutMUL(i32_MLS_reg, RH-2, RH, y.r, x.r); 
          DEC(RH); x.r := RH-1
        END
      END
    END
  END DivOp;

  (* Code generation for REAL operators *)

  PROCEDURE RealOp*(op: INTEGER; VAR x, y: Item);   (* x := x op y *)
  BEGIN loadf(x); loadf(y);
    IF op = ORS.plus THEN PutR32_1(i32_VADD, x.r , RH-2, y.r)
    ELSIF op = ORS.minus THEN PutR32_1(i32_VSUB, x.r , RH-2, y.r)
    ELSIF op = ORS.times THEN PutR32_1(i32_VMUL, x.r , RH-2, y.r)
    ELSIF op = ORS.rdiv THEN PutR32_1(i32_VDIV, x.r , RH-2, y.r)
    END ;
    DEC(RH); x.r := RH-1
  END RealOp;

  (* Code generation for set operators *)

  PROCEDURE Singleton*(VAR x: Item);  (* x := {x} *)
  BEGIN
    IF x.mode = ORB.Const THEN x.a := LSL(1, x.a) 
    ELSE load(x); PutI8(i16_MOV_imm8, RH, 1); PutR32_2(i32_LSL_reg, x.r, RH, x.r)
    END
  END Singleton;

  PROCEDURE Set*(VAR x, y: Item);   (* x := {x .. y} *)
  BEGIN
    IF (x.mode = ORB.Const) & ( y.mode = ORB.Const) THEN
      IF x.a <= y.a THEN x.a := LSL(2, y.a) - LSL(1, x.a) ELSE x.a := 0 END
    ELSE
      IF (x.mode = ORB.Const) THEN x.a := LSL(1, x.a)
      ELSE load(x); PutI12(i32_MOV_exp12, RH, 0, 1); PutR32_2(i32_LSL_reg, x.r, RH, x.r); x.r := RH -1;
      END ;
      IF (y.mode = ORB.Const) THEN PutI12(i32_MOV_exp12, RH, 0, LSL(2, y.a)); y.mode := Reg; y.r := RH; incR
      ELSE load(y); PutI12(i32_MOV_exp12, RH, 0, 2); PutR32_2(i32_LSL_reg, y.r, RH, y.r)
      END ;
      IF x.mode = ORB.Const THEN PutI32(i32_ADD_exp12, RH-1, y.r, -x.a, i32_ADD_reg); x.mode := Reg;
      ELSE DEC(RH); PutR32_2(i32_SUB_reg, RH-1, x.r, y.r)
      END;
      x.r := RH-1;
    END
  END Set;

  PROCEDURE In*(VAR x, y: Item);  (* x := x IN y *)
  BEGIN load(y);
    IF x.mode = ORB.Const THEN PutR32_2(i32_RORS_imm5, y.r, 0, y.r +  LSL((x.a + 1) MOD maxSet MOD C2,6) + LSL((x.a + 1) MOD maxSet DIV C2,12)); DEC(RH)
    ELSE load(x); PutI12(i32_MOV_exp12, x.r, x.r, 1); PutR32_2(i32_RORS_reg, y.r, y.r, x.r); DEC(RH, 2)
    END ;
    SetCC(x, MI)
  END In;

  PROCEDURE SetOp*(op: INTEGER; VAR x, y: Item);   (* x := x op y *)
    VAR xset, yset: SET; (*x.type.form = Set*)
  BEGIN
    IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
      xset := SYSTEM.VAL(SET, x.a); yset := SYSTEM.VAL(SET, y.a);
      IF op = ORS.plus THEN xset := xset + yset
      ELSIF op = ORS.minus THEN xset := xset - yset
      ELSIF op = ORS.times THEN xset := xset * yset
      ELSIF op = ORS.rdiv THEN xset := xset / yset
      END ;
      x.a := SYSTEM.VAL(INTEGER, xset)
    ELSIF y.mode = ORB.Const THEN
      load(x);
      IF op = ORS.plus THEN PutI32(i32_ORR_exp12, x.r, x.r, y.a, i32_ORR_reg)
      ELSIF op = ORS.minus THEN PutI32(i32_BIC_exp12, x.r, x.r, y.a, i32_BIC_reg)
      ELSIF op = ORS.times THEN PutI32(i32_AND_exp12, x.r, x.r, y.a, i32_AND_reg)
      ELSIF op = ORS.rdiv THEN PutI32(i32_EOR_exp12, x.r, x.r, y.a, i32_EOR_reg)
      END ;
    ELSE load(x); load(y);
      IF op = ORS.plus THEN PutR32_2(i32_ORR_reg, RH-2, x.r, y.r)
      ELSIF op = ORS.minus THEN PutR32_2(i32_BIC_reg, RH-2, x.r, y.r)
      ELSIF op = ORS.times THEN PutR32_2(i32_AND_reg, RH-2, x.r, y.r)
      ELSIF op = ORS.rdiv THEN PutR32_2(i32_EOR_reg, RH-2, x.r, y.r)
      END ;
      DEC(RH); x.r := RH-1
    END 
  END SetOp;

  (* Code generation for relations *)

  PROCEDURE IntRelation*(op: INTEGER; VAR x, y: Item);   (* x := x < y *)
  VAR op2, op3: INTEGER;
  BEGIN
    IF (y.mode = ORB.Const) & (y.type.form # ORB.Proc) THEN
      IF y.a < 0 THEN op2 := i32_CMN_exp12; op3 := i32_CMN_reg; y.a := -y.a ELSE op2 := i32_CMP_exp12; op3 := i32_CMP_reg END ;
        load(x); PutI32(op2, 0, x.r, y.a, op3); DEC(RH);
    ELSE
      IF (x.mode = Cond) OR (y.mode = Cond) THEN ORS.Raise("not implemented") END ;
      load(x); load(y); PutR32_2(i32_CMP_reg, 0, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - ORS.eql])
  END IntRelation;

  PROCEDURE RealRelation*(op: INTEGER; VAR x, y: Item);   (* x := x < y *)
  BEGIN loadf(x);
    IF (y.mode = ORB.Const) & (y.a = 0) THEN PutR32_1(i32_VCMPZ, 0, x.r, 0); PutR32_1(i32_VMRS, 1, 15, 0); DEC(RH)
    ELSE loadf(y); PutR32_1(i32_VCMP, 0, x.r, y.r); PutR32_1(i32_VMRS, 1, 15, 0); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - ORS.eql])
  END RealRelation;

  PROCEDURE StringRelation*(op: INTEGER; VAR x, y: Item);   (* x := x < y *)
    (*x, y are char arrays or strings*)
  BEGIN
    IF x.type.form = ORB.String THEN loadStringAdr(x) ELSE loadAdr(x) END ;
    IF y.type.form = ORB.String THEN loadStringAdr(y) ELSE loadAdr(y) END ;
    PutLS(i32_LDRB_imm8_w, RH, x.r, 1); incR;
    PutLS(i32_LDRB_imm8_w, RH, y.r, 1); incR;
    PutR32_2(i32_CMP_reg, 0, RH-2, RH-1); PutB32(i32_B_cond_imm21, NE, 3 - dPC);  (*check offset*)
    PutI12(i32_CMP_exp12, 0, RH-2, 0); PutB32(i32_B_cond_imm21, NE, - 5 - dPC);  
    DEC(RH, 4); SetCC(x, relmap[op - ORS.eql])
  END StringRelation;

  (* Code generation of Assignments *)

  PROCEDURE StrToChar*(VAR x: Item);
  BEGIN x.type := ORB.charType; DEC(strx, 4); x.a := ORD(str[x.a])
  END StrToChar;

  PROCEDURE Store*(VAR x, y: Item); (* x := y *)
    VAR op: INTEGER;
  BEGIN  load(y);
    IF x.type.size = 1 THEN op := i32_STRB_imm8_i ELSE op := i32_STR_imm8_i END ;  (*carefull for the opcode used*)
    IF x.mode = ORB.Var THEN
      IF x.r > 0 THEN (*local*) PutLS(op, y.r, SP, x.a + frame)
      ELSE fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0); PutLS(op, y.r, RH, 0)
      END
    ELSIF x.mode = ORB.Par THEN PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame); PutLS(op, y.r, RH, x.b);
    ELSIF x.mode = RegI THEN PutLS(op, y.r, x.r, x.a); DEC(RH);
    ELSE ORS.Raise("bad mode in Store")
    END ;
    DEC(RH)
  END Store;

  PROCEDURE Storef(VAR x, y: Item); (* x := y*)
  CONST op = i32_VSTR;
  BEGIN loadf(y);
    IF x.type # ORB.realType THEN ORS.Raise("Storef 0") END;
    IF x.mode = ORB.Var THEN
      IF x.r > 0 THEN (*local*) PutVLS(op, y.r, SP, x.a + frame)
      ELSE fixvar(x.r, x.a); PutI16(i32_MOVT, RH, 0); PutVLS(op, y.r, RH, x.b);
      END;
    ELSIF x.mode = ORB.Par THEN PutLS(i32_LDR_imm8_i, RH, SP, x.a + frame); PutVLS(op, y.r, RH, x.b);
    ELSIF x.mode = RegI THEN PutVLS(op, y.r, x.r, x.a); DEC(RH);
    ELSE ORS.Raise("bad mode in Storef")
    END ;
    DEC(RH);
  END Storef;

  PROCEDURE StoreStruct*(VAR x, y: Item); (* x := y, frame = 0 *)
    VAR s, pc0: INTEGER;
  BEGIN loadAdr(x); loadAdr(y);
    IF(x.type.form = ORB.Array) & (x.type.len > 0) THEN 
      IF y.type.len >= 0 THEN
        IF x.type.size = y.type.size THEN PutMOVI(RH, (y.type.size+3) DIV 4)
        ELSE ORS.Raise("different lenght/size, not implemented")
        END
      ELSE (*y open array param of dynamic open array*)
        IF y.type.size > 0 THEN PutLS(i32_LDR_imm8_i, RH, SP, y.a+4); ELSE PutLS(i32_LDR_imm8_i, RH, y.r, -16) END ; (*len*)
        s := y.type.base.size; (*element size*)
        PutI12(i32_CMP_exp12, 0, RH, 0); pc0 := pc; PutB32(i32_B_cond_imm21, EQ, 0);
        IF s = 1 THEN 
          PutI12(i32_ADDS_exp12, RH, RH, 3); PutR32_2(i32_ASR_reg, RH, RH, 4);  
          PutR32_2(i32_ASR_imm5, RH, 0, RH + LSL(2 MOD C2,6) + LSL(2 DIV C2,12))
        ELSIF s # 4 THEN PutMOVI(RH+1, s); PutR32_2(i32_MUL_reg, RH, RH, RH+1);
        END;
        IF check THEN (*check array lengths*) incR;
          PutMOVI(RH, (x.type.size +3) DIV 4); PutR32_2(i32_CMP_reg, 0, RH-1, RH); Trap(GT, TrapCopyOV); DEC(RH)
        END;
        fixB(pc0, pc+4 - pc0)
      END
    ELSIF x.type.form = ORB.Record THEN PutMOVI(RH, x.type.size DIV 4)
    ELSE ORS.Raise("inadmissible assignment, not implemented")
    END ;
    incR;
    PutLS(i32_LDR_imm8_w, RH, y.r, 4); 
    PutI12(i32_SUBS_exp12, RH-1, RH-1, 1);  (*TODO : add setflags*)
    PutLS(i32_STR_imm8_w, RH, x.r, 4); 
    PutB32(i32_B_cond_imm21, GT, -3 - dPC);
    RH := 0
  END StoreStruct;

  PROCEDURE CopyString*(VAR x, y: Item);  (* x := y, frame = 0 *) 
     VAR len: INTEGER;
   BEGIN loadAdr(x); len := x.type.len;
    IF len >= 0 THEN
      IF len <  y.b THEN ORS.Raise("string too long") END
    ELSIF check THEN  (*open array param or dynamic open array *)
      IF x.type.size > 0 THEN PutLS(i32_LDR_imm8_i, RH, SP, x.a+4); ELSE PutLS(i32_LDR_imm8_i, RH, x.r, -16) END ; (*len*)
      PutI32(i32_CMP_exp12, 0, RH, y.b, i32_CMP_reg); Trap(LT, TrapCopyOV)
    END ;
    loadStringAdr(y);
    PutLS(i32_LDR_imm8_w, RH, y.r, 4); 
    PutLS(i32_STR_imm8_w, RH, x.r, 4);
    PutR32_2(i32_ASRS_imm5, RH, 0, RH + LSL(24 MOD C2,6) + LSL(24 DIV C2,12));
    PutB32(i32_B_cond_imm21, NE,  -3 - dPC);  RH := 0
   END CopyString;
  
  (* Code generation for parameters *)
  
  PROCEDURE OpenArrayParam*(VAR x: Item);
  BEGIN loadAdr(x);
    IF x.type.len >= 0 THEN PutMOVI(RH, x.type.len) 
    ELSIF x.type.size > 0 THEN (*open array param*) PutLS(i32_LDR_imm8_i, RH, SP, x.a+4) 
    ELSE (*dynamic open array*) PutLS(i32_LDR_imm8_i, RH, x.r, -16) (*len*)
    END ;
    incR
  END OpenArrayParam;

  PROCEDURE VarParam*(VAR x: Item; ftype: ORB.Type);
    VAR xmd: INTEGER;
  BEGIN xmd := x.mode; loadAdr(x);
    IF (ftype.form = ORB.Array) & (ftype.len < 0) THEN (*open array*)
      IF x.type.len >= 0 THEN PutMOVI(RH, x.type.len) 
      ELSIF x.type.size > 0 THEN (*open array param*) PutLS(i32_LDR_imm8_i, RH, SP, x.a+4+frame) 
      ELSE (*dynamic open array*) PutLS(i32_LDR_imm8_i, RH, x.r, -16) (*len*)
      END ;
      incR
    ELSIF ftype.form = ORB.Record THEN
      IF xmd = ORB.Par THEN PutLS(i32_LDR_imm8_i, RH, SP, x.a+4+frame); incR 
      ELSE loadTypTagAdr(x.type) 
      END
    END
  END VarParam;

  PROCEDURE ValueParam*(VAR x: Item);
  BEGIN load(x)
  END ValueParam;

  PROCEDURE StringParam*(VAR x: Item);
  BEGIN loadStringAdr(x); PutMOVI(RH, x.b); incR  (*len*)
  END StringParam;

  (* PROCEDURE ReceiverParam*(VAR x: Item; par : ORB.Object);
  BEGIN 
    IF x.r # RH THEN PutMOV16(RH, x.r) END ;
    incR;
    IF par.class = ORB.par THEN /(record) loadTypTagAdr(par.type);  /(type tag); 
    ELSIF ~x.deref THEN ORS.Raise("incompatible receiver");
    END;
  END ReceiverParam; *)

  (*For Statements*)

  PROCEDURE For0*(VAR x, y: Item);
  BEGIN load(y)
  END For0;

  PROCEDURE For1*(VAR x, y, z, w: Item; VAR L: INTEGER);
  BEGIN 
    IF z.mode = ORB.Const THEN PutI32(i32_CMP_exp12, 0, y.r, z.a, i32_CMP_reg)
    ELSE load(z); PutR32_2(i32_CMP_reg, 0, y.r, z.r); DEC(RH)
    END ;
    L := pc;
    IF w.a > 0 THEN PutB32(i32_B_cond_imm21, GT, 0)
    ELSIF w.a < 0 THEN PutB32(i32_B_cond_imm21, LT, 0)
    ELSE ORS.Raise("zero increment"); PutB32(i32_B_cond_imm21, MI, 0)
    END ;
    Store(x, y)
  END For1;

  PROCEDURE For2*(VAR x, y, w: Item);
  BEGIN load(x); DEC(RH); 
    IF w.a < 0 THEN PutI32(i32_SUBS_exp12, x.r, x.r, -w.a, i32_SUBS_reg);
    ELSE PutI32(i32_ADDS_exp12, x.r, x.r, w.a, i32_ADDS_reg);
    END
  END For2;

  (* Branches, procedure calls, procedure prolog and epilog *)

  PROCEDURE Here*(): INTEGER;
  BEGIN RETURN pc
  END Here;

  PROCEDURE FJump*(VAR L: INTEGER);
  BEGIN PutB32_2(i32_B_imm25, L); L := pc-1
  END FJump;

  PROCEDURE CFJump*(VAR x: Item);
  BEGIN loadCond(x);
    IF x.r # AL THEN 
      PutB32(i32_B_cond_imm21, negated(x.r), x.a); FixLink(x.b); x.a := pc-1
    END;
  END CFJump;

  PROCEDURE BJump*(L: INTEGER);
  BEGIN PutB32_2(i32_B_imm25, L-pc-dPC)
  END BJump;

  PROCEDURE CBJump*(VAR x: Item; L: INTEGER);
  BEGIN loadCond(x); PutB32(i32_B_cond_imm21, negated(x.r), L-pc-dPC); FixLink(x.b); FixLinkWith(x.a, L)
  END CBJump;

  PROCEDURE Fixup*(VAR x: Item);
  BEGIN FixLink(x.a)
  END Fixup;

  PROCEDURE SaveRegs(r: INTEGER);  (* R[0 .. r-1]*)
  BEGIN (*r > 0*) 
    DEC(frame, 4*r);
    PutLSM(i32_STMDB_w, SP, {0..r-1});
  END SaveRegs;

  PROCEDURE RestoreRegs(r: INTEGER); (*R[0 .. r-1]*)
  BEGIN (*r > 0*) 
    DEC(frame, 4*r);
    PutLSM(i32_LDMIA_w, SP, {0..r-1});
  END RestoreRegs;

  PROCEDURE PrepCall*(VAR x: Item; VAR r: INTEGER);
  BEGIN (*x.type.form = ORB.Proc*)
    IF x.mode > ORB.Par THEN load(x) END ;
    r := RH;
    IF RH > 0 THEN SaveRegs(RH); RH := 0 END
  END PrepCall;

  PROCEDURE Call*(VAR x: Item; r: INTEGER);
  BEGIN (*x.type.form = ORB.Proc*)
    IF x.mode = ORB.Const THEN
      IF x.r >= 0 THEN PutB32_2(i32_BL_imm25, (x.a DIV 4)-pc-dPC)
      ELSE (*imported*) fixcode(x.r, x.a);
      END
    ELSE (*installed procedure*)
      IF x.mode <= ORB.Par THEN load(x); DEC(RH)
      ELSE PutLS(i32_LDR_imm8_i, RH, SP, 0); PutI12(i32_ADD_imm12, SP, SP, 4); DEC(r); DEC(frame, 4)
      END ;
      IF check THEN PutI12(i32_CMP_exp12, 0, RH, 0); Trap(EQ, TrapIllProc) END ;
      PutIns(i16_BLX + RH * C3)
    END ;
    IF x.type.base.form = ORB.NoTyp THEN (*procedure*) RH := 0
    ELSE (*function*)
      IF r > 0 THEN PutMOV16(r, 0); RestoreRegs(r) END ;
      x.mode := Reg; x.r := r; RH := r+1
    END
  END Call;

  PROCEDURE Enter*(parblksize, locblksize: INTEGER; int: BOOLEAN);
    VAR off_high, i, j: INTEGER;
  BEGIN frame := 0;
    IF int THEN ORS.Raise("not implemented") END; (*procedure prolog*)
    IF locblksize >= 10000H THEN ORS.Raise("too many locals") END ;
    IF locblksize >= C8 THEN 
        off_high := locblksize DIV C8;
        i := GetMSB(off_high);
        j := LSL(off_high, 7-i) MOD C7 + (24 + 7 - i)* C7;
        PutI12(i32_SUB_exp12, SP, SP, j) 
    END; (*TODO : verify the instruction*)
    PutLS(i32_STR_imm8_w, RA, SP, -(locblksize MOD C8));
    IF parblksize > 4 THEN 
      PutI12(i32_ADD_exp12, SP, SP, 4); (*avance de 4 pour simuler STMIB*)
      PutLSM(i32_STMIA_i, SP, {0..(parblksize DIV 4 -2)});
      PutI12(i32_SUB_exp12, SP, SP, 4) (*replace SP*)
    END
  END Enter;

  PROCEDURE Return*(form: INTEGER; VAR x: Item; size: INTEGER; int: BOOLEAN);
  BEGIN
    IF int THEN ORS.Raise("not implemented") END;
    IF form # ORB.NoTyp THEN 
      IF x.type.form = ORB.Real THEN loadf(x) ELSE load(x) END ;
    END;
    IF size < 4096 THEN PutLS(i32_LDR_imm8_w, PC, SP, size);
    ELSE PutLS(i32_LDR_imm8_i, RA, SP, 0); PutI32(i32_ADD_exp12, SP, SP, size, i32_ADD_reg); PutIns(i16_BX + RA * C3)
    END ;
    RH := minR
  END Return;

    (* Case Statements *)

  PROCEDURE CaseHead*(VAR x: Item; VAR L0: INTEGER);
  BEGIN load(x);  (*value of case expression*)
    L0 := pc; PutI8(i16_CMP_imm8, x.r, 0);  (*higher bound, fixed up in CaseTail*)
    PutB32(i32_B_cond_imm21, HI, 0);  (* unsigned higher; branch to else, fixed up in CaseTail*)
    PutI12(i32_ADD_exp12, RH, x.r, 0);  (*nof words between BL instruction at L0+4 and jump table, fixed up in CaseTail*)
    PutR32_2(i32_ADD_reg, PC, PC, RH + LSL( 2, 6));
    DEC(RH)
  END CaseHead;

  PROCEDURE CaseTail*(L0, L1: INTEGER; n: INTEGER; VAR tab: ARRAY OF LabelRange);  (*L1 = label for else*)
    VAR i, j: INTEGER;
  BEGIN
    IF n > 0 THEN fixI(L0, tab[n-1].high ) (*higher bound*) ELSIF L1 = 0 THEN ORS.Raise("empty case") END ;
    IF L1 = 0 THEN L1 := pc; Trap(AL, TrapArray) END ;  (*create else*)
    fixB(L0+1, L1-L0 - 1);  (*branch to else*)
    fixI(L0+2, pc-L0 - 3 - dPC);  (*nof words between ADD PC instruction at L0+4 and jump table*)
    j := 0;
    FOR i := 0 TO n-1 DO  (*construct jump table*)
      WHILE j < tab[i].low DO BJump(L1); INC(j) END ;  (*else*)
      WHILE j <= tab[i].high DO BJump(tab[i].label); INC(j) END
    END
  END CaseTail;

  (* In-line code procedures*)

  PROCEDURE Increment*(upordown: INTEGER; VAR x, y: Item);
    VAR op, op2, zr, v: INTEGER;
  BEGIN (*frame = 0*)
    IF upordown = 0 THEN 
      op := i32_ADD_exp12;
      op2 := i32_ADD_reg
    ELSE 
      op := i32_SUB_exp12; 
      op2 := i32_SUB_reg
    END ;
    IF x.type = ORB.byteType THEN v := 400000H ELSE v := 0 END ;
    IF y.type.form = ORB.NoTyp THEN y.mode := ORB.Const; y.a := 1 END ;
    IF (x.mode = ORB.Var) & (x.r > 0) THEN
      zr := RH; PutLS(i32_LDR_imm8_i+v, zr, SP, x.a); incR;
      IF y.mode = ORB.Const THEN PutI32(op, zr, zr, y.a, op2) ELSE load(y); PutR32_2(op2, zr, zr, y.r); DEC(RH) END ;
      PutLS(i32_STR_imm8_i+v, zr, SP, x.a); DEC(RH)
    ELSE loadAdr(x); zr := RH; PutLS(i32_LDR_imm8_i+v, RH, x.r, 0); incR;
      IF y.mode = ORB.Const THEN PutI32(op, zr, zr, y.a, op2) ELSE load(y); PutR32_2(op2, zr, zr, y.r); DEC(RH) END ;
      PutLS(i32_STR_imm8_i+v, zr, x.r, 0); DEC(RH, 2)
    END
  END Increment;

  PROCEDURE Include*(inorex: INTEGER; VAR x, y: Item);
    VAR op, op2, zr: INTEGER;
  BEGIN loadAdr(x); zr := RH; PutLS(i32_LDR_imm8_i, RH, x.r, 0); incR;
    IF inorex = 0 THEN op := i32_ORR_exp12; op2 := i32_ORR_reg ELSE op := i32_BIC_exp12; op2 := i32_BIC_reg END ;
    IF y.mode = ORB.Const THEN PutI32(op, zr, zr, LSL(1, y.a),op2)
    ELSE load(y); PutI12(i32_MOV_exp12, RH, 0, 1); PutR32_2(i32_LSL_reg, y.r, RH, y.r); PutR32_2(op2, zr, zr, y.r); DEC(RH)
    END ;
    PutLS(i32_STR_imm8_i, zr, x.r, 0); DEC(RH, 2)
  END Include;

  PROCEDURE Assert*(VAR x: Item);
    VAR cond: INTEGER;
  BEGIN loadCond(x);
    IF x.a = 0 THEN cond := negated(x.r)
    ELSE PutB32(i32_B_cond_imm21, x.r, x.b); FixLink(x.a); x.b := pc-1; cond := AL
    END ;
    Trap(cond, TrapAssert); FixLink(x.b)
  END Assert; 

  (*More work to do*)
  PROCEDURE New*(VAR x: Item);
  BEGIN loadAdr(x); loadTypTagAdr(x.type.base); Trap(AL, 0); RH := minR
  END New;

  PROCEDURE Pack*(VAR x, y: Item);
    VAR z: Item;
  BEGIN z := x; load(x); load(y);
    PutR32_2(i32_LSL_imm5, y.r, 0, y.r + LSL(23 MOD C2,6) + LSL(23 DIV C2,12)); PutR32_2(i32_ADD_reg, x.r, x.r, y.r); DEC(RH); Store(z, x)
  END Pack;

  PROCEDURE Unpk*(VAR x, y: Item);
    VAR z, e0: Item;
  BEGIN  z := x; load(x); e0.mode := Reg; e0.r := RH; e0.type := ORB.intType;
    PutR32_2(i32_ASR_imm5, RH, 0, x.r + LSL(23 MOD C2,6) + LSL(23 DIV C2,12)); PutI12(i32_SUB_imm12, RH, RH, 127); Store(y, e0); incR;
    PutR32_2(i32_LSL_imm5, RH, 0, RH + LSL(23 MOD C2,6) + LSL(23 DIV C2,12)); PutR32_2(i32_SUB_reg, x.r, x.r, RH); Store(z, x)
  END Unpk;

  PROCEDURE Led*(VAR x: Item);
  BEGIN load(x); 
    PutI12(i32_MOV_exp12, RH, 0, 0); PutI12(i32_SUB_exp12, RH, RH, -60);
    PutLS(i32_STR_imm8_i, x.r, RH, 0); DEC(RH)
  END Led;

  PROCEDURE Get*(VAR x, y: Item);
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(y, x)
  END Get;

  PROCEDURE Put*(VAR x, y: Item);
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(x, y)
  END Put;

  PROCEDURE Copy*(VAR x, y, z: Item);
  BEGIN load(x); load(y);
    IF z.mode = ORB.Const THEN
      IF z.a > 0 THEN load(z) ELSE ORS.Raise("bad count") END
    ELSE load(z);
      PutI12(i32_CMP_exp12, 0, z.r, 0);
      IF check THEN Trap(LT, TrapCopyOV) END ;
      PutB32(i32_B_cond_imm21, NE, 5-dPC); 
    END ;
    PutLS(i32_LDR_imm8_w, RH, x.r, 4); 
    PutI12(i32_SUBS_exp12, z.r, z.r, 1); 
    PutLS(i32_STR_imm8_w, RH, y.r, 4); 
    PutB32(i32_B_cond_imm21, EQ, -3-dPC); DEC(RH, 3);
  END Copy;

  (* TODO *)
  PROCEDURE LDPSR*(VAR x: Item);
  BEGIN (*x.mode = Const*)  ORS.Raise("not implemented")
  END LDPSR;

  PROCEDURE LDREG*(VAR x, y: Item);
  BEGIN
    IF x.a = 15 THEN x.a := RA
    ELSIF x.a = 14 THEN x.a := SP
    ELSIF x.a = 13 THEN x.a := TR
    ELSIF x.a <= 0 THEN x.a := -x.a
    ELSE INC(x.a, minR)
    END ;
    IF y.mode = ORB.Const THEN PutMOVI(x.a, y.a)
    ELSE load(y); PutR32_2(i32_MOV_reg, x.a, 0, y.r); DEC(RH)
    END
  END LDREG;

  (*In-line code functions*)

  PROCEDURE Abs*(VAR x: Item);
  BEGIN
    IF x.mode = ORB.Const THEN x.a := ABS(x.a)
    ELSE load(x);
      IF x.type.form = ORB.Real THEN loadf(x); PutR32_1(i32_VABS, x.r, 0, x.r)
      ELSE load(x); PutI12(i32_CMP_exp12, 0, x.r, 0); PutIns(i16_IT + VS * C4 + 8H); PutI12(i32_RSB_exp12, x.r, x.r, 0);
      END
    END
  END Abs;

  PROCEDURE Odd*(VAR x: Item);
  BEGIN load(x); PutI12(i32_ANDS_exp12, x.r, x.r, 1); SetCC(x, NE); DEC(RH)
  END Odd;

  PROCEDURE Floor*(VAR x: Item);
  BEGIN loadf(x); PutR32_1(i32_VCVTM, 0, x.r, x.r); PutR32_1(i32_VMOVA, x.r, x.r, 0)
  END Floor;

  PROCEDURE Float*(VAR x: Item);
  BEGIN loadf(x); PutR32_1(i32_VMOVV, x.r, 0, x.r); PutR32_1(i32_VCVT_if_s, 0, x.r, x.r)
  END Float;

  (*TODO check if modif are usefull*)
  PROCEDURE Ord*(VAR x: Item);
  BEGIN
    IF x.mode IN {ORB.Var, ORB.Par, RegI, Cond} THEN load(x);
      IF (x.type.form = ORB.Pointer) OR (x.type.base.form = ORB.Array) THEN PutI12(i32_AND_exp12, x.r, x.r, 16) END
    ELSIF (x.mode = Reg) & (x.type = ORB.realType) THEN PutR32_1(i32_VMOVA, x.r, 0, x.r)
    END
  END Ord;

  (*TODO check if modif are usefull*)
  PROCEDURE Len*(VAR x: Item);
  BEGIN
    IF x.type.len >= 0 THEN
      IF x.mode = RegI THEN DEC(RH) END ;
      x.mode := ORB.Const; x.a := x.type.len
    ELSIF x.type.size > 0 THEN (*open array param*) 
      PutLS(i32_LDR_imm8_i, RH, SP, x.a + 4 + frame); x.mode := Reg; x.r := RH; incR
    ELSE (*dynamic open array*) PutLS(i32_LDR_imm8_i, RH, x.r, -16); x.mode := Reg;
    END 
  END Len;

  PROCEDURE Shift*(fct: INTEGER; VAR x, y: Item);
    VAR op, op2: INTEGER;
  BEGIN load(x);
    IF fct = 0 THEN op := i32_LSL_imm5; op2 := i32_LSL_reg
    ELSIF fct = 1 THEN op := i32_ASR_imm5; op2 := i32_ASR_reg
    ELSE op := i32_ROR_imm5; op2 := i32_ROR_reg
    END ;
    IF y.mode = ORB.Const THEN IF y.a#0 THEN PutR32_2(op, x.r, 0, x.r + LSL(y.a MOD C2,6) + LSL((y.a DIV C2) MOD C5,12)) END;
    ELSE load(y); PutR32_2(op2, RH-2, x.r, y.r); DEC(RH); x.r := RH-1;
    END
  END Shift;

  PROCEDURE ADC*(VAR x, y: Item);
  BEGIN load(x); load(y); PutR32_2(i32_ADC_reg, x.r, x.r, y.r); DEC(RH)
  END ADC;

  PROCEDURE SBC*(VAR x, y: Item);
  BEGIN load(x); load(y); PutR32_2(i32_SBC_reg, x.r, x.r, y.r); DEC(RH)
  END SBC;

  PROCEDURE UML*(VAR x, y: Item);
  BEGIN load(x); load(y); PutMUL(i32_UMUL_reg, 0, x.r, y.r, x.r); DEC(RH)
  END UML;

  PROCEDURE Bit*(VAR x, y: Item);
  BEGIN load(x); PutLS(i32_LDR_imm8_i, x.r, x.r, 0);
    IF y.mode = ORB.Const THEN PutR32_2(i32_RORS_imm5, x.r, 0, x.r + LSL(y.a+1, 7)); DEC(RH)
    ELSE load(y); PutI12(i32_ADD_exp12, y.r, y.r, 1); PutR32_2(i32_RORS_reg, x.r, y.r, x.r); DEC(RH, 2)
    END ;
    SetCC(x, MI)
  END Bit;

  PROCEDURE Register*(VAR x: Item);
  BEGIN (*x.mode = Const*)
    IF x.a = 15 THEN x.a := RA
    ELSIF x.a = 14 THEN x.a := SP
    ELSIF x.a = 13 THEN x.a := TR
    ELSIF x.a <= 0 THEN x.a := -x.a
    ELSE INC(x.a, minR)
    END ;
    (* TODO CHECK REG ORDER *)
    PutMOV16(RH, x.a MOD C4); x.mode := Reg; x.r := RH; incR
  END Register;

  (*TODO*)
  PROCEDURE H*(VAR x: Item);
  BEGIN (*x.mode = Const*)
    ORS.Raise("not implemented")
  END H;

  PROCEDURE Adr*(VAR x: Item);
  BEGIN 
    IF x.mode IN {ORB.Var, ORB.Par, RegI} THEN loadAdr(x)
    ELSIF (x.mode = ORB.Const) & (x.type.form = ORB.Proc) THEN load(x)
    ELSIF (x.mode = ORB.Const) & (x.type.form = ORB.String) THEN loadStringAdr(x)
    ELSE ORS.Raise("not addressable")
    END
  END Adr;

  PROCEDURE Condition*(VAR x: Item);
  BEGIN (*x.mode = Const*) SetCC(x, x.a)
  END Condition;

  PROCEDURE Open*(v: INTEGER);
    VAR i : INTEGER;
  BEGIN pc := 0; tdw := 0; strx := 0; RH := 0; check := v # 0;
      fixorgP := 0; fixorgD := 0; fixorgT := 0;
      FOR i := 0 TO 6 DO PutI32(i32_ADD_exp12, TR, TR, 10000H, i32_ADD_reg) END ;
      fixcode(-0FFH, 0FFH);
  END Open;

  PROCEDURE SetDataSize*(dc: INTEGER);
  BEGIN varx := dc
  END SetDataSize;

  PROCEDURE Header*;
  BEGIN entry := pc*4;
    PutLS(i32_STR_imm8_w, RA, SP, -4);
  END Header;

  PROCEDURE NofPtrs(typ: ORB.Type): INTEGER;
    VAR fld: ORB.Object; n: INTEGER;
  BEGIN
    IF (typ.form = ORB.Pointer) OR (typ.form = ORB.NilTyp) THEN n := 1
    ELSIF typ.form = ORB.Record THEN fld := typ.dsc; n := 0;
      WHILE fld # NIL DO n := NofPtrs(fld.type) + n; fld := fld.next END
    ELSIF typ.form = ORB.Array THEN n := NofPtrs(typ.base) * typ.len
    ELSE n := 0
    END ;
    RETURN n
  END NofPtrs;

  PROCEDURE FindPtrs(VAR R: Files.Rider; typ: ORB.Type; adr: INTEGER);
    VAR fld: ORB.Object; i, s: INTEGER;
  BEGIN
    IF (typ.form = ORB.Pointer) OR (typ.form = ORB.NilTyp) THEN Files.WriteInt(R, adr)
    ELSIF typ.form = ORB.Record THEN fld := typ.dsc;
      WHILE fld # NIL DO FindPtrs(R, fld.type, fld.val + adr); fld := fld.next END
    ELSIF typ.form = ORB.Array THEN s := typ.base.size;
      FOR i := 0 TO typ.len-1 DO FindPtrs(R, typ.base, i*s + adr) END
    END
  END FindPtrs;

  PROCEDURE Close*(VAR modid: ORS.Ident; key, nofent: INTEGER);
    VAR obj: ORB.Object;
      i, comsize, nofimps, nofptrs, size, tdx, fix: INTEGER;
      name: ORS.Ident;
      F: Files.File; R: Files.Rider;
      msg: ARRAY 32 OF CHAR;
  BEGIN  (*exit code*)
    obj := ORB.topScope.next; nofimps := 0; comsize := 4; nofptrs := 0; tdx := varx + strx;
    WHILE obj # NIL DO
      IF (obj.class = ORB.Mod) & (obj.dsc # ORB.system) THEN INC(nofimps) (*count imports*)
      ELSIF (obj.exno # 0) & (obj.class = ORB.Const) & (obj.type.form = ORB.Proc)
          & (obj.type.nofpar = 0) & (obj.type.base = ORB.noType) THEN i := 0; (*count commands*)
        WHILE obj.name[i] # 0X DO INC(i) END ;
        i := (i+4) DIV 4 * 4; INC(comsize, i+4)
      ELSIF obj.class = ORB.Var THEN INC(nofptrs, NofPtrs(obj.type))  (*count pointers*)
      ELSIF (obj.class = ORB.Typ) & (obj.type.form = ORB.Record) & (obj.type.typobj = obj) THEN (*build type descriptors*)
        fix := obj.type.len; (*heading o fixup chain of instructions pairs inserted into fixorgD chain in loadTypTagAdr*)
        BuildTD(obj.type, tdw); (*obj.len.len now used as TD offset in bytes relative to tdx*)
        IF fix > 0 THEN FixLinkPair(fix, tdx + obj.type.len) END (*fix chain of instructions pairs with TD adr*)
      END ;
      obj := obj.next
    END ;
    size := tdx + tdw*4 + comsize + (pc + nofimps + nofent + nofptrs + 2)*4;  (*varsize includes type descriptors*)
    
    ORB.MakeFileName(name, modid, appendix); (*write code file*)
    F := Files.New(name); Files.Set(R, F, 0); Files.WriteString(R, modid); Files.WriteInt(R, key); Files.WriteChar(R, version);
    Files.WriteInt(R, size);
    obj := ORB.topScope.next;
    WHILE (obj # NIL) & (obj.class = ORB.Mod) DO  (*imports*)
      IF obj.dsc # ORB.system THEN Files.WriteString(R, obj(ORB.Module).orgname); Files.WriteInt(R, obj.val) END ;
      obj := obj.next
    END ;
    Files.WriteChar(R, 0X);
    Files.WriteInt(R, varx);  (*variable space*)
    Files.WriteInt(R, strx);
    FOR i := 0 TO strx-1 DO Files.WriteChar(R, str[i]) END ;  (*strings*)
    Files.WriteInt(R, tdw*4);  (*code len*)
    FOR i := 0 TO tdw-1 DO Files.WriteInt(R, td[i]) END ; (*type descriptors*)
    Files.WriteInt(R, pc);
    (* Files.WriteChar(R, 0X); (*align to 4 bytes for test ONLY*) *)
    FOR i := 0 TO (pc-1) DIV 2 DO 
      Files.WriteInt(R, code[i]); 
      (* IntToStr(code[i], msg); ORS.Raise(msg);  (* DEBUG ONLY *) *)
    END ;  (*program*)
    obj := ORB.topScope.next;
    WHILE obj # NIL DO  (*commands*)
      IF (obj.exno # 0) & (obj.class = ORB.Const) & (obj.type.form = ORB.Proc) &
          (obj.type.nofpar = 0) & (obj.type.base = ORB.noType) THEN
        Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val)
      END ;
      obj := obj.next
    END ;
    Files.WriteChar(R, 0X);
    Files.WriteInt(R, nofent); Files.WriteInt(R, entry);
    obj := ORB.topScope.next;
    WHILE obj # NIL DO  (*entries*)
      IF obj.exno # 0 THEN
        IF obj.class = ORB.Const THEN
          IF obj.type.form = ORB.String THEN Files.WriteInt(R, varx + obj.val MOD C20); 
          ELSIF obj.type.form = ORB.Proc THEN Files.WriteInt(R, obj.val)
          END
        ELSIF obj.class = ORB.Typ THEN
          IF obj.type.form = ORB.Record THEN Files.WriteInt(R,  tdx + obj.type.len MOD C16)
          ELSIF (obj.type.form = ORB.Pointer) & ((obj.type.base.typobj = NIL) OR (obj.type.base.typobj.exno = 0)) THEN
            Files.WriteInt(R,  tdx + obj.type.base.len MOD C16)
          END
        ELSIF obj.class = ORB.Var THEN Files.WriteInt(R, obj.val)
        END
      END ;
      obj := obj.next
    END ;
    obj := ORB.topScope.next;
    WHILE obj # NIL DO  (*pointer variables*)
      IF obj.class = ORB.Var THEN FindPtrs(R, obj.type, obj.val) END ;
      obj := obj.next
    END ;
    Files.WriteInt(R, -1);
    Files.WriteInt(R, fixorgP*2); Files.WriteInt(R, fixorgD*2); Files.WriteInt(R, fixorgT);
    Files.WriteInt(R, entry);
    Files.WriteChar(R, "O"); Files.Register(F)
  END Close;

BEGIN relmap[0] := EQ; relmap[1] := NE; relmap[2] := LT; relmap[3] := LE; relmap[4] := GT; relmap[5] := GE;

  (* Test: write a simple instruction and create file *)
  Open(0);
  
  (* Test immediate operations *)
  PutI12(i32_ADD_exp12, 0, 1, 42);  (* ADD R0, R1, #42 *)
  PutI12(i32_SUB_exp12, 2, 3, 100);  (* SUB R2, R3, #100 *)
  PutI12(i32_AND_exp12, 4, 5, 255);  (* AND R4, R5, #255 *)
  PutI12(i32_ORR_exp12, 6, 7, 15);   (* ORR R6, R7, #15 *)
  PutI12(i32_EOR_exp12, 8, 9, 7);    (* EOR R8, R9, #7 *)
  PutI12(i32_RSB_exp12, 10, 11, 1);  (* RSB R10, R11, #1 *)

  (* Test 32-bit immediate operations *)
  PutI32(i32_ADD_exp12, 1, 2, 1000, i32_ADD_reg);  (* ADD R1, R2, #1000 *)
  PutI32(i32_SUB_exp12, 3, 4, 500, i32_SUB_reg);   (* SUB R3, R4, #500 *)

  (* Test 32-bit branch operations *)
  PutB32(i32_B_cond_imm21, GT, 100);  (* BGT label *)
  PutB32(i32_B_cond_imm21, LT, 50);   (* BLT label *)
  PutB32_2(i32_BL_imm25, 200);        (* BL label *)

  (* Test MOV operations *)
  PutMOV16(0, 1);  (* MOV R0, R1 *)
  PutMOVI(1, 42);  (* MOV R2, #42 *)
  PutMOVI(0, 42);  (* MOV R2, #42 *)
  PutMOVI(0, 256);  (* MOV R2, #256 *)

  (* Test 16-bit immediate operations *)
  PutI16(i32_MOVW, 0, 1234H);  (* MOVW R0, #12345 *)
  PutI16(i32_MOVT, 0, 5678H);  (* MOVT R0, #67890 *)

  (* Test load/store operations *)
  PutLS(i32_STR_imm8_i, 0, SP, -4);
  PutLS(i32_STR_imm8_w, 0, SP, -8);
  PutLS(i32_LDR_imm8_i, 0, SP, -12);
  PutLS(i32_LDR_imm8_w, 0, SP, -16);
  PutR32_1(i32_VMOVA, 1, 1, 0);
  PutR32_1(i32_VMOVV, 1, 1, 0);

  (* Test multiple load/store operations *)
  PutLSM(i32_LDMIA_w, SP, {0,1,2,3});  (* LDMIA SP!, {R0,R1,R2,R3} *)
  PutLSM(i32_STMDB_w, SP, {4,5,6});    (* STMDB SP!, {R4,R5,R6} *)

  (* Test vector load/store operations *)
  PutVLS(i32_VLDR, 0, SP, 8);   (*? VLDR S0, [SP, #8] *)
  PutVLS(i32_VSTR, 1, SP, 12);  (*? VSTR S1, [SP, #12] *)

  (* Test 32-bit arithmetic operations *)
  PutR32_2(i32_ADD_reg, 1, 2, 3);  (* ADD R1, R2, R3 *)
  PutR32_2(i32_SUB_reg, 4, 5, 6);  (* SUB R4, R5, R6 *)
  PutR32_2(i32_RORS_reg, 1, 2, 3); (* RORS R1, R2, R3 *)

  (* Test additional floating point operations *)
  PutR32_1(i32_VADD, 1 , 2, 3);
  PutR32_1(i32_VSUB, 4, 5, 6);  (* VSUB S10, S8, S12 *)
  PutR32_1(i32_VNEG, 0, 1, 2);  (* VNEG S3, S2 *)
  PutR32_1(i32_VABS, 0, 3, 4);  (* VABS S4, S3 *)
  PutR32_1(i32_VCMP, 0, 1, 0);  (* VCMP S2, S0 *)
  PutR32_1(i32_VCMPZ, 0, 2, 0); (* VCMPZ S4, #0 *)

  (* Test additional multiplication operations *)
  PutR32_2(i32_SDIV_reg, 0, 1, 2);  (* SDIV R0, R1, R2 *)
  PutR32_2(i32_UBFX, 3, 4, 8);      (* UBFX R3, R4, #8, #width *)

  (* Test ADC/SBC operations *)
  PutR32_2(i32_ADC_reg, 5, 6, 7);  (* ADC R5, R6, R7 *)
  PutR32_2(i32_SBC_reg, 8, 9, 10); (* SBC R8, R9, R10 *)


  PutIns(1234H);

  (* problematic sequence*)
  PutR32_2(i32_ADD_reg, 1, 2, 3);  (* Add 1 to R0 *)
  PutMOVI(0, 42);  (* Move immediate value 42 to register R0 *)
  PutMOVI(0, 256);  (* Move immediate value 256 to register R0 *)
  PutMOV16(11, 15);
  PutR32_2(i32_SUB_reg, 1, 2, 3);  (* Subtract 1 from R0 *)
  PutR32_2(i32_RORS_reg, 1, 2, 3);  (* RORS *)

  (*fix B Test*)
  PutB32(i32_B_cond_imm21, NE, 0);
  fixB(pc-2, 4);
  
  PutR32_1(i32_VCVTM, 0, 1, 2);
  PutR32_1(i32_VCVT_if_s, 0, 3, 4);

  PutR32_2(i32_MUL_reg, 0, 1, 2);
  PutMUL(i32_MLS_reg, 1, 2, 3, 4); 
  PutMUL(i32_UMUL_reg,5, 6, 7, 8);

  modid := "Test";
  Close(modid, 0, 0)

END ORG.