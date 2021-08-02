
		.286

		.XList
		include TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
		.List

_TEXT           segment byte public 'CODE'
		assume  CS:_TEXT , DS:_TEXT
;
;=============================================================================
;       Procedure <ReadClkCounter> returns counter from chip I8254 or I8254
;   in register AX. This procedure can be used to measure time intervals less
;   than 0.0552 seconds.
;=============================================================================
;
ReadClkCounter  proc    near
		push	cx
		pushf
		cli
		mov	al , 0
		out	43h , al	; Fix clock counter
		jmp	short $+2
		in 	al , 40h	; Read low byte
		mov	ah , al         ; Save it in AH
		in	al , 40h	; Read high byte
		xchg	al , ah         ; Swap AL and AH
		xor	ax , 0FFFFh	; Inverse result
		popf
		pop     cx
		ret
ReadClkCounter	endp
;
;=============================================================================
;       Procedure <GetCpuSpeed> returns number of empty loops that can be
;   executed in 256 microseconds. Procedure can be used to establish delays
;   that is necessary between I/O operations.
;=============================================================================
;
GetCpuSpeed	proc	near
		push	cx
		push	dx
		push	si
		mov     cx , 1000h
		pushf
		cli
		call    ReadClkCounter
		mov	si , ax
	CS1:	loop	CS1
		call	ReadClkCounter
		popf
		xchg	ax , si
		sub	si , ax
		mov	ax , 0000h
		mov     dx , 0010h

		div	si
		pop	si
		pop	dx
		pop	cx
                retn
GetCpuSpeed	endp


outportbw 	proc	near
		push	cx
		out	dx , al
		mov     cx , cpuSpeed
	op_01:  loop	op_01
		pop	cx
		ret
outportbw       endp


DummyProc       proc	near
		ret
DummyProc	endp


IO_Wait		proc	near
		push	ax cx dx
		mov	cx , 18
	@@01:	mov	ax , 15
		imul    ax , ax , 45
		loop	@@01
		pop	dx cx ax
		ret
IO_Wait		endp


isSound		db	0

sound           proc    near
		push	bx
		push	cx
		mov     bx , ax
		mov     ax , 34DDh
		mov     dx , 0012h
		cmp     dx , bx
		jnb     j2
		div     bx
		mov     bx , ax
		in      al , 61h
		test    al , 3
		jne     j1
		or      al , 3
		out     61h , al
		mov     al , 0B6h
		out     43h , al
j1:             mov     al , bl
		jmp	short $+2
		jmp	short $+2
		out     42h , al
		mov     al , bh
		jmp	short $+2
		jmp	short $+2
		out     42h , al
j2:             or	cs:isSound , 1
		pop	cx
		pop	bx
		ret
sound           endp

nosound         proc    near
		test	cs:isSound , 255	; We use CS because of this
		jz	@@1			; procedure is called from
		in      al , 61h		; IRQ handler procedures when
		and     al , 0FCh		; DS does not have correct
		jmp	short $+2		; value
		jmp	short $+2
		out     61h , al
	@@1:	mov	cs:isSound , 0
		ret
nosound         endp



_TEXT		ENDS
		END
