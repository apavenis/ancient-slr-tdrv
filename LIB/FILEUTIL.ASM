		locals
		.286

		.XList
		include LIB.INC
		.List

_TEXT		Segment byte public 'CODE'
		Assume	CS:_TEXT , DS:_TEXT

;-----------------------------------------------------------------------------
;    _tell : returns current position in file
;-----------------------------------------------------------------------------
;    Input:    BX     - file handle
;    Output:   DX:AX - current pointer (DX-high word)
;	       CF=Y on error
;-----------------------------------------------------------------------------
_tell		proc	near
		push	cx
		mov	ax , 04201h   	; DOS FN: Seek from current position
		xor	cx , cx		; We don't really want to move the
		xor	dx , dx		; pointer (therefore offset is 0)
		int	21h		; Issue DOS FN call
		pop	cx
		retn
_tell		endp

;-----------------------------------------------------------------------------
;    _seek : moves file pointer
;-----------------------------------------------------------------------------
;    Input:    BX     - file handle
;              DX:AX - desired location.
;    Output:   DX:AX - current pointer (DX-high word) after call
;	       CF=Y on error
;-----------------------------------------------------------------------------
_seek		proc	near
		push	cx
		mov	cx , dx		; New location must be in DX:CX
		mov	dx , ax  	; (CX - higher word)
		mov     ax , 04200h	; DOS Fn: seek from begin of file
		int     21h
		pop	cx
		retn
_seek		endp



_TEXT		EndS
		END