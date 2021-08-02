	.XList
        include OUTPUT.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;=============================================================================
;
;  PROCEDURE :   PrintFarPtr
;
;     	Outputs far pointer to MS DOS standard output
;
;  ARGUMENTS :
;       DX:AX   - Far pointer to be outputed
;
;=============================================================================

PrintFarPtr	proc	near
		push	ax
		mov	ax , dx
		call	PrintHexWord
		mov	al , ':'
		call	PrintChar
		pop	ax
		call	PrintHexWord
		ret
PrintFarPtr	endp

_TEXT	ends
	end
