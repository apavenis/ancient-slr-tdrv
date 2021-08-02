
		.286
		.XList
		include	TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
                include DBGSTRCT.INC
		locals
		.List

_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT


		include	DCTABLE.INC	; Include table of division's
					; coefficients.

OutpInfo	struc
OI_Address	dw	 ?
OI_Value	db	 ?
		ends

OutpCount	dw	 0
OutpBuffer      OutpInfo 30 dup (?)


PrevHStat	db	0

;-----------------------------------------------------------------------------
;  	Outputs divisions coefficients and time gate parameters to hardware.
;-----------------------------------------------------------------------------

OutputDC	proc
		enter	0 , 0

		mov	dx , P_RdStatus
		in	al , dx
		out	80h, al

		cld
		push	si
		mov	cx , OutpCount
		or	cx , cx
		jz	@@2

		lea	si , OutpBuffer
	  @@1:  lodsw
		mov	dx , ax
		lodsb
		out	dx , al

		out	080h, al
;		call	word ptr IOWaitAddr

		jmp	short $+2
		jmp	short $+2
		loop	@@1
		mov	OutpCount , 0
	  @@2:	pop	si
		and     DRV_STAT2 , Not OUTPUT_READY

		leave
		retn

OutputDC	endp

;=============================================================================
;  Procedure <FillOutpBuffer> creates list for output to hardware card
;  while processing the next IRQ15
;=============================================================================

FillOutpBuffer  proc	near
		cld
		push	di
		push	es
		mov	OutpCount , 0		; Clear counter
		push	cs
		pop	es
		lea	di , OutpBuffer

	@@XA1:  mov	bl , DRV_X.hrdwStat	; Load status for both
		mov	bh , DRV_Y.hrdwStat	; coordinates in BL and BH
		mov	DRV_X.PrevHrdwStat , bl
		mov	DRV_Y.PrevHrdwStat , bh

		test	DRV_X.DC_Options , DC_InvertSign
		jz	@@XA2
		xor	bl , 4
	@@XA2:	test	DRV_Y.DC_Options , DC_InvertSign
		jz	@@XA3
		xor	bh , 4
	@@XA3:

	;----------------------------------------------------------;
	;  Prepare byte for port <P_WriteStatus>                   ;
	;----------------------------------------------------------;

		mov	al , bl			;
		and	al , 5
		mov	ah , bh
		and	ah , 5
		shl	ah , 1
		or	al , ah
		or      al , GateMask
		push	ax

	;----------------------------------------------------------;
	;  If the sign is changed for any coordinate then reset    ;
	;  I8253 chanal for this coordinate (use status previously ;
	;  written to card in the previos step)                    ;
	;----------------------------------------------------------;

		mov	al , PrevHStat
		test    DRV_X.Status , DC_SignChanged
		jz	@@21
		and	al , Not 1
	@@21:   test    DRV_Y.Status , DC_SignChanged
		jz	@@22
		and	al , Not 2
	@@22:   push	ax
		mov	ax , P_WriteStatus
		stosw
		pop	ax
		stosb
		inc     OutpCount
		mov	PrevHStat , al

	;----------------------------------------------------------;
	;  Output division's coefficients to I8253 chip            ;
	;----------------------------------------------------------;

		push	bx
		mov	bx , DRV_X.hrdwCoeff
		mov	ax , P_DivCoeff_1
		stosw
		xchg	al , bl
		stosb
		xchg	al , bl
		stosw
		mov     al , bh
		stosb
		add     OutpCount , 2

		mov	bx , DRV_Y.hrdwCoeff
		mov	ax , P_DivCoeff_2
		stosw
		xchg	al , bl
		stosb
		xchg	al , bl
		stosw
		mov     al , bh
		stosb
		add     OutpCount , 2
		pop	bx
		pop	ax

		mov	ah , al
		test	bl , 128
		jz      @@31
		and	al , Not 1
		and	DRV_X.hrdwStat , Not 128
	@@31:   test	bh , 128
		jz	@@32
		and	al , Not 2
		and	DRV_Y.hrdwStat , Not 128
	@@32:	cmp	al , ah
		je	@@33
		push	ax
		mov	ax , P_WriteStatus
		stosw
		pop	ax
		stosb
		inc	OutpCount
	@@33:	push	ax
		mov	ax , P_WriteStatus
		stosw
		pop	ax
		mov	al , ah
		stosb
		inc	OutpCount
		mov	PrevHStat , al

		and	DRV_X.hrdwStat , Not 1
		and	DRV_Y.hrdwStat , Not 1

		and	DRV_X.Status , Not DC_SignChanged
		and	DRV_Y.Status , Not DC_SignChanged

		pop	es
		pop	di
		retn
FillOutpBuffer  endp

;=============================================================================
;  Procedure <DC_OldStep> computes the number of steps that must be done in
;  the last control interval. At the entry register SI must contain offset of
;  corresponding 'DrvCoord' structure.
;=============================================================================

C2_FailureCnt	dw	0

DC_OldStep	proc	near
		enter	0 , 0
		mov     ax , word ptr [si].CurrX     ; Get correction from
		mov	dx , word ptr [si].CurrX+2   ; second card.
		call	rshift8			     ; The result is in steps
		sub	ax , [si].StepCnt

		shl     ax , 4			     ; Convert it to full
		sar	ax , 4			     ; word.

		test	HRDW_OPT , ENABLE_STEP_CNT   ; Look if use of 2-nd
		jz	@@10			     ; card is enabled

		mov	bx , ax			     ; Copy correction to BX
		or	bx , bx			     ; Look for sign
		jge	@@06			     ; and take ABS value
		neg	bx
	@@06:   cmp	bx , 10			     ; If ABS value > 10 then
		jbe	@@07			     ; treate it as error
		inc	C2_FailureCnt		     ; Switch of use of CARD 2
		cmp	C2_FailureCnt , 10	     ; if there are more than
		jb	@@11			     ; 10 errors
                and     HRDW_OPT , Not ENABLE_STEP_CNT

	@@07:   add	[si].dbgInfo , ax            ; Correction is OK. Add
		cwd				     ; it to total correct.
		mov     dl , ah			     ; Convert to internal
		mov     ah , al			     ; units and add to the
		xor     al , al			     ; coordinate
		sub     word ptr [si].CurrX   , ax
		sbb     word ptr [si].CurrX+2 , dx
		jmp	@@11

	@@10:   mov	[si].dbgInfo , ax            ; Use of corrections is
						     ; NOT allowed. Save
						     ; current value only
	@@11:	or	[si].Status , DC_Tracking
		xor	ax , ax
		xchg	ax , [si].NextSteps
		or	ax , ax
                jnz     @@12
		and	[si].Status , Not DC_Tracking
        @@12:   push    ax
		or	ax , ax
                jnl     @@13
		neg	ax
        @@13:   cwd
		add	word ptr [si].TotalSteps   , ax
		adc	word ptr [si].TotalSteps+2 , dx
		pop	ax
		cwd
		;*********  Modify argument of histeresis  ****************
		push	ax
		push	dx
		add	ax , word ptr [si].HistArg
		adc	dx , word ptr [si].HistArg+2
		lea	bx , [si].HistMin
		call	IsInside
		mov	word ptr [si].HistArg   , ax
		mov	word ptr [si].HistArg+2 , dx
		pop	dx
		pop	ax
		;**********************************************************
		call	lshift8
		add     word ptr [si].CurrX   , ax
		adc     word ptr [si].CurrX+2 , dx

@@Done:		leave
		retn

DC_OldStep	endp

;=============================================================================
;
;  Procedure <DC_DivCoeff> computes division's coefficient for given
;  coordinate and stores it <DrvCoord> structure. The procedure also
;  sets <Driving> flag for this coordinate to correct value (0- when
;  no steps must be done, 1- otherwise )
;
;  ARGUMENTS:
;       DS:SI   - address of <DrvCoord> structure
;       AX & DX - increment of coordinate
;
;  RESULTS:
;       [SI].DivCoeff  - the new division coefficient (undefined if
;                        <hrdwCoeff & 1> is 0
;       [SI].hrdwStat  - speed: 0-no motion   1-move    4-sign
;	[SI].hrdwCoeff - division coefficient for hardware
;
;  Used global variables:
;       Frequency
;
;  Called procedures:
;       rshift8 , labs , lsort2 , ldiv
;
;=============================================================================

DC_DivCoeff	proc 	near
		local   @@Dist:word ,             \
			@@ISign:byte:2            \
			= LocBytes
		enter	LocBytes,0

		and	[si].Status , Not (DC_SignChanged+DC_RequestReset)
		or	DRV_STAT2 , OUTPUT_READY

		;----------------------------------------------------;
		; Get number of steps to be gone and look whether    ;
		; telescope must be moved. Here we need ABS value of ;
		; this number (!!!)                                  ;
		;----------------------------------------------------;

		mov	ax , word ptr [si].IncrX ;### Distance to be done ###
		mov	dx , word ptr [si].IncrX+2
		call	rshift8			; Convert to steps
		mov     @@ISign , dh
                call    labs                    ; Abs value of distance
		mov     bx , dx                 ; Look if far enough to move
		or	bx , ax			; telscope
		ja	@@NotZero

@@ZeroIncr:     ;----------------------------------------------------;
		; No steps must be done:                             ;
		;  - clear motion flag in the status byte            ;
		;  - requests counter reset before the first motion  ;
		;  - set number of steps per next interval to 0      ;
		;----------------------------------------------------;

		and	[si].hrdwStat , Not 1   ; No motion: clear counter
		or	[si].hrdwStat , 010h	; Request reset for this when
		mov	[si].NextSteps , 0	; next non zero step
		jmp	@@Done			;

@@NotZero:      ;----------------------------------------------------;
		; The distance that must be gone is not 0            ;
		;  - Look if counter reset is requested. If so then  ;
		;    set flag in <hrdwStat>                          ;
		;----------------------------------------------------;

;           cmp  si , Offset DRV_Y
;           jne  @@DBG1
;           cmp  ax , 1
;           ja   @@DBG1
;           nop

  @@DBG1:

		test	[si].hrdwStat , 010h
		jz	@@4
		and	[si].hrdwStat , Not 16
		or	[si].hrdwStat , 080h
		mov	[si].Remainder , 0
        @@4:
		;----------------------------------------------------;
		; Test once more whether the speed is correct and    ;
		; reduce to allowed range if test failed.            ;
		;----------------------------------------------------;

		or	dx , dx			; TEST REQUESTED SPEED:
		jnz	@@SpeedInvalid		; Replace requested speed with
		cmp	ax , MaxSpeed		; maximal allowed when this
		jbe     @@SpeedOk			; limit is exceeded
@@SpeedInvalid:	mov	ax , MaxSpeed

@@SpeedOk:      ;----------------------------------------------------;
		; Now set flag that allows telescope motion for the  ;
		; specified coordinate and save requested number of  ;
		; steps.                                             ;
		;----------------------------------------------------;

		or	[si].hrdwStat , 1
		mov	@@Dist , ax		; Save distance in stack

		cmp	ax , RST_FQ
		ja	@@HighSpeed
		mov	bx , ax
		shl	bx , 1
		mov	ax , DCTABLE [bx]
		mov	[si].hrdwCoeff , ax
		mov     [si].Remainder , 0
		or	[si].hrdwStat , 090h
		jmp     @@16

@@HighSpeed:    mov	bx , ax
		mov	ax , word ptr Frequency
		mov	dx , word ptr Frequency+2
		sub     ax , [si].Remainder
		sbb     dx , 0
		shl     ax , 1
		rcl     dx , 1
		shl     bx , 1
		dec     bx
		div     bx
		mov	[si].hrdwCoeff , ax

	@@16:   and	[si].hrdwStat , Not 4
;                test    byte ptr [si].IncrX+3 , 128
		test    @@ISign , 128
		jz	@@21
		or	[si].hrdwStat , 4
	@@21:   and	[si].Status , Not DC_SignChanged
		mov	al , [si].PrevHrdwStat
		xor	al , [si].hrdwStat
		test    [si].hrdwStat , 80h
		jnz	@@22
		test	al,4
		jz	@@31
		or	[si].hrdwStat , 80h
		or	[si].Status , DC_SignChanged
	@@22:   mov     [si].Remainder , 0

	@@31:   ;----------------------------------------------------;
		; Compute number of steps that must be gone using    ;
		; computed division's coefficient                    ;
		;----------------------------------------------------;

		mov     ax , word ptr Frequency	;
		mov	dx , word ptr Frequency+2
		sub	ax , [si].Remainder
		sbb	dx  ,0
		div     [si].hrdwCoeff   	; Number of steps (REAL)
		test    [si].hrdwStat , 128	; Look for step from the
		jnz	@@32			; previous interval. Add it
		inc	ax			; if necessary.
	@@32:	test	[si].hrdwStat , 4       ; Invert result if necessary
		jz	@@41
		neg	ax

	@@41:	mov	[si].NextSteps , ax
		xor	ax,ax
		test	[si].hrdwStat , 10h ; Remainder = if reset requested
		jnz	@@42                ; after step then hrdwCoeff else
		mov	ax , [si].hrdwCoeff
		sub	ax , dx		    ; hrdwCoeff - [DX value]
	@@42:	mov	[si].Remainder , ax

@@Done:		leave
		ret

DC_DivCoeff	endp

;-----------------------------------------------------------------------------
;	     Sets full second flag on full second
;      (debugging version: simply counts the interrupts)
;-----------------------------------------------------------------------------

IsFullSecond?	proc	near
		cmp	IntCount , 0
		jg	FS_01
		or	DRV_STAT , FULL_SECOND_DETECTED
		mov	IntCount , 10
   FS_01:	dec	IntCount
		ret
   IntCount	db	0
IsFullSecond?	endp

;-----------------------------------------------------------------------------
;  Procedure:	InitCard
;  Arguments:   none
;-----------------------------------------------------------------------------

InitCard	proc	near

		and	DRV_STAT  , Not (DRIVER_READY+CTRL_BREAK)
		and	DRV_STAT2 , Not (PREV_DEST_OK+INTERVAL_DONE+	\
					 OUTPUT_READY)

		mov	al , 0          	; Disable tracking
		mov	dx , P_WriteStatus
		out	dx , OutRegister
		out	080h , al

                BTRACE

		lea	si , DRV_X
		call    DC_DoReset
		lea	si , DRV_Y
		call	DC_DoReset
		call    LShootInit

		mov	ax , 32000  		; Initialize I8253 chanal used
		mov	bl , M_ChanalCommutator	; to form chanal commutator
		mov	dx , P_ChanalCommutator	; strobe
		call	I8253_WriteC

		mov	ax , 40			; Chanal 2: window width
		mov	bl , M_Window		; Set to default value
		mov	dx , P_Window		;  (32*1.6 = 51.2mks)
		call	I8253_WriteC

		mov	ax , 100
		mov	bl , M_DivCoeff
		mov	dx , P_DivCoeff_1
		call	I8253_WriteC

		mov	ax , 100
		mov	bl , M_DivCoeff
		mov	dx , P_DivCoeff_2
		call	I8253_WriteC

		mov	ax , 32000
		mov	bl , M_GateH
		mov	dx , P_GateH
		call	I8253_WriteC

		mov	PrevHStat , 0

		retn
InitCard	endp

;-----------------------------------------------------------------------------
;  Procedure:   ReadCardStatus
;  Returns value in register AL. The following bits are defined:
;      .... ...0  -  full scond signal is active
;      .... ..0.  -  zero point line is active for 1-st. coord
;      .... .0..  -  zero point line is active for 2-nd. coord
;  WARNING: This procedure resets 0.1 sec. interrupt signal too (this is true
;           only to first version of hardware card. The next ones uses output
;           to port 01A6h for this purpose instead of this call)
;-----------------------------------------------------------------------------

ReadCardStatus	proc	near
		push	dx
		mov     dx , P_RdStatus
		in	al , dx
		out	80h , al
		RBTRACE
		pop	dx
		retn
ReadCardStatus	endp

;-----------------------------------------------------------------------------
;  Procedure:   InitializeTimer
;  Performs 0.1 second timer initialization. After that sets timer to the
;  value near BIOS timer.
;-----------------------------------------------------------------------------

InitializeTimer proc	near
		INITTRACE
		mov	ax , 62500
		mov	bl , M_Timer
		mov	dx , P_Timer
		call	I8253_WriteC
		and	DRV_STAT , Not SYNCHRONIZATION_OK
		mov	dx , P_ResetClkCounter
		out	dx , OutRegister
		out	80h , al
		BTRACE
		mov     TM_ResetRq , 1
		mov	ax , TimeSyncType
		mov	TimerIndex , ax
		retn
		;jmp	InitCard
InitializeTimer endp

;-----------------------------------------------------------------------------
;  Procedure:	H_Set_CC_Strobe
;  Argument:	AX - delay in units of 1.6 microseconds
;-----------------------------------------------------------------------------

Set_CC_Strobe	proc	near
                or      dx , dx
		jge     @@1
                retn
     @@1:
                mov     bx , 62500
		div	bx
		mov	ax , dx         ; We need only remainder
		mov	dx , P_ChanalCommutator
		jmp	I8253_Write
Set_CC_Strobe	endp

;-----------------------------------------------------------------------------
;  Procedure: 	I8253_Write
;  Arguments:   DX - port address
;		AX - value to be written
;               BL - mode to be written (0-5)
;-----------------------------------------------------------------------------

I8253_WriteC    proc	near            ; We have to send command code too
		push	dx		; Save port address in stack
		push	ax		; Save value in stack
		mov	al , dl  	; Extract chanal number from port
		and	al , 06h	; and shift to higher bits
		shl	al , 5          ;
		or	al , 030h	; Write lower bit then higher one
		and	bl , 7
		shl	bl , 1		; Add requested mode
		or	al , bl         ; and output data to port
                or      dx , 6          ; Address of I8253 command port
		out	dx , OutRegister ;
		out	80h , al
;		call	word ptr IOWaitAddr
		CTRACE
		pop	ax
		pop	dx
I8253_Write:    TTRACE
		mov     cx , 5
	@@1L:   loop    @@1L
		out	dx , OutRegister
		out	080h , al
		xchg    al , ah
		mov     cx , 5
	@@2L:   loop    @@2L
		out	dx , OutRegister
		out	080h , al
		retn
I8253_WriteC	endp


;-----------------------------------------------------------------------------
;  Procedure:	ReadStepCnt
;  Arguments:   None
;  Results:	AX    - integer number for 1-st coord (lower 12 bits)
;               BX    - integer number for 2-nd coord (lower 12 bits)
;-----------------------------------------------------------------------------

ReadStepCnt     proc	near
		push	cx
		push	dx
		mov	dx , 126h
		in	ax , dx
		out	080h , al
		mov	cx , ax
		mov	dx , 128h
		in	ax , dx
		out	080h , al
		xor	bx , bx
		xchg	bl , ah
		mov	ah , cl
		mov     bh , cl
		shr	bh , 4
		test	DRV_X.DC_Options , DC_InvertSign
		jnz	@@11
		neg	ax
	@@11:	test	DRV_Y.DC_Options , DC_InvertSign
		jnz	@@12
		neg	bx
	@@12:	pop	dx
		pop	cx
		clc
		retn
ReadStepCnt	endp

_TEXT		ends
		end
