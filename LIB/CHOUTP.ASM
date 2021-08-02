	.XList
        include OUTPUT.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

		.8086
ChOutp          proc    near
NewLine:        mov     al , 10
PrintChar:	cmp	al , 10
		jne	Pch1
		mov	al , 13
		call	Pch1
		mov	al , 10
Pch1:		push	ax
		push	dx
		mov     dl , al
		mov	ah , 2
		int	21h
		pop	dx
		pop	ax
		ret
ChOutp          endp

_TEXT	ends
	end
