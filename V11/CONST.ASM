		.286
		locals
		.XList
		include LIB.INC
		include TDRV.INC
		.List

_TEXT		segment	byte public 'CODE'
		assume	cs:_TEXT , ds:_TEXT

GetConfigParam  proc	near
		mov	bx , [bp].r_bx
		cmp	bx , @@ParamCount
		jae	@@Done
		shl	bx , 2
		mov	ax , @@ParamTable [bx+2]  ;Function that copies param
		mov	bx , @@ParamTable [bx]
@@ReturnByte:   mov	al , byte ptr [bx]
		xor	ah , ah
		jmp	@@ReturnWord
@@ReturnDWord:	mov	ax , word ptr [bx+2]
		mov	[bp].r_dx , ax
@@ReturnWord:	mov	ax , word ptr [bx]
		mov	[bp].r_ax , ax
@@Done:         ret

@@ParamCount	dw	0010h

@@ParamTable	dw      X_UPD,		@@ReturnDWord	; 0
		dw      Y_UPD,		@@ReturnDWord   ; 1
		dw      0,		@@ReturnWord    ; 2
		dw      0,		@@ReturnWord    ; 3
		dw      0,		@@ReturnWord    ; 4
		dw      0,		@@ReturnWord    ; 5
		dw      0,		@@ReturnWord    ; 6
		dw      0,		@@ReturnWord    ; 7
		dw      0,		@@ReturnWord    ; 8
		dw      0,		@@ReturnWord    ; 9
		dw      0,		@@ReturnWord    ; A
		dw      0,		@@ReturnWord    ; B
		dw      0,		@@ReturnWord    ; C
		dw      0,		@@ReturnWord    ; D
		dw      0,		@@ReturnWord    ; E
		dw      0,		@@ReturnWord    ; F
@@EndOfParam	equ 	this word

GetConfigParam	endp

_TEXT		ENDS
		END