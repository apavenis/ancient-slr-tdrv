	.XList
        include OUTPUT.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

		.8086
PrintString     proc    near
		ARG	Strng:WORD = RetBytes
		push    bp
		mov     bp , sp
		push	si
		mov	si , Strng
PrintLoop:      lodsb
		or	al , al
		je	PrintDone
		call	PrintChar
		jmp	PrintLoop
PrintDone:	pop	si
		pop     bp
		ret	RetBytes
PrintString	endp

_TEXT	ends
	end
