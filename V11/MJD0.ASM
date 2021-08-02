		.286
		locals

_TEXT           Segment	Byte Public 'CODE'
		Assume	CS:_TEXT , DS:Nothing

V_5		dw	5
V_153		dw	153
V_1461		dw	1461

		global	DateToMJD		:Near
		global  MJDToDate		:Near

;-----------------------------------------------------------------------------
;       long  DateToMJD ( Year , Month , Day )
;-----------------------------------------------------------------------------
;		AX 	- Year
;		BX	- Month
;		CX	- Day
;-----------------------------------------------------------------------------

DateToMJD	proc	near
		sub	ax , 1900
		cmp     bx , 2
		jg	@@10
		add	bx , 9
		dec	ax
		jmp	@@11
	@@10:   sub	bx , 3
	@@11:   imul	V_1461		; Year * 1461
		sar	dx , 1
		rcr	ax , 1
		sar	dx , 1
		rcr	ax , 1		; (long) (Year*365.25)
		add	cx , 15078
		add	ax , cx
		adc	dx , 0		; Add day and start shift
		push	ax		; Save results in stack
		push	dx
		mov	ax , bx
		imul	ax , ax , 153
		add	ax , 2
		cwd
		idiv	V_5
		pop	dx
		pop	bx
		add	ax , bx
		adc	dx , 0
		ret
DateToMJD	endp

;-----------------------------------------------------------------------------
;       MJDToDate
;-----------------------------------------------------------------------------
;  Input:	AX,DX 	- mjd
;  Output:	AX	- Year
;		BX      - Month
;		CX	- Day
;  Results are correct from March 1900 to the end of 2099
;-----------------------------------------------------------------------------

MJDToDate	proc    near
		push	si
		push	di
		sub 	ax , 15078
		sbb	dx , 0
		mov	si , ax
		mov	di , dx
		shl	ax , 1
		rcl	dx , 1
		shl	ax , 1
		rcl	dx , 1
		idiv	V_1461
		push	ax
		mul     V_1461
		sar	ax , 2
		sub	si , ax
		mov	ax , si
		imul	ax , ax , 5
		sub	ax , 2
		cwd
		idiv	V_153
		mov	bx , ax
		imul	ax , ax , 153
		add	ax , 2
		cwd
		idiv     V_5
		sub	si , ax
		mov	cx , si
		add	bx , 3
		pop	ax
		cmp	bx , 12
		jbe	@@11
		sub	bx , 12
		inc	ax
	@@11:	pop	di
		pop	si
		add	ax , 1900
		retn
MJDToDate	endp

                ENDS
                END
