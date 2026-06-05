MODULE ORL;

  IMPORT SYSTEM, LibC, Files, Error, Err, Out, ORG;

  CONST MemSize = 1000000H;
        DescSize = 96; MnLenght = 32; BootSec = 2; BootSize = 192; FPrint = 12345678H;
        elfheader = 80H; pbase = 10000H + elfheader;
        noerr* = 0; nofile* = 1; badversion* = 2; badkey* = 3; badfile* = 4; nospace* = 5;
        TrapAdr = 4; DestAdr = 8; MemAdr = 12; AllocAdr = 16; RootAdr = 20; StackAdr = 24; FPrintAdr = 28; ModAdr = 32;

        C3 = 8H; C4 = 10H; C6 = 40H; C8 = 100H; C10 = 400H; C11 =800H; C12 = 1000H; C13 = 2000H; C14 = 4000H; C15 = 4000H;
        C16 = 10000H; C21 = 200000H; C22 = 400000H; C23 = 800000H; C24 = 1000000H; C26 = 4000000H;

        i32_B = 0F0009000H; 
        i32_BL = 0F000D000H; 
        i32_MOVW = 0F2400000H;

        dPC = 2;

        AllocPtrInit = 0H;

        versionkey = 3;

        limit = 100000H;  (*TODO build it correctly*)

  TYPE Path = ARRAY 256 OF CHAR;
       Module* = POINTER TO ModDesc;
       Command* = PROCEDURE;
       ModuleName* = ARRAY MnLenght OF CHAR;
       ModDesc* = RECORD
         name: ModuleName;
         next*: Module;
         key*, num*, size*, refcnt*: INTEGER;
         var*, str*, tdx*, prg*, imp*, cmd*, ent*, ptr*, pvr*: INTEGER; (*addresses*)
         selected*, marked, hidden, sel: BOOLEAN;
         final: Command;
       END;

  VAR arg                   : Path;
      arg_num               : INTEGER;
      root : Module;
      AllocPtr, Reused, Start, (*limit,*) res*: INTEGER;
      importing*, imported*: ModuleName;
      appendix : ARRAY 5 OF CHAR;
      bin : ARRAY 1000000 OF BYTE;

  PROCEDURE GetInt(index: INTEGER): INTEGER;
  BEGIN 
    RETURN ORD(bin[index]) * C12 + ORD(bin[index+1]) * C8 + ORD(bin[index+2]) * C4 + ORD(bin[index+3])
  END GetInt;

  PROCEDURE PutInt(index: INTEGER; value: INTEGER);
  BEGIN 
    bin[index] := SYSTEM.VAL(BYTE, (value DIV C12) MOD C4);
    bin[index+1] := SYSTEM.VAL(BYTE, (value DIV C8) MOD C4);
    bin[index+2] := SYSTEM.VAL(BYTE, (value DIV C4) MOD C4);
    bin[index+3]  := SYSTEM.VAL(BYTE, value MOD C4)
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
    RETURN bin[index]
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

  PROCEDURE WriteELF32( VAR R: Files.Rider; size: INTEGER);
  CONST a32EMachine = 40; a32EFlags = 5000400H; PHEntSize = 20H; ElfHdrSize = 34H;
  BEGIN
    Files.WriteInt(R, ((ORD("F")*100H+ORD("L"))*100H+ORD("E"))*100H + 7FH); 
    Files.WriteInt(R, 00010101H);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, a32EMachine*10000H+2);
    Files.WriteInt(R, 1);
    Files.WriteInt(R, pbase + 1); (*e_entry virtual adr to first start control*)
    Files.WriteInt(R, 40H);    (*e_phoff, program header's table's file offset*)

    Files.WriteInt(R, 0);     (*e_shoff, section header's table's file offset*)
    Files.WriteInt(R, a32EFlags); (*e_flags*)
    Files.WriteInt(R, PHEntSize*10000H+ElfHdrSize);    (*e_ehsize, ELF header's size in bytes*) (* e_phentsize, size of one entry in file's program header table*)
    Files.WriteInt(R, 40*10000H+1);     (*e_shentsize, section header entry size, was 40 *) (* e_phnum, number of entries in the program header table *)
    Files.WriteInt(R, 0);     (*e_shstrndx, e_shnum *)
    Files.WriteInt(R, 0);     (* 12 bytes padding needed *)
    Files.WriteInt(R, 0); 
    Files.WriteInt(R, 0); 

    (*Program Header Table*)
    Files.WriteInt(R, 1);     (*p_type, 1 for loadable segment*)
    Files.WriteInt(R, 0);     (*p_offset, offset from the beginning of the file to the first byte of the segment in the file*)
    Files.WriteInt(R, pbase - elfheader); (*p_vaddr, virtual address of the first byte in mem*)
    Files.WriteInt(R, 0);     (*p_paddr, physical address ignored*)
    Files.WriteInt(R, size + elfheader);  (*p_filesz, number of bytes in the file image of the segment*)
    Files.WriteInt(R, MemSize);
    Files.WriteInt(R, 7);     (*p_flags, PF_R + PF_W + PF_X , allow rwx*)
    Files.WriteInt(R, 10000H);(*p_align, page size*)

    Files.WriteInt(R, 0);     (*padding to elfheadersize*)
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
    Files.WriteInt(R, 0);
  END WriteELF32;

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
      i, n, key, impkey, mno, nofimps, size: INTEGER;
      version, p, u, v, w, x: INTEGER; (*addresses*)
      ch: CHAR;
      body: Command;
      fixorgP, fixorgD, fixorgT, fixorgM: INTEGER;
      rd, disp, adr, inst, pno, vno, dest, offset, offset2, s, j1, j2: INTEGER;
      name1, impname: ModuleName;
      F: Files.File; R: Files.Rider;
      import: ARRAY 64 OF Module;

  BEGIN mod := root; error(noerr, name); nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END;
    IF mod = NIL THEN (*link*)
      CheckName(name, n);
      IF res = noerr THEN MakeFileName(name1, name, ".arm"); F := Files.Old(name1) ELSE F := NIL END;
      IF F # NIL THEN
        Files.Set(R, F, 0);  Files.ReadString(R, name1); Files.ReadInt(R, key); Files.ReadChar(R, ch);
        version := ORD(ch); 
        Files.ReadInt(R, size); importing := name1;
        IF (version = versionkey) (*regular module*) THEN 
          Files.ReadString(R, impname); (*imports*)
          WHILE (impname[0] # 0X) & (res = noerr) DO
            Files.ReadInt(R, impkey); (*import key*)
            LinkOne(impname, impmod, R1); import[nofimps] := impmod; INC(nofimps);
            IF res = noerr THEN
              IF impkey = impmod.key THEN INC(impmod.refcnt); INC(nofimps)
              ELSE error(badkey, name1); imported := impname;
              END
            END;
            Files.ReadString(R, impname)
          END
        ELSE error(badversion, name1)
        END
      ELSE error(nofile, name)  
      END;
      IF res = noerr THEN 
        INC(size, DescSize);
        IF AllocPtr + size < limit THEN (*allocate space*)
          p := AllocPtr; mod := NIL; mod := SYSTEM.VAL2(Module, p); 
          AllocPtr := (p + size + 3) DIV 4 * 4; mod.size := AllocPtr - p; u := Reused - Start + pbase;
          IF root = NIL THEN mod.num := 1 ELSE mod.num := root.num + 1 END;
          mod.next := root; root := mod
        ELSE error(nospace, name1)
        END
      END;
      IF res = noerr THEN (*read file*)
        INC(p, DescSize); (*allocate descriptor*)
        mod.name := name; mod.key := key; mod.refcnt := 0; i := n;
        WHILE i < MnLenght DO mod.name[i] := 0X; INC(i) END;
        mod.selected := FALSE; mod.hidden := FALSE; mod.marked := FALSE; mod.sel := FALSE;
        mod.var := p; Files.ReadInt(R,n);
        WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 4);  DEC(n, 4) END; (*variable space*)
        mod.str := p; Files.ReadInt(R,n);
        WHILE n > 0 DO Files.ReadChar(R, ch); SYSTEM.PUT(p, ch); INC(p); DEC(n) END; (*strings*)
        mod.tdx := p; Files.ReadInt(R,n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p,4); DEC(n, 4) END; (*type descriptors*)
        mod.prg := p; Files.ReadInt(R,n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p,4); DEC(n) END; (*program code*)
        mod.imp := p; i := 0; 
        WHILE i < nofimps DO SYSTEM.PUT(p, import[i]); INC(p,4); INC(i) END; (*copy imports*)
        mod.cmd := p; Files.ReadChar(R, ch);
        WHILE ch # 0X DO (*commands*)
          REPEAT SYSTEM.PUT(p, ch); INC(p); Files.ReadChar(R, ch) UNTIL ch = 0X;
          REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 4 = 0; 
          Files.ReadInt(R,n); SYSTEM.PUT(p, n); INC(p, 4); Files.ReadChar(R, ch)
        END;
        REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 4 = 0;
        mod.ent := p; Files.ReadInt(R,n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p,4); DEC(n) END; (*entries*)
        mod.ptr := p; Files.ReadInt(R, w);
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.var + w + u); INC(p,4); Files.ReadInt(R, w) END; (*pointers refs*)
        SYSTEM.PUT(p, 0); INC(p,4);
        mod.pvr := p; Files.ReadInt(R, w);
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.var + w + u); INC(p,4); Files.ReadInt(R, w) END; (*procedure variable refs*)
        SYSTEM.PUT(p, 0); INC(p,4);
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); 
        Files.ReadInt(R, fixorgT); Files.ReadInt(R, fixorgM);
        Files.ReadInt(R, w); x := mod.prg + w + u;  body := NIL; body := SYSTEM.VAL2(Command, x); 
        Files.ReadInt(R, w);
        mod.final := NIL;
        IF w >= 0 THEN x := mod.prg + w + u; mod.final := SYSTEM.VAL2(Command, x) END; 
        Files.ReadChar(R, ch);
        IF ch # "0" THEN mod := NIL; error(badfile, name) END
      END;
      IF res = noerr THEN (*fixup of BL*)
        adr := mod.prg + fixorgP;
        WHILE adr # mod.prg DO
          SYSTEM.GET(adr, inst);
          IF inst DIV C16 = -1 THEN dest := Start + TrapAdr; 
          ELSE 
            mno := inst DIV C24 MOD 80H;
            pno := inst DIV C16 MOD 100H;
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            SYSTEM.GET(impmod.ent + pno * 4, dest); dest := dest + impmod.prg + impmod.pvr;
          END;
          offset := dest - (adr + Reused);
          offset2 := ((offset DIV 4) - dPC) MOD C24;
          s := offset2 DIV C23;
          j1 := ABS((1 - offset2 DIV C22 MOD 2) - s);
          j2 := ABS((1 - offset2 DIV C21 MOD 2) - s);
          SYSTEM.PUT(adr, i32_BL + s * C26 + (offset2 DIV C11) MOD C10 * C16 + j1 * C13 + j2 * C11 + offset2 MOD C11);
          adr := adr - inst MOD C15 * 2
        END;
        (*fixup of LDR/STR/ADD*)
        adr := mod.prg + fixorgD;
        WHILE adr # mod.prg DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV C24 MOD 80H;
          dest := inst DIV C16 MOD C16;
          disp := inst MOD C15;
          IF ~ODD(inst DIV C15) THEN (*global*) INC(dest, mod.var + u);
          ELSE (*import *)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            vno := dest MOD 100H;
            SYSTEM.GET(impmod.ent + vno * 4, dest);
            IF inst < 0 THEN INC(dest, impmod.prg - Start + impmod.pvr) 
            ELSE INC(dest, impmod.var + impmod.pvr)
            END;
            INC(dest, pbase);
          END;
          SYSTEM.GET(adr + 4, inst);
          SYSTEM.PUT(adr, i32_MOVW + (dest DIV C11 MOD 2) * C26 + (dest DIV C12 MOD C4) * C16 + (dest DIV C10 MOD C3) * C12 + dest MOD C8);
          adr := adr - disp * 2
        END;  
        (*fixup of type descriptors*)
        adr := mod.tdx + fixorgT * 4;
        WHILE adr # mod.tdx DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV C24 MOD C6;
          vno := inst DIV C12 MOD C12;
          disp := inst MOD C12;
          IF mno = 0 THEN (*global*) inst := mod.tdx + u + vno
          ELSE (*import*)
             SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
             SYSTEM.GET(impmod.ent + vno * 4, offset); 
             inst := impmod.var - Start + pbase + impmod.pvr + offset
          END;
          SYSTEM.PUT(adr, inst); adr := adr - disp * 4
        END;  
        (*fixup of method tables*)
        adr := mod.tdx + fixorgM * 4;
        WHILE adr # mod.tdx DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV C26 MOD C6;
          vno := inst DIV C10 MOD C16;
          disp := inst MOD C10;
          IF mno = 0 THEN (*global*) inst := mod.prg + u + vno
          ELSE (*import*)
             SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
             SYSTEM.GET(impmod.ent + vno * 4, offset); 
             inst := impmod.prg - Start + pbase + impmod.pvr + offset
          END;
          SYSTEM.PUT(adr, inst); adr := adr - disp * 4
        END;  
        SYSTEM.PUT(Start, SYSTEM.ADR(body) - pbase); (*module initialization body*)
        (*write module to boot file*)
        i := SYSTEM.VAL(INTEGER, mod); n := 8;
        WHILE n > 0 DO SYSTEM.GET(i, w); Files.WriteInt(R1, w); INC(i, 4); DEC(n) END; (*name*)
        IF mod.next # NIL THEN Files.WriteInt(R1, SYSTEM.VAL(INTEGER, mod.next) - Start + pbase + mod.next.pvr) (*next*)
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
          SYSTEM.GET(i, w); Files.WriteInt(R1, w); INC(i, 4)  (*variables, strings, TD, program code*)
        END;
        WHILE i < mod.cmd DO
          SYSTEM.GET(i, w); impmod := NIL; impmod := SYSTEM.VAL2(Module, w); Files.WriteInt(R1, w - Start + pbase + impmod.pvr); INC(i, 4)  (*imports*)
        END;
        WHILE i < mod.ent DO
          SYSTEM.GET(i, w); Files.WriteInt(R1, w); INC(i, 4)  (*commands*)
        END;
        p := mod.var;
        WHILE i < mod.ptr DO
          SYSTEM.GET(i, w); Files.WriteInt(R1, w); SYSTEM.PUT(p, w); INC(i, 4); INC(p, 4)  (*copy entries to variable area*)
        END;
        mod.ent := mod.var;
        WHILE i < AllocPtr DO
          SYSTEM.GET(i, w); Files.WriteInt(R1, w); INC(i, 4)  (*pointers and procedure variable refs*)
        END;
        mod.pvr := Reused; INC(Reused, AllocPtr - p); AllocPtr := p; (*reuse module area after entries for the next module*)
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
      MakeFileName(name, name2, ".elf");
      F := Files.New(name); Files.Set(R, F, 0);
      i := Start;
      WHILE i < AllocPtr DO SYSTEM.PUT(i, 0); Files.WriteInt(R, 0); INC(i, 4) END; (*place holders*)
      LinkOne(name2, M, R);  (*link process*)
      IF res = noerr THEN M := root;
        WHILE M # NIL DO 
          Files.Set(R,F,SYSTEM.VAL(INTEGER, M) - Start + pbase + M.pvr + 48 + elfheader); Files.WriteInt(R, M.refcnt); (*insert refcnt*)
          M := M.next
        END; 
        SYSTEM.GET(Start, x); (*adress of init body of topmodule relative to start*)
        x := x MOD C24;
        s := x DIV C23 MOD 2;
        j1 := ABS((1 - x DIV C22 MOD 2) - s);
        j2 := ABS((1 - x DIV C21 MOD 2) - s);
        SYSTEM.PUT(Start, i32_B + s * C26 + (x DIV C11) MOD C10 * C16 + j1 * C13 + j2 * C11 + x MOD C11); (*jump to start of program*)
        SYSTEM.PUT(Start + TrapAdr, 0); (*trap handler, overwritten by the inner core*)
        SYSTEM.PUT(Start + DestAdr, 0); (*destination address of the prelinked, executable binary*)
        SYSTEM.PUT(Start + MemAdr, 1000000H); (*limit of mem, overwritten by bootloader*)
        SYSTEM.PUT(Start + AllocAdr, AllocPtr + Reused - Start + pbase); (*address of the end of the module space loaded*)
        SYSTEM.PUT(Start + RootAdr, SYSTEM.VAL(INTEGER, root) - Start + pbase + root.pvr); (*current root of the loaded modules*)
        SYSTEM.PUT(Start + StackAdr, 100000H); (*limit of module area, overwritten by the bootloader*)
        SYSTEM.PUT(Start + FPrintAdr, FPrint); (*fingerprint*)
        Files.Set(R, F, 0);  i := Start;
        WriteELF32(R, AllocPtr + Reused - Start); (*write ELF header*)
        WHILE i < Start + ModAdr DO SYSTEM.GET(i, x); Files.WriteInt(R, x); INC(i, 4) END; (*insert boot parameters*)
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

BEGIN
  arg_num := 1;
  LibC.getarg(arg_num, arg);

  IF arg # ""
  THEN Link(arg)
  ELSE Error.throw_error(); Err.String("No source file specified"); Err.Ln()
  END
END ORL.