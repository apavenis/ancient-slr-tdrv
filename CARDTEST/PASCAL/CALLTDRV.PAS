Unit  CallTDRV;
{$F+}
{$A-}

Interface
  Uses  Dos;


  Var	DrvNKStat	:^Word;


  Function   r256 ( X : LongInt )                        : LongInt;

  {---------------------------------------------------------------------}
  { Function <DriverReady> returns TRUE when TDRV.EXE is ready to       }
  { receive new destination                                             }
  {---------------------------------------------------------------------}

  Function   DriverReady                                 : Boolean;

  {---------------------------------------------------------------------}
  { Function <IsStartCoord> returns TRUE is coordinate system is        }
  { defined with procedure <SetCurrrentCoord> (look below)              }
  {---------------------------------------------------------------------}

  Function   IsStartCoord                                : Boolean;

  {---------------------------------------------------------------------}
  { Functions <tdrvIsTimerIRQ> and <tdrvIsFullSecond> returns TRUE if   }
  { an timer interrupt has occurred or full second signal was active    }
  { at the last interrupt.                                              }
  {---------------------------------------------------------------------}

  Function   tdrvIsTimerIRQ 				 : Boolean;
  Function   tdrvIsFullSecond                            : Boolean;


  {---------------------------------------------------------------------}
  { SetNewDest : Sets new destination for TDRV.EXE                      }
  {---------------------------------------------------------------------}

  Procedure  SetNewDest  ( DestTime , DestX , DestY , DestRO : LongInt );

  Procedure  SetNewDestR ( DestTime , DestX , DestY , DestRO : LongInt ;
                           ClrX , ClrY : LongInt );

  Procedure  TdrvClearDest (cnt :Word);

  {---------------------------------------------------------------------}
  { Procedures and functions for manipulation with 0.1 sec. timer       }
  {   ResetTimer    : synchronizes timer to full second signal and sets }
  {                   it nearly equal to BIOS timer                     }
  {   GetTimeL      : Returns value of 0.1 sec. timer                   }
  {   IncrTimeL     : Adds specified value to 0.1 sec timer             }
  {   WaitTimerIrq  : Waits until first 0.1 sec. timer interrupt is     }
  {                   occured. Returns FALSE if no interrupts are found }
  {                   in 4*55.2 ms.                                     }
  {   WaitFullSecond: Waits for next free second. Returns FALSE is no   }
  {                   full second signal and 20 BIOS timer clicks       }
  {                   detected.                                         }
  {---------------------------------------------------------------------}

  Procedure  ResetTimer;
  Function   GetTimeL                                    : LongInt;
  Procedure  IncrTimeL ( tIncr : LongInt );
  Function   WaitTimerIrq                                : Boolean;
  Function   WaitFullSecond                              : Boolean;

  {---------------------------------------------------------------------}
  { Manipulation with TDRV.EXE options word                             }
  {---------------------------------------------------------------------}

  Const      D_TakeKb        = $0001;
  Const      D_TakeMouse     = $0002;
  Const      D_InstrCoord    = $0004;
  Const      D_UserRotation  = $0008;
  Const	     D_ConvCoord     = $0010;
  Const      D_UseJoystick   = $0020;

  Function   GetTrackingOptions                          : Word;
  Procedure  SetTrackingOptions ( NewOpt :Word );

  {---------------------------------------------------------------------}
  { Setting/quering numeric keypad sensitivity                          }
  {---------------------------------------------------------------------}

  Function   GetNumKbSensitivity                         : Word;
  Procedure  SetNumKbSensitivity ( NewVal :Word );

  {----------------------------------------------------------------------------}
  {  Setting/Quering max. allowed speed and acceleration                       }
  {----------------------------------------------------------------------------}

  Procedure  SetMaxSpeed ( NewVal : Word );
  Procedure  SetMaxAcc   ( NewVal : Word );
  Function   GetMaxSpeed                                  : Word;
  Function   GetMaxAcc                                    : Word;

  {------------------------------------------------------------------------}
  { SetCCStrobe : Set chanal commutator strobe without setting destination }
  {------------------------------------------------------------------------}

  Procedure  SetCCStrobe ( ccDelay : LongInt );

  {---------------------------------------------------------------------}
  { SetCurrentCoord : Sets current coordinates of telescope             }
  {---------------------------------------------------------------------}

  Procedure  SetCurrentCoord ( NewX , NewY : LongInt );

  {---------------------------------------------------------------------}
  { GetCurrPosition : Returns current position of telescope at the last }
  {                   0.1 second interrupt (And other information too)  }
  {---------------------------------------------------------------------}

  Type  CurrPosition = Record
                             t          : LongInt;
                             CurrX      : LongInt;
                             CurrVX     : LongInt;
                             CurrDX     : LongInt;
                             CurrY      : LongInt;
                             CurrVY     : LongInt;
                             CurrDY     : LongInt;
                       End;

  Procedure  GetCurrPosition ( Var Pos : CurrPosition );

  Procedure  StopTracking;

  {---------------------------------------------------------------------}
  { Setting/Quering coordinate limits                                   }
  {---------------------------------------------------------------------}

  Type DCoordLimits = Record
                            xMin , xMax         : LongInt;
                            yMin , yMax         : LongInt;
                      End;

  Procedure  GetCoordLimits ( Var CL :DCoordLimits );
  Procedure  SetCoordLimits ( Var CL :DCoordLimits );

  {---------------------------------------------------------------------}
  {  TDRV.EXE beep options                                              }
  {---------------------------------------------------------------------}

  Const      D_NoBeep          =  0;
  Const      D_BeepOnHSec      =  1;
  Const      D_BeepOnSSec      =  2;
  Const      D_BeepOnShoot     = 16;
  Const      D_BeepOnIRQ15     = 32;

  Type  DBeepOptions = Record
                          EventType     :Byte;
                          BeepLen       :Byte;
                          BeepFq        :Word;
                       End;

  Procedure GetBeepOptions ( Var b :DBeepOptions );
  Procedure SetBeepOptions (     b :DBeepOptions );

  {---------------------------------------------------------------------}
  { TDRVX laser control procedures and functions                        }
  {---------------------------------------------------------------------}

  Procedure TDRV_LaserEnable;
  Procedure TDRV_LaserDisable;
  Procedure TDRV_StartShooting;
  Procedure TDRV_SetLaserPeriod  ( NewPeriod :Word );
  Procedure TDRV_StartShootingAt ( StartTime :LongInt );
  Procedure TDRV_SetWindow       ( NewWindow :LongInt );
  Procedure TDRV_SetGateShift    ( NewShift  :LongInt );

  Function  TDRV_GetLaserStat                         :Boolean;
  Function  TDRV_GetLaserPeriod                       :Word;
  Function  TDRV_GetNextShootTime                     :LongInt;
  Function  TDRV_GetWindow                            :LongInt;
  Function  TDRV_GetGateShift                         :LongInt;

  {---------------------------------------------------------------------}
  { Global variables defined in unit <CallTDRV>                         }
  {---------------------------------------------------------------------}

  Var   TDRV_Found        :Boolean;

  Var   DriverStatus      :^Word;
                Const   S1_TimerIntDetected       = $8000;
                Const   S1_FullSecondDetected     = $4000;
                Const   S1_DriverReady            = $2000;
                Const   S1_IsStartCoord           = $0100;
                Const   S1_LaserDisable           = $0080;
                Const   S1_ManualTracking	  = $0040;
                Const   S1_mtModeChanged	  = $0020;
                Const   S1_isHardwareIRQ15	  = $0008;
                Const   S1_CtrlBreak              = $0004;
                Const   S1_MidnightFound          = $0002;
                Const   S1_SynchrOk               = $0001;

  Var   DriverStat2       :^Word;
                Const   S2_PrevDestOk             = $4000;
                Const   S2_IntervalDone           = $2000;
                Const   S2_OutputReady            = $1000;
                Const   S2_NewDestReady           = $0800;
                Const   S2_DrvWaiting             = $0400;
                Const   S2_ResetDriver            = $0200;
                Const   S2_FO_Enable              = $0100;
                Const   S2_DrvTracking		  = $0080;
                Const   S2_jsButton4		  = $0040;
                Const   S2_jsButton3		  = $0020;
                Const   S2_jsButton2		  = $0010;
                Const   S2_jsButton1		  = $0008;
                Const   S2_moCenterButtonDown     = $0004;
                Const   S2_moRightButtonDown      = $0002;
		Const   S2_moLeftButtonDown       = $0001;

  {---------------------------------------------------------------------}
  { Structures for tracking both coordinates                            }
  {---------------------------------------------------------------------}

  Type DriveCoord = Record
                       DC_Status        :Byte;
                       DC_Options       :Byte;
                       ErrorDef         :Word;
                       CurrX            :LongInt;
                       CurrV            :LongInt;
                       Residual         :LongInt;
                       PrevDest         :LongInt;
                       CurrDest         :LongInt;
                       DestSpeed        :LongInt;
                       DestAcc          :LongInt;
                       RsdlX            :LongInt;
                       d_RsdlX          :LongInt;
                       PrevRsdlX        :LongInt;
                       IncrX            :LongInt;
                       MinCoord         :LongInt;
                       MaxCoord         :LongInt;
                       iCount           :Word;
                       hrdwStat         :Byte;
                       DivCoeff		:Word;
                       Remainder	:Word;
                       c2Val		:Word;
                       nDestP		:Word;
                       PrevCnt          :Word;
                       TotalSteps       :LongInt;
		       DrvCorr		:LongInt;
		       StartShift	:LongInt;
                       CurrSteps	:Integer;
                       NextSteps	:Integer;
                       PrevHrdwStat	:Byte;
                       CntZeroVal	:Word;
                       StepCnt		:Word;
                       HistArg		:LongInt;
                       HistMin		:LongInt;
                       HistMax		:LongInt;
                       Signature	:Word;	{ Must be 23761 }
                    End;

   Var    Drv_X            : ^DriveCoord;
   Var    Drv_Y            : ^DriveCoord;

  {---------------------------------------------------------------------}
  { Structures for tracking distance                                    }
  {---------------------------------------------------------------------}

   Type DrvRO     = Record
                       CurrRO		:LongInt;
                       IncrRO		:LongInt;
                    End;

   Var	Drv_RO		:^DrvRO;

  {---------------------------------------------------------------------}
  { Structures with TDRV timing information                             }
  {---------------------------------------------------------------------}

   Type DrvTiming = Record
                       IrqStart		:Array [0..1] of LongInt;
                       IrqEnd		:Array [0..1] of LongInt;
                       IrqDiffMin	:LongInt;
                       IrqDiffMax	:LongInt;
                    End;

   Var	Drv_Timing	:^DrvTiming;

{############################################################################}
{                                                                            }
{                         IMPLEMENTATION SECTION                             }
{                                                                            }
{############################################################################}

Implementation

  { Definitions of variables for function <GetDriverDataAddress>   }

  Const   GI_Status              = 0;
  Const   GI_Opt                 = 1;
  Const   GI_PrevTime            = 2;
  Const   GI_CurrTime            = 3;
  Const   GI_DrvX                = 4;
  Const   GI_DrvY                = 5;
  Const   GI_DrvRO               = 6;
  Const   GI_Timing              = 7;
  Const   GI_NumKbStat           = 8;


  Var     i                                :Integer;
  Var     PgmIdent                         :Byte;

  Var     PrevTime                         :^LongInt;
  Var     CurrTime                         :^LongInt;


  Var     WResult                          :Word;
  Var     DResult                          :LongInt;

Label   dFound;


Procedure  Enable; Begin Asm sti End End;
Procedure  Disable; Begin Asm cli End End;


Function   DriverReady  : Boolean;
  Begin
     if (DriverStatus^ And S1_DriverReady)<>0
              then DriverReady := true
              else DriverReady := false
  End;


Function   IsStartCoord : Boolean;
  Begin
     if (DriverStatus^ And S1_IsStartCoord)<>0
              then IsStartCoord := true
              else IsStartCoord := false
  End;



Function   tdrvIsTimerIRQ : Boolean;
  Begin
     Asm
          push	es
          les 	bx , DriverStatus;
          cli
 	  mov	ax , es:[bx]
          and	word ptr es:[bx] , ($FFFF Xor S1_TimerIntDetected)
          sti
          mov	@Result , 0
          test  ax , S1_TimerIntDetected
          jz    @1
          mov	@Result , 1
      @1: ;
     End
  End;




Function   tdrvIsFullSecond : Boolean; Assembler;
   Asm
        push	es
        les 	bx , DriverStatus;
        cli
 	mov	ax , es:[bx]
        and	word ptr es:[bx] , ($FFFF Xor S1_FullSecondDetected)
        sti
        xor     bx , bx
        test    ax , S1_FullSecondDetected
        jz      @1
        inc     bx
    @1: mov	ax , bx
  End;



Procedure  SetCurrentCoord ( NewX , NewY : LongInt ); Assembler;
  Asm
      mov   ah , PgmIdent;
      mov   al , $03;
      push  si;
      push  di;
      mov   bx , word ptr NewX;
      mov   cx , word ptr NewX+2;
      mov   si , word ptr NewY;
      mov   di , word ptr NewY+2;
      int   $2F;
      pop   di;
      pop   si;
  End;



{----------------------------------------------------------------------------}
{  Procedure <SetNewDest> sets new destination for TDRV.EXE                  }
{----------------------------------------------------------------------------}

Type  NewDest  = Record
                     Flags      :Word;
                     Time       :LongInt;
                     X          :LongInt;
                     Y          :LongInt;
                     R          :LongInt;
                     rAngle     :Integer;
                     ClrX	:LongInt;
                     ClrY	:LongInt;
                 End;



Procedure  SetNewDest ( DestTime , DestX , DestY , DestRO : LongInt );
  Var   D    : NewDest;
        DPtr :^NewDest;
  Begin
       D.Flags    :=   $0000;
       D.Time     :=   DestTime;
       D.X        :=   DestX;
       D.Y        :=   DestY;
       D.R        :=   DestRO;
       D.rAngle   :=   0;
       D.ClrX     :=   0;
       D.ClrY     :=   0;
       DPtr       :=  @D;
       Asm
          push   es;
          mov    ah , PgmIdent;
          mov    al , $02;
          les    bx , DPtr;
          int    $2F;
          pop    es;
       End
  End;


Procedure  SetNewDestR ( DestTime , DestX , DestY , DestRO : LongInt ;
                         ClrX , ClrY  :LongInt );
  Var   D    : NewDest;
        DPtr :^NewDest;
  Begin
       D.Flags    :=   $8000;
       D.Time     :=   DestTime;
       D.X        :=   DestX;
       D.Y        :=   DestY;
       D.R        :=   DestRO;
       D.rAngle   :=   0;
       D.ClrX     :=   ClrX;
       D.ClrY     :=   ClrY;
       DPtr       :=  @D;
       Asm
          push   es;
          mov    ah , PgmIdent;
          mov    al , $02;
          les    bx , DPtr;
          int    $2F;
          pop    es;
       End
  End;



Procedure  TdrvClearDest (cnt :Word);
  Begin
     if Cnt<3 Then Cnt:=3;
     Disable;
     if Drv_X^.iCount>3 then Drv_X^.iCount:=3;
     if Drv_Y^.iCount>3 then Drv_Y^.iCount:=3;
     DriverStat2^ := DriverStat2^ And ($FFFF Xor S2_NewDestReady);
  End;


{----------------------------------------------------------------------------}
{  SetCCStrobe : Set chanal commutator strobe without setting destination    }
{----------------------------------------------------------------------------}

Procedure  SetCCStrobe ( ccDelay : LongInt ); Assembler;
  Asm
      mov   ah , PgmIdent;
      mov   al , $01;
      mov   cx , word ptr ccDelay;
      mov   dx , word ptr ccDelay+2;
      int   $2F;
  End;


Procedure  GetCurrPosition ( Var Pos : CurrPosition ); Assembler;
  Asm
      push  es;
      mov   ah , PgmIdent;
      mov   al , $04;
      les   bx , Pos;
      int   $2F;
  End;



Function   GetTrackingOptions : Word; Assembler;
  Asm
      mov    ah , PgmIdent;
      mov    al , $1E;
      mov    bx , $0007;
      int    2Fh;
      mov    ax , cx;
  End;



Procedure   SetTrackingOptions ( NewOpt :Word ); Assembler;
  Asm
      mov    ah , PgmIdent;
      mov    al , $1E;
      mov    bx , $0107;
      mov    cx , NewOpt;
      int    2Fh;
  End;

{----------------------------------------------------------------------------}
{        Setting/quering numeric keypad sensitivity                          }
{----------------------------------------------------------------------------}

Function   GetNumKbSensitivity   : Word;  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0005
      int     $2F
      mov     ax , cx
  End;


Procedure  SetNumKbSensitivity ( NewVal :Word );  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0105
      mov     cx , NewVal
      int     $2F
  End;


{----------------------------------------------------------------------------}

Function  TdrvGetMouseSensitivity :Word;  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0006
      int     $2F
      mov     ax , cx
  End;


Procedure  TdrvSetMouseSensitivity ( NewVal : Word );  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0106
      mov     cx , NewVal
      int     $2F
  End;

{----------------------------------------------------------------------------}

Function  TdrvGetJoystickSensitivity	: Word;   Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0008
      int     $2F
      mov     ax , cx
  End;


Procedure  TdrvSetJoystickSensitivity ( NewVal : Word );  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0108
      mov     cx , NewVal
      int     $2F
  End;


{----------------------------------------------------------------------------}
{  0.1 second timer functions                                                }
{----------------------------------------------------------------------------}


Procedure  ResetTimer;  Assembler;
  Asm
      mov    ah , PgmIdent;
      mov    al , $1F;
      mov    bx , $0300;
      int    2Fh
  End;


Procedure   TdrvSetSystemTime;  Assembler;
  Asm
      mov	ah , PgmIdent
      mov	al , $1F
      mov	bh , $09
      int	$2F
  End;


Function   GetTimeL : longint;
  Begin
     Disable;
     GetTimeL := CurrTime^ - 1;
     Enable;
  End;


Function   TdrvGetCurrMJD : Double;
  Begin
     Asm
        mov    ah , PgmIdent;
        mov    al , $1F
	mov    bh , $01
        int    $2F
	fstp   @Result
     End
  End;


Procedure  TdrvGetExtTime ( Var  Year, Month, Day  :Integer;
                            Var  Hours, Minutes, Seconds, Tenths :Integer);
  Var   Regs	:Registers;
  Begin
      Regs.AH := PgmIdent;
      Regs.AL := $1F;
      Regs.BX := $0200;
      intr ($2F,Regs);
      Year  	:= Regs . AX;
      Month     := Regs . BX Shr 8;
      Day       := Regs . BX And $00FF;
      Hours     := Regs . CX Shr 8;
      Minutes   := Regs . CX And $00FF;
      Seconds   := Regs . DX Div 10;
      Tenths    := Regs . DX Mod 10;
  End;



Procedure   TdrvNormalizeTime;  Assembler;
  Asm
     mov     ah , PgmIdent
     mov     al , $1F
     mov     bx , $0500
     int     $2F
  End;



Procedure   TdrvGetTimeString ( tm :String );
  Begin
     {Not Ready still;}
  End;



Procedure  IncrTimeL ( tIncr : LongInt );  Assembler;
  Asm
      mov    ah , PgmIdent;
      mov    al , $1F;
      mov    bx , $0200;
      mov    cx , Word Ptr tIncr;
      mov    dx , Word Ptr tIncr+2;
      int    2Fh;
  End;



Function   WaitTimerIrq : Boolean;  Assembler;
  Asm
      mov     ah , PgmIdent;
      mov     al , $1F;
      mov     bx , $1000;
      int     $2F;
      cmc
      db      $D6;
      cwd
  End;


Function   WaitFullSecond : Boolean;  Assembler;
  Asm
      mov     ah , PgmIdent;
      mov     al , $1F;
      mov     bx , $1100;
      int     $2F;
      cmc
      db      $D6;
      cwd
  End;



Procedure  StopTracking;  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $07
      int     $2F;
  End;


{----------------------------------------------------------------------------}
{  Setting/Quering max. allowed speed and acceleration                       }
{----------------------------------------------------------------------------}

Procedure  SetMaxSpeed ( NewVal : Word ); Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0100
      mov     cx , NewVal
      int     $2F
  End;


Procedure  SetMaxAcc   ( NewVal : Word ); Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0101
      mov     cx , NewVal
      int     $2F
  End;


Function   GetMaxSpeed : Word;  Assembler;
  Asm
      mov     ah , PgmIdent
      mov     al , $1E
      mov     bx , $0000
      int     $2F
      mov     ax , cx
  End;


Function   GetMaxAcc : Word;  Assembler;
  Asm
     mov     ah , PgmIdent
     mov     al , $1E
     mov     bx , $0001
     int     $2F
     mov     ax , cx
  End;

{---------------------------------------------------------------------}
{ Setting/Quering coordinate limits                                   }
{---------------------------------------------------------------------}

Procedure  GetCoordLimits ( Var CL :DCoordLimits );
Var  rPtr  :^DCoordLimits;
Begin
     rPtr := @CL;
     Asm
        mov     ah , PgmIdent
        mov     al , $1E
        mov     bx , $0002
        les     dx , rPtr
        int     $2F
     End
End;


Procedure  SetCoordLimits ( Var CL :DCoordLimits );
Var  rPtr  :^DCoordLimits;
Begin
     rPtr := @CL;
     Asm
        mov     ah , PgmIdent
        mov     al , $1E
        mov     bx , $0102
        les     dx , rPtr
        int     $2F
     End
End;


{---------------------------------------------------------------------}
{  TDRV.EXE beep options                                              }
{---------------------------------------------------------------------}

Procedure GetBeepOptions ( Var b :DBeepOptions );
Var   b1  :DBeepOptions;
Begin
     b1 := b;
     Asm
        mov     ah , PgmIdent;
        mov     al , $1E;
        mov     bx , $0003;
        int     $2F
        mov     b1.EventType , ch
        mov     b1.BeepLen   , cl
        mov     b1.BeepFq    , dx
     End
End;


Procedure SetBeepOptions (     b :DBeepOptions );
Begin
     Asm
        mov     ah , PgmIdent;
        mov     al , $1E;
        mov     bx , $0003;
        mov     ch , b.EventType
        mov     cl , b.BeepLen
        mov     dx , b.BeepFq
        int     $2F
     End
End;

{---------------------------------------------------------------------}
{ TDRVX laser control procedures and functions                        }
{---------------------------------------------------------------------}

Procedure TDRV_LaserEnable; Assembler;      { This procedure enables laser   }
                                            { shooting. Take care that       }
     Asm                                    { <S1_LaserDisable> bit in       }
        mov     ah , PgmIdent;              { <DriverStatus> must be 0 to    }
        mov     al , $1A;                   { really enable laser ranging    }
        mov     bh , $01;
        int     $2F;
     End;


Procedure TDRV_LaserDisable;  Assembler;    { This procedure disables laser  }
                                            { shooting. The same function can}
     Asm                                    { be done if corresponding bit is}
        mov     ah , PgmIdent;              { set in <DriverStatus>.         }
        mov     al , $1A;
        mov     bh , $02;
        int     $2F;
     End;


Function  TDRV_GetLaserStat     :Boolean;   { Returns TRUE if laser shooting }
Begin                                       { is enabled with procedures     }
     Asm                                    { TDRV_LaserEnable or others.    }
        mov     ah , PgmIdent;              {                                }
        mov     al , $1A;                   {                                }
        mov     bh , $03;                   {                                }
        int     $2F;
        cbw
        mov     @Result , al
     End;
End;

Procedure TDRV_StartShootingAt ( StartTime :LongInt );
Begin                                       { Starts shooting at specified   }
     Asm                                    { time and enables laser shooting}
        mov     ah , PgmIdent;              {                                }
        mov     al , $1A;
        mov     bh , $04;
        mov     cx , word ptr StartTime;
        mov     dx , word ptr StartTime+2;
        int     $2F;
     End;
End;

Function  TDRV_GetNextShootTime                     :LongInt;
Begin                                       { Returns time of next shoot:    }
     Asm                                    { (The value of 0.1 sec. timer)  }
        mov     ah , PgmIdent;
        mov     al , $1A;
        mov     bh , $05;
        int     $2F;
        mov     word ptr @Result   , ax
        mov     word ptr @Result+2 , dx
     End;
End;

Procedure TDRV_SetLaserPeriod  ( NewPeriod :Word );
Begin                                       { Sets laser shooting period to  }
     Asm                                    { specified value (in units of   }
        mov     ah , PgmIdent;              { 0.1 seconds.                   }
        mov     al , $1A;
        mov     bh , $06;
        mov     cx , NewPeriod;
        int     $2F;
     End;
End;

Function  TDRV_GetLaserPeriod                       :Word;
Begin                                       { Returns current setting of     }
     Asm                                    { laser shooting period in units }
        mov     ah , PgmIdent;              { of 0.1 seconds.                }
        mov     al , $1A;
        mov     bh , $07;
        int     $2F;
        mov     @Result , ax;
     End;
End;

Procedure TDRV_StartShooting;               { Starts laser shooting.         }
Begin                                       {                                }
     Asm                                    {                                }
        mov     ah , PgmIdent;
        mov     al , $1A;
        mov     bh , $08;
        int     $2F;
     End;
End;

Procedure TDRV_SetWindow ( NewWindow :LongInt );
Begin                                       { Sets new value of window width }
     Asm                                    { in units of nanoseconds        }
        mov     ah , PgmIdent;              {                                }
        mov     al , $1A;
        mov     bh , $09;
        mov     cx , word ptr NewWindow;
        mov     dx , word ptr NewWindow+2;
        int     $2F;
     End;
End;

Function  TDRV_GetWindow        :LongInt;   { Returns current value of window}
Begin                                       { width in units of nanoseconds  }
     Asm
        mov     ah , PgmIdent;
        mov     al , $1A;
        mov     bh , $0A;
        int     $2F;
        mov     word ptr @Result   , ax
        mov     word ptr @Result+2 , dx
     End;
End;

Procedure TDRV_SetGateShift    ( NewShift  :LongInt );
Begin
     Asm
        mov     ah , PgmIdent;
        mov     al , $1A;
        mov     bh , $0E;
        mov     cx , word ptr NewShift;
        mov     dx , word ptr NewShift+2;
        int     $2F;
     End;
End;

Function  TDRV_GetGateShift                         :LongInt;
Begin
     Asm
        mov     ah , PgmIdent;
        mov     al , $1A;
        mov     bh , $0F;
        int     $2F;
        mov     word ptr @Result   , ax
        mov     word ptr @Result+2 , dx
     End;
End;

{----------------------------------------------------------------------------}
{  Function <GetDriverDataAddress> returns pointer to TDRV.EXE internal data }
{----------------------------------------------------------------------------}

Function   GetDriverDataAddress ( index :Integer ; Ofst :Integer ) :Pointer;
Begin
     asm
        mov    ah , PgmIdent;
        mov    al , $0F;
        mov    bh , Byte Ptr index;
        int    2Fh
        add    bx , Ofst;
        mov    Word Ptr @Result   , bx;
        mov    Word Ptr @Result+2 , es;
     end;
End;


Function   R256 ( X : LongInt ) : LongInt;
Begin
     Asm
         mov   cx , 8
         mov   ax , word ptr X
         mov   dx , word ptr X+2
     @1: sar   dx , 1
         rcr   ax , 1
         loop  @1
         adc   ax , 0
         adc   dx , 0
         mov   word ptr @Result   , ax
         mov   word ptr @Result+2 , dx
     End;
End;


Begin
     PgmIdent := 0;
     TDRV_Found := False;
     for i:=$C0 to $FF do
       Begin
         Asm
                        jmp     @1;
            @IdName:    db      'Telescope control driver : Version 1.12',0
            @1:         push    si;
                        push    es;
                        xor     bx , bx;
                        mov     ah , Byte Ptr i;
                        xor     al , al;
                        int     2Fh;
                        cmp     al , 0FFh;      { Must be $FF if there is    }
                        jne     @2;             { process that uses this ID  }
                        cmp     bx , 200h;      { BX must be in range        }
                        ja      @2;             { $0103...$0200              }
                        cmp     bx , 03h
                        jae     @3;
            @2:         xor     ax , ax;
                        jmp     @99
            @3:         xor     si , si;
            @4:         mov     al , byte ptr @IdName [si];
                        cmp     al , byte ptr ES:[bx];
                        jne     @2;
                        or      al , al
                        je      @98;
                        inc     bx;
                        inc     si;
                        jmp     @4;
            @98:        mov     ah , Byte Ptr i;
                        mov     PgmIdent , ah;
            @99:        pop     es;
                        pop     si;
                        or      ax , ax;
                        jne     dFound;
         End;
       End;
     WriteLn;
     WriteLn ('You must load TDRV.EXE as TSR before You can use unit <CallTDRV>' );
     WriteLn ('Command line format : TDRV /I');
     Halt (3);

dFound:
     TDRV_Found := True;
     DriverStatus       := GetDriverDataAddress ( GI_Status , 0 );
     DriverStat2        := GetDriverDataAddress ( GI_Status , 2 );
     PrevTime           := GetDriverDataAddress ( GI_PrevTime , 0 );
     CurrTime           := GetDriverDataAddress ( GI_CurrTime , 0 );
     Drv_X              := GetDriverDataAddress ( GI_DrvX , 0 );
     Drv_Y              := GetDriverDataAddress ( GI_DrvY , 0 );
     Drv_RO		:= GetDriverDataAddress ( GI_DrvRO , 0 );
     Drv_Timing		:= GetDriverDataAddress ( GI_Timing , 0 );
     DrvNKStat		:= GetDriverDataAddress ( GI_NumKBStat , 0 );

End.