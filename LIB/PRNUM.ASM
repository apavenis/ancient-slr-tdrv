	.XList
        include OUTPUT.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;*****************************************************************************
;	Output numbers to  <stdout>
;
; -- PrintUnsigned	: output unsigned integer number (from AX)
; -- PrintInteger       : output signed integer number (from AX)
; -- PrintUnsignedLong  : outputs double word in decimal system (from DX,AX)
; -- PrintLong		: output signed integer number (from DX,AX)
; -- PrintBByte         : output byte in bit form (from AL)
;
;*****************************************************************************

PrintNumber	proc	near
PrintUnsigned:
		xor	dx , dx
		xor	bx , bx
		mov	cx , 10
		jmp	DoOutput_01
PrintInteger:
		cwd
		xor	bx , bx
		mov	cx , 10 + SIGNED_LONG
		jmp	DoOutput_01
PrintLong:
		xor	bx , bx
		mov	cx , 10 + SIGNED_LONG
		jmp	DoOutput_01
PrintUnsignedLong:
		xor	bx , bx
		mov	cx , 10
		jmp	DoOutput_01
PrintBByte:
		xor	ah , ah
		xor	dx , dx
		mov	bx , 8
		mov	cx , 2 + LEADING_ZEROS

DoOutput_01:	push	bx		; Output length
		push	cx		; Type and radix
		push	cs		; Output buffer address
		push	Offset NumBuffer
		push	dx		; Value : High word
		push	ax		; Value : Low word
		call	ltoax
		push	Offset NumBuffer
		call	PrintString
		ret

NumBuffer	db	16 dup (0)
PrintNumber	endp

_TEXT	ends
	end
