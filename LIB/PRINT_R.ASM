
		.XList
		include OUTPUT.INC
		.List

_TEXT		Segment Byte Public 'CODE'
		Assume 	CS:_TEXT , DS:_TEXT

Print_R		proc	near
		push	bp
		mov	bp , sp
		push	si
		mov     si , [bp+2]	; Return address
		cld
PS001:          lodsb
		or	al , al
		je	PS002
		call	PrintChar
		jmp	PS001
PS002:		mov     [bp+2] , si
		pop	si
		pop     bp
		retn
Print_R		endp

_TEXT		EndS
		End
