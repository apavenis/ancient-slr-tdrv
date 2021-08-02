	.XList
	include LIB.INC
	.List

	locals
_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;-----------------------------------------------------------------------------
;	long  FindWord ( char near * , WList near * )
;-----------------------------------------------------------------------------

FindWord 	proc	near
		local   CurrIdentL	:word	, \
			CurrIdentH	:word	, \
			WordAddr	:word   , \
			= LocBytes
		arg     _Str		:word	, \
			WL		:word	  \
			= RetBytes
                push    bp
                mov     bp , sp
                sub     sp , LocBytes
;               enter   LocBytes , 0
		push    si
		push	di
		push	es

		push	ds		; Copy register DS to ES
		pop	es
		cld			; Increment positive for string op.
		mov     si , WL
@@1:            mov	WordAddr , si	; Save address in table
		lodsw             	; Copy double word to temporary
		mov     CurrIdentL,ax	; variable
		lodsw
		mov	CurrIdentH,ax
		or	ax,CurrIdentL	; Zero in both words is treated
		jnz	@@2		; as the end of list
		stc         		; Word is not found in list:
		jmp     @@99		;  SET CF=1 AND EXIT
@@2:            mov	di , _Str
		xor	cl , cl         ; Difference flag
@@3:            lodsb      		; Load byte from list of names
		or	al , al		; End of name?
		je	@@4		; >> YES >>
		scasb
		jz	@@3
		or	cl , 1		; Set difference flag
		jmp	@@3
@@4:            or	cl , cl		; Take next name if no differences
		jnz	@@1		; are found
		mov	al , [di]	; Look for the next byte
		lea	bx , CharTable
		xlat
		test	al , IS_DIGIT+IS_ALPHA
		jnz     @@1
		mov	ax , CurrIdentL
		mov	dx , CurrIdentH
		mov	bx , di
		mov	cx , WordAddr
		clc
@@99:		pop	es
		pop	di
		pop	si
;               leave
                mov     sp , bp
                pop     bp
                retn    RetBytes
FindWord	endp


_TEXT	ends
	end
