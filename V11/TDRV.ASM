
		.286

		.XList
		include TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
		.List

_TEXT           segment byte public 'CODE'
		assume  CS:_TEXT , DS:_TEXT
;
;----------------------------------------------------------------------------
;       Jump around the resident part of program
;----------------------------------------------------------------------------
;
Start:          jmp     MainPgm         ; Jump to the start
;
;*****************************************************************************


		;----------------------------------------------;
		;   The identification string of driver. This  ;
		; string is used to identify resident instance ;
		; of driver using INT 2Fh.                     ;
		;----------------------------------------------;

PgmIdent        db      'Telescope control driver : Version 1.12',0
		dd	API_SIGNATURE
		dw	API_ENTRY

		;----------------------------------------------;
		;   This word contains segment addr. of BIOS   ;
		;  data area (0040h:xxxx)                      ;
		;----------------------------------------------;

BIOS_Seg	dw	0040h

		;----------------------------------------------;
		;   Area where information about interrupts    ;
		; the programm uses are saved. This infor-     ;
		; mation is used by uninstall function to      ;
		; restore old interrupt vectors when it is     ;
		; possible                                     ;
		;----------------------------------------------;

IntTableAddr    dw      INT_09
INT_09          IntInfo <  09h ,   0 , Offset INT_09_PROC >
INT_19          IntInfo <  19h ,   0 , Offset RESET_PROC >
INT_1B          IntInfo <  1Bh ,   0 , Offset BREAK_PROC >
INT_2F          IntInfo <  2Fh ,   0 , Offset INT_2F_PROC >
IRQ_08          IntInfo <  70h ,   1 , Offset IRQ_08_PROC >
IRQ_0C          IntInfo < 0FFh ,   1 , Offset IRQ_0C_PROC >	; 074h
TIMER_IRQ       IntInfo <  77h ,   1 , Offset TIMER_PROC >
		db      0

TIntMaskPort	dw	000A1h
TIntMask	db	080h

INT_2F_IDENT    db      0C4h

		;----------------------------------------------;
		;   Segment of PSP of current instance. From   ;
		; this field the value is taken for uninstall. ;
		;----------------------------------------------;

PspSeg          dw      0

;***************************************************************************
;*    This byte shows that TDRV.EXE is running under MS-WINDOWS
;*        .... ...1  - TDRV.EXE loaded from DOS window
;*        .... ..1.  - TDRV.EXE loaded before MS WINDOWS
;***************************************************************************

IsWindows       db      0

;***************************************************************************
;*    The following fields contains physical limits that are               *
;*  determined by hardware and the frequency tha card is working with.     *
;*  The time unit for all these settings is 0.1 sec (not 1 sec !!!).       *
;***************************************************************************

Frequency      	dd	125000

MaxAcc		dw      000Ah
MaxAcc_D        dd      00000A00h       ; MaxAcc * 256
MaxAcc_W        dd      00000140h       ; max (01400h,MaxAcc_D>>3)
MaxAcc_W2	dd      00000780h	; (7/8)*MaxAcc_D
MaxAcc_W3	dd	000009B0h	; (31/32)*MaxAcc_D

MaxSpeed        dw          3600h
MaxSpeed_D      dd      000E1000h       ; MaxSpeed*256

;*****************************************************************************
;*    Manual control parameters
;*****************************************************************************

dft_fdef        equ     FO_SEL_COORD+   \
			FO_XDEF+	\
			FO_YDEF+	\
			FO_YSIGN

kbSensitivity   dw      1
moSensitivity	dw	1
jsSensitivity	dw	16
jWidth2		dw	0
f_Options	dw	dft_fdef
f_divX		dw	720
f_divY		dw	720
f_argShift	dw	0
f_dShift	dw	0
f_cLow		dd     -15360
f_cHigh		dd	15360

;*****************************************************************************
;*    RTC Options
;*****************************************************************************

RTC_Funct	db	0
BeepLen		dw	30
BeepFq          dw	1000

;****************************************************************************
;     The coordinate change limits
;****************************************************************************

MinX		dd	081000000h
MaxX		dd	07F000000h
MinY		dd	081000000h
MaxY		dd	07F000000h

HistWX		dd      10800
HistWY		dd      10800

;*****************************************************************************
;*    The following field contains driver status words. Status is awailable  *
;* to user with INT 2Fh function  ??  (DRV_GET_STAT_ADDR).                   *
;*****************************************************************************

DRV_STAT        dw      0
DRV_STAT2       dw      0
DRV_OPT         dw      0
HRDW_OPT	dw      ENABLE_LASER_CTRL + ENABLE_BEEPS
EXT_OPT		dw	0
LAS_TRIG	dw	0

;*****************************************************************************
;       Information about mouse
;*****************************************************************************

MOUSE_STAT      dw      0

IF MO_SAVE Ne 0
    MoBuffer    dd      0       ; Address of buffer where to save mouse status
ENDIF

;*****************************************************************************
;*    Other variables used by driver                                         *
;*****************************************************************************

		;---------------------------------------------------------;
		;    Structures that contains variables for satellite     ;
		;  tracking for both coordinates                          ;
		;---------------------------------------------------------;

FldRotAngle     dw              ?

DRV_X           DrvCoord        ?       ; Parameters for 1-st coord.
DRV_Y           DrvCoord        ?       ; Parameters for 2-nd coord.

x_correction	dd		0       ; Corrections that has to be added
y_correction	dd		0	; to coordinates in current step

RO              dd              ?       ; Current distance
dRO             dd              ?       ; Increment of RO per 0.1 sec.

X_UPD		dd		921600	; The default values for 1" per step
Y_UPD		dd		921600

;#########  This value of this variable is never used ###################
;cc_RO		dw		?	; Parameter for canal commutator
;########################################################################

		;---------------------------------------------------------;
		;    New destination request (here the information will   ;
		; be placed after call to SubFn 'DRV_SET_DEST'. Call to   ;
		; this function sets bit NEW_DEST_READY in DRV_STAT too.  ;
		;---------------------------------------------------------;

NewDest         DrvRequest      ?

		;---------------------------------------------------------;
		;    Number of empty loops that can be executed to wait   ;
		; at least 1 microsecond.                                 ;
		;---------------------------------------------------------;

cpuSpeed	dw		?

		;---------------------------------------------------------;
		;    Status read from hardware while 0.1 sec. interrupt   ;
		;  processing: 01h-full second , 02-ZeroX , 04-ZeroY      ;
		;---------------------------------------------------------;

HR_Stat		db		?

		;---------------------------------------------------------;
		;    Strobe periods for counters in nanoseconds           ;
		;---------------------------------------------------------;

fqWin           dw       800    ; period for generating window
fqGate          dw       200    ; period for generating gate
fqTimer         dw      1600    ; period for timer
fqCC		dw	1600	; period for chanal commutator

		;---------------------------------------------------------;
		; Default settings for laser control. These settings can  ;
		; be redefined in file TDRV.CFG ( Group [LaserCtrl] ).    ;
		;     dftWindow		- default window width in nano-   ;
		;			  seconds. ('Window = <n>')       ;
		;     dftLaserPeriod	- default laser shooting period   ;
		;			  in units of 0.1 second.         ;
		;			  ('Period = <n>)                 ;
		;---------------------------------------------------------;

winMax          dw      64000   ; Max allowed value of window in instr. units

dftWindow	dd      32000	; If not redefined then 32 microseconds

dftLaserPeriod	dw	10	; If not redefined then 1.0 second

ShootAlign	dw	10	; Alignment of first shoot time. Can only
				; be changed from configuration file

RST_FQ		dw	200	; Max frequency for which I8253 counters
				; is being reset each 0.1 second

GateMask	db	030h	; Mask for calibration and satellite gates
;
;=============================================================================
;	The following variables contains timing information about 0.1 sec
;   interrupts.
;=============================================================================
;
irqStart        dq      ?       ; Filled at the start of IRQ15
irqEnd          dq      ?       ; Filled when returning from IRQ15
irqDiffMin	dd      7FFFFFFFh
irqDiffMax	dd      80000001h
;
;=============================================================================
;        Coordinate system definitions file info
;=============================================================================
;
InstrType	dw	0	; Instrument type ident. Used to reject
				; incorrect instrument model if specified
InstrDefLen	dw	0
InstrDefPath	db	87 dup (0)
;
;=============================================================================
;       Variables for TDRV callback services
;=============================================================================
;
EventMask	dw      0
CallBackAddr    dd	0
;
;=============================================================================
;	Address of IO Wait procedure
;=============================================================================

IOWaitAddr	dw	DummyProc
IOWaitCnt	dw	15	; the value for AMD PENTIUM 75

;=============================================================================
;
;       Some multiplex interrupt (2Fh) functions that returns addresses
;   of driver internal data.
;
;=============================================================================
;       Subfunction 0C400h : get program indentification
;  Input  : AX = 0C400h
;  Output : ES:BX - address of ident string
;	    CX    - interrupt number used by TDRV (simulation mode when 8)
;           DX    - paragraph of PSP of the resident instance
;=============================================================================
;
GetIdent        Proc    Near
		mov     ax , PspSeg
		mov     [bp] . r_dx , ax
		mov     cl , TIMER_IRQ.Num
		xor	ch , ch
		mov	[bp] . r_cx , cx
		mov     [bp] . r_es , cs
		mov     [bp] . r_bx , Offset PgmIdent
                or      [bp] . r_ax , 000FFh
		ret
GetIdent        EndP
;
;=============================================================================
;       This procedure is called when CTRL-BREAK is pressed
;=============================================================================
;
BREAK_PROC      Proc    Far
		or      cs:DRV_STAT  , CTRL_BREAK + LASER_DISABLE
OldBrk:		jmp     dword ptr  cs:INT_1B.OldVect
BREAK_PROC      EndP
;
;=============================================================================
;       This procedure is called when CTRL_ALT_DEL is pressed
;=============================================================================
;
RESET_PROC      Proc    Far
		push    ds
		push    cs
		pop     ds
		call    InitCard
		pop     ds
		jmp     dword ptr cs:INT_19.OldVect
RESET_PROC      endp
;
;=============================================================================
;  	Procedures to convert data between binary and BCD format
;=============================================================================
;
BCDByteToBin	PROC	NEAR
		mov	ah , al
		shr	ah , 4		; Upper digit --> AH
		and	al , 15		; Lower digit --> AL
		aad
		ret
BCDByteToBin	ENDP

BCDWordToBin    PROC	NEAR
		push	bx
		mov	bl , al
		mov	al , ah
		and	al , 15
		shr	ah , 4
		aad
		xor	ah , ah
		imul	ax , ax , 100
		xchg	ax , bx
		mov	ah , al
		and	al , 15
		shr	ah , 4
		aad
		add	ax , bx
		pop	bx
		ret
BCDWordToBin	ENDP
;
;=============================================================================
;	Read/Write  byte from/to CMOS memory
;=============================================================================
;
ReadCMOSByte    PROC	NEAR
		mov	al , ah
		out	70h , al
		jmp	short $+2
		jmp 	short $+2
		jmp	short $+2
		in	al , 71h
		ret
ReadCMOSByte	ENDP
;
WriteCMOSByte   PROC	NEAR
		xchg	al , ah
		out	70h , al
		jmp	short $+2
		jmp 	short $+2
		xchg	al , ah
		out	71h , al
		ret
WriteCMOSByte	ENDP


		ENDS
		END
_TEXT           ends
		end     Start
