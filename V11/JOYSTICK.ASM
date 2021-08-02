		.286
		locals

		include	TDRV.INC


_TEXT		segment	byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT


NON_LINEAR	equ	0

J_Active	dw	0

;===========================================================================
;   Joystick control information
;===========================================================================

CenterX		dw	40		; The reading of joystick coordinate
					; X in the center
CenterY		dw	40		; The reading of joystick coordinate
					; Y in the center
jcWidth         dw      8               ; halfwidth of joystick dead zone
					; around central position
jOptions	dw	0		; some joystick related options
					; (inverting corrections from joystick)

;===========================================================================

TakeJoystick	proc	near
		mov	J_Active , 1
		retn
		endp

ReleaseJoystick	proc	near
		mov	J_Active , 0
		retn
		endp

;=============================================================================

J_GetXY		proc	near
		test	HRDW_OPT , ENABLE_JOYSTICK
		jz	@@01
		test	J_Active , 0FFFFh
		jnz	J_GetXY0
	@@01:	xor	ax , ax
		xor	bx , bx
		retn

J_GetXY0:       push	cx
		push	dx
		call	_ReadJoystick
		mov	ax , _JButtons
		shl	ax , 3
		and     DRV_STAT2 , Not(JS_BUTTON1+JS_BUTTON2+JS_BUTTON3+JS_BUTTON4)
		or      DRV_STAT2 , ax
		mov	ax , _JX
		mov	bx , _JY
;----------------------------------------------------------------------------
;   Now the values read from joystick are in registers:
;      AX - correction for the first coordinate
;      BX - correction for the second coordinate
;----------------------------------------------------------------------------
		push	ax		; Save value for 1st coord
		mov	ax , bx		; Value. for 2nd correction
		mov	bx , CenterY	; Center position for 2nd coord.
		mov	cx , jcWidth	; Width of central (dead) part
		call    GetJVal		; Convert value to the correction and
		mov	dx , ax		;   save it into register DX
		pop	ax              ; Restore value gfor the 1st coord
		mov	bx , CenterX	; Center position for 1st coord.
		mov     cx , jcWidth	; Width of central (dead) part
		call	GetJVal		; Width of central (dead) part
		mov	bx , dx         ; Restore correction for 2nd coord

	@@30:   test	jOptions , J_INVERT_X
		jz	@@31
		neg	ax
	@@31:	test	jOptions , J_INVERT_Y
		jz	@@32
		neg     bx
	@@32:	pop     dx
		pop	cx
		neg     bx
		retn
J_GetXY		endp



;===========================================================================
;  Get value for joystick correction
;       AX - value read from joystick
;       BX - center value
;       CX - center width
;===========================================================================

IF NON_LINEAR Ne 0

GetJVal		proc
		push	dx
		cmp	ax , 0400h	; Lets avoid too big values
		jbe	@@10
		mov	ax , bx
	@@10:	sub	ax , bx		; Subtract value in the center
		push	ax
		shl	ax , 1		; Isolate sign in CF
		pop	ax
		pushf			; And save it in stack
		jnc	@@11            ; Take absolute value
		neg	ax
	@@11:   sub     ax , cx
		jnc	@@12
		xor	ax , ax
	@@12:   mov	bx , ax
		mul	bx
		mov	cx , 3
	@@13:	shr	dx , 1
		rcr	ax , 1
		loop	@@13
		add	ax , bx
		popf
		jnc	@@14
		neg	ax
	@@14:   pop	dx
		retn
GetJVal		endp

ELSE

GetJVal		proc
		push	dx
		cmp	ax , 0400h	; Lets avoid too big values
		jbe	@@10
		mov	ax , bx
	@@10:	sub	ax , bx		; Subtract value in the center
		push	ax
		shl	ax , 1		; Isolate sign in CF
		pop	ax
		pushf			; And save it in stack
		jnc	@@11            ; Take absolute value
		neg	ax
	@@11:   sub     ax , cx
		jnc	@@12
		xor	ax , ax
	@@12:   popf
		jnc	@@14
		neg	ax
	@@14:   pop	dx
		retn
GetJVal		endp

ENDIF

;===========================================================================

I_Joystick	proc	near
		mov     bx , [bp].r_bx
		cmp     bx , 10h
		jae	@@Err
		shl	bx , 1
		mov	bx , @@JFunctTable [bx]
		cmp	bx , 0
		je	@@Err
		jmp 	bx

@@JFunctTable	dw	@@CheckSign	; BX=00h - check extended support
		dw	@@Read		; BX=01h - reads joystick
		dw	@@ReadCorr	; BX=02h - reads joystick corrections
		dw	@@ReadLast	; BX=03h
		dw	0               ; BX=04h
		dw	0               ; BX=05h
		dw	0               ; BX=06h
		dw	0               ; BX=07h
		dw	0               ; BX=08h
		dw	0               ; BX=09h
		dw	0               ; BX=0Ah
		dw	0               ; BX=0Bh
		dw	0               ; BX=0Ch
		dw	0               ; BX=0Dh
		dw	0               ; BX=0Eh
		dw	@@GetOptAddr    ; BX=0Fh

	@@Err:	or	[bp].r_flags , 1
		ret

		;-------------------------------------------------------------
   @@CheckSign: mov	[bp].r_ax , 04587h
		mov	[bp].r_dx , 07854h
		retn
		;-------------------------------------------------------------
   @@Read:      cli				; Reads joystick coordinates
		call	_ReadJoystick 		; and button status
		sti				; Returns values in registrs
		mov	ax , _JX                ; (only after return from
		mov	bx , _JY		; interrupt):
		mov	cx , _JButtons          ;   AX - coordinate X
   @@StVal:	mov	[bp].r_ax , ax		;   BX - coordinate Y
		mov	[bp].r_bx , bx		;   CX - button status
		mov	[bp].r_cx , cx
		retn
		;-------------------------------------------------------------
   @@ReadCorr:	cli				; Reads joystick corrections
		call	J_GetXY0		; after conversion
		sti
		mov	[bp].r_ax , ax
		mov 	[bp].r_bx , bx
		mov	ax , _JButtons
		mov	[bp].r_cx , ax
		retn
		;-------------------------------------------------------------
  @@GetOptAddr: lea     ax , CenterX		; Get address of joystick
		mov	dx , cs			; parameters
		mov     [bp].r_ax , ax
		mov	[bp].r_dx , dx
		retn
		;-------------------------------------------------------------
  @@ReadLast:	mov	ax , _JX
		mov	bx , _JY
		mov     cx , _JButtons
		jmp	@@StVal
		;-------------------------------------------------------------
I_Joystick	endp




ReadClockCnt	PROC	NEAR
		push	bx
		push	cx
		mov     al , 0C2h       ; Send command to fix counter value
		out     43h , al        ; for 8254 chanal 0 (PC timer) and
					; status byte of this chanal
		in	al , 40h	; Read 8254 status for chanal 0
		mov	ah , al		; Duplicate status
		and	al , 6		; Extract 2 of 3 mode bits only
		mov	bx , ax		; and save the result in BX
		in      al , 40h        ; Load lower byte of timer counter
		xchg    al , ah         ; Save it
		in      al , 40h        ; Load higher byte of timer counter
		xchg    al , ah         ; and build resulting word
		mov	cx , ax		; Save counter for later use
		cmp	bl , 6		; Look if chanal is in mode 3
		jne	@@12		; Skip the followin code if not
		or	ax , ax		; Look if the counter is 0:
		jne	@@11		; [I know at least one computer where
		mov	al , 0E2h	;  we cannot trust the status if
		out	43h , al	;  counter is 0. Therefore we have to
		jmp	short $+2	;  read status once more]
		in	al , 40h	; Now certainly the output line status
		xor	al , 80h
		mov	bh , al		; is changed. After that copy it to BH
	@@11:   shl	bh , 1		; Move output line status in CF
		rcr	cx , 1		; And shift it into result
	@@12:	mov	ax , cx
		neg	ax
		pop	cx
		pop	bx
		retn
ReadClockCnt	ENDP


_JButtons	dw	0
_JX		dw	0
_JY		dw	0


_ReadJoystick	PROC	NEAR
		Local   StartTime	:Word  \
		       = LocBytes
		Enter   LocBytes , 0

		push	ax			; Let's save registers we'll
		push	bx			; change
		push	dx
		pushf				; Save also processor flags
		cli				; and disable interrupts
						; for joystick reading time

		call    ReadClockCnt  		; Read counter of PC timer
		mov	StartTime , ax          ; and save as the start time

		mov	dx , 0201h		; A joystick port
		out	dx , al			; Trigger joystick

	@@11:   call	ReadClockCnt		; Read counter of PC timer
		mov	bx , ax			; and copy it to BX
		in      al , dx			; Tests joystick port
		mov	ah , al                 ; and save the value
		and	al , 3			; Exit the loop if all done
		jz      @@21                    ; While the values of 2 lower
		shr	al , 1			; bits in AL are one update
		jnc	@@12			; corresponding values
		mov     _JX , bx		; of time in _JX and _JY
	@@12:   shr	al , 1
		jnc	@@13
		mov	_JY , bx
	@@13:   sub	bx , StartTime		; If less than 2 ms have
		cmp	bx , 2380		; passed then go to the next
		jbe	@@11			; loop. Otherwise exit the
						; loop
	@@21:   popf                            ; Restore processor flags
		not	ax			; and finish the work
		shr	ax , 12
		and	ax , 15
		mov     _JButtons , ax
		mov	ax , StartTime
		sub	_JX , ax
		sub	_JY , ax
		shr	_JX , 3
		shr	_JY , 3
		pop	dx
		pop	bx
		pop	ax
		Leave
		RetN
_ReadJoystick	ENDP

		ENDS
		END

		ends
		end

