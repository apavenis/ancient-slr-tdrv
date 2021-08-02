	.XList
        include OUTPUT.INC
	.List


_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

PrintHexWord	proc	near
		push	ax
		mov	al , ah		; Select high byte
		call	PrintHexByte
		pop	ax
PrintHexByte:   push	ax
		shr	al , 4
		call	PrintHexDigit
		pop	ax
PrintHexDigit:  and	al , 15
		cmp	al , 10
		cmc
                adc     al , 48
		daa
		call	PrintChar
		ret
PrintHexWord	EndP

_TEXT	ends
	end
