MODULE ORL;

  IMPORT SYSTEM, LibC, Files, Error, Err, Out;

  CONST MemSize = 1000000H;
        DescSize = 96; MnLenght = 32;
        BootSec = 2; BootSize = 192; FPrint = 12345678H;
        
        (* NXP Bare-metal Target Memory Alignment *)
        pbase = 0H; (* Base of Flash memory for Execute-In-Place (XIP) *)
        
        noerr* = 0;
        nofile* = 1; badversion* = 2; badkey* = 3; badfile* = 4; nospace* = 5;
        TrapAdr = 4;
        DestAdr = 8; MemAdr = 12; AllocAdr = 16; RootAdr = 20; StackAdr = 24; FPrintAdr = 28;
        ModAdr = 32;

        C3 = 8H; C4 = 10H; C6 = 40H; C8 = 100H; C10 = 400H; C11 =800H;
        C12 = 1000H; C13 = 2000H; C14 = 4000H; C15 = 4000H;
        C16 = 10000H; C21 = 200000H;
        C22 = 400000H; C23 = 800000H; C24 = 1000000H; C26 = 4000000H; C27 = 8000000H; C31 = 80000000H;
        i32_B = 0F0009000H; 
        i32_BL = 0F000D000H; 
        i32_MOVW = 0F2400000H;

        dPC = 2;
        AllocPtrInit = 0; (*start index for bin*)
        versionkey = 3;
        limit = 100000H;  (*TODO build it correctly*)


  TYPE Path = ARRAY 256 OF CHAR;
       Module* = POINTER TO ModDesc;
       Command* = INTEGER;  (*PROCEDURE adr*)
       ModuleName* = ARRAY MnLenght OF CHAR;
       ModDesc* = RECORD
         name: ModuleName;
         next*: Module;
         key*, num*, size*, refcnt*: INTEGER;
         var*, str*, tdx*, prg*, imp*, cmd*, ent*, ptr*, pvr*: INTEGER; (*addresses*)
         selected*, marked, hidden, sel: BOOLEAN;
         adr: INTEGER;
       END;

  VAR arg                   : Path;
      arg_num               : INTEGER;
      root : Module;
      AllocPtr, Reused, Start, (*limit,*) res*: INTEGER;
      importing*, imported*: ModuleName;
      appendix : ARRAY 5 OF CHAR;
      bin : ARRAY 1000000 OF BYTE;


  PROCEDURE err(str : ARRAY OF CHAR);
  BEGIN
    Err.String(str); Err.Ln();
  END err;

  PROCEDURE GetInt(index: INTEGER): INTEGER; (*rebuilt ins in order from bin*)
  BEGIN 
    RETURN  ROR(ORD(bin[index+3]) * C24 + ORD(bin[index+2]) * C16 + ORD(bin[index+1]) * C8 + ORD(bin[index]), 16)
  END GetInt;

  PROCEDURE GetInt2(index: INTEGER): INTEGER; (*rebuilt data/ins keeping bin order*)
  BEGIN 
    RETURN  ORD(bin[index+3]) * C24 + ORD(bin[index+2]) * C16 + ORD(bin[index+1]) * C8 + ORD(bin[index])  
  END GetInt2;

  PROCEDURE PutInt(index: INTEGER; value: INTEGER); (*32 bits little endian*)
  BEGIN 
    bin[index+3] := (value DIV C24) MOD C8;
    bin[index+2] := (value DIV C16) MOD C8;
    bin[index+1] := (value DIV C8) MOD C8;
    bin[index]  := value MOD C8
  END PutInt;

  PROCEDURE PutChar(index: INTEGER; chr : CHAR);
  BEGIN
    bin[index] := SYSTEM.VAL(BYTE, chr)
  END PutChar;

  PROCEDURE GetChar(index: INTEGER): CHAR;
  BEGIN
    RETURN SYSTEM.VAL(CHAR, bin[index])
  END GetChar;

  PROCEDURE GetByte(index: INTEGER): BYTE;
  BEGIN
    RETURN ORD(bin[index])
  END GetByte;

  PROCEDURE PutByte(index: INTEGER; b: BYTE);
  BEGIN
    bin[index] := b
  END PutByte;

  PROCEDURE MakeFileName(VAR Fname: ARRAY OF CHAR; Mname, appendix: ARRAY OF CHAR);
    VAR i,j: INTEGER;
  BEGIN i := 0; j := 0;
    WHILE (i < MnLenght - 5 ) & (Mname[i] > 0X) DO Fname[i] := Mname[i]; INC(i) END;
    REPEAT Fname[i] := appendix[j]; INC(i); INC(j) UNTIL appendix[j] = 0X;
    Fname[i] := 0X;
  END MakeFileName;

  PROCEDURE error(code: INTEGER; name: ARRAY OF CHAR);
  BEGIN res := code; importing := name
  END error;

  PROCEDURE CheckName(name: ARRAY OF CHAR; VAR slen: INTEGER);
    VAR i: INTEGER; ch: CHAR;
  BEGIN ch := name[0]; res := 1; i := 0; slen := 0;
    IF (ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") THEN
      REPEAT INC(i); ch := name[i] 
      UNTIL ~((ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") OR (ch >= "0") & (ch <= "9") OR (ch = ".")) OR (i >= MnLenght);
      IF ch = 0X THEN res := 0; slen := i+1 END
    END
  END CheckName;

	PROCEDURE ParseFileName(VAR filename: ARRAY OF CHAR; VAR name: ARRAY OF CHAR): BOOLEAN;
  VAR i,j,k : INTEGER;
    appendix : ARRAY 5 OF CHAR;
  BEGIN
    i := 0; j := 0;
    WHILE filename[i] # "." DO
      IF filename[i] = 0X THEN (* give an error if no extension *)
        Error.throw_error(); Err.String(filename); Err.String("Not a valid source file, no extension"); Err.Ln();
      ELSE
        name[i] := filename[i];
      END;
      INC(i);
    END;
    name[i] := 0X;
    CheckName(name, k);
    WHILE filename[i] > 0X DO
      appendix[j] := filename[i];
      INC(i); INC(j);
    END;
    appendix[j] := 0X;
    RETURN appendix = ".arm"
  END ParseFileName;

  PROCEDURE LinkOne(name: ARRAY OF CHAR; VAR newmod: Module; VAR R1: Files.Rider);
    VAR mod, impmod: Module;
      i, j, n, key, impkey, mno, nofimps, size: INTEGER;
      version, p, u, v, w, x: INTEGER; (*addresses*)
      ch: CHAR;
      body: Command;
      fixorgP, fixorgD, fixorgT: INTEGER;
      rd, disp, adr, inst, pno, vno, dest, offset, offset2, s, j1, j2: INTEGER;
      name1, impname: ModuleName;
      F: Files.File; R: Files.Rider;
      import: ARRAY 64 OF Module;
      impadr : INTEGER;
      msg : ARRAY 32 OF CHAR;

  BEGIN mod := root; error(noerr, name); nofimps := 0;
    err("t");
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END;
    IF mod = NIL THEN (*link*)
      CheckName(name, n);
      IF res = noerr THEN MakeFileName(name1, name, ".arm"); F := Files.Old(name1) ELSE F := NIL END;
      err(name1);
      IF F # NIL THEN
        Files.Set(R, F, 0); Files.ReadString(R, name1); Files.ReadInt(R, key); Files.ReadChar(R, ch);
        version := ORD(ch); 
        Files.ReadInt(R, size); importing := name1;
        IF (version = versionkey) (*regular module*) THEN 
          Files.ReadString(R, impname); (*imports*)
          err("t3"); err(impname);
          WHILE (impname[0] # 0X) & (res = noerr) DO
            Files.ReadInt(R, impkey); (*import key*)
            Err.Int(impkey, 10); Err.Ln();
            LinkOne(impname, impmod, R1); import[nofimps] := impmod; importing := name1;
            Err.String("impadr:"); Err.Int(import[nofimps].adr, 10); Err.Ln();
            IF res = noerr THEN
              IF impkey = impmod.key THEN INC(impmod.refcnt); INC(nofimps)
              ELSE error(badkey, name1); imported := impname;
              END
            END;
            Files.ReadString(R, impname)
          END;
          err("t4");
        ELSE error(badversion, name1)
        END
      ELSE error(nofile, name)  
      END;
      IF res = noerr THEN 
        INC(size, DescSize);
        IF AllocPtr + size < limit THEN (*allocate space*)
          p := AllocPtr; mod := NIL; NEW(mod); mod.adr := p;
          AllocPtr := (p + size + 3) DIV 4 * 4; mod.size := AllocPtr - p; u := Reused - Start + pbase;
          IF root = NIL THEN mod.num := 1 ELSE mod.num := root.num + 1 END;
          mod.next := root; root := mod
        ELSE error(nospace, name1)
        END
      END;
      err("t5");
      IF res = noerr THEN (*read file*)
        INC(p, DescSize); (*allocate descriptor*)
        mod.name := name; mod.key := key; mod.refcnt := 0; i := n;
        WHILE i < MnLenght DO mod.name[i] := 0X; INC(i) END;
        Err.String(mod.name); Err.Ln();
        mod.selected := FALSE; mod.hidden := FALSE; mod.marked := FALSE; mod.sel := FALSE;
        mod.var := p; Files.ReadInt(R,n);
        WHILE n > 0 DO PutInt(p, 0); INC(p, 4);  DEC(n, 4) END; (*variable space*)
        mod.str := p; Files.ReadInt(R,n); 
        err("t6");
        WHILE n > 0 DO Files.ReadChar(R, ch); PutChar(p, ch); INC(p); DEC(n) END; (*strings*)
        mod.tdx := p; Files.ReadInt(R,n); 
        err("t7");
        WHILE n > 0 DO Files.ReadInt(R, w); PutInt(p, w); INC(p,4); DEC(n, 4) END; (*type descriptors*)
        mod.prg := p; Files.ReadInt(R,n);
        err("t8");
        WHILE n > 0 DO Files.ReadInt(R, w); Err.Int(w, 10); Err.Ln(); PutInt(p, w); INC(p,4); DEC(n, 2); END; (*program code*)
        mod.imp := p; i := 0; 
        err("t9");
        Err.Int(nofimps, 10); Err.Ln();
        Err.Int(mod.imp, 10); Err.Ln();
        WHILE i < nofimps DO Err.Int(p, 10); Err.Ln(); PutInt(p, import[i].adr); INC(p,4); INC(i) END; (*copy imports*)
        mod.cmd := p; Files.ReadChar(R, ch);
        err("t10"); 
        WHILE ch # 0X DO (*commands*)
          REPEAT PutChar(p, ch); INC(p); Files.ReadChar(R, ch) UNTIL ch = 0X;
          REPEAT PutChar(p, 0X); INC(p) UNTIL p MOD 4 = 0; 
          Files.ReadInt(R,n); PutInt(p, n); INC(p, 4); Files.ReadChar(R, ch)
        END;
        err("t11");
        REPEAT PutChar(p, 0X); INC(p) UNTIL p MOD 4 = 0;
        mod.ent := p; Files.ReadInt(R,n); 
        WHILE n > 0 DO Files.ReadInt(R, w); PutInt(p, w); INC(p,4); DEC(n) END; (*entries*)
        mod.ptr := p; Files.ReadInt(R, w); 
        WHILE w >= 0 DO PutInt(p, mod.var + w + u); INC(p,4); Files.ReadInt(R, w) END; (*pointers refs*)
        PutInt(p, 0); INC(p,4); 
        mod.pvr := p; Files.ReadInt(R, w); Err.Int(w,10); Err.Ln();
        WHILE w >= 0 DO PutInt(p, mod.var + w + u); INC(p,4); Files.ReadInt(R, w) END; (*procedure variable refs*)
        PutInt(p, 0); INC(p,4); err("t12");
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
        Files.ReadInt(R, w); body := mod.prg + w + u; 
        Err.String("prg "); Err.Int(mod.prg, 10); Err.Ln();
        Err.Int(w, 10); Err.Ln();
        Err.Int(u, 10); Err.Ln();
        Files.ReadChar(R, ch);
        IF ch # "O" THEN mod := NIL; error(badfile, name) END
      END;
      IF res = noerr THEN (*fixup of BL*)
        adr := mod.prg + fixorgP; 
        Err.Int(mod.prg, 10); Err.Ln();
        WHILE adr # mod.prg DO
          Err.Int(adr,10); Err.Ln();
          inst := GetInt(adr);
          Err.Int(inst,10); Err.Ln();
          IF inst DIV C16 = -1 THEN dest := Start + TrapAdr;
          ELSE 
            mno := inst DIV C24 MOD 80H;
            pno := inst DIV C16 MOD 100H;
            Err.Int(mno, 5); Err.Ln();
            Err.Int(pno, 5); Err.Ln();
            impadr := GetInt2(mod.imp + (mno-1)*4);
            Err.Int(impadr, 10); Err.Ln();
            j := 0; impmod := NIL;
            WHILE (impadr # import[j].adr) & (j < nofimps) DO INC(j) END;
            IF impadr # import[j].adr THEN Err.String("Link error : import not found"); Err.Ln() END;
            impmod := import[j];
            dest := GetInt2(impmod.ent + pno * 4); dest := dest + impmod.prg + impmod.pvr;
          END;
          offset := dest - (adr + Reused);
          Err.Int(offset, 10); Err.Ln();
          offset2 := ((offset DIV 2) - dPC) MOD C24;
          Err.Int(offset2, 10); Err.Ln();
          s := offset2 DIV C23;
          Err.Int(s, 10); Err.Ln();
          j1 := ABS((1 - offset2 DIV C22 MOD 2) - s);
          j2 := ABS((1 - offset2 DIV C21 MOD 2) - s);
          Err.Int(j1, 10); Err.Ln();
          Err.Int(j2, 10); Err.Ln();
          PutInt(adr, ROR(i32_BL  + s * C26 + (offset2 DIV C11) MOD C10 * C16 + j1 * C13 + j2 * C11 + offset2 MOD C11, 16));
          adr := adr - inst MOD C15 * 2
        END;
        err("t13");  
        (*fixup of LDR/STR/ADD*)
        adr := mod.prg + fixorgD;
        WHILE adr # mod.prg DO
          Err.Int(adr,10); Err.Ln();
          inst := GetInt(adr); 
          mno := inst DIV C24 MOD 80H;
          dest := inst DIV C16 MOD C16;
          disp := inst MOD C15;
          IF ~ODD(inst DIV C15) THEN (*global*) INC(dest, mod.var + u);
          ELSE (*import *)
            impadr := GetInt2(mod.imp + (mno-1)*4);
            j := 0; impmod := NIL;
            WHILE (impadr # import[j].adr) & (j < nofimps) DO INC(j) END;
            IF impadr # import[j].adr THEN Err.String("Link error : import not found"); Err.Ln() END;
            impmod := import[j];
            vno := dest MOD 100H;
            dest := GetInt2(impmod.ent + vno * 4);
            IF inst < 0 THEN INC(dest, impmod.prg - Start + impmod.pvr) 
            ELSE INC(dest, impmod.var + impmod.pvr)
            END;
            INC(dest, pbase);
          END;
          Err.Int(mod.var,10); Err.Ln(); 
          Err.Int(dest,10); Err.Ln(); 
          inst := GetInt(adr + 4);
          PutInt(adr, ROR(i32_MOVW + (dest DIV C11 MOD 2) * C26 + (dest DIV C12 MOD C4) * C16 + 
          (dest DIV C8 MOD C3) * C12 + dest MOD C8 + (inst DIV C8 MOD C4) * C8, 16));
          PutInt(adr + 4, ROR(inst + (dest DIV C27 MOD C4) * C16 + (dest DIV C24 MOD C3) * C12 + 
          dest DIV C16 MOD C8,  16));
          adr := adr - disp * 2
        END;
        err("t14");  
        (*fixup of type descriptors*)
        adr := mod.tdx + fixorgT * 4;
        WHILE adr # mod.tdx DO
          inst := GetInt(adr);
          mno := inst DIV C24 MOD C6;
          vno := inst DIV C12 MOD C12;
          disp := inst MOD C12;
          IF mno = 0 THEN (*global*) inst := mod.tdx + u + vno
          ELSE (*import*)
            impadr := GetInt2(mod.imp + (mno-1)*4);
            j := 0; impmod := NIL;
            WHILE (impadr # import[j].adr) & (j < nofimps) DO INC(j) END;
            IF impadr # import[j].adr THEN Err.String("Link error : import not found"); Err.Ln() END;
            impmod := import[j];
            offset := GetInt2(impmod.ent + vno * 4); 
            inst := impmod.var - Start + pbase + impmod.pvr + offset
          END;
          PutInt(adr, inst); adr := adr - disp * 4
        END;
        err("t15");    
        PutInt(Start, body - pbase); (*module initialization body*)
        Err.Int(body-pbase, 10); Err.Ln();
        (*write module to boot file*)
        i := mod.adr; n := MnLenght;
        WHILE n > 0 DO Files.WriteChar(R1, mod.name[MnLenght-n]); INC(i); DEC(n) END; (*name*)
        IF mod.next # NIL THEN Files.WriteInt(R1, mod.next.adr - Start + pbase + mod.next.pvr) (*next*)
        ELSE Files.WriteInt(R1, 0) 
        END;
        Files.WriteInt(R1, mod.key); Files.WriteInt(R1, mod.num); 
        Files.WriteInt(R1, mod.size); Files.WriteInt(R1, mod.refcnt); 
        Files.WriteInt(R1, mod.var + u); Files.WriteInt(R1, mod.str + u); 
        Files.WriteInt(R1, mod.tdx + u); Files.WriteInt(R1, mod.prg + u);
        Files.WriteInt(R1, mod.imp + u); Files.WriteInt(R1, mod.cmd + u);
        Files.WriteInt(R1, mod.ent + u); Files.WriteInt(R1, mod.ptr + u); 
        Files.WriteInt(R1, mod.pvr + u); INC(i, 56);
        WHILE i < mod.imp DO
          w := GetInt2(i); Files.WriteInt(R1, w); INC(i, 4)  (*variables, strings, TD, program code*)
        END;
        WHILE i < mod.cmd DO
          w := GetInt2(i);
          j := 0; impmod := NIL;
          WHILE (w # import[j].adr) & (j < nofimps) DO INC(j) END;
          IF w # import[j].adr THEN Err.String("Link error : import not found"); Err.Ln() END;
          impmod := import[j];
          Files.WriteInt(R1, w - Start + pbase + impmod.pvr); INC(i, 4)  (*imports*)
        END;
        WHILE i < mod.ent DO
          w := GetInt2(i); Files.WriteInt(R1, w); INC(i, 4)  (*commands*)
        END;
        p := mod.var;
        WHILE i < mod.ptr DO
          w := GetInt2(i); Files.WriteInt(R1, w); PutInt(p, w); INC(i, 4); INC(p, 4)  (*copy entries to variable area*)
        END;
        mod.ent := mod.var;
        WHILE i < AllocPtr DO
          w := GetInt2(i); Files.WriteInt(R1, w); INC(i, 4)  (*pointers and procedure variable refs*)
        END;
        mod.pvr := Reused; INC(Reused, AllocPtr - p); AllocPtr := p; (*reuse module area after entries for the next module*)
        Err.Int(Reused, 10); Err.Ln();
      ELSIF res >= badkey THEN importing := name;
        WHILE nofimps > 0 DO DEC(nofimps); DEC(import[nofimps].refcnt) END
      END;
    END;
    newmod := mod
  END LinkOne;

  PROCEDURE Link(VAR filename: ARRAY OF CHAR);
    VAR i, x, s, j1, j2: INTEGER; 
      ch : CHAR;
      F: Files.File;
      R: Files.Rider;
      M: Module;
      name, name2: ModuleName;
	BEGIN res := -1; root := NIL; Start := AllocPtrInit; AllocPtr := Start + ModAdr; Reused := 0;
    IF ParseFileName(filename, name2) THEN
      MakeFileName(name, name2, ".bin");
      F := Files.New(name); Files.Set(R, F, 0);
      i := Start;
      err("t");
      WHILE i < AllocPtr DO PutInt(i, 0); Files.WriteInt(R, 0); INC(i, 4) END; (*place holders*)
      err("t2");
      LinkOne(name2, M, R);  (*link process*)
      IF res = noerr THEN M := root;
        WHILE M # NIL DO 
          Files.Set(R,F, M.adr - Start + pbase + M.pvr + 48); Files.WriteInt(R, M.refcnt); (*insert refcnt*)
          M := M.next
        END; 
        x := GetInt2(Start); (*adress of init body of topmodule relative to start*)
        x := (x DIV 2 - dPC) MOD C24;
        s := x DIV C23 MOD 2;
        j1 := ABS((1 - x DIV C22 MOD 2) - s);
        j2 := ABS((1 - x DIV C21 MOD 2) - s);
        Err.Int(x, 10); Err.Ln();
        Err.Int(j1, 10); Err.Ln();
        Err.Int(j2, 10); Err.Ln();
        PutInt(Start, ROR(i32_B + s * C26 + (x DIV C11) MOD C10 * C16 + j1 * C13 + j2 * C11 + x MOD C11, 16)); (*jump to start of program*)
        PutInt(Start + TrapAdr, 0); (*trap handler, overwritten by the inner core*)
        PutInt(Start + DestAdr, 0); (*destination address of the prelinked, executable binary*)
        PutInt(Start + MemAdr, 1000000H); (*limit of mem, overwritten by bootloader*)
        PutInt(Start + AllocAdr, AllocPtr + Reused - Start + pbase); (*address of the end of the module space loaded*)
        PutInt(Start + RootAdr, root.adr - Start + pbase + root.pvr); (*current root of the loaded modules*)
        PutInt(Start + StackAdr, 100000H); (*limit of module area, overwritten by the bootloader*)
        PutInt(Start + FPrintAdr, FPrint); (*fingerprint*)
        Files.Set(R, F, 0);  i := Start;
        WHILE i < Start + ModAdr DO x := GetInt2(i); Err.Int(x, 10); Err.Ln(); Files.WriteInt(R, x); INC(i, 4) END; (*insert boot parameters*)
        Files.Register(F)
      ELSE
        IF res = nofile THEN Err.String("Link error : module not found"); Err.Ln()
        ELSIF res = badversion THEN Err.String("Link error : bad version"); Err.Ln()
        ELSIF res = badkey THEN Err.String("Link error : imports with bad key :"); Err.String(imported); Err.Ln()
        ELSIF res = badfile THEN Err.String("Link error : corrupted obj file"); Err.Ln()
        ELSIF res = nospace THEN Err.String("Link error : not enough space"); Err.Ln()
        END
      END
    ELSE Err.String("Link error : invalid source file name"); Err.Ln() END
	END Link;


  PROCEDURE NXP_Header(VAR R: Files.Rider; imageLength: INTEGER);
  VAR 
    i: INTEGER;
    sp, pc: INTEGER;
    nmi, hardFault, memManage, busFault, usageFault: INTEGER;
    svCall, debugMonitor: INTEGER;
    imageType, extHeaderOffset, executionAddress: INTEGER;
  BEGIN 
    (* 1. Set up standard addresses based on your 0x100 code placement *)
    sp := 020040000H;           (* Top of SRAM for MCXN947 *)
    pc := 000000101H;           (* Code entry point at 0x100 + 1 for Thumb bit *)
    
    (* System exception stubs (Assuming they sit sequentially right after entry code) *)
    nmi        := 000000105H;   (* 0x104 + 1 *)
    hardFault  := 000000109H;   (* 0x108 + 1 *)
    memManage  := 00000010DH;   (* 0x10C + 1 *)
    busFault   := 00000010DH;   (* Map remaining faults to a generic loop stub *)
    usageFault := 00000010DH;
    
    svCall       := 00000010DH;
    debugMonitor := 00000010DH;

    (* Metadata Constants *)
    imageType        := 0;      (* 0 = Plain Execute-In-Place (XIP) *)
    extHeaderOffset  := 0;      (* No extended or CRC header *)
    executionAddress := 0;      (* Must be 0 for XIP images *)

    (* 2. Serialize the exact NXP Container Table layout (36 bytes total) *)
    (* Offset 00H *) Files.WriteInt(R, sp);
    (* Offset 04H *) Files.WriteInt(R, pc);
    
    (* Offset 08H to 1FH: Vector Table Entries Part 1 (24 bytes = 6 words) *)
    Files.WriteInt(R, nmi);
    Files.WriteInt(R, hardFault);
    Files.WriteInt(R, memManage);
    Files.WriteInt(R, busFault);
    Files.WriteInt(R, usageFault);
    Files.WriteInt(R, 0);       (* Reserved ARM Vector slot *)
    
    (* Offset 20H *) Files.WriteInt(R, imageLength);
    (* Offset 24H *) Files.WriteInt(R, imageType);
    (* Offset 28H *) Files.WriteInt(R, extHeaderOffset);
    
    (* Offset 2CH to 33H: Vector Table Entries Part 2 (8 bytes = 2 words) *)
    Files.WriteInt(R, svCall);
    Files.WriteInt(R, debugMonitor);
    
    (* Offset 34H *) Files.WriteInt(R, executionAddress);

    (* 3. Append the remaining core ARM vectors to complete the 0x40 boundary *)
    (* Offset 38H *) Files.WriteInt(R, 00000010DH); (* PendSV Vector *)
    (* Offset 3CH *) Files.WriteInt(R, 00000010DH); (* SysTick Vector *)

    (* 4. Optional: Pad from 0x40 to 0x100 with default peripheral vector stubs *)
    (* This fills the gap with 48 empty/stubbed pointers so code lands precisely at 0x100 *)
    FOR i := 0 TO 47 DO
      Files.WriteInt(R, 00000010DH) 
    END;

  END NXP_Header;

BEGIN
  arg_num := 1;
  LibC.getarg(arg_num, arg);

  IF arg # ""
  THEN Link(arg)
  ELSE Error.throw_error(); Err.String("No source file specified"); Err.Ln()
  END
END ORL.