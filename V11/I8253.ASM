
		.286
		locals
		.XList
		include	TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
		.List

_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT

;-----------------------------------------------------------------------------
;  Procedure: 	I8253_Write
;  Arguments:   DX - port address
;		AX - value to be written
;               BL - mode to be written (0-5)
;-----------------------------------------------------------------------------

I8253_WriteC    proc	near            ; We have to send command code too
		push	dx		; Save port address in stack
		push	ax		; Save value in stack
		mov	al , dl  	; Extract chanal number from port
		and	al , 06h	; and shift to higher bits
		shl	al , 5          ;
		or	al , 030h	; Write lower bit then higher one
		and	bl , 7
		shl	bl , 1		; Add requested mode
		or	al , bl         ; and output data to port
		out	dx , OutRegister ; AL or AX		;
		out	80h, al
 		BTRACE
		pop	ax
		pop	dx
I8253_Write:    jmp	short $+2
		jmp	short $+2
		jmp	short $+2
		out	dx , OutRegister
		out	80h, al
		BTRACE
		xchg    al , ah
		jmp	short $+2
		jmp	short $+2
		jmp	short $+2
		jmp	short $+2
		out	dx , OutRegister
		out	80h, al
		BTRACE
		retn
I8253_WriteC	endp

;-----------------------------------------------------------------------------


_TEXT		ends
		end
