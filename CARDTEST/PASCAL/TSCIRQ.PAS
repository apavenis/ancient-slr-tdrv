Unit	TSCIRQ;

{$F+}
{$N+}

Interface

  Uses  TscCard , RdTime , Dos , Crt , Utils;

  Const
        IrqFrequency  = 200;
        IrqNum	      = 15;

  Var
  	IrqTime		:LongInt;
        IrqCount	:LongInt;

        LaserTriggering :Boolean;


  Function  IsIrq : Boolean;
  Procedure SetDist ( dist:Double ; wWidth:Double );


Implementation

  Const
  	WindowStep    = 1600;

  Var
  	IrqFound	:WORD;
        OldVect		:Pointer;
        Cnt		:Integer;

        IRQC2		:Boolean;
        IntNum		:Integer;	{ Number of actual interrupt for CPU }
	PrevIRQMask	:Byte;
        IrqMaskPort     :Word;

        PrevExitProc	:Pointer;


  Function  IsIrq : Boolean;
    Var	tmp	:Word;
    Begin
       Asm
          xor	ax , ax
          xchg  ax , IrqFound;
          mov	Tmp , ax;
       End;
       if tmp=0 then IsIrq:=False else IsIrq:=True;
    End;


  Procedure  SetDist ( dist:Double ; wWidth:Double );
    Var   d	:LongInt;
    	  w	:Integer;
    Begin
       d := round (1000000.0*dist);
       w := round (wWidth*1000.0/WindowStep);
       if w<3 then w:=3;
       SetCCDelay (d);
       SetGate (d,w);
    End;


  Procedure  ClearTimerIRQ;
    Begin
      port [pClearIrqRequest] := 0;
    End;


  procedure  TimerIRQ ; Interrupt;
    Begin
      ClearTimerIrq;
      IrqFound := 1;
      IrqTime := ReadTime;
      Inc (IrqCount);

      if IRQC2 then port [$A0] := $20;
      port [$20] := $20;
      if Cnt<1 then begin sound(1000); Cnt:=IrqFrequency; End else nosound;
      if LaserTriggering Then
        Begin
          port [pEnableShoot] := 0;
        End;
      Dec(Cnt);
    End;



  Procedure  ReleaseIRQ;
    Begin
        ExitProc:=PrevExitProc;
        port [irqMaskPort] := PrevIRQMask;
        SetIntVec (IntNum,OldVect);
        Write ('Interrupt mask in port '); PrHexWord (IrqMaskPort);
        Write ('h restored to old value: '); PrBByte (PrevIRQMask);
        WriteLN;
        Nosound;
    End;



  Procedure  InitIRQ;
    Var  TimerDC	:Word;
    	 ifq		:Word;
    Begin

        IrqFound:=1;
        PrevExitProc:=ExitProc;
        ExitProc:=@ReleaseIRQ;
        IRQC2:=False;
        case (IrqNum And $FFF8) of
	  0: Begin;
	        IntNum:=$08+IrqNum;
		IRQC2:=False;
                IrqMaskPort:=$21;
	     End;
          8: Begin;
	        IntNum:=$70+(IrqNum And 7);
		IRQC2:=True;
		IrqMaskPort:=$A1;
	     End;
          Else Begin; WriteLN('Invalid interrupt specified'); Halt; End;
        End;

        ifq := IrqFrequency;
        if (ifq<10) Or (Ifq>10000) Then Begin
           WriteLN('Invalid interrupt frequency specified');
	   Halt; End;
        TimerDC := 625000 Div ifq;
        WriteI8253_C (pTimer,mTimer,TimerDC);
        port [pResetClockCounter] := 0;
        GetIntVec (IntNum,OldVect);
        SetIntVec (IntNum,@TimerIRQ);
	ClearTimerIRQ;
        PrevIRQMask := port [IrqMaskPort];
        port [irqMaskPort] := PrevIRQMask And Not ($01 Shl (IrqNum And 7));

        Write   ('IRQ ',IrqNum,' used (INT '); PrHexByte(IntNum); WriteLN('h)');

        Write   ('8253 divisor set to '); PrHexWord (TimerDC);
	WriteLN ('h. Interrupt frequency is ',ifq,' Hz');

        Write   ('Interrupt mask in port '); PrHexWord(IrqMaskPort);
        Write   ('h changed from '); PrBByte (PrevIRQMask);
        Write   (' to '); PrBByte (port[IrqMaskPort]); WriteLN;
    End;




Begin
  Cnt := 18;
  IrqFound := 0;
  LaserTriggering := True;
  InitIRQ;
End.