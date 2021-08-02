

		.286
		.XList
		include	ARITH.INC
		.List

_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT

;=============================================================================
;
;       Procedures : ISIN and ICOS
;
;       Argument:
;          Argument for corresponding trigonometric function in units
;	   of 0ø.1 in register pair (AX,DX)
;
;	Result:
;          Register AX contains SIN or COS of argument times 10000.
;          Other registers remains intact.
;
;=============================================================================

ISIN            proc	near
		call	lneg		; - x
		add	ax , 900	; ã/2 - x
		adc	dx , 0
ICOS:           push	bx
		push	cx
		push	si
		mov	bx , 3600	; Reduce argument to interval
		call	IMod42		;     [ 0 ... 2ã [
IC_001:         cmp	ax , 1800	; if (arg>=180)
		jb	IC_002		;     arg = 3600 - arg
		add	ax , -3600
		neg	ax
IC_002:         xor	cx , cx		; sgn=0;
		cmp     ax , 900	; if (arg>=90)
		jb	IC_003		;    {
		or	ch , 128	;       sgn=1;
		add	ax , -1800	;       arg = 180-arg
		neg	ax		;    }
IC_003:         cwd			; Convert to double word again
		div	V_00050		; Get index in AX and remainder in DX
		mov	si , ax		; Index in table
		shl	si , 1		; Offset
		mov	bx , dx		; Remainder
		mov	ax , cTbl+2[si]	; Get values from the table
		sub	ax , cTbl  [si]	; Increment
		imul    bx
		idiv	V_00050
		add	ax , cTbl  [si]
		or	ch , ch
		jnl	IC_004
		neg	ax
IC_004:		pop	si
		pop	cx
		pop	bx
		ret

V_00050		dw	  50
V_03600		dw	3600

cTbl		dw	10000,9962,9848,9659,9397,9063,8660,8191,7660
		dw     	7071,6428,5736,5000,4226,3420,2588,1736,872,0,-872

ISIN		endp

_TEXT		ends
		end
