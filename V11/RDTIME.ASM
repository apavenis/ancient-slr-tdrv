		.286
                locals
                include LIB.INC

_TEXT           segment byte public 'CODE'
                assume  CS:_TEXT , DS:_TEXT

;===============================================================================
;   The procedure <GetTime0> returns time in units of (1/1193180) seconds
;
;   The value is returned as 6 bytes long integer number in registers
;   AX (low word) , DX , CX (high word)
;
;   WARNING:  This procedure will not work with timer 8253 !!!
;             Timer 8254 is necessary.
;===============================================================================

GetTime0        PROC    NEAR
		pushf
		cli                     ; Mask all iterrupts
		push    es              ; Save registers ES,BX and SI
                push    bx              ; to restore them before return
                push    si

                mov     ax , 040h       ; Segment where BIOS variables area
		mov     es , ax         ; os located
		mov     al , 0C2h       ; Send command to fix counter value
		out     43h , al        ; for 8254 chanal 0 (PC timer) and
					; status byte of this chanal
		mov     dx , es:[06Ch]  ; Retrieve BIOS timer counter from
		mov	si , es:[06Eh]	; BIOS variables area
		in	al , 40h	; Read 8254 status for chanal 0
		mov	ah , al		; Duplicate status
		and	al , 6		; Extract 2 of 3 mode bits only
		mov	bx , ax		; and save the result in BX
		in      al , 40h        ; Load lower byte of timer counter
		xchg    al , ah         ; Save it
		in      al , 40h        ; Load higher byte of timer counter
		xchg    al , ah         ; and build resulting word
		mov	cx , ax		; Save counter for later use

                cmp     bl , 6          ; Look  if chanal is in mode 3
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

	@@12:   cmp	cx , 08000h	; Look if we have to test for pending
		jb	@@13		;     IRQ 0.
		mov	al , 0Ah	; Send 8259 command to return IRR
		out	20h , al	;   (Interrupt request register)
		jmp	$+2		; Waste some time before reading IRR
		in	al , 20h	; Retrieve IRR from 8259
		test	al , 1		; Look if IRQ 0 is requested. If so
		jz	@@13		; then add 1 to the value retrieved
		add	dx , 1          ; from BIOS timer.
		adc	si , 0

	@@13:   not     cx
		mov	ax , cx
		mov	cx , si

		add	ax , 1
		adc	dx , 0
		adc	cx , 0

                pop     si              ; Now we can restore registers
                pop     bx              ; SI,BX and ES from stack and return
                pop     es              ; to caller
                popf                     ;
                RET
GetTime0        ENDP

_TEXT           ENDS
                END

