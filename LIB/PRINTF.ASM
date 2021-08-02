
		LOCALS
.XList
		include	LIB.INC
		include	OUTPUT.INC
.List

_TEXT		segment	byte public 'CODE'
		assume	cs:_TEXT , ds:_TEXT

		IS_FLD_DESCR	=	00001h
		LONG_NUM	=	00002h
		START_DESCR	=	00004h

_PrintF         proc	near
		arg	FmtAddr 	:word
		local   FieldLen	:word , \
			LastPos		:word ,	\
			FldType		:word , \
			Radix		:word , \
			Index		:word , \
			Options		:word   \
			= LocBytes
		push    bp		; Entry code : compatible
		mov	bp , sp      	; with 8086
		sub	sp , LocBytes
		push	si
		push	dx
		push	cx
		push	bx
		push	ax

		mov	si , FmtAddr	; Load format address from stack
		lea	bx , [bp+6]	; Next argument address
@@RdLoop0:	mov	Options , 0
@@RdLoop:       call	@@GetFmtByte
		jnz	@@NotZero
		jmp	@@Done

@@NotZero:	test	Options , IS_FLD_DESCR
		jnz     @@5
@@1:        	cmp     al , '%'
		je	@@4
@@3:		call	PrintChar
		jmp	@@RdLoop0
@@4:            mov	Options , IS_FLD_DESCR + START_DESCR
		mov	FieldLen , 0
		mov	FldType , 0
		jmp	@@RdLoop
@@5:            cmp	al , '0'
		jb	@@NotDig
		je	@@ZeroDig
		cmp	al , '9'
		ja      @@NotDig
		jmp	@@6
@@ZeroDig:	test    Options , START_DESCR
		jz      @@6
		or      FldType , LEADING_ZEROS
		jmp	@@RdLoop
@@6:            and	Options , Not START_DESCR
		push	ax
		mov	ax , FieldLen
		shl	ax , 1
		shl	ax , 1
		add	FieldLen , ax
		shl	FieldLen , 1
		pop	ax
		and	ax , 15
		add	FieldLen , ax
		jmp	@@RdLoop
@@NotDig:       test	Options , START_DESCR
		jz	@@10
		cmp	al , '+'
		jne	@@10
		or	FldType , PLUS_SIGN
		jmp	@@RdLoop
@@10:		cmp	al , '%'	; %% - print '%'
		je	@@3
		cmp	al , 'l'	; %l...
		jne	@@11
		or	Options , LONG_NUM
		jmp     @@RdLoop
@@11:		cmp     al , 'u'
		jne	@@12
		mov	Radix , 10
		jmp     @@Number
@@12:		cmp	al , 'd'
		jne	@@13
		or	FldType , SIGNED_LONG
		mov	Radix , 10
		jmp	@@Number
@@13:           cmp	al , 'x'
                je      @@Hex
		cmp     al , 'X'
		jne     @@14
@@Hex:          mov     Radix , 16
		jmp	@@Number
@@14:           cmp	al , 'c'
		jne	@@15
		mov	ax , ss:[bx]
		add     bx , 2
		call	PrintChar
		jmp	@@RdLoop0
@@15:		cmp	al , 's'
		jne	@@16
		push	ss:[bx]
		add	bx , 2
		call	PrintString
		jmp	@@RdLoop0
@@16:		cmp	al , 'b'
		je	@@Bit
		cmp	al , 'B'
		jne	@@17
@@Bit:		mov	Radix , 2
		jmp	@@Number
@@17:		jmp	@@3

@@Number:     	push    FieldLen		; Push length of data

		mov	ax , FldType
		add	ax , Radix
		push    ax			; Push data type

		lea	ax , NumBuffer		; Push far pointer to the
		push	cs			; buffer
		push	ax

		mov	ax , ss:[bx]
		add     bx , 2
		test	Options , LONG_NUM
		jz      @@21
		mov	dx , ss:[bx]
		add	bx , 2
		jmp	@@23
@@21:           test	FldType , SIGNED_LONG
		jnz	@@22
		xor	dx , dx
		jmp	@@23
@@22:		cwd
@@23:           push	dx
		push	ax
		mov	Index , bx
		call	ltoax
		mov	bx , Index
		lea	ax , NumBuffer
		push	ax
		call	PrintString
		jmp	@@RdLoop0

@@Done:         pop	ax
		pop	bx
		pop	cx
		pop	dx
		pop	si
		mov	sp , bp		; Exit code
		pop	bp
		ret

NumBuffer	db	32 dup (' '),0

@@GetFmtByte:	lodsb
		or	al , al
		retn

_PrintF		endp

_TEXT		ends
		END
