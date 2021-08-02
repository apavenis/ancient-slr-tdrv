
		.286
		.XList
                include OUTPUT.INC
		.List

_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT

IS_ZERO		equ	1
IS_SIGN		equ	2

ltoax           proc	near
		local	Buffer		:byte:34 ,	\
			LenCount	:word ,		\
			ltStatus	:byte ,		\
			Sign		:byte		\
			= LocBytes
		arg     Value		:dword ,	\
			OutpAddr	:dword ,	\
			OutpType        :word  ,        \
			MinLength	:word		\
			= RetBytes

                push    bp
                mov     bp , sp
                sub     sp , LocBytes
;               enter   LocBytes , 0
		push	si
		push	di
		push	es

		cld
		les	di , OutpAddr		; Output address
		mov	ltStatus , 0
		mov	Sign , ' '

		;--------------------------------------------------------;
		;    Test radix (must be in range 2...36)                ;
		; If radix is out of that range then return empty string ;
		;--------------------------------------------------------;

		mov     bx , OutpType
		cmp	bl , 2
		jb	RadixInvalid
		cmp	bl , 36
		jb	RadixOk
RadixInvalid:	jmp     ltoa_End
RadixOk:

		;-------------------------------------------------------;
		;    Process length request                             ;
		;-------------------------------------------------------;

		mov	ax , MinLength
		or	ax , ax
		jl	InvLength
		cmp	ax , 32
		jbe	LengthOk
InvLength:	mov	ax , 0
		and     OutpType , Not (DEF_LENGTH+LEADING_ZEROS)
LengthOk:	mov     LenCount , ax

		;-------------------------------------------------------;
		;    Now load value and look for sign when necessary    ;
		;-------------------------------------------------------;

		mov     ax , word ptr Value
		mov	dx , word ptr Value+2

		test	bx , SIGNED_LONG
		jz	ltoa_SignOk
		test	bx , PLUS_SIGN
		jz	ltoa_NoPlus
		or	ltStatus , IS_SIGN
ltoa_NoPlus:	mov     Sign , '+'
		or	dx , dx			; Look sign
		jnl	ltoa_SignOk
		neg     dx
		neg	ax
		sbb	dx , 0
		mov	Sign , '-'
		or	ltStatus , IS_SIGN
ltoa_SignOk:

		;-------------------------------------------------------;
		;    Now we extract all digits beginning from low ones  ;
		; The digits are being stored in inverse order in the   ;
		; buffer.                                               ;
		;-------------------------------------------------------;

		mov	cx , dx			; Copy high word to CX
		and	bx , 255		; Radix
		xor	si , si			; Index

ltoa_LongLoop:  xchg	cx , ax
		xor	dx , dx
		div	bx
		xchg	ax , cx
		div	bx
		add	dl , '0'
		cmp	dl , '9'
		jbe	ltoa_PutDigit
		add	dl , 7
ltoa_PutDigit:	mov	Buffer[si] , dl		; Store digit
		dec	LenCount
		inc	si
		test    OutpType , DEF_LENGTH
		je	ltoa_LongTest
		cmp	LenCount , 0
		jle     ltoa_LoopDone
ltoa_LongTest:	or	cx , cx
		jne	ltoa_LongLoop
		or	ax , ax
		jne	ltoa_LongLoop
		or      ltStatus , IS_ZERO
		cmp	LenCount , 0
		jle     ltoa_LoopDone
		test    OutpType , LEADING_ZEROS
		jnz     ltoa_LongLoop
		mov	dl , ' '
		jmp	ltoa_PutDigit
ltoa_LoopDone:

		;-------------------------------------------------------;
		;    All digits are stored in the buffer in reverse     ;
		; order. Now convert them to ASCII and store in the     ;
		; result string in correct order.                       ;
		;-------------------------------------------------------;

		test	ltStatus , IS_SIGN
		jz	ltoa_CopyLoop
		mov	Buffer[si] , ' '
		inc	si
		push	si
ltoa_FindSign:  dec	si           	     	; The buffer contains at least
		cmp	Buffer[si] , ' '  	; one digit. Therefore test for
		je	ltoa_FindSign     	; SI==0 is not necessary
		mov	al , Sign
		mov	Buffer+1 [si] , al	; Store sign
		pop	si

ltoa_CopyLoop:  or	si , si			; Is all digits copied ?
		jle	ltoa_CopyDone
		dec	si
		mov	al , Buffer[si]
		test    ltStatus , IS_ZERO
		jnz	ltoa_PutResult
		test    OutpType , CHECK_SIZE
		jz      ltoa_PutResult
		mov	al , '*'
ltoa_PutResult:	stosb
		jmp	ltoa_CopyLoop
ltoa_CopyDone:

ltoa_End:       mov	al , 0
		stosb
ltoa_Done:	pop	es
		pop	di
		pop	si
;                leave
                mov     sp , bp
                pop     bp
		ret	RetBytes
ltoax		endp

_TEXT		ends
		end
