Unit TscCard;

{$N+}
{$G+}

Interface

   Uses Crt, Dos;

   Const
        {------------------------------------------------------------------

        Ports used by telescope control card ( and also related constants).
        All these ports are write only unless otherwise written.

        ------------------------------------------------------------------}

        { Reset 5MHz until next full second strobe. Used for time
	  synchronization }

        pResetClockCounter      = $1A0;

        { Request laser triggering at the next timer interrupt }

        pEnableShoot            = $1A2;

        { Clears interrupt request. User must write something to this
          port before returning from interrupt processing }

        pClearIrqRequest        = $1A6;

        { Port where to write lower 4 bits of time gate delay }

        pGateLW                 = $1A8;

        { Port where to write various flags for telescope control card }
        { and the meaning of bits that can be used }

        pWrStatus               = $1AA;
        	wsMoveX			= $01;
		wsMoveY			= $02;
                wsSignX			= $04;
                wsSignY			= $08;
                wsEnableCG		= $10;
                wsEnableSG		= $20;

        { R/O port from which the user can read the status of full second
	  signal and the one of zero points (active value is 0 !!!) }

        pRdStatus		= $1AC;
                rsFullSecond		= $01;
                rsZeroX			= $02;
                rsZeroY			= $04;

        { Ports for accessing both 8253 timers }

        { Ports where to write divisions coefficients into }

        pDivCoeffX		= $1B0;
        pDivCoeffY		= $1B2;

        { Port for 3th channel of the timer to be used for window width }

        pWindow			= $1B4;

        { Port for commands for 1st timer }

        pCmdA			= $1B6;

        { Port for 1st channel of the 2nd timer to be used for delay
          of channel commutator }

        pCCDelay		= $1B8;

        { Port for 2nd channel of the 2nd timer to be used for timer }

        pTimer			= $1BA;

        { Port for 3th channel of the 2nd timer chip used for generating
          delay of time window }

        pGateH			= $1BC;

        { Port for commands for 2nd timer }

        pCmdB			= $1BE;

        {=================================================================}

        { Modes used for channels of timers }

        mDC			= 2;
        mCC			= 5;
        mTimer			= 2;
        mGateH			= 5;
        mWindow			= 1;

  Var	v_WrStat	:Byte;
  Var	DCX, DCY	:Word;
  Var	VX, VY		:Integer;

  Function  IsFullSecond :Boolean;
    { Returns TRUE is full second line is active }

  Function  IsZeroPointX :Boolean;
    { }

  Function  IsZeroPointY :Boolean;
    { }

  Procedure SetV (index:Integer ; nSteps:Word);
    { Sets speed for requested coordinate. The value of index must be
      1 for 1st coordinate and 2 forthe 2nd one }

  Procedure SetCCDelay (value: LongInt);
    { Sets delay of channel commutator. The value must be specified
      in nanoseconds. }

  Procedure SetGate (value :LongInt; width :Word);
    { Set delay and width of time window. The delay must be specified
      in nanoseconds and the width in units of 0.2 or 1.6 microseconds
      depending on the position of jumber on the card. The old version
      had the second step only }

  Procedure WriteI8253 ( address , value :Word );

  Procedure WriteI8253_C ( address:Word ; mode:Integer ; value:Word );


Implementation


  Procedure IODelay;
    Var  i:Integer;
    Begin
       for i:=1 to 10 do ;
    End;


  Procedure WriteI8253 ( address , value :Word );
    Begin
       IODelay;
       port [address] := value;
       IODelay;
       port [address] := value Shr 8;
    End;


  Procedure WriteI8253_C ( address:Word ; mode:Integer ; value:Word );
    Var   Command	:Byte;
          Base		:Word;
    Begin
    	Command := ((address And 6) Shl 5) + $0030 + ((mode And 7) Shl 1);
        Base    := address And $03F8;
        port [base+6] := Command;
        WriteI8253 (address, value);
    End;


  Function CheckRdStat (mask:Byte) :Boolean;
    Var   V	:Byte;
    Begin
        V := port [pRdStatus];
        if (V And mask)=0 Then CheckRdStat:=True else CheckRdStat:=False;
    End;


  Procedure UpdateStatus ( clrb , setb : Byte );
    Begin
        v_WrStat := (v_WrStat And Not ClrB) Or SetB;
        port [pWrStatus] := v_WrStat;
    End;


  Function IsFullSecond :Boolean;
    Begin
       IsFullSecond := CheckRdStat (rsFullSecond);
    End;


  Function IsZeroPointX :Boolean;
    Begin
       IsZeroPointX := CheckRdStat (rsZeroX);
    End;


  Function IsZeroPointY :Boolean;
    Begin
       IsZeroPointY := CheckRdStat (rsZeroY);
    End;


  Procedure SetV (index:Integer ; nSteps:Word);
    Var   SetB , ClrB , mMove , mSign	 :Byte;
          Addr :Word;
          D0 :LongInt;
          DC :^LongInt;
          V :^Integer;
    Begin
       case index of
         1: Begin mMove:=$01; Addr:=pDivCoeffX; DC:=@DCX; V:=@VX; End;
         2: Begin mMove:=$02; Addr:=pDivCoeffY; DC:=@DCY; V:=@VY; End;
         else Begin WriteLN ('SetV : 1st parameter must be 1 or 2'); Halt; end;
         End;
       mSign := mMove Shl 2;
       V^:=nSteps;
       if abs(nSteps)<20 then Begin UpdateStatus (mMove,0); Exit; End;
       if nSteps<0 then Begin SetB:=mSign+mMove; ClrB:=0; nSteps:=-nSteps; End
       		   else Begin SetB:=mMove; ClrB:=mSign; End;
       D0 := 1250000 Div nSteps;
       DC^ := D0;
       WriteI8253_C (Addr,mDC,DC^);
       UpdateStatus (ClrB,SetB);
    End;


  Procedure SetCCDelay ( value: LongInt );
    Var  ns 	:Word;
    Begin
       value := value Mod 100000000;
       if value<6400 then value:=6400;
       ns := (value+800) Div 1600;
       WriteI8253_C (pCCDelay,mCC,ns);
    End;


  Procedure SetGate ( value :LongInt; width :Word );
    Var   l,h		:Word;
    	  c		:LongInt;
    Begin
       WriteI8253_C (pWindow,mWindow,width);
       If value>200000000 Then value:=200000000;
       If value<10000 Then value:=10000;
       c := (value+100) Div 200;
       l := c Mod 16;
       h := c Div 16 + 1;
       port [pGateLW] := l;
       WriteI8253_C (pGateH,mGateH,h);
    End;

Begin
  v_WrStat := $00;
  DCX:=0;  DCY:=0;
  VX:=0;  VY:=0;
End.




