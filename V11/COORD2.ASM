
		.286

		JUMPS

		.XList
		include TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
		include VFIELD.INC
		locals
		.List

_TEXT           segment byte public 'CODE'
		assume  CS:_TEXT , DS:_TEXT


ManualMode      db      0

;***************************************************************************
;
;   Procedure:  DoStep()
;
;   This is main procedure that generates data to be sent to telescope
;   control card at the next interrupt
;
;***************************************************************************

DoStep          proc    near
		push    ds      ; Save segment registers DS and ES
		push    es      ; in the stack

		;-----------------------------------------------------------;
		;  At first look for DRV_WAITING flag. If this one is on    ;
		;  we don't need to do anything, only simply return         ;
		;-----------------------------------------------------------;

		test    DRV_STAT2 , DRV_WAITING
		je      TI_100
		jmp     TI_199

		;-----------------------------------------------------------;
		;  Update satellite distance (double light propagation time ;
		;  in nanoseconds). Lower limit of this value is 65.536 mks ;
		;  is set (clipping is done when needed)                    ;
		;-----------------------------------------------------------;

TI_100:		mov	ax , word ptr RO
		mov	dx , word ptr RO+2
		add	ax , word ptr dRO
		adc	dx , word ptr dRO+2
		jl      @@Inv1
		or	dx , dx
		jne     @@rOk
		cmp	ax , 10000
		ja	@@rOk
@@Inv1: 	mov	ax , 10000
		mov     dx , 0
		mov     word ptr dRO   , ax
		mov     word ptr dRO+2 , dx
@@rOk:          mov     word ptr RO   , ax
		mov	word ptr RO+2 , dx

		;--------------------------------------------------------;
		;                                                        ;
		;   Compute settings for the next interval:              ;
		;                                                        ;
		;      Set destination to the current position if        ;
		;   RESET_DRIVER flag is ON (before step)                ;
		;                                                        ;
		;--------------------------------------------------------;

		test    DRV_STAT2,RESET_DRIVER     ; At first look for
		jz      TI_118                     ; RESET_DRIVER flag

		and	DRV_STAT , Not MANUAL_TRACKING
		mov     si , Offset DRV_X          ; RESET_DRIVER flag is ON !
		call    DC_SetToCurr               ; Therefore set destination
		mov     si , Offset DRV_Y          ; to the current position.
		call    DC_SetToCurr
		xor	ax , ax
		mov	word ptr dRO   , ax
		mov	word ptr dRO+2 , ax
		or      DRV_STAT , LASER_DISABLE + MT_MODE_CHANGED

		or      DRV_STAT  , DRIVER_READY
		and     DRV_STAT2 , Not ( PREV_DEST_OK		\
					+ NEW_DEST_READY        \
					+ FO_ENABLE)

		mov	al , DRV_X.Status  	   ; Reset RESET_DRIVER flag
		or	al , DRV_Y.Status	   ; if telescope is no more
		test	al , DC_Tracking	   ; moving
		jnz	TI_118

		and     DRV_STAT2,Not RESET_DRIVER ; NO: turn DRIVER_RESET
						   ;     flag OFF

TI_118:		;-------------------------------------------------------;
		;   Now look for manual corrections and convert them    ;
		; to the instrumental system (if needed)                ;
		;-------------------------------------------------------;

		call	GetMCor
		jne     @@21
	@@20:	test    DRV_STAT , MANUAL_TRACKING
		jz      @@22
		and     DRV_STAT , Not MANUAL_TRACKING
		or      DRV_STAT , MT_MODE_CHANGED
		jmp	@@22
	@@21:	call	VField
		or      DRV_STAT , MANUAL_TRACKING + MT_MODE_CHANGED
	@@22:	lstore  x_correction
		lstoreb y_correction

		;-------------------------------------------------------;
		;   Compute settings for the next step                  ;
		;-------------------------------------------------------;

		lload	x_correction
		mov     si , Offset DRV_X          ; Now the new destination
		call    DC_DoStep                  ; is OK even when reset is
		lload   y_correction               ; required. Therefore we
		mov     si , Offset DRV_Y          ; can compute settings for
		call    DC_DoStep                  ; next interval.

		call	FillOutpBuffer

		;--------------------------------------------------------;
		;   Look whether dest. time is reached. If so, set       ;
		; 'INTERVAL_DONE' flag in status.                        ;
		;--------------------------------------------------------;

                test    DRV_X.Status , DC_Ready
		jne     TI_119
                test    DRV_Y.Status , DC_Ready
		je      TI_121
TI_119:         or      DRV_STAT2 , INTERVAL_DONE

TI_121:

		;--------------------------------------------------------;
		;   Look for new destination point when necessary        ;
		;--------------------------------------------------------;

		test    DRV_STAT2 , INTERVAL_DONE  	; Look if end of
		jz	TI_116				; interval is reached
		call    SetNewDest
TI_116:
		test	DRV_STAT , CTRL_BREAK
		jz	TI_126
		or      DRV_STAT2 , RESET_DRIVER
TI_126:
		call	LCtrlShoot	    ; Perform laser control functions

TI_199:         pop     es      ; Restore all registers to the old values
		pop     ds
		ret
DoStep          endp



debug1	db	0

OutputHrdwData	proc	near

		;--------------------------------------------------------;
		;   Output data to hardware if data are computed in      ;
		; previous step.                                         ;
		;--------------------------------------------------------;

		test    DRV_STAT2 , OUTPUT_READY    ; Look if output data
		jz      @@1A                        ; is ready. If so then
						    ; output them
		call    OutputDC

		jmp	@@1

	@@1A:   test	DRV_X.Status , DC_StartCoord
		jz	@@1
		nop

	@@1:    call	ReadStepCnt
		sub	ax , DRV_X.CntZeroVal
		sub	bx , DRV_Y.CntZeroVal
		mov	DRV_X.StepCnt , ax
		mov     DRV_Y.StepCnt , bx

                COORD_TRACE

	@@21:
		NSTEPS
                lea     si , DRV_X
		call	DC_OldStep
		lea     si , DRV_Y
		call	DC_OldStep

		retn
OutputHrdwData	endp


;=============================================================================
;
;   PROCEDURE   : SetNewDest
;
;=============================================================================

SetNewDest      proc    near
		local	iLength:word = LocBytes
		enter   LocBytes,0
		pusha

		;-----------------------------------------------------;
		;   We need new destination. Look if one is avalable. ;
		; If not then clear flag PREV_DEST_OK.                ;
		;-----------------------------------------------------;

		test    DRV_STAT2 , NEW_DEST_READY
		jnz	SN_003

		and	DRV_STAT2 , Not (PREV_DEST_OK + DRV_TRACKING)
		or	DRV_STAT2 , RESET_DRIVER
		call    ApplyTrackingOpt
		jmp	SN_091

SN_003:		;-----------------------------------------------------;
		;   The new destintion is available.                  ;
		; Update values of manual corrections if these        ;
		; corrections are taken into account while computing  ;
		; ephemeris.                                          ;
		;-----------------------------------------------------;

                test    NewDest._Flags , RESET_JCR
		jz      SN_006

		lpush
		lload   NewDest._DCorrX
		lstore  DRV_X.d_RsdlX
		lload   NewDest._DCorrY
		lstore  DRV_Y.d_RsdlX
		lpop

SN_006:

SN_011:		;-----------------------------------------------------;
		;   OK: we can process it. If requested time is       ;
		; already reached, then ignore request. If time field ;
		; contains -1 then current time is assumed:           ;
		;  - copy field rotation's angle, that is being used  ;
		;    only if D_USER_ROTATION flag in DRV_OPT is on    ;
		;  - Clear NEW_DEST_READY flag;                       ;
		;  - Clear INTERVAL_DONE flag                         ;
		;  - compute length of interval in units of 0.1 sec.  ;
		;    Take current time as the begin if -1 specified.  ;
		;-----------------------------------------------------;

		mov     ax , NewDest._FldAngle
		mov	FldRotAngle , ax

		and     DRV_STAT2 , Not (INTERVAL_DONE + NEW_DEST_READY)
		lload   NewDest._Time
		sub     ax , 1               ; Extract more 0.1 second
		sbb     dx , 0
		mov     bx , ax
		and     bx , dx
		cmp     bx , 0FFFFh
		jne     SN_012
		lload   CURR_TIME
SN_012:         lsub    CURR_TIME

		or      dx , dx
		jnl	SN_013
		mov     ax , 00000h     ; Result < 0 : set interval to 0
		jmp	SN_017		; and process new destination
SN_013:         jg      SN_014          ; Result > 65536 --> set to 64000
                cmp     ax , 64000
		jb	SN_017
SN_014:         mov     ax , 64000
SN_017:		mov     iLength , ax

		;-----------------------------------------------------;
		;   Now register CX contains length of new interval   ;
		; units of 0.1 seconds or 0 if the new destination    ;
		; doesn't contain time. Therefore all data for        ;
		; DC_SetDest is ready.                                ;
		;-----------------------------------------------------;

		mov	cx , iLength
		mov     si , Offset DRV_X
                mov     ax , word ptr NewDest._DestX
                mov     dx , word ptr NewDest._DestX + 2
		call    DC_SetDest
		mov	cx , iLength
		mov     si , Offset DRV_Y
                mov     ax , word ptr NewDest._DestY
                mov     dx , word ptr NewDest._DestY + 2
		call    DC_SetDest

		;-----------------------------------------------------;
		;   Set the parameters for distance for the new       ;
		; interval                                            ;
		;-----------------------------------------------------;

		mov	bx , iLength		 ; Interval length
                or      bx , bx
                je      SN_UnDefInt              ; >>> Zero >>>
                cmp     bx , 64000               ; Test interval length
                ja      SN_UnDefInt              ; >>> Greater then 1 hour >>>
		test	DRV_STAT2 , PREV_DEST_OK ; Is prev. dest. known ?
		jz	SN_FirstDest		 ; >>> Not known >>>

		test	DRV_STAT2 , DRV_TRACKING
		jnz	SN_FindIncr
		or	DRV_STAT2 , DRV_TRACKING
		call	ApplyTrackingOpt

SN_FindIncr:	lload	NewDest._DestR        	 ; Find new dest. for RO
		mov     bx , iLength
		lsub    RO                       ; Prev. dest. in known and
		call    IDiv42R			 ; the interval length is not
		lstore  dRO			 ; zero
		and	DRV_STAT , Not LASER_DISABLE
		jmp	SN_Done

SN_UnDefInt:    and	DRV_STAT2 , Not (PREV_DEST_OK + DRV_TRACKING)
		or	DRV_STAT2 , INTERVAL_DONE
		call    ApplyTrackingOpt
		jmp	short SN_ZeroIncr

SN_FirstDest:   or	DRV_STAT2 , PREV_DEST_OK
		or	DRV_STAT  , LASER_DISABLE
SN_ZeroIncr:    lload   NewDest._DestR
                lstore  RO
		xor     bx , bx
		mov	word ptr dRO   , bx
		mov	word ptr dRO+2 , bx

SN_Done:        ;-----------------------------------------------------;
		;   At least set DRIVER_READY flag (to tell user to   ;
		; send new data) and return to caller.                ;
		;-----------------------------------------------------;

SN_091:         or      DRV_STAT  , DRIVER_READY
SN_092:         popa
		leave
		ret

_ti		dw	?

SetNewDest      endp


;=============================================================================
;
;	Procedure <GetMCor> returns manual corrections that are read from
;   numeric keypad and mouse. These corrections are not transformed to the
;   instrumental coordinate system.
;   INPUT:	none
;   OUTPUT:     AX,DX - correction in X-dir (steps times 256)
;               BX,CX - correction in Y-dir (steps times 256)
;
;=============================================================================

GetMCor		proc	near
		local	xCor0:dword , yCor0:dword = LocBytes
		enter	LocBytes , 0

		call	GetKbCorrections
		imul    kbSensitivity
		lstore	xCor
		mov     ax , bx
		imul    kbSensitivity
		lstore  yCor

		call	GetMoMotion

		mov	cx , moSensitivity
		shr	cx , 2
		imul	cx
		add	word ptr xCor , ax
		adc     word ptr xCor+2 , dx
		mov     ax , bx
		imul	cx
		add	word ptr yCor , ax
		adc     word ptr yCor+2 , dx

		call    J_GetXY
		imul	jsSensitivity
		add	word ptr xCor , ax
		adc	word ptr xCor+2 , dx
		mov	ax , bx
		imul	jsSensitivity
		add	word ptr yCor , ax
		adc	word ptr yCor+2 , dx

		lload   xCor
		lloadb	yCor
		push	si
		mov	si , ax
		or	si , bx
		or	si , cx
		or      si , dx
		pop	si

		leave
		ret
	public  xCor , yCor
xCor		dd	?
yCor		dd	?
GetMCor		endp

;=============================================================================
;	Procedure <ClrCorrections> clears manual correction fields in
;   both <DrvCoord> structures. All registers except AX remains intact.
;=============================================================================

ClrCorrections 	proc	near
		push	si
		lea	si , DRV_X
		call	DC_ClearCorrection
		lea     si , DRV_Y
		call	DC_ClearCorrection
		pop	si
		retn
ClrCorrections  endp

;=============================================================================
;       Procedure <I_ManCorrections> provides user interface to query/set
;   manual correction values for each coordinate.
;   Full values are returned (not in motor steps) to provide more accurate
;   account of these corrections while computing ephemeris
;
;   Register values after return from INT 2Fh:
;
;       AX,BX  - correction for the first coordinate  (BX- high word)
;       CX,DX  - correction for the second coordinate (DX- high word)
;
;=============================================================================

I_ManCorrections proc  near
		lload	DRV_X.RsdlX
		mov	[bp].r_ax , ax
		mov	[bp].r_bx , dx
		lload	DRV_Y.RsdlX
		mov	[bp].r_cx , ax
		mov	[bp].r_dx , dx
		ret
I_ManCorrections endp

;==============================================================================
;	Procedure <I_ConvManCorr> converts corrections in coordinates
;       on monitor to ones used for tracting according rules specified
; 	in TDRV configuration file and current telescope position.
;  	Return value is invalid when telescope position is not set.
;	Anyway even in this case this function call may be used
;	to detect whether this function is supported.
;
;   Register values when INT 2Fh is called
;
;	AH     - multiplex interrupt ID
;	AL     - 0x0C
;       CX,DX  - correction for the first coordinate  (DX- high word)
;       SI,DI  - correction for the second coordinate (DI- high word)
;
;   Register values after return from INT 2Fh:
;
;	AX     - sum of source values (for autodetection)
;       BX     - sum of result values (for autodetection)
;       CX,DX  - correction for the first coordinate  (DX- high word)
;       SI,DI  - correction for the second coordinate (DI- high word)
;==============================================================================
;
I_ConvManCor	proc	near
		mov	ax , [bp].r_cx	; Find sum of arguments for
		add	ax , [bp].r_dx	; autodetecting and modify value
		add	ax , [bp].r_si	; returned in AX register
		add	ax , [bp].r_di
		mov	[bp].r_ax , ax

		mov	ax , [bp].r_cx
		mov	dx , [bp].r_dx
		mov	bx , [bp].r_si
		mov	cx , [bp].r_di
		push	DRV_STAT2
		or	DRV_STAT2, FO_ENABLE
		call	VField
		pop	DRV_STAT2
		mov	[bp].r_cx , ax
		mov	[bp].r_dx , dx
		mov	[bp].r_si , bx
		mov	[bp].r_di , cx
		add	bx , ax
		add	bx , cx
		add	bx , dx
		mov	[bp].r_bx , bx
		retn
I_ConvManCor	endp

;==============================================================================
;	Procedure <StopTracking> stops traking any object
;   AX = 1   - stops tracking immediatelly in the next 0.1 second
;   AX = 0   - stops tracking smootly
;==============================================================================

I_StopTracking	proc	near
		mov	ax , [bp].r_bx
StopTracking:   cmp	ax , 0
		je	@@00
		cmp	ax , 1
		je	@@01
		retn
	@@01:   lea	si , DRV_X
		call	DC_Stop
		lea	si , DRV_Y
		call	DC_Stop
	@@00:	or	DRV_STAT2 , RESET_DRIVER
		call	LaserDisable
		call	ApplyTrackingOpt
		retn
		retn
I_StopTracking	endp


;=============================================================================
;  Procedure: I_ModelInfo
;  Provides:  TDRV API call 18h: get information about instrument model file
;
;  Registers: AH - TDRV API multiplex interrupt ID
;	      AL - TDRV API function number - 18h
;	      BX - function code
;=============================================================================
;  BX=8,9   - get interpolated value of corrections caused by instrument
;             model. (8-for the 1-st coordinate, 9- for the second one).
;             0 is returned if no model is available
;
;             Input:   CX:DX - coordinate value in TDRV internal units
;                              (CX is higher word)
;             Output:  DX:AX - the correction value in TDRV internal units
;
;=============================================================================

I_ModelInfo	proc	near
                mov     bx , [bp].r_bx
		cmp	bx , 16		  	; Look for range of argument
                jb      @@Go                    ; must in inside [0...15]
  @@Err:	or	[bp].r_flags , 1	; Error: return with CF=Y
		retn
  @@Go:     	shl	bx , 1			; Offset in function table
		mov	bx , @@MInfoProc [bx]	; Look if the function is
		or	bx , bx			; defined. If not return with
		je	@@Err			; CF=Y
		jmp	bx

  @@MInfoProc	dw      0
		dw	0
		dw	0
		dw	0
		dw	0         ; 4
		dw	0
		dw	0
		dw	0
		dw	@@CorrX   ; 8
		dw	@@CorrY   ; 9
		dw	0	  ; 10
		dw	0         ; 11
		dw	0         ; 12
		dw	0         ; 13
		dw	0         ; 14
		dw	0         ; 15

  @@CorrX:	lea     si , DRV_X
		jmp	@@CorrGo
  @@CorrY:	lea	si , DRV_Y
  @@CorrGo:     mov	ax , [bp].r_dx		; Get lower word
		mov	dx , [bp].r_cx		; Get higher word
		call    DC_GetDrvCorrection
		mov     [bp].r_ax , ax
		mov	[bp].r_dx , dx
		retn

I_ModelInfo	endp

_TEXT           ends
		end
