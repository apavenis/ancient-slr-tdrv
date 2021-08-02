		locals
		.286

		.XList
		include LIB.INC
		include TDRV.INC
		include ARITH.INC
                include MACROS.INC
                include OUTPUT.INC
		include INTVECT.INC
		include HARDWARE.INC
		.List

_TEXT		Segment byte public 'CODE'
		Assume	CS:_TEXT , DS:_TEXT
;
;
NEW_MODEL_INPUT=1
;
;=============================================================================
;	Procedure 'DetectInstance' tries to find resident instance of
;   this program. If one is found paragraph address of PSP of the resident
;   instance is returned in AX.  Otherwise AX is set to 0. ES contains
;   code segment address of resident instance (if one exist)
;=============================================================================
;
DetectInstance  Proc	Near
                Local   Ident:Byte:2         = LocBytes
                Enter   LocBytes , 0
		push	ds
		push	si
		push	di

                mov     Ident , 0C0h
                mov     Ident+1 , 0     ; Free
@@Loop1:        mov     ah , cs:Ident
                xor     al , al

                xor     al , al
		int	2Fh
                cmp     al , 0FFh
                je      @@InUse

                test    cs:Ident+1 , 255        ; Save number if this is the
                jnz     @@Next                  ; first free number found
                mov     ah , cs:Ident
                mov     cs:Ident+1 , ah

@@Next:         inc     cs:Ident
                jnz     @@Loop1

                mov     al , cs:Ident+1         ; Exit of loop: look for free
                or      al , al                 ; multiplex number
                jz      @@NoNumber
                mov     cs:INT_2F_IDENT , al
                xor     ax , ax
                jmp     @@DI_Done

@@NoNumber:     push    cs
                pop     ds
                lea     ax , @@M1
                call    PrintString
                mov     ax , 4C01h
                int     21h
@@M1            db      'No free process number found between 0C0h and 0FFh',10,0

@@InUse:        cld                             ; Test offset of ID string
                cmp     bx , Offset PgmIdent    ; Take next number if test
                jne     @@Next                  ;    failed
		mov	cx , 255
		mov	di , bx
		push    cs
		pop	ds
		mov     si , Offset PgmIdent
		repne	cmpsb
                jne     @@Next
                mov     al , cs:Ident
                mov     cs:INT_2F_IDENT , al

@@InstanceFound:mov     ax , dx
@@DI_Done:
                pop     di
		pop	si
		pop	ds
		Leave
		ret
DetectInstance  EndP
;
;=============================================================================
;	Procedure 'Install' installs all interrupt vectors, prepares driver
;  for work and stays resident
;=============================================================================
;
Install         Proc    Near

		;--------------------------------------------------------;
		;   Init some variables in TSR part of this program      ;
		;--------------------------------------------------------;

		xor	ax , ax
		mov	DRV_X . DC_Options 	, al
		mov	DRV_Y . DC_Options 	, al

		lea	si , DRV_X	 ; Initialize tracking data
		call	DC_Init		 ; structures for both coordinates
		lea	si , DRV_Y
		call	DC_Init

		;--------------------------------------------------------;
		;   At first try to read configuration file TDRV.CFG     ;
		;   (It must be in the same directory as TDRV.EXE)       ;
		;--------------------------------------------------------;

		push	Offset @@CfgGrpDef	; Group definitions table
		push	Offset ConfigName	; File name
		push	ConfigOptions
		call	LoadIniFile		; Try to read file
		jc	@@1			; Jump if ERROR
		jmp	@@2
@@1:		push	Offset @@MC1		;
		call    PrintString
		mov     ax , 4C01h
		int	21h

@@MC1		db	'An error was occurred while reading '
                db      'configuration file. Instalation failed'
		db	10,0
@@MM1		db	'Mouse driver is not available',10,0
@@M_EmuMode	db      'WARNING: PC timer interrupts (IRQ 0) will be used to simulate',10
		db	'         telescope control card interrupts'
		db	10,0
@@CfgName	db	'TDRV.CFG',0
@@InstrDef	db	'INSTR.DEF',0

IDefHandle	dw	?

@@CfgGrpDef:    WInfo   MainGrp 	, 0 , '[Main]'
		WInfo   InterfaceGrp    , 0 , '[Interface]'
		WInfo   RTC_Grp         , 0 , '[RTC]'
		WInfo   Coord1Grp       , 0 , '[Coord1]'
		WInfo   Coord2Grp       , 0 , '[Coord2]'
		WInfo	LaserCtrlGrp	, 0 , '[LaserCtrl]'
		dw	0,0

	@@M111: db	'Reading instrument parameters file ',39
		db	'%s',39,10,0

        @@M112: db      'WARNING: ',7,'/NM command line option found',10
                db      'Skipping instrument model lookup',10,0

	@@2:	cmp	TIMER_IRQ.Num , 8
		jne	@@3
		push	Offset @@M_EmuMode
		call	_PrintF
		pop	ax

	@@3:	;--------------------------------------------------------;
		;   Load instrument theory file (TDRV.EXE uses only      ;
		;   first part of this file                              ;
		;--------------------------------------------------------;

		cmp     SkipModel , 0
                je      LoadModel
                push    Offset @@M112
                call    _PrintF
                pop     ax
                jmp     ModelDone

LoadModel:
		lea	bx , InstrDefPath
		call	ReadInstrModel
ModelDone:

	@@71:	;--------------------------------------------------------;
		;   Initialize hardware card                             ;
		;--------------------------------------------------------;

		INITTRACE
		mov	dx,P_ClearIRQ15 ; Clears IRQ15 line (if one is active)
		out	dx,OutRegister           ;
		out	80h, al
		BTRACE
		call	ReadCardStatus	; Added for compatibility with first
					; version of card
		call	InitializeTimer ; Perform 0.1 sec. timer initialization
					; Initializes all chanals of both
					; I8253 except one used for timer.

		;--------------------------------------------------------;
		;   Set coord. limits for both coordinates               ;
		;--------------------------------------------------------;

		push 	cs              ; Load ES:BX with address of the
		pop	es		; initial coordinate change interval
		lea	bx , MinX
		call	SetCoordLimits
		or	ax , ax
		je      @@81
		push	Offset @@E1
		push	ax
		call    _PrintF
		add     sp , 4
@@81:
		lea	si , DRV_X       ; Now set limits of hysteresis
		call	DC_ResetCoord	 ; arguments for both coordinates
		call	DC_ApplyHistLim  ; to be sure these arguments are
		lea	si , DRV_Y       ; set when any program is invoked
		call	DC_ResetCoord	 ; and alse reset coordinates to
		call	DC_ApplyHistLim	 ; to be sure that no unnecessary
					 ; steps will be done at startup
		call	LShootInit	 ; Initialize Laser triggering code

		;--------------------------------------------------------;
		;   Now look for mouse.                                  ;
		;--------------------------------------------------------;

		IF MO_SAVE Ne 0
		   mov     MoLength , 0
		   mov     word ptr MoBuffer , 0
		   mov	   word ptr MoBuffer+2 , 0
		ENDIF
		and     MOUSE_STAT , Not MOUSE_OK  ; Look for mouse and set
		mov	ax , 0000h		   ; bit MOUSE_OK if mouse
		int	33h			   ; driver is found.
		cmp	ax , 0FFFFh
		je      @@MouseOk
		push	Offset @@MM1
		call	PrintString
		jmp	@@Mouse_B

@@MouseOk:      IF MO_SAVE ne 0
		   mov	ax , 0015h		 ; Query buffer size for mouse
		   int	33h			 ; interrupt functions 16h and 17h
		   mov	MoLength , bx		 ; Buffer size
		   mov	ax , TSR_END             ; Store buffer address
		   mov  word ptr MoBuffer , ax   ; And add length to TSR
		   mov	word ptr MoBuffer+2 , cs ; length
		   add	TSR_END , bx
		ENDIF
		or	MOUSE_STAT , MOUSE_OK
@@Mouse_B:
		;---------------------------------------------------------;
		;  Now we can modify interrupt vectors                    ;
		;---------------------------------------------------------;

		push    IntTableAddr
		call    ReplaceVect     ; Set new interrupt vectors and
					; replace old ones
                mov     dx , P_ClearIRQ15
		out     dx , OutRegister
		out	80h , al
		call	ClearIRQ8	; Clear pending IRQ8 request (if any)

		;---------------------------------------------------------;
		;  Set window width for registrator                       ;
		;---------------------------------------------------------;

		mov	ax , word ptr dftWindow
		mov	dx , word ptr dftWindow+2
		call	SetWindow

		ret

@@E1		db	7,'Error %02X setting coordinate limits. Check values in file TDRV.CFG',10,0
Install		endp


StayResident	proc	near

		;--------------------------------------------------------;
		;   At first release environment space that is not       ;
		; necessary for TSR. After that we can exit to DOS       ;
		; leaving part of program resident in the memory.        ;
		;--------------------------------------------------------;

		call	FreeEnvSeg

		mov     bx , PspSeg     ; At first compute length of resident
		mov	dx , cs		; part of this program.
		sub	dx , bx

		mov	bx , TSR_END	; Get real TSR length together with
		add	bx , 15		; data and round up to full paragraph

		shr	bx , 4
		add	dx , bx

		push    dx              ; DX now contains (length of TSR+15)/16
		xor     ah , ah
		mov     al , INT_2F_IDENT
		push    ax
		shl     dx , 4          ; Shift it 4 bits left for output
		push    0               ; Push  start address (Last parameter)
		push    PspSeg          ; At first zero shift, then PSP segment
		push    dx              ; Push length of TSR in bytes
		push    Offset @@MemFmt ; Push format string address
		call    _PrintF         ; At least we can call _PrintF
		add     sp , 10         ; Clean stack after return from _PrintF
	IF IOTRACE Ne 0
			 push    Offset @@TraceMsg
			 call    PrintString
			 jmp     @@1
	      @@TraceMsg db 7,13,10,'I/O tracing is ON. Please rebuild '
			 db 'for faster ond smaller code',13,10,7,0
	      @@1:
	ENDIF

		pop     dx

		jmp	FinishLoading

@@MemFmt:       db      'TDRV.EXE is installed. %u bytes used at %04X:%04X'
		db      '   ID=0%02Xh',10,0

IF MO_SAVE NE 0
  MoLength	dw	0
ENDIF

StayResident		EndP
;
;=============================================================================
;	Procedure 'UnInstall' tries to remove resident copy of TDRV.EXE
;=============================================================================
;
UnInstall	PROC	NEAR
		ENTER	0,0
		push	es

		call	nosound
		test	TSR_PSP , 0FFFFh
		je	@@Done2

		mov	ax , 0C405h		; Reset driver
		mov     ah , INT_2F_IDENT
		int	02Fh

		push	TSR_SEG
		push    IntTableAddr
		call	RestoreVect
		or	ax , ax
		je	@@FreeTSR
@@Done2:        jmp     @@Done3
@@FreeTSR:	mov	es , TSR_PSP
		mov	ah , 49h
		int	21h
		push	Offset @@M1
		call	PrintString
@@Done3:	mov	ax , 4C01h
		int	21h
@@M1		db	'TDRV.EXE is removed from memory',10,0
UnInstall       ENDP
;
;=============================================================================
;	Group	[Main]
;=============================================================================
;
G_Main		proc	near
		retn

MainGrp:	WInfo   @@SetMaxAcc 	, 0 , 'MaxAcc'
		WInfo   @@SetMaxSpeed   , 0 , 'MaxSpeed'
		WInfo	@@Frequency	, 0 , 'Frequency'
		WInfo	@@EnableStpCnt  , 0 , 'EnableStepCount'
		WInfo	@@MaxRSTFq	, 0 , 'MaxRSTFq'
                WInfo   @@TimerIRQ      , 0 , 'TimerIRQ'
                WInfo   @@StrictIRQ15   , 0 , 'StrictIRQ15'
		WInfo   @@TimeSyncType  , 0 , 'TimeSyncType'
		WInfo   @@InstrType     , 0 , 'ModelType'
		WInfo   @@EmuMode	, 0 , 'EmulateTimerIRQ'
		WInfo	@@FastCPU       , 0 , 'FastCPU'
		WInfo   @@IO_Delay	, 0 , 'IO_Delay'
		WInfo	@@EnableIRQ12   , 0 , 'EnableIRQ12'
		dw      0,0

@@SetMaxAcc:    call	IL_ReadIntVar		; Processing 'MaxAcc=nnn'
		jc      @@Done1			; line in configuration file
		call    _SetMaxAcc
		jnc     @@Done1
		lea     ax , @@InvAccMsg
@@Done1:	retn

@@SetMaxSpeed:	call	IL_ReadIntVar		; Processing 'MaxSpeed=nnn'
		jc	@@Done1			; line in configuration file
		call	_SetMaxSpeed
		jnc	@@Done1
		lea	ax , @@InvMaxSpeed
		retn

@@Frequency:	call	IL_ReadLongVar
		jc	@@Done1
		or      dx , dx
		jl	@@Err1
		jne	@@1
		cmp	dx , 10000
		jl	@@Err1
@@1:            mov	bx , 10
		call	IDiv42
		mov	word ptr Frequency   , ax
		mov	word ptr Frequency+2 , dx
		clc
                retn
@@Err1:         stc
		lea     ax , @@InvFq
		jmp     @@Done1

@@EnableStpCnt: call	IL_ReadIntVar
		jc	@@5
		cmp	ax , 2
		jb      @@11
		lea	ax , @@InvFlg
		stc
	@@5:	jmp	@@Done1
	@@11:   and	HRDW_OPT , Not ENABLE_STEP_CNT
		cmp	ax , 0
		jz	@@12
		or	HRDW_OPT , ENABLE_STEP_CNT
	@@12:	clc
		retn

@@MaxRSTFq:	call	IL_ReadIntVar
		jc      @@5
		cmp	ax , 20
		jbe 	@@16
		cmp	ax , 3000
		ja      @@16
		push	dx
		cwd
		div	@@V0010
		mov	RST_FQ , ax
		pop	dx
		clc
		retn
	@@16:   lea     ax , @@RstFqMsg
                stc
		retn

@@TimerIRQ:     call    IL_ReadIntVar		; Read integer value
		jnc	@@21			; Not error: continue
		jmp     @@26
	@@21:	cmp     ax , 0Fh		; Check if in allowed range
		ja      @@25			; Error exit if outside
		push	bx                      ; Now look for compatibility
		mov	bx , ax			; (we must not to allow to
		cmp     @@tIrqMask [bx] , 1	; use interrupts that are
		jae	@@24			; used by standard PC devices)
		mov	ax , 010h		; Incorrect: set outside range
	@@24:	pop	bx
		cmp	ax , 0Fh		; Check again if <10h
		ja	@@25			; and exit if invalid
		cmp	TIMER_IRQ.Num , 8	; Check for previous
		je	@@23			;    EmulateTimerIRQ=1
		push    ax
		cmp	al , 8                  ; Now convert IRQ number to
		jb      @@1Half			; internal interrupt number:
	@@2Half:add     al , 068h               ;   00h-07h to 08h-0Fh
		mov	TIntMaskPort , 0A1h
		jmp     @@22			;   08h-0Fh to 70h-77h
	@@1Half:add	al , 008h
		mov	TIntMaskPort , 021h
	@@22:   mov     TIMER_IRQ.Num , al
		push	cx
		mov     cl , al
		and 	cl , 7
		mov     al , 1
		shl	al , cl
		mov	TIntMask , al
		pop	cx
		push    Offset @@IRQChangedMsg
		call    _PrintF
		add     sp , 4
	@@23:	clc
		retn
	@@25:   lea     ax , @@InvIRQNum
		stc
	@@26:   retn
  @@tIrqMask    db	0,0,0,1,0,1,0,0
		db      0,0,1,1,0,0,0,1

@@StrictIRQ15:	call	IL_ReadIntVar
		jc	@@36
		cmp	ax , 1
		ja	@@35
		and	HRDW_OPT , Not STRICT_IRQ15
		or	ax , ax
		jz	@@34
		or	HRDW_OPT , STRICT_IRQ15
	@@34:	clc
		jmp	@@36
	@@35:   lea     ax , @@InvFlg
		stc
	@@36:   retn

@@TimeSyncType: call	IL_ReadIntVar
		jc	@@36
		cmp	ax , 1
		jb      @@41
		cmp	ax , 2
		ja      @@41
		mov	TimeSyncType , ax
		clc
		retn
	@@41:	lea	ax , @@InvSyncType
	@@43:	stc
		retn

@@InstrType:	call	IL_ReadIntVar
		jc	@@36
	@@42:	mov	InstrType , ax
		clc
		retn

@@EmuMode:	call	IL_ReadIntVar
		jc	@@36
		cmp	ax , 0		; 0 - default (no emulation)
		je	@@42
		cmp	ax , 1
		je	@@EmuModeOn
		lea	ax , @@InvFlg
		stc
		retn
@@EmuModeOn:    mov	TIMER_IRQ.Num , 8   	; Change to PC timer interrupt
		mov	TIMER_IRQ.SaveMask , 0  ; We don't more need to save it
		mov	TIMER_IRQ.NewVectOff , Offset IRQ00
		mov	TIMER_IRQ.NewVectSeg , cs
		clc
		retn

; Configuration parameter 'FastCPU': allows to generate delays
; for fast CPUs (Pentiums e.t.c)

@@FastCPU:	call	IL_ReadIntVar
		jc      @@46
		cmp     ax , 0
		je	@@isSlow
		cmp	ax , 1
		je	@@isFast
    @@45A:	lea	ax , @@InvFlg
		stc
    @@46:	ret
    @@isSlow:   mov	IOWaitAddr , Offset DummyProc
		jmp	@@46
    @@isFast:   mov	IOWaitAddr , Offset IO_Wait
    @@47:	clc
		ret

@@IO_Delay: 	call	IL_ReadIntVar
		jc	@@46
		cmp	ax , 1
		jb	@@51
		cmp	ax , 100
		ja	@@51
		mov	IOWaitCnt , ax
		jmp	@@47
     @@51:      lea     ax , @@InvDelayCnt
		stc
		ret

@@EnableIRQ12:  call	IL_ReadIntVar
		jc	@@46
		cmp	ax , 0
		je	@@61
		cmp     ax , 1
		je      @@62
		jne     @@45A
     @@61:      mov	IRQ_0C.Num , 255
		cli
		ret
     @@62: 	mov	IRQ_0C.Num , 074h
		cli
		ret


@@IRQChangedMsg db      '0.1 second timer interrupt number is set to %2d',10,0

@@InvFq		db	'The value of frequency must be greater then 10000 Hz',0
@@InvAccMsg     db      'The value of <MaxAcc> must be in range 20...2000',0
@@InvMaxSpeed	db	'The value of <MaxSpeed> must be in range 100...14400',0
@@InvFlg	db	'The value must be 0 or 1',0
@@RstFqMsg	db	'The value must be in range 30...3000 Hz'
@@InvIRQNum     db      '0.1 sec. timer interrupt vector must be in range 8...15',0
@@InvSyncType   db	'Allowed values for TimeSymcType are 1 (second) and 2 (minute)',0
@@InvDelayCnt   db	'Allowed values for FastCPUDelay are in range from 1 to 100',0

@@V0010         dw      10

G_Main		endp
;
;=============================================================================
;	Group <Interface>
;=============================================================================
;
G_Interface	proc	near	; Fictious procedure
		retn

InterfaceGrp:	WInfo   @@KbSensitivity	, 0 		, 'KbSensitivity'
		WInfo   @@MoSensitivity , 0 		, 'MouseSensitivity'
                WInfo   @@jsSensitivity , 0             , 'JoystickSensitivity'
		WInfo   @@MaxCorrection , 0 		, 'MaxCorrection'
	;------------------  Orientation of the field of view ----------------
		WInfo   @@VF_Coeff      , 1             , 'VFCoeff1'
		WInfo	@@VF_Coeff	, 2 		, 'VFCoeff2'
		WInfo	@@VF_Div	, 1 		, 'VFDiv1'
		WInfo	@@VF_Div	, 2 		, 'VFDiv2'
		WInfo	@@VFArgShift	, 0 		, 'VFArgShift'
		WInfo	@@VFDShift	, 0 		, 'VFDShift'
		WInfo   @@VFSetBit 	, FO_SEL_COORD  , 'VFSelCoord2'
		WInfo   @@VFSetBit	, FO_XINV	, 'VFInvX'
		WInfo	@@VFSetBit	, FO_YINV	, 'VFInvY'
		WInfo	@@VFSetBit	, FO_INVARG	, 'VFInvArg'
	;----------- The description of joystick related options -------------
		WInfo	@@EnableJoystick, 0             , 'EnableJoystick'
		WInfo   @@JSSetBit      , J_INVERT_X    , 'JInvertX'
		WInfo   @@JSSetBit      , J_INVERT_Y    , 'JInvertY'
		WInfo   @@jcWidth       , 0             , 'jcWidth'
	;----------- Unused kept for compatibility only ----------------------
		WInfo	@@jWidth2       , 0             , 'jWidth2'
		dw	0,0

	;-----------------------------------------------------------;
	;  KbSensitivity  = <n>                                     ;
	;  Sets numeric keypad sensitivity while tracking.          ;
	;  Value 1 corresponds 10" per second ?                     ;
	;-----------------------------------------------------------;

@@KbSensitivity:call    IL_ReadIntVar
		jc	@@Done1
		cmp	ax , 1
		jl	@@Err1
		cmp	ax , 8000
		jg	@@Err1
		mov 	kbSensitivity , ax
		jmp	@@Ok

	;-----------------------------------------------------------;
	;  MouseSensitivity = <n>                                   ;
	;-----------------------------------------------------------;

@@MoSensitivity:call	IL_ReadIntVar
		jc	@@Done1
		cmp	ax , 1
		jl	@@Err2
		cmp	ax , 8000
		jg	@@Err2
		mov     moSensitivity , ax
@@Ok:		clc
		jmp	@@Done1
@@Err1:		lea	ax , @@M01
		jmp	@@Failed
@@Err2:         lea	ax , @@M02
		jmp	@@Failed
@@Err3:         lea     ax , @@M03
@@Failed:	stc
@@Done1:	retn

	;-----------------------------------------------------------;
        ;  JoystickSensitivity = <n>                                ;
	;-----------------------------------------------------------;

@@jsSensitivity:call    IL_ReadIntVar
                jc      @@Done1
                or      ax , ax
                je      @@VF06
                cmp     ax , 255
                ja      @@VF06
                mov     jsSensitivity , ax
                clc
                retn
        @@VF06: lea     ax , @@M08
		jmp     @@Failed

@@jWidth2:	call	IL_ReadIntVar
		jc      @@Done1
		cmp	ax , 256
		jbe	@@ja3
	@@ja1:	lea	ax , @@M08
	@@ja2:	stc
		retn
	@@ja3:	mov	jWidth2 , ax
		clc
		ret

        ;-----------------------------------------------------------;
	;  VFCoeff1 = <n1>                                          ;
	;  VFCoeff2 = <n2>                                          ;
	;-----------------------------------------------------------;

@@VF_Coeff:     push	dx
		call	IL_ReadIntVar
		pop	dx
		jc      @@Done1
		cmp	ax , 1
		jg	@@Err3
		cmp	dx , 2
		je	@@VF_Second
@@VF_First:	and	f_Options , Not (FO_XDEF+FO_XSIGN)	; clear bits
		or	ax , ax
		je	@@Ok               		;    0*X
		jg 	@@VF12
@@VF11:         or	f_Options , FO_XDEF+FO_XSIGN    ;    -X
		jmp	@@Ok
@@VF12:		or	f_Options , FO_XDEF             ;    +X
@@VF13:		jmp	@@Ok
@@VF_Second:	and	f_Options , Not (FO_YDEF+FO_YSIGN)
		or	ax , ax
		je	@@VF13               		;    0*X
		jg 	@@VF22
@@VF21:         or	f_Options , FO_YDEF+FO_YSIGN    ;    -X
		jmp	@@Ok
@@VF22:		or	f_Options , FO_YDEF             ;    +X
		jmp	@@Ok

;-----------------------------------------------------------------------------

@@VF_Div:       call	IL_ReadIntVar   ;*************************************
@@VF30:		jc      @@Done1		;*    VFDiv1=<n>                     *
		cmp	ax , 10		;*    VFDiv2=<n>                     *
		jl      @@Err6		;* Defines number of steps in 1ø.    *
		push	dx		;* These variables is being used to  *
		push	bx		;* compute position angle for coord. *
		cwd			;* system transformation to take     *
		mov	bx , 10		;* the orientation of field of view  *
		div	bx		;* into account.                     *
		pop	bx		;*************************************
		pop	dx
		cmp	dx , 2
		je	@@VF31
		mov     f_divX , ax
		jmp	@@Ok
@@VF31:         mov	f_divY , ax
		jmp	@@Ok
@@Err6:		stc
		lea	ax , @@M06
		jmp	@@Done1

	;----------------------------------------------------------;
	;   VFArgShift = <n>                                       ;
	;----------------------------------------------------------;

@@VFArgShift:	call	IL_ReadIntVar
		jc	@@VF30
		mov	f_argShift , ax
		jmp	@@Ok

	;----------------------------------------------------------;
	;   VFDShift = <n>                                         ;
	;----------------------------------------------------------;

@@VFDShift:	call	IL_ReadIntVar
		jc	@@VF30
		mov	f_dShift , ax
		jmp	@@Ok

	;----------------------------------------------------------;
	;   MaxCorrection = <n>                                    ;
	;----------------------------------------------------------;

@@MaxCorrection: call	IL_ReadIntVar
		jc	@@VF30
		cmp     ax , 5
		jng     @@Err4
		cmp	ax , 600
		jg	@@Err4
		cwd
		mov	bx , 10
		div     bx
		call	lshift8
		mov	word ptr f_cHigh   , ax
		mov	word ptr f_cHigh+2 , dx
		call	lneg
		mov	word ptr f_cLow    , ax
		mov	word ptr f_cLow+2  , dx
		jmp	@@Ok
@@Err4:		stc
		lea     ax , @@M04
@@VF32:		jmp	@@Done1

	;----------------------------------------------------------;
	;   VFEnableRotation = < 0 | 1 >                           ;
	;   ...							   ;
	;----------------------------------------------------------;

@@VFSetBit:     push	dx		; DX contains bit mask in options word
		call	IL_ReadIntVar
		pop	dx
		jc	@@VF32
		cmp	ax , 0
		jl      @@Err5
		cmp	ax , 1
		jg	@@Err5
		not	dx
		and	f_Options , dx
		not	dx
		or	ax , ax
		jz	@@VF33
		or	f_Options , dx
@@VF33:         jmp	@@Ok
@@Err5:		stc
		lea     ax , @@M05
		jmp	@@Done1


	;----------------------------------------------------------;
	;   JSInvertX = < 0 | 1 >                                  ;
	;   ...							   ;
	;   Sets or clear bit in <jOptions>
	;----------------------------------------------------------;

@@JSSetBit:     push	dx		; DX contains bit mask in options word
		call	IL_ReadIntVar
		pop	dx
		jc	@@VF32
		cmp	ax , 0
		jl      @@Err5
		cmp	ax , 1
		jg	@@Err5
		not	dx
		and	jOptions , dx
		not	dx
		or	ax , ax
		jz	@@VF33
		or	jOptions , dx
@@JS33:         jmp	@@Ok


@@EnableJoystick: call  IL_ReadIntVar
		jc      @@VF43
		cmp	ax , 1
		ja      @@VF42
		and	HRDW_OPT , Not ENABLE_JOYSTICK
		or	ax , ax
		jz	@@VF41
		or	HRDW_OPT , ENABLE_JOYSTICK
	@@VF41: clc
		retn
	@@VF42: lea     ax , @@M05
		stc
	@@VF43: retn


@@jcWidth:      call    IL_ReadIntVar
		jc      @@VF52
		cmp     ax , 50
                ja      @@VF51
                or      ax , ax
                je      @@VF51
                mov     jcWidth , ax
                clc
                retn
        @@VF51: stc
                lea     ax , @@M07
        @@VF52: retn


@@M01		db	'The value of <KbSensitivity> must be in range 1...8000',0
@@M02		db	'The value of <MouseSensitivity> must be in range 1...8000',0
@@M03		db	'Only values -1,0,1 are allowed',0
@@M04		db	'Must be in range 5...600',0
@@M05		db	'Only values 0,1 are allowed',0
@@M06		db	'The value must be greater that 10',0
@@M07           db      'The value must be in range 1...50',0
@@M08           db      'The value must be in range 1...255',0
G_Interface	endp
;
;=============================================================================
;      Group  	[RTC]
;=============================================================================
;
Grp_RTC		proc	near
		retn

RTC_Grp:        WInfo	@@Enable	, HRDW_OPT	, 'Enable'
		WInfo   @@RTC_Funct     , 0             , 'RTCFunct'
		WInfo	@@BeepLen	, 0		, 'BeepLen'
		WInfo	@@BeepFq	, 0		, 'BeepFq'
		dw	0,0

@@Enable:       push	cx
		mov	cx , ENABLE_BEEPS
		call    IL_SetFlagsW
		pop	cx
		retn

@@RTC_Funct:    call	IL_ReadIntVar
		jc	@@Done
		or	ah , ah
		jnz     @@Err1
		mov	RTC_Funct , al
@@Ok:		clc
@@Done:         retn
@@Err1:		stc
		lea	ax , @@M01
		jmp	@@Done

@@BeepLen:      call	IL_ReadIntVar
		jc	@@Done
		cmp	ax , 100
		jae     @@Err2
		cmp	ax , 2
		jb	@@Err2
		mov	BeepLen , ax
		jmp	@@Ok
@@Err2:         stc
		lea	ax , @@M02
		jmp	@@Done

@@BeepFq:	call	IL_ReadIntVar
		jc	@@Done
		cmp	ax , 100
		jb	@@Err3
		cmp	ax , 15000
		ja	@@Err3
		mov	BeepFq , ax
		jmp	@@Ok
@@Err3:         stc
		lea	ax , @@M03
		jmp	@@Done

@@M01:		db	'RTC function number must be in range 0...255',0
@@M02:		db	'Beep length must be in range 2...100 ms',0
@@M03:          db	'Beep frequency must be in range 100...15000 Hz',0
Grp_RTC		endp
;
;=============================================================================
;	Groups	[Coord1] and [Coord2]
;=============================================================================
;
;		WInfo   Coord1Grp       , 0 , '[Coord1]'
;		WInfo   Coord2Grp       , 0 , '[Coord2]'
Grp_Coord	proc	near
@@Done:		retn

@@DestAddr      dw	?
@@W1		dd	0,0

Coord1Grp:	WInfo   @@CLimits	, MinX    , 'Limits'
		WInfo	@@InvSign	, DRV_X   , 'InvertSign'
                WInfo	@@UnitsPerDg	, X_UPD	  , 'UnitsPerDg'
		WInfo	@@C_Start 	, DescrX  , 'C_Start'
		WInfo	@@C_Period	, DescrX  , 'C_Period'
		WInfo	@@C_Step	, DescrX  , 'C_Step'
		WInfo   @@C_Count	, DescrX  , 'C_Count'
		WInfo   @@InvertLC      , DRV_X   , 'InvertLC'
		WInfo   @@hWidth	, HistWX  , 'hWidth'
		dw      0,0

Coord2Grp:	WInfo	@@CLimits	, MinY    , 'Limits'
		WInfo	@@InvSign	, DRV_Y   , 'InvertSign'
		WInfo	@@UnitsPerDg	, X_UPD	  , 'UnitsPerDg'
		WInfo	@@C_Start 	, DescrY  , 'C_Start'
		WInfo	@@C_Period	, DescrY  , 'C_Period'
		WInfo	@@C_Step	, DescrY  , 'C_Step'
		WInfo   @@C_Count	, DescrY  , 'C_Count'
		WInfo   @@InvertLC      , DRV_Y   , 'InvertLC'
		WInfo   @@hWidth	, HistWY  , 'hWidth'
		dw      0,0

	;--------------------------------------------------------;
	;   [Coord.]  : CLimits = { <LowLimit> , <HighLimit> }   ;
	;--------------------------------------------------------;

@@CLimits:      mov	@@DestAddr,dx	; Save destination address
		mov	cx , 2
		lea	dx , @@W1
		call	IL_GetLongArray
	@@11:	jc	@@14
		mov	ax , word ptr @@W1   	; Load lower limit
		mov	dx , word ptr @@W1+2
		cmp	dx , word ptr @@W1+6
		jg      @@Err1
		jl	@@12
		cmp	ax , word ptr @@W1+4
		jae	@@Err1
	@@12:	call	@@Shl8
		jc      @@11
		push	si
		mov	si , @@DestAddr
		mov	word ptr [si]   , ax
		mov	word ptr [si+2] , dx
		mov     ax , word ptr @@W1+4
		mov	dx , word ptr @@W1+6
		call	@@Shl8
		mov	word ptr [si+4] , ax
		mov	word ptr [si+6] , dx
		pop	si
		jc	@@11
		clc
		retn
	@@Err1: stc
		lea     ax , @@M01
	@@14:	jmp	@@Done
	@@Shl8: cmp	dx , 0007Fh
		jg	@@Err2
		cmp	dx , 0FF80h
		jl	@@Err2
		call	lshift8
	@@10:	clc
		retn
	@@Err2: lea	ax , @@M02
	@@16:	stc
	@@17:	retn

	;--------------------------------------------------------;
	;  [Coord.]  : InvSign = { 0 | 1 }                       ;
	;--------------------------------------------------------;

@@InvSign:      mov	@@DestAddr , dx	   ; Save address of <DrvCoord> struct
		call    IL_ReadIntVar	   ; Read integer number
		jc	@@17		   ; Exit when syntax error
		cmp     ax , 2
		jb      @@20
		lea     ax , @@M03
		jmp	short @@16
	@@20:	push	si
		mov	si , @@DestAddr
		or	ax , ax
		jnz     @@22
	@@21:	and	[si].DC_Options , Not DC_InvertSign
		jmp	short @@23
	@@22:	or	[si].DC_Options , DC_InvertSign
	@@23:	pop	si
		jmp	@@10

	;--------------------------------------------------------;
	;  [Coord?] : UnitsPerDg = <value>                       ;
	;  Specifies number of driver coord. units per degree    ;
	;  (steps per ø times 256)                               ;
	;--------------------------------------------------------;

@@UnitsPerDg:	mov	@@DestAddr , dx
		call    IL_ReadLongVar
		jc	@@26
		cmp	dx , 0100h
		ja	@@25
		or	dx , dx
		je      @@25
		push	bx
		mov	bx , @@DestAddr
		mov     word ptr [bx] , ax
		mov 	word ptr [bx+2] , dx
		pop	bx
		clc
		ret
	@@25:   lea	ax , @@M07
		stc
	@@26:	ret

	;--------------------------------------------------------;
	;  [Coord.] : C_Start = <value>                          ;
	;  Specifies value of base coordinate for computation    ;
	;  of corrections due to drive error.                    ;
	;  Must be <long int> number in range {-2^23+1...2^23-1} ;
	;--------------------------------------------------------;

@@C_Start:      mov	@@DestAddr , dx
		call	IL_ReadLongVar
		jc	@@31
		lpush
		call	labs
		cmp	dx , 07FFh
		lpop
		jae     @@32
		call	lshift8
		push    bx
		mov	bx , @@DestAddr
		lstore  [bx].CoordRStart
                pop     bx
		clc
	@@31:	retn
        @@32:   lea     ax , @@M02
                stc
                retn

	;--------------------------------------------------------;
	;  [Coord.] : C_Period = <long int value>                ;
	;--------------------------------------------------------;

@@C_Period:	mov	@@DestAddr , dx
		call	IL_ReadLongVar
		jc	@@49
		or	dx , dx
		jle	@@48
		cmp	dx , 007Fh
		ja	@@48
		call	lshift8
                push    bx
		mov	bx , @@DestAddr
		lstore  [bx].CoordRPeriod
                pop     bx
		clc
		ret
	@@48:	lea	ax , @@M04
		stc
	@@49:	retn

	;--------------------------------------------------------;
	;  [Coord.] : C_Step = <long int value>                  ;
	;--------------------------------------------------------;

@@C_Step:	mov	@@DestAddr , dx
		call    IL_ReadLongVar
		jc	@@59
		or	dx , dx
		jl	@@58
		jne	@@51
		or	ax , ax
		je      @@58
	@@51:	cmp	dx , 007Fh
		ja	@@58
		call	lshift8
                push    bx
		mov	bx , @@DestAddr
		lstore  [bx].CoordRStep
                pop     bx
		clc
		ret
	@@58:	lea	ax , @@M05
		stc
	@@59:	ret

	;--------------------------------------------------------;
	;  [Coord.] : C_Count = <positive int value>             ;
	;--------------------------------------------------------;

@@C_Count:	mov	@@DestAddr , dx
		call	IL_ReadIntVar
		jc	@@63
		or      ax , ax
		jle	@@61
		cmp	ax , 361
		jb	@@64
	@@61:	lea	ax , @@M06
	@@62:	stc
	@@63:	retn
        @@64:   inc     ax
                push    bx
                mov     bx , @@DestAddr
		mov	[bx].CoordRSize , ax
                pop     bx
		clc
		ret

@@InvertLC:     mov     @@DestAddr , dx
		call    IL_ReadIntVar
                jc      @@63
                cmp     ax , 0
                je      @@71
                cmp     ax , 1
                je      @@71
                lea     ax , @@M03
                stc
                retn
        @@71:   push    bx
		mov     bx , @@DestAddr
                and     byte ptr [bx].DC_Options , Not DC_InvertLC
                or      ax , ax
		jz      @@72
                or      byte ptr [bx].DC_Options , DC_InvertLC
        @@72:   pop     bx
                clc
	@@73:	retn

@@hWidth:       mov     @@DestAddr , dx
		call	IL_ReadLongVar
		jc	@@73
		cmp	dx , 2
		jae     @@84
		cmp	dx , 0
		jne     @@81
		cmp	ax , 100
		jb	@@84
	@@81:	push	bx
		mov	word ptr [bx] , ax
		mov	word ptr [bx+2] , dx
		pop	bx
		clc
		retn
	@@84:	lea	ax , @@M08
		stc
		retn

@@M01	db 'Lower limit is greater or equal th upper one',0
@@M02	db 'The number is out of range -8388608...8388607',0
@@M03	db 'Only values 0 and 1 is allowed',0
@@M04	db 'The number must be in range 256...8388607',0
@@M05	db 'The number must be in range 1...8388607',0
@@M06	db 'The number must be in range 1...360',0
@@M07	db 'The number must be in range 65536...16777215',0
@@M08   db 'The value must be in range 100...131071',0
Grp_Coord	endp
;
;=============================================================================
;	Groups	[LaserCtrl]
;=============================================================================
;
GrpLC		proc	near
LaserCtrlGrp:   WInfo   @@l_Enable      , HRDW_OPT      , 'Enable'
		WInfo   @@l_fq 		, 0 		, 'Period'
		WInfo	@@l_align       , 0 		, 'Align'
		WInfo	@@l_window	, 0 		, 'Window'
		WInfo   @@l_window_step , 0             , 'WindowStep'
		WInfo	@@l_GateMask	, 0 		, 'GateMask'
		dw	0,0

		;############################################################
@@l_Enable:	push	cx
		mov	cx , ENABLE_LASER_CTRL
		call	IL_SetFlagsW
		pop	cx
		retn

		;############################################################
@@l_fq:		call    IL_ReadIntVar		; 'Period = <int number>'
		jc      @@Done			;
		cmp	ax , 1                  ; Sets default laser shooting
		jl      @@Err1			; period. The unit here is 0.1
		cmp	ax , 100		; second.
		jg	@@Err1			; The default value is 10
		mov	dftLaserPeriod , ax	;      (1.0 second)
		mov     LIncrTime , cx
		clc
		jmp	@@Done
@@Err1:		lea	ax , @@M01
		stc
@@Done:		retn
		;############################################################
@@l_align:	call	IL_ReadIntVar		; 'Align = <int number>'
		jc	@@Done                  ;
		cmp	ax , 1                  ; Specifies first shoot time
		jb	@@Err2			; alignment in units of 0.1 sec
		cmp	ax , 600		;   1 - any 0.1 sec.
		ja	@@Err2			;  10 - start from next full
		mov	ShootAlign , ax		;       second (default)
		clc
		jmp	@@Done
@@Err2:		lea	ax , @@M02
@@ErrX:		stc
		jc	@@Done
		;############################################################
@@l_window:	call	IL_ReadLongVar          ; 'Window = <long number>'
		jc	@@Done			;
		cmp	dx , fqWin              ; Sets default registrator
		jae	@@Err3			; window in nanoseconds
		mov	word ptr dftWindow  ,ax ; The only test here is that
		mov	word ptr dftWindow+2,dx ; dftWindow/fqWin<=65535
@@Done2:	clc
		jmp	@@Done
@@Err3:         lea	ax ,@@M03
		jmp	short @@ErrX
		;############################################################
@@l_window_step:call	IL_ReadIntVar          ; 'WindowStep = <int number>'
		jc      @@ErrX
		mov	fqWin , ax
		clc
		retn
		;############################################################
@@l_GateMask:	call	IL_ReadIntVar
		jc	@@ErrX
		cmp	ax , 3
		ja	@@Err4
		shl	al , 4
		mov     GateMask , al
		jmp	short @@Done2
@@Err4:		lea	ax , @@M04
		jmp	short @@ErrX

@@M01		db	'Invalid laser shooting period. Must be in range 1...100 (in units of 0.1 seconds)'
@@M02		db	'The number is out of range 1...600'
@@M03		db	'The value of default window width is too large'
@@M04		db	'The value of gate mask must be in range 0...3'

GrpLC		endp
;
;=============================================================================
;	IL_SetFlagsB
;=============================================================================
;
IL_SetFlagsB	proc	near
		push	dx
		call	IL_ReadIntVar
		pop	dx
		jc	@@Done
		cmp	ax , 2
		jb	@@1
		lea	ax , M_InvBit
		stc
	@@Done:	ret
	@@1:    push	bx
		not	cl
		mov	bx , dx
		and	[bx] , cl
		not	cl
		or	ax , ax
		jz	@@2
		or	[bx] , cl
	@@2:	pop	bx
		clc
		ret
IL_SetFlagsB	endp


IL_SetFlagsW	proc	near
		push	dx
		call	IL_ReadIntVar
		pop	dx
		jc	@@Done
		cmp	ax , 2
		jb	@@1
		lea	ax , M_InvBit
		stc
	@@Done:	ret
	@@1:    push	bx
		not	cx
		mov	bx , dx
		and	[bx] , cx
		not	cx
		or	ax , ax
		jz	@@2
		or	[bx] , cx
	@@2:	pop	bx
		clc
		ret
IL_SetFlagsW	endp

M_InvBit	db	'The value must be 0 or 1',0
;
;=============================================================================
;	End of segment
;=============================================================================
;
_TEXT		EndS
		END
