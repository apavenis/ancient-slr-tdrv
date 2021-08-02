StackSize	=       512	; Stack size in words. Used only if
				; SwitchStack Ne 0
SwitchStack     =       1	; Requests stack switching in IRQ 15 when
				; not 0

		.286
                locals

                .XList
                include LIB.INC
                include TDRV.INC
		include	ARITH.INC
		include HARDWARE.INC
                include DBGSTRCT.INC
		.List

_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT

;=============================================================================

BeepRequested	db	0
TDfStat		db	0
RqRTCL		db	0

		;---------------------------------------------------------;
		;    Double word that contains current time counter.      ;
		; Contains count of 0.1 seconds interrupt measured from   ;
		; midnight.                                               ;
		;---------------------------------------------------------;

CURR_TIME       dd      ?
BASE_MJD        dd      ?       ; Address must be CURR_TIME+4

PREV_TIME       dd      ?

TimeSyncType	dw	1

TS_Index	dw	0
TS_MaxInd	dw      5
DisableFlag     db      0

;--------------------------------------
;FP_SAVE	db	94 dup (?)
;TickFq         dq      1193180.0       ; 18.2064819335938
;V_00010	dw	10
;--------------------------------------

IRR2            db      0

;=============================================================================
;       Procedure <IRQ00> is invoked by PC timer (18.2Hz) timer interrupts
;  in interrupt emulation mode to avoid use of IRQ 15 (int 77h). Procedure
;  TIMER_PROC in this case is called from <IRQ00> instead.
;=============================================================================

IRQ00		proc	far
		cli
		pushf
		call	dword ptr cs:TIMER_IRQ.OldVect
		endp
	;  Now previous IRQ 0 handler is called and we may proceed to
	;  TIMER_PROC

;=============================================================================
;       Procedure <TIMER_PROC> is invoked by 0.1 second timer interrupt.
;  The real interrupt number used depends on command line (IRQ 12 = INT 74
;  when option '/IRQ12' is specified or IRQ 15 = INT 77 when option '/IRQ15'
;  or none is specified when installing TDRV.EXE.
;       <TIMER_PROC> saves registers in the stack and invokes procedure
;  which index is specified in <TimerIndex>. All actions to send the EOI
;  signal to the interrupt controller is done by this program. The index must
;  be in range 0...7 (or it is reduced to this range). Register DS is set
;  equal to CS at the start (so the procedure called from this one may
;  not take care on this).
;=============================================================================


TIMER_PROC      proc	far
		cli

	IF SwitchStack Ne 0
		push    ax			; Save AX in old stack
		test	CS:StackSwitched , 255	; Look if IRQ 15 is already
		jz      @@S1			; active. This situation
	  @@S0: cmp	TIMER_IRQ.Num , 8
		je	@@S5
		mov     al , 20h		; cannot be ocurred under
		out     020h , al		; normal program work.
		jmp     $+2			; If this situation took place
		out     0A0h , al		; we have to return from IRQ
	  @@S5: pop     ax			; immediatelly (of course
		iret				; interrupt request must be
						; reset).

		;-----------------------------------------------------;
		;  Perform check if we are really processing correct  ;
		;  hardware interrupt.                                ;
		;-----------------------------------------------------;

	  @@S1: test	cs:HRDW_OPT , STRICT_IRQ15
		jz	@@S3
		cmp	TIMER_IRQ.Num , 8	; Skip test for PC timer IRQ
		je	@@S3

		push	dx
		mov	dx , CS:TIntMaskPort
		and	dx , 0FEh
		mov	al , 00Bh
		out	dx , al
		jmp	short $+2
		jmp 	short $+2
		in	al , dx
		and	al , CS:TIntMask
		cmp	al , 1
		jae	@@S2
		pop	dx
		jmp	@@S0
	 @@S2:	pop	dx

	 @@S3:  mov     CS:OldStack_Seg , ss	; OK to switch stack:
		mov     CS:OldStack_Off , sp	; Save old values of SS & SP
		mov     ax , cs			; and replace the stack with
		mov     ss , ax			; internal one.
		mov     sp , Offset IRQ_StackTop
		mov     CS:StackSwitched , 1
	ENDIF

		pusha                   ; Push all GPR in the stack

		push	ds		; Save segment registers DS and ES
		push	es		; in the stack

		push	cs		; Set DS equal to CS
		pop	ds

		test	LAS_TRIG , LAS_TRIG_REQUESTED
		jz	@@L1
		and	LAS_TRIG , not LAS_TRIG_REQUESTED
		or	LAS_TRIG , LAS_TRIG_DONE

	 @@L1:  call	OutputHrdwData

		call    GetTime0        ; Get time and store it

		stc
		rcl	TDfStat , 1
		test	TDfStat , 32
		jz	@@11
		cmp     TimerIndex , 0
		jne	@@11

		push	cx
		push	ax
		push	dx
		sub	ax , word ptr irqStart
		sbb	dx , word ptr irqStart+2
		push    ax
		push	dx
		mov	bx , word ptr irqDiffMin
		mov	cx , word ptr irqDiffMin+2
		call	lsort2
		mov	word ptr irqDiffMin   , ax
		mov	word ptr irqDiffMin+2 , dx
		pop     dx
		pop     ax
		mov	bx , word ptr irqDiffMax
		mov	cx , word ptr irqDiffMax+2
		call	lsort2
		mov	word ptr irqDiffMax   , bx
		mov	word ptr irqDiffMax+2 , cx
		pop	dx
		pop	ax
		pop	cx

	@@11:   mov	word ptr irqStart   , ax
		mov	word ptr irqStart+2 , dx
		mov	word ptr irqStart+4 , cx
		mov	word ptr irqStart+6 , 0

		IRQTIME

		mov	BeepRequested , 0

		call	ReadCardStatus	; Read full second bit and zero points
		mov	HR_Stat , al	; status from hardware and save it
					; for later use.

		cmp	TIMER_IRQ.Num , 8
		jz	@@12
		cli
		mov     dx,P_ClearIRQ15 ; Clears IRQ15 line (of course if one
		out	dx,OutRegister	; is set)
		out	80h, al
		jmp     short $+2       ; Waste some time before next I/O
		jmp	short $+2
		mov	dx , TIntMaskPort
		and	dx , 0FEh
		mov     al , 0Bh        ; Request ISR from second interrupt
		out     dx , al         ; controller
		jmp     short $+2       ; Waste some time once more
		jmp     short $+2
		and	DRV_STAT , Not HARDWARE_IRQ15
		in      al , dx         ; Read ISR from interrupt controller
		and	al , TIntMask
		cmp	al , 1
		jb	@@12
		or	DRV_STAT , HARDWARE_IRQ15
		mov     al , 20h        ; At least send End Of Interrupt
		cmp	dx , 023h
		jb	@@12A
		out	020h , al	; signal to both interrupt controlers
		jmp     short $+2       ; We have to do it if the interrupt
		jmp     short $+2       ; really is caused by IRQ 15
       @@12A:	out	dx , al
       @@12:    sti

		call	RTC_Check	; Check if sound effects are working
					; and turn them of if not

		call	UpdateTimer

		mov     bx , TimerIndex   ; Get index of procedure that must
		or      bx , bx           ; If not tracking then skip test
		jnz     @@13              ; for disable flag
		test    DisableFlag , 255 ; Look if tracking is disabled
		jnz     @@14
       @@13:    and     bx , 7            ; be called. Make sure that the
		shl	bx , 1		  ; is correct and invoke the procedure.
		call    word ptr TimerTable [bx]

       @@14:    call    GetTime0
		mov	word ptr irqEnd   , ax
		mov	word ptr irqEnd+2 , dx
		mov	word ptr irqEnd+4 , cx
		mov	word ptr irqEnd+6 , 0

		test	HRDW_OPT , ENABLE_BEEPS
		jz	@@99

		call	LookForBeeps

	@@99:	pop	es	; Restore all registers to the old values
		pop	ds	; and return from IRQ
		popa

	IF SwitchStack Ne 0
		cli
		mov     CS:StackSwitched , 0
		mov     ss , cs:OldStack_Seg
		mov     sp , cs:OldStack_Off

		pop     ax
	ENDIF
		sti
		iret
TIMER_PROC	endp

TimerIndex	dw	0
TM_ResetRq	db	0
SkipBeep        dw      0

TimerTable	dw      DoStep
		dw	DoTimerInit
		dw	FullMinuteSync
		dw	DummyProc
		dw	DummyProc
		dw	DummyProc
		dw	DummyProc
		dw	DummyProc

TimerMask	db      ?


LookForBeeps	proc	near
		test    IsWindows , 255
                jnz     @@TestDone
                test    SkipBeep , 255
		jz      @@11
		and     SkipBeep , 00Fh
		dec     SkipBeep
		jmp     @@NoSecBeep
@@11:           mov     al , RTC_Funct
		cmp	al , BEEP_ON_IRQ
		je      @@DoSecBeep
		cmp	al , BEEP_FSEC_H
		je	@@TestHrdwBeep
		cmp	al , BEEP_FMIN_S
		je	@@TestMinBeep
		cmp	al , BEEP_FSEC_S
		jne     @@NoSecBeep
		jmp     @@TestSoftBeep

@@TestMinBeep:	mov	bx , 600
		call	@@B1
		cmp	dx , 8
		jnc	@@12
		shl	dx , 8
		mov	ax , BeepFq
		add	ax , dx
		call	sound
		retn
@@12:           jne     @@13
		call	nosound
@@13:		retn

@@TestSoftBeep:	mov	bx , 10
		call	@@B1
		or	dx , dx
		jne	@@NoSecBeep
		je      @@DoSecBeep

@@TestHrdwBeep: test	HR_Stat , 1
		jnz	@@NoSecBeep
@@DoSecBeep:    or	BeepRequested , 255
@@NoSecBeep:    test	BeepRequested , 255
                jz      @@TestDone
                call    DoBeep
@@TestDone:     retn

@@B1:		mov	ax , word ptr PREV_TIME+2
		xor	dx , dx
		div	bx
		mov	ax , word ptr PREV_TIME
		div	bx
		retn
LookForBeeps	endp

;*****************************************************************************
;
;       Procedure :   UpdateTimer
;
;	This procedure increments timer and sets MIDNIGHT_FOUND flag in
;    DRV_STAT when necessary. The timer is not reset to 0 after midnight
;    automatically! This procedure is called while processing 0.1 sec. timer
;    interrupt from <DoStep>
;
;*****************************************************************************

UpdateTimer     proc	near

		;-----------------------------------------------------;
		;    Save current time in field PREV_TIME             ;
		;-----------------------------------------------------;

		mov	ax , word ptr CURR_TIME
		mov	dx , word ptr CURR_TIME+2
		mov     word ptr PREV_TIME   , ax
		mov     word ptr PREV_TIME+2 , dx

		;-----------------------------------------------------;
		;    Increment current time counter                   ;
		;-----------------------------------------------------;

		add	word ptr CURR_TIME , 1
		adc	word ptr CURR_TIME+2 , 0

		;-----------------------------------------------------;
		;    Set flag TIMER_INT_DETECTED and if necessary     ;
		; FULL_SECOND_DETECTED too. Full second detection is  ;
		; hardware dependant.                                 ;
		;-----------------------------------------------------;

		or	DRV_STAT , TIMER_INT_DETECTED
		call	IsFullSecond?

		;-----------------------------------------------------;
		;    Now look for MIDNIGHT                            ;
		;-----------------------------------------------------;

		cmp     word ptr CURR_TIME+2 , 864000 Shr 16
		jl      TI_112
		jg      MidnightOver
		cmp     word ptr CURR_TIME   , 864000 And 65535
		jl      TI_112
MidnightOver:   or	DRV_STAT , MIDNIGHT_FOUND
TI_112:         ret
UpdateTimer	endp


;*****************************************************************************
;     Procedure <DoTimerInit> procedure will be called from <TIMER_PROC>
;  to adjust current time to full second after initialization of I8253
;  chip.
;*****************************************************************************

DoTimerInit     proc	near
		mov     SkipBeep,16
		mov	TDfStat , 0
		mov 	word ptr irqDiffMin   , 0FFFFh
		mov	word ptr irqDiffMin+2 , 07FFFh
		mov	word ptr irqDiffMax   , 00001h
		mov	word ptr irqDiffMax+2 , 08000h
		test	TM_ResetRq,255
		jz	@@21
		mov	dx,P_ResetClkCounter
		out	dx,OutRegister
		out	80h, al
		BTRACE
		mov	TM_ResetRq,0
		retn
@@21:		call    GetCMOSTime     ; Get MJD and time
		mov	word ptr BASE_MJD   , bx
		mov	word ptr BASE_MJD+2 , cx

		mov	bx , 10
		mov	cx , dx
		mul	bx
                add     ax , 1
                adc     dx , 0
                mov     word ptr PREV_TIME   , ax
                mov     word ptr PREV_TIME+2 , dx
		imul	cx , cx , 10
                add     word ptr PREV_TIME+2 , cx
		call	TNorm
		or	DRV_STAT , SYNCHRONIZATION_OK
		mov     TimerIndex , 0
		mov	TS_MaxInd , 5
		ret
DoTimerInit     endp

;*****************************************************************************
;    Procedure <FullMinuteSync> provides TDRV.EXE 0.1 second timer
; synchronization when full minute signal is provided instead of full second
; signal for telescope control card
;*****************************************************************************

FullMinuteSync	proc	near
		mov	SkipBeep , 3
		mov	TDfStat , 0
		mov 	word ptr irqDiffMin   , 0FFFFh
		mov	word ptr irqDiffMin+2 , 07FFFh
		mov	word ptr irqDiffMax   , 00001h
		mov	word ptr irqDiffMax+2 , 08000h
@@21:           call    GetCMOSTime     ; Get MJD and time
		mov	word ptr BASE_MJD   , bx
		mov	word ptr BASE_MJD+2 , cx
		mov	bx , 10
		mov	cx , dx
		mul	bx
                add     ax , 1
                adc     dx , 0
                mov     word ptr PREV_TIME   , ax
                mov     word ptr PREV_TIME+2 , dx
		imul	cx , cx , 10
                add     word ptr PREV_TIME+2 , cx
                mov     ax , word ptr PREV_TIME
                mov     dx , word ptr PREV_TIME+2
		mov     bx , 600        ; Divide with 10 and get remainder
		mov	cx , 0		; in BX & CX
		call	ldiv
                sub     word ptr PREV_TIME   , bx
                sbb     word ptr PREV_TIME+2 , cx
                call    TNorm
		or	DRV_STAT , SYNCHRONIZATION_OK
		mov     TimerIndex , 0
		mov	TS_MaxInd , 4
		retn
FullMinuteSync	endp


;*****************************************************************************
;  Procedure:   DateToMJD
;*****************************************************************************
;  Converts date to modified Julian day (after February 1900)
;
;  Arguments:	AX 	- Year
;		BX	- Month
;		CX	- Day
;
;  Result:	AX,DX   - MJD
;*****************************************************************************

DateToMJD	proc	near
		sub	ax , 1900
		cmp     bx , 2
		jg	@@10
		add	bx , 9
		dec	ax
		jmp	@@11
	@@10:   sub	bx , 3
	@@11:   imul	word ptr V_1461	 ; Year * 1461
		sar	dx , 1
		rcr	ax , 1
		sar	dx , 1
		rcr	ax , 1		 ; (long) (Year*365.25)
		add	cx , 15078
		add	ax , cx
		adc	dx , 0		; Add day and start shift
		push	ax		; Save results in stack
		push	dx
		mov	ax , bx
		imul	ax , ax , 153
		add	ax , 2
		cwd
		mov	bx , 5
		idiv	bx
		pop	dx
		pop	bx
		add	ax , bx
		adc	dx , 0
		ret
DateToMJD	endp

;*****************************************************************************
;  Procedure:   MJDToDate
;*****************************************************************************
;  Input:	AX,DX 	- mjd
;
;  Output:	AX	- Year
;		BX      - Month
;		CX	- Day
;
;  Results are correct from March 1900 to the end of 2099
;*****************************************************************************

MJDToDate	proc    near
		push	si
		push	di
		sub 	ax , 15078
		sbb	dx , 0
		mov	si , ax
		mov	di , dx
		shl	ax , 1
		rcl	dx , 1
		shl	ax , 1
		rcl	dx , 1
                sub     ax , 1
                sbb     dx , 0
		idiv	V_1461
		push	ax
		mul     V_1461
                sar     dx , 1
                rcr     ax , 1
                sar     dx , 1
                rcr     ax , 1
		sub	si , ax
		mov	ax , si
		imul	ax , ax , 5
                sub     ax , 3
		cwd
		idiv	V_153
		mov	bx , ax
		imul	ax , ax , 153
		add	ax , 2
		cwd
		idiv     V_5
		sub	si , ax
		mov	cx , si
		add	bx , 3
		pop	ax
		cmp	bx , 12
		jbe	@@11
		sub	bx , 12
		inc	ax
	@@11:	pop	di
		pop	si
		add	ax , 1900
		retn
MJDToDate	endp


;*****************************************************************************
;  Procedure <GetCMOSTime> reads time and date from CMOS (INT 1Ah functions
;  2 and 4) and computes following values (returned in registers):
;	AX,DX  - second count beginning from midnight;
;       BX,CX  - modified Julian day
;*****************************************************************************

GetCMOSTime     PROC	NEAR
		Local	@@t1:word , @@t2:word = LocBytes
		Enter	0,0
		push	si
		push	di
		mov	si , 64
	@@Rd1:  dec	si
		or	si , si
		je	@@F1
		mov	ah , 04h	; RTC services: 2 - get CMOS Date
		int	1Ah
		jc	@@Rd1           ; Repeat if busy or not operational
		push	cx
		push	dx
		mov	ah , 02h
		int	1Ah
		jc	@@Rd1
	@@Ok:   mov	@@t1 , cx
		mov	@@t2 , dx
		pop	dx
		pop	cx
		mov	ax , cx
		call	BCDWordToBin	; Year
		push	ax
		mov	al , dh
		call	BCDByteToBin	; Month
		mov	bl , al
		xor	bh , bh
		mov	al , dl
		call	BCDByteToBin	; Day
		mov	cl , al
		xor	ch , ch
		pop	ax
		call	DateToMJD
		mov	si , ax
		mov	di , dx

		mov	al , byte ptr @@t1+1	; Hours (CH)
		call	BCDByteToBin
		xor	ah , ah
		imul    ax , ax , 60
		mov	bx , ax		 	; 60*Hours
		mov	al , byte ptr @@t1
		call	BCDByteToBin
		xor	ah , ah
		add	ax , bx		 	; 60*Hours+Minutes
		mov	bx , 60
		mul     bx			; 3600*Hours+60*Minutes
		mov	bx , ax
		mov	al , byte ptr @@t2+1
		call	BCDByteToBin
		xor	ah , ah
		add	ax , bx

		mov     bx , si
		mov	cx , di

		clc
		jmp	@@Done
	@@F1:	stc
	@@Done:	pop	si
		pop	di
		leave
		ret
GetCMOSTime	ENDP

;*****************************************************************************
;  Procedure:  TNorm
;*****************************************************************************

		global	TNorm	:Near

TNorm		PROC	NEAR
		pushf
		cli
		call	TNorm0
                mov     word ptr PREV_TIME , ax
                mov     word ptr PREV_TIME+2 , dx
		mov	word ptr BASE_MJD , bx
		mov	word ptr BASE_MJD+2 , cx
                add     ax , 1
                adc     dx , 0
                mov     word ptr CURR_TIME , ax
                mov     word ptr CURR_TIME+2 , dx
		popf
		retn
TNorm		ENDP

TNorm0		PROC	Near
		Local   @@Cnt:word = LocBytes
		Enter	LocBytes,0
		mov	@@Cnt , 0
                mov     ax , word ptr PREV_TIME
                mov     dx , word ptr PREV_TIME+2
		mov	bx , word ptr BASE_MJD
		mov	cx , word ptr BASE_MJD+2
	@@10:	cmp	@@Cnt , 10
		ja	@@21
		or	dx , dx
		jge	@@11
		add	ax , 864000 And 65535
		adc 	dx , 864000 Shr 16
		sub	bx , 1
		sbb	cx , 0
		inc	@@Cnt
		jmp	@@10
	@@11:	cmp	dx , 864000 Shr 16
		jb	@@21
		ja      @@12
		cmp	ax , 864000 And 65535
		jb      @@21
	@@12:	sub	ax , 864000 And 65535
		sbb	dx , 864000 Shr 16
		add	bx , 1
		adc	cx , 0
		inc	@@Cnt
		jmp	@@10
	@@21:	leave
		retn
TNorm0		ENDP

;*****************************************************************************
;  TDRV.EXE user interface: INT 2Fh function ??1Fh
;  Manipulation with 0.1 sec. timer value
;
;  Subfunctions:
;    BH = 0		; Get current value of time. The time in units of
;			; 0.1 seconds is returned in registers AX,DX and
;			; current MJD in CX,DX
;
;    BH = 1             ; Get current MJD as FP number in ST(1)
;
;    BH = 2             ; Return date and time
;                       ;     AX-year , BH-month , BL-day
;                       ;     CH-hours , CL-minutes
;			;     DX-seconds and tenths of sec
;
;    BH = 5             ; Normalize time and date format
;
;    BH = 6             ; Increment time:  BL - index
;    BH = 7             ; Decrement time:  BL - index
;                       ;   BL = 0   - Seconds
;		        ;   BL = 1   - Minutes
;			;   BL = 2   - Hours
;			;   BL = 3   - Days
;			;   BL = 4   - Months
;			;   BL = 5   - Years
;
;    BH = 8             ; Reset 0.1 seconds timer (sets time and date to
;                       ; the values read from CMOS RTC)
;
;    BH = 9             ; Sets CMOS RTC and BIOS timer equal to TDRV
;			; 0.1 seconds timer
;
;    BH = 16		; Performs wait until next 0.1 second interrupt
;
;    BH = 17            ; Performs wait until next hardware full
;                       ; second/minute pulse.
;
;    BH = 18            ; Get time synchronization mode
;                       ;    1 - synchronize to full second pulse
;                       ;    2 - synchronize to full minute pulse
;
;*****************************************************************************

TimerFunct	PROC	NEAR
		mov	ax , [bp].r_bx      	; Command code in AX
		and	[bp].r_flags , Not 1	; Clear CF in stack

	@@080:  cmp	ah , 8
                jne     @@010
		and	DRV_STAT , Not SYNCHRONIZATION_OK
		call	InitializeTimer
		retn

        @@010:  cmp     ah , 1
                jne     @@160
		pushf
		cli
		FILD    dword ptr PREV_TIME
		FIDIV   dword ptr V_864000
		FIADD	dword ptr BASE_MJD
		popf
		retn

        @@160:  cmp     ah , 16
		jne	@@170
		mov	bx , TIMER_INT_DETECTED
		mov	cx , 15
		jmp     @@171

	@@170:  cmp	ah , 17
                jne     @@180
		mov	bx , FULL_SECOND_DETECTED
		mov     cx , 30
	@@171:  and     [bp].r_flags , Not 1 ; Clear CF in stack
		call	WaitTimerInt
		jnc     @@172
		or	[bp].r_flags , 1
	@@172:	retn

        @@180:  cmp     ah , 18                 ; Function 18
                jne     @@000                   ; return time synchronization
                mov     ax , TimeSyncType       ; mode
                mov     [bp].r_ax , ax
                retn

        @@000:  test    DRV_STAT , SYNCHRONIZATION_OK
		jnz	@@001
		or	[bp].r_flags , 1
		ret

	@@001:	cmp	ah , 0
                jne     @@090
		pushf
		cli
		mov	ax , word ptr PREV_TIME
		mov	dx , word ptr PREV_TIME+2
		mov	bx , word ptr BASE_MJD
		mov	cx , word ptr BASE_MJD+2
		popf
		mov	[bp].r_ax , ax
		mov	[bp].r_bx , bx
		mov	[bp].r_cx , cx
		mov	[bp].r_dx , dx
		retn

	@@090:  cmp	ah , 9
		je	@@091
                jmp     @@050

	@@091:	call	TNorm
		mov	ax , word ptr BASE_MJD
                mov     dx , word ptr BASE_MJD+2
		call	MJDToDate
		mov	dh , bl		; Month to DH
                mov     dl , cl         ; Day to DL
                mov     cx , ax
		mov     ah , 02Bh	; DOS Fn. 2Bh: Set date
		int	21h

		mov	bx , 36000
                mov     ax , word ptr CURR_TIME
                mov     dx , word ptr CURR_TIME+2
		div	bx
                push    ax              ; AL-hours
                mov     ax , dx
		xor	dx , dx
                mov     bx , 600
		div	bx
                push    ax              ; AL-minutes
		xor	ax , ax
		xchg	ax , dx
		mov	bx , 10
		div     bx
                imul    dx , dx , 10
                mov     dh , al         ; Seconds
                pop     ax
                mov     cl , al         ; Minutes
                pop     ax
                mov     ch , al         ; Hours
		mov	ah , 2Dh
		int	21h
		retn


        @@050:  cmp     ah , 5
                jne     @@060
                call    TNorm
                retn

        @@060:  cmp     ah , 6
                je      @@061
		jmp	@@070
	@@061:	cmp	al , 3
		jae	@@063
		xor	bh , bh
		mov	bl , al
		shl	bx , 2
		mov	ax , word ptr @@TIncr   [bx]
		mov	dx , word ptr @@TIncr+2 [bx]
                cli
                add     word ptr PREV_TIME , ax
                adc     word ptr PREV_TIME+2 , dx
                sti
	@@062:	call	TNorm
		retn
	@@063:	push	ax
		mov	ax , word ptr BASE_MJD
		mov	dx , word ptr BASE_MJD+2
		call	MJDToDate
		pop	dx
		cmp	dl , 3
		jne	@@064
		inc	cx
		jmp     @@066
	@@064:  cmp	dl , 4
		jne	@@065
		inc	bx
		cmp	bx , 12
		jbe	@@066
		sub	bx , 12
		inc	ax
		jmp	@@066
	@@065:  cmp	dl , 5
		jne     @@067
		inc	ax
	@@066:	cmp	ax , 2079
		ja  	@@067
		call	DateToMJD
		mov	word ptr BASE_MJD   , ax
		mov	word ptr BASE_MJD+2 , dx
	@@067:	retn


	@@070:  cmp	ah , 7
		jz	@@071
                jmp     @@020
	@@071:	cmp	al , 3
		jae	@@073
		xor	bh , bh
		mov	bl , al
		shl	bx , 2
		mov	ax , word ptr @@TIncr   [bx]
		mov	dx , word ptr @@TIncr+2 [bx]
                cli
                sub     word ptr PREV_TIME , ax
                sbb     word ptr PREV_TIME+2 , dx
                sti
	@@072:	call	TNorm
		retn
	@@073:	push	ax
		mov	ax , word ptr BASE_MJD
		mov	dx , word ptr BASE_MJD+2
		call	MJDToDate
		pop	dx
		cmp	dl , 3
		jne	@@074
		dec	cx
		jmp     @@076
	@@074:  cmp	dl , 4
		jne	@@075
		dec	bx
		or	bx , bx
		jg	@@076
		add	bx , 12
		dec	ax
		jmp	@@076
	@@075:  cmp	dl , 5
		jne     @@077
		dec	ax
	@@076:	cmp	ax , 1981
		jb  	@@077
		call	DateToMJD
		mov	word ptr BASE_MJD   , ax
		mov	word ptr BASE_MJD+2 , dx
	@@077:	retn

	@@020:  cmp	ah , 2
		jne	@@999
		call	TNorm0		; Fn. 2: return time in expanded form
		push	ax		; Save time in stack
		push	dx
		mov	ax , bx
		mov	dx , cx
		call	MJDToDate
		mov	ch , bl
		mov	[bp].r_ax , ax	; Year-->AX
		mov     [bp].r_bx , cx  ; Month-->BH, Day-->BL
		pop	dx
		pop	ax
		div	V_36000
		mov     bh , al		; Hours
		mov     ax , dx
		xor	dx , dx
		div	V_600
		mov	bl , al
		mov	[bp].r_cx , bx
		mov	[bp].r_dx , dx
		retn

	@@999:  retn

@@TXH           db      0
@@TXM           db      0
@@TIncr		dd	10,600,36000

TimerFunct	ENDP


WaitTimerInt    proc	near
		sti
		push	ax
		push	es
		mov	ax , 040h	; Segment of BIOS variables
		mov	es , ax		; in ES
		mov	ax , bx
		not	ax
		and	DRV_STAT , ax   ; Reset corresponding bit in status
	@@2:    mov	ax , es:[006Ch] ; Load BIOS time counter (low word)
	@@3:    mov	dx , DRV_STAT   ; Look for 0.1 sec timer events
		and     dx , bx		; and exit loop when success
		jnz	@@8
		cmp	ax , es:[006Ch]	; Loop while no ticks detected
		je	@@3
		loop	@@2             ; Loop while tick count exceeded
		stc
		jc	@@9
	@@8:    clc
	@@9:	pop	es
		pop	ax
		retn
WaitTimerInt	endp

        ;-----------------------------------------------------------;
        ;  I_DisableTDRV : disables any output of division coeff.   ;
        ;  to hardware card until the next call to <SetCoord>       ;
        ;  Timer continues work, the coordinate system and any      ;
        ;  motion are reset.                                        ;
        ;-----------------------------------------------------------;

I_DisableTDRV   proc    near
                mov     DisableFlag , 255
                and     DRV_STAT , Not IS_START_COORD
                ret
I_DisableTDRV   endp


	;-----------------------------------------------------------;
	;       Some constant values used in this module            ;
	;-----------------------------------------------------------;

V_5             dw	5
V_10		dw	10
V_153		dw	153
V_600		dw	600
V_1461		dw	1461
V_36000		dw	36000
V_864000	dd	864000

	;-----------------------------------------------------------;
	;	Add data areas for stack switching if this is       ;
	;	requested.                                          ;
	;-----------------------------------------------------------;

	IF SwitchStack Ne 0
		StackSwitched	db	0
		OldStack_Seg	dw	?
		OldStack_Off	dw	?

				public  IRQ_Stack
				public  IRQ_StackTop

		IRQ_Stack	dw	StackSize dup (?)
		IRQ_StackTop    dw      ?
	ENDIF

_TEXT		ends
		end

;--------------------------------------
;FP_SAVE	db	94 dup (?)
;TickFq         dq      1193180.0       ; 18.2064819335938
;V_00010	dw	10
;--------------------------------------


