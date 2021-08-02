		Locals
		.286

_TEXT		Segment	Byte Public 'CODE'
		Assume  CS:_TEXT, DS:_TEXT


		Global	_JButtons	:Word
		Global	_JX		:Word
		Global	_JY		:Word
		Global	_ReadJoystick	:Near


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
		Local   StartTime	:Word,  \
			B1_Time		:Word,  \
			B2_Time		:Word	\
		       = LocBytes
		Enter   LocBytes , 0

		push	ax
		push	bx
		push	dx

		call    ReadClockCnt  		; Read counter of PC timer
		mov	StartTime , ax          ; and save as the start time

		mov	dx , 0201h		; A joystick port
		out	dx , al			; Trigger joystick

	@@11:   call	ReadClockCnt		; Read counter of PC timer
		mov	bx , ax			; and copy it to BX
		in      al , dx			; Tests joystick port
		mov	ah , al                 ; and save the value
		and	al , 3			; Exit the loop if all done
		jz      @@21
		shr	al , 1
		jnc	@@12
		mov     _JX , bx
	@@12:   shr	al , 1
		jnc	@@13
		mov	_JY , bx
	@@13:   sub	bx , StartTime
		cmp	bx , 2380
		jbe	@@11

	@@21:	not	ax
		shr	ax , 12
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