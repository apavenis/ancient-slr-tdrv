
		.286


                IOTRACE = 0
		MO_SAVE = 0

                include MACROS.INC
		include COORD.INC
                include DBGSTRCT.INC

RegStruct       struc
r_ax            dw 	?
r_cx		dw	?
r_dx		dw	?
r_si		dw	?
r_di		dw	?
r_bp		dw	?
r_ds		dw	?
r_es		dw	?
r_bx		dw	?
		dw	?	; Flags saved at INT 2Fh (don't touch!!)
r_cs		dw	?
r_ip		dw	?
r_flags		dw	?
RegStruct	ends

;******************************************************************************
;*	MODULE  :  TDRV.ASM         *******************************************
;******************************************************************************

API_SIGNATURE	equ     0C3621494h

;-----------------------------------------------------------------------------

	global  PgmIdent	:Byte	; Identification string

	global	BIOS_Seg	:Word	; Real mode segment for BIOS data area

	;--------------------------------------------------------;
	;   Information about interrupts the driver uses         ;
	;--------------------------------------------------------;

	global	IntTableAddr	:Word

	global	INT_09		:IntInfo
	global	INT_19		:IntInfo
	global	INT_1B		:IntInfo
	global	INT_2F		:IntInfo
	global	IRQ_08		:IntInfo
	global	IRQ_0C		:IntInfo
	global	TIMER_IRQ	:IntInfo

	global	TIntMaskPort	:Word
	global	TIntMask	:Byte

	;--------------------------------------------------------;
	;   Multiplex number used by this program. At the start  ;
	;   of program a scan is done for a free multiplex       ;
	;   process number (if the first instance) or for the    ;
	;   multiplex process number used by existing resident   ;
	;   copy of this program.                                ;
	;--------------------------------------------------------;

	global  INT_2F_IDENT    :Byte

	;--------------------------------------------------------;
	;   Segment of PSP of the current instance               ;
	;--------------------------------------------------------;

	global	PspSeg		:Word

        ;--------------------------------------------------------;

        global  IsWindows       :Byte

        ;--------------------------------------------------------;
	;   Physical characteristics used by driver              ;
	;--------------------------------------------------------;

	global  Frequency	:dWord

	global  MaxAcc		:Word
	global	MaxAcc_D	:dWord	; MaxAcc*256
	global	MaxAcc_W	:dWord  ; max(MaxAcc*32,20*256)
	global  MaxAcc_W2	:dWord  ; MaxAcc*192
	global  MaxAcc_W3	:dWord	; MaxAcc*(31/32)

	global	MaxSpeed	:Word
	global	MaxSpeed_D	:dWord	; MaxSpeed*256

	;--------------------------------------------------------;
	;   Manual control parameters                            ;
	;--------------------------------------------------------;

	global  kbSensitivity   :word   ;
	global	moSensitivity	:word
	global	jsSensitivity	:word
	global	f_Options	:word
	global	f_divX		:word
	global	f_divY		:word
	global	f_argShift	:word
	global	f_dShift	:word
	global	f_cLow		:dword
	global	f_cHigh		:dword

	;--------------  Definitions of bits used in f_Options ---;

		FO_SEL_COORD	equ	0080h   ; ........ ?.......
			; 0 : dX must be divided with cos Y
			; 1 : dY must be divided with cos X
		FO_XDEF		equ	0040h	; ........ .?......
			; 0 : P does not depend on X
			; 1 : P does depend on X
		FO_XSIGN	equ	0020h	; ........ ..?.....
			; 0 : X must be added
			; 1 : X must be substracted
		FO_YDEF		equ	0010h	; ........ ...?....
			; 0 : P does not depend on Y
			; 1 : P does depend on Y
		FO_YSIGN        equ     0008h	; ........ ....?...
			; 0 : Y must be added
			; 1 : Y must be substracted
		FO_XINV		equ	0004h	; ........ .....?..
			; 1 : invert X' correction before use
		FO_YINV		equ	0002h	; ........ ......?.
			; 1 : invert Y' correction before use
		FO_INVARG	equ	0001h	; ........ .......?
			; 1 : invert sign of sin P

	;--------------------------------------------------------;
	;   RTC options (Is being used to generate full second   ;
	;   beeps, beeps on laser shooting etc., Only one of     ;
	;   these options is available any time)                 ;
	;--------------------------------------------------------;

	global	RTC_Funct	:byte
	global	BeepLen		:word
	global	BeepFq		:word

	;--------------------------------------------------------;
	;   Coordinate change limits                             ;
	;--------------------------------------------------------;

	global	MinX		:dword
	global	MaxX		:dword
	global	MinY		:dword
	global	MaxY		:dword

	global	HistWX		:dword
	global	HistWY          :dword


;###########################################################################

	;--------------------------------------------------------;
	;   Driver status word (DRV_STAT)                        ;
	;   The meaning of bits in driver status word            ;
	;--------------------------------------------------------;

	global  DRV_STAT        :Word     ; For user program too

;               Bit name                        value   DRV_STAT  DRV_STAT2

		TIMER_INT_DETECTED	equ 	8000h;     +          -
			; This bit is set to 1 when
			; timer IRQ is detected
		FULL_SECOND_DETECTED	equ	4000h;     +          -
			; This bit is set to 1 when
			; full second is detected
		DRIVER_READY		equ	2000h;     +          -
			; DRV_STAT : 1 tells user that
			;   he can send new destination
		IS_START_COORD		equ	0100h;     +          -
			; 1 - after setting initial coord.
			; 0 - after driver reset
		LASER_DISABLE		equ	0080h
			; 1 - disable laser shooting. This bit is being
			; reset while accepting new destination
		MANUAL_TRACKING		equ     0040h
			; 1 - when tracking manually.
                MT_MODE_CHANGED         equ     0020h
                        ; Set to 1 when MANUAL_TRACKING
                        ; bit is changed. User may set this
                        ; bit to 0
		HARDWARE_IRQ15		equ	0008h
			; This bit is set to 1 when bit 7 in
			; ISR of second interrupt controller is
			; on
		CTRL_BREAK              equ     0004h;     +          -
			; TDRV.EXE sets this bit to 1
			; when Ctrl-Break is pressed
		MIDNIGHT_FOUND		equ	0002h;     +          -
			; 1 - if time is greater than
			; 864000. Don't reset the timer!
		SYNCHRONIZATION_OK	equ	0001h;     +          -
			; User may use this byte to tell
			; that synchronisation is done.
			; The driver doesn't check this
			; bit

	global	DRV_STAT2	:Word	  ; For internal use only

		PREV_DEST_OK		equ	4000h
			; Previous destination is available to compute dest.
			; speed
		INTERVAL_DONE		equ	2000h
			; DRIVER_READY flag in DRV_STAT will be set while
			; processing the next 0.1 seconds interrupt
		OUTPUT_READY		equ	1000h
			; Set to 1 when control parameters are computed for
			; next interval
		NEW_DEST_READY		equ	0800h
			; Set to 1 when user sends new destination
		DRV_WAITING		equ	0400h
			; Set to 1 when driver is waiting for 1-st destination
		RESET_DRIVER		equ     0200h
			; 1 - request to reset driver.
		FO_ENABLE		equ	0100h
			; 1 - when manual corrections are allowed.
			; 0 - <VField> returns 0.
		DRV_TRACKING		equ	0080h
			; 1 - when in tracking sequence
		MO_LEFT_DOWN		equ     0001h
		MO_RIGHT_DOWN		equ	0002h
		MO_CENTER_DOWN		equ     0004h
			; 1 - when corresponding mouse button is down
			;     valid only in tracking mode
                JS_BUTTON1              equ     0008h
                JS_BUTTON2              equ     0010h
                JS_BUTTON3              equ     0020h
                JS_BUTTON4              equ     0040h

	;--------------------------------------------------------;
	;   Options word                                         ;
	;--------------------------------------------------------;

	global	DRV_OPT		:word

		D_TAKE_KB		equ     00001h
			; When this option is ON, DRV_START commands tell
			; driver to process keyboard events from numeric
			; keypad by itself. (Keys from numeric keypad then
			; is being used for manual corrections of the
			; telescope's position

		D_TAKE_MOUSE		equ     00002h
			; When this bit is on, the driver tries to use mouse
			; for manual corrections of the position.

		D_INSTR_COORD		equ     00004h
			; When this bit is ON, the driver assumes that
			; manual corrections is being done directly in
			; instrumental corrections

		D_USER_ROTATION		equ     00008h
			; When this bit is on an extra rotation of coordinate
			; system is being done (valid if D_INSTR_COORD=1)

		D_CONV_CORR		equ	00010h
			; Enables conversion of manual corrections when this
			; bit is on

		D_USE_JOYSTICK		equ	00020h
			; Enables use of joystick for manual corrections

	global	HRDW_OPT	:Word

		ENABLE_BEEPS		equ	00001h
		ENABLE_LASER_CTRL	equ	00002h
		ENABLE_STEP_CNT		equ	00004h
		STRICT_IRQ15            equ     00008h
		ENABLE_JOYSTICK		equ	00010h

	global	EXT_OPT		:Word

		HOME_POS_USED		equ 	00001h

	global	LAS_TRIG	:Word

		LAS_TRIG_REQUESTED      equ     0100h
		LAS_TRIG_DONE		equ	0001h

	;--------------------------------------------------------;
	;   Information obout mouse                              ;
	;--------------------------------------------------------;

	global	MOUSE_STAT	:word

		MOUSE_OK		equ	08000h
		MO_STATUS_SAVED		equ     04000h

	global	MoBuffer	:dWord

	;--------------------------------------------------------;
	;   Some joystick related parameters                     ;
	;--------------------------------------------------------;

	global	CenterX		:word	; Joystick parameters
	global	CenterY		:word
	global  jcWidth         :word
	global	jOptions	:word

		J_INVERT_X		equ	00001h
		J_INVERT_Y		equ	00002h

	global  jWidth2		:word	; This is really unused any more

	;--------------------------------------------------------;
	;   Data necessary for tracking both coordinates and     ;
	;   distance of the object.                              ;
	;--------------------------------------------------------;

	global	FldRotAngle	:word

	global	DRV_X		:DrvCoord
	global	DRV_Y		:DrvCoord

	global	x_correction	:dword
	global	y_correction	:dword

	global	RO		:dword
	global	dRO		:dword

	global	cc_RO		:word

	global	X_UPD		:dword	; Coefficient for conversion from
	global	Y_UPD		:dword	; TDRV units to degrees

	;-------------------------------------------------------;
	;	Structure that contains information about       ;
	;  the next destination                                 ;
	;-------------------------------------------------------;

	global	NewDest		:DrvRequest

	;-------------------------------------------------------;
	;       Variable thet characterizes CPU speed while     ;
	;  executing loops.                                     ;
	;-------------------------------------------------------;

	global	cpuSpeed	:word

	;-------------------------------------------------------;
	;      Full second signal and zero point status read    ;
	;  from hardware while processing 0.1 sec interrupt:    ;
	;-------------------------------------------------------;

	global	HR_Stat		:byte	; This byte is written by 0.1 sec. IRQ
					; procedure and contains following
					; bits:
					;  .......X : 0 - full second strobe
					;  ......X. : 0 - ZP for 1-st coord
					;  .....X.. : 0 - ZP for 2-nd coord

	;-------------------------------------------------------;
	;     Time units for forming different signals in hard- ;
	; ware card (All units are in nanoseconds)              ;
	;-------------------------------------------------------;

	global	fqWin		:word
	global	fqGate		:word
	global	fqTimer		:word
	global	fqCC		:word

	;-------------------------------------------------------;
	;     Settings for time window                          ;
	;-------------------------------------------------------;

	global	winMax		:word	; Max. allowed value in instr. units
					; (1 unit is <fqWin> nanoseconds)

	global  dftWindow	:dword	; Default value (may be modified from
					; TDRV.CFG file)

	global	dftLaserPeriod  :word	;

	global	ShootAlign	:word	; Defines alignment of first shoot
					; time in units of 0.1 second. Can be
					; changed only from configuration
					; file

	global	RST_FQ		:word	; Max frequency for which chip
					; i8253 counters (coordinates only)
					; is being reset each 0.1 second

	global	GateMask	:byte   ; Enables/disables gate for calibration
					; and staellite ranging.
					;   Value   Calibration  Satellite
					;    00h      Disabled    Disabled
					;    10h      Enabled     Disabled
					;    20h      Disabled    Enabled
					;    30h      Enabled     Endbled

	;-------------------------------------------------------;
	; Instrument coordinate syystem definition file         ;
	;-------------------------------------------------------;

	global	InstrType	:word	; Integer value used to identify
					; correct instrument model file.
					; Currently supported values are
					;       101 for LS-105
					;       630 for ULISS
					; Ignored if not specified

		IT_LS105	equ	101
		IT_ULISS	equ	630

	global	InstrDefLen	:word
	global	InstrDefPath	:byte:87

	;-------------------------------------------------------;
	; I8254 timer value for 0.1 sec interrupts              ;
	; All values are in units of (1/1193180) seconds        ;
	;-------------------------------------------------------;

	global	irqStart	:qword	; Time when last timer interrupt
					; was occurred.
	global	irqEnd		:qword	; Time when the last return from
					; IRQ15 was occurred
	global  irqDiffMin	:dword
	global	irqDiffMax	:dword

	;-------------------------------------------------------;

	global	EventMask	:word    ; Event mask for TDRV callback service
	global	CallBackAddr	:dword   ; Address of callback procedure

		EV_TDRV_READY	equ	04000h
		EV_INTERRUPT	equ	00001h

	;-------------------------------------------------------;

		R_LASER_TRIG_REQ  	equ	08000h
		R_IS_LASER_TRIG		equ	00001h
		R_IS_IRQ		equ	00002h

	;-------------------------------------------------------;
	;      TDRV.EXE function 0 : return identification data ;
	; This function must be used to detect resident copy of ;
	; TDRV.EXE.                                             ;
	;-------------------------------------------------------;

	global	GetIdent	:Near

	;-------------------------------------------------------;
	; Interrupt procedures for:                             ;
	;   	 INT 1Bh  - Ctrl-Break is pressed;              ;
	;        INT 19h  - Ctrl-Alt-Del is pressed             ;
	;-------------------------------------------------------;

	global	BREAK_PROC	:far
	global	RESET_PROC	:far

	;-------------------------------------------------------;
	; Data conversion from BCD format to binary one         ;
	;-------------------------------------------------------;

	global  BCDByteToBin	:Near
	global	BCDWordToBin	:Near

	;-------------------------------------------------------;
	; Read/write byte from/to CMOS                          ;
	;-------------------------------------------------------;

	global	ReadCMOSByte	:Near
	global	WriteCMOSByte	:Near

;******************************************************************************
;	MODULE  :  KEYBOARD.ASM
;******************************************************************************

		NUM_KB_ENABLE	equ	080h
		IS_E0_CODE	equ	040h

		NK_0		equ	1
		NK_1		equ	2
		NK_2		equ	4
		NK_3		equ	8
		NK_4		equ	16
		NK_5		equ	32
		NK_6		equ	64
		NK_7		equ	128
		NK_8		equ	256
		NK_9		equ	512
		NK_MINUS	equ     1024
		NK_PLUS		equ	2048
		NK_POINT	equ	4096
		NK_ENABLED	equ	08000h


	global	INT_09_PROC		:FAR
	global  EnableKbdDriver		:near
	global	DisableKbdDriver	:near
	global	GetKbCorrections	:near

	global	NumKeypadStatus		:word
	global  kStatus			:byte

;*****************************************************************************
;	MODULE:  INT2F.ASM
;*****************************************************************************

	global	INT_2F_PROC	:far
	global	API_ENTRY	:Byte	; Procedure to simulate interrupts
	global  SubFnTable      :Word


		TDRV_Initialize	    = 012h

		TDRV_TimerFunct     = 01Fh
		    T0_QueryTime    	= 0
		    T0_SetTime 		= 1
		    T0_IncrTime		= 2
		    T0_ResetTimer 	= 3
		    T0_WaitTenth	= 16
		    T0_WaitFullSec	= 17

	global	I_GetTempBufferAddr	:Near

;*****************************************************************************
;	MODULE:   TIMER0.ASM
;*****************************************************************************

	;--------------------------------------------------------;
	;   Current time ( in 0.1 sec intervals )                ;
	;--------------------------------------------------------;

	global	CURR_TIME	:dword
	global  BASE_MJD        :dword
	global  PREV_TIME       :dword

	global	TimeSyncType	:word	; Time synchronization type:
					;   1 - full second
					;   2 - full minute

		T_DEBUG		equ	1		;
		TM_DRIVE	equ	0
		TM_INIT_TIMER	equ	1

	global	BeepRequested	:Byte	; Non zero when requested
	global	TimerIndex	:Word
	global	TM_ResetRq	:Byte
	global  TimerTable	:Word
        global  DisableFlag     :Byte

	global  IRQ00		:far
	global	TIMER_PROC	:far
	global	UpdateTimer	:Near
	global  DateToMJD	:Near
	global  MJDToDate	:Near

	global	TimerFunct	:Near
	global	WaitTimerInt	:Near   ; BX-Mask (TIMER_INT_DETECTED or FULL_SECOND_DETECTED)
					; CX-how many ticks to wait

        global  I_DisableTDRV   :Near

;*****************************************************************************
;	MODULE:  DRV1.ASM
;*****************************************************************************

	global	InitCoordLimits		:near
	global	SetCoordLimits		:near
	global	I_SetCCDelay		:near
	global	I_SetDest		:near
	global	I_SetCoord		:near
	global	I_GetPosition   	:near
	global	I_ResetDriver		:near
	global	I_ManCorrections	:near
	global	I_InitializeDriver	:near
	global	I_InstrDefFile		:near
	global	I_GetRData		:near
	global  I_ConvManCor            :near

	global	I_CallBack		:near
	global	InstallCallBack		:near
	global  ClearCallBack		:near

;*****************************************************************************
; 	MODULE:  COORD2.ASM
;*****************************************************************************

	global	I_ModelInfo		:near

;*****************************************************************************
;	MODULE:  MAIN.ASM
;*****************************************************************************

	global  FinishLoading	:Near

	global  MainPgm		:Near

	global  TSR_PSP         :Word
	global  TSR_SEG         :Word
	global  CmdLine         :Near
	global  SkipModel       :Byte
	global	ConfigOptions	:Word
	global	ConfigName	:Byte

	global	TSR_END		:Word

  global  EndOfPgm  :Byte  ; First unused byte after end of TDRV

;*****************************************************************************
;	MODULE:  INSTALL.ASM
;*****************************************************************************

	global	DetectInstance	:Near
	global	Install		:Near
	global	StayResident	:Near
	global	UnInstall	:Near
	global	TestSystem	:Near
	global	DetectCPU	:Near

;*****************************************************************************
;  	MODULE:  RD_MODEL.ASM
;*****************************************************************************

	global	ReadInstrModel  :Near

;*****************************************************************************
;  	MODULE:  MOUSE.ASM
;*****************************************************************************

	global	TakeMouse	:near
	global	ReleaseMouse	:near
	global	GetMoMotion	:near

;*****************************************************************************
;  	MODULE:  JOYSTICK.ASM
;*****************************************************************************


	Global	_JButtons	:Word
	Global	_JX		:Word
	Global	_JY		:Word
	Global	_ReadJoystick	:Near

	global  J_GetXY		:near
	global	CenterJoystick	:near
	global  I_Joystick	:near
	global	TakeJoystick	:near
	global	ReleaseJoystick :near

;*****************************************************************************
;  	MODULE:  VFIELD.ASM
;*****************************************************************************

	global	VField		:near

;*****************************************************************************
;	MODULE:  RTC.ASM
;*****************************************************************************

		BEEP_FSEC_H	equ	1
		BEEP_FSEC_S	equ	2
		BEEP_FMIN_S	equ	3
		BEEP_ON_SHOOT   equ     16
		BEEP_ON_IRQ     equ     32

	global  IRQ_08_PROC     :far
	global	ClearIRQ8	:near
	global	EnableIRQ8	:near
	global	DisableIRQ8	:near
	global	DoBeep		:near
	global	RTC_Check	:near

	global	RTC_FLAGS	:byte
		  RTC_Enable    = 080h
		  RTC_InUse	= 001h

	global	RTC_COUNT	:word
	global  RTC_EXIT	:word


;****************************************************************************
;	MODULE:  UTIL.ASM
;****************************************************************************

	global  ReadClkCounter  :near   ; Procedure reads value of
					; counter 0 from I8254
					; chip in AX

	global  GetCpuSpeed     :near   ; Returns number of empty
					; loops that can be executed
					; in 256 microseconds

	global  outportbw       :near   ; Outputs value from <AL>
                                        ; to port specified in <DX>
                                        ; and waits for at least
                                        ; 1 microsecond

        global  DummyProc       :near   ; Dummy procedure: returns
					; without any actions

	global	IO_Wait		:near

        global  sound           :near   ; Start generating sound
					; with frequency about
                                        ; <AX> Hz

	global  nosound         :near   ; Switch off PC speaker

	global	IOWaitAddr	:word   ; Address of IO delay procedure
					; (Must be either <DummyProc> (default)
					; either <IO_Wait>(value for fast
					; CPUs: Pentiums e.t.c)

	global	IOWaitCnt	:word	; Counter value for IO_Wait
					; There are no effect for slow
					; computers if default <DummyProc>
					; is used instead of <IO_Wait>

;*******************************************************************************
;       MODULE : OPTIONS.ASM
;*******************************************************************************

	global	UpdOptions	:near	; Procedure that is called by INT 2Fh
					; handler to query or update TDRV
					; parameters

	global	GetConfigParam	:near	; Procedure that is called by INT 2Fh
					; handler to query constants. Many of
					; these constants are read from
					; TDRV.CFG

	global  _SetMaxAcc      :near   ; Set max. allowed acceleration to the
					; value specified in register AX.
                                        ; The value must be in range 20...2000

        global  _SetMaxSpeed    :near   ; Set max. allowed speed for both to the
                                        ; value specified in register AX
                                        ; The value must be in range 2000...14400

	global	ApplyTrackingOpt:near	; Set tracking flags in effect to
					; value specified in DRV_OPT
					; if DRV_TRACKING=1 or disable
					; interface if DRV_TRACKING=0

;*******************************************************************************
;       MODULE : RDTIME.ASM
;*******************************************************************************

        global  GetTime0        :near


;----------------------------------------------------------------------------
	global	dumpModel	:byte
