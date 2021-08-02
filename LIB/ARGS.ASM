;                .286

		.XList
		include ARGLIST.INC
		.List

_TEXT		Segment	Byte Public 'CODE'
		Assume 	CS:_TEXT , DS:_TEXT

ArgString	db	129 dup (0)
ArgIndex	dw	0
LastChar	db	0

;	***********************************************************
;	*   Procedure  CopyArg(void)  copies argument string to   *
;	*         variable for further use                        *
;	***********************************************************

CopyArg		proc	near
                push    bp
                mov     bp , sp
;               Enter   0,0
		push	es

		mov     ah , 62h		; Get segment of current PSP
		int	21h
		mov	es , bx
		xor     bx , bx

		xor	ch , ch         	;   Get length of argument
		mov	cl , es: [80h]		; string in CX
		or	cx , cx  		;   Bypass copy when no
		je	CopyDone1		; arguments specified
CopyLoop1:      mov	al , es: [bx+81h]	;   Now copy argument string
		cmp	al , 61h		; from PSP to the <ArgString>
		jc	Copy_1                  ; (and convert this string
		cmp	al , 7Bh		; to uppercase)
		jnc	Copy_1
		xor	al , 20h
Copy_1:		mov	ArgString [bx] , al	;
		inc	bx
		Loop	CopyLoop1
CopyDone1:	mov     ArgString [bx] , 0      ;   Append 0 at the end of
						; the argument string
		mov	ArgIndex , 0
		mov	al , ArgString
		mov	LastChar , al
		pop	es
                pop     bp
;               Leave
		ret
CopyArg		endp


GetWord		proc	near
;                Enter   0,0
                push    bp
                mov     bp , sp
		push	si
		xor	si , si
		test	LastChar , 255		;   Look if the end of string
		je	GW_91			; is reached.
		mov	bx , ArgIndex		;   Restore current character
		mov	al , LastChar		; in string that may be pre-
		mov	ArgString [bx] , al	; viously set to 0.

		jmp	GW_02			;   Find first non blank
GW_01:		inc	bx			; character.
GW_02:          cmp	byte ptr ArgString [bx] , ' '
		je	GW_01

		cmp	byte ptr ArgString [bx] , 0
		je	GW_91

		mov	si , bx			;   Save index of first non
						; blank symbol.

		jmp     GW_07			;   Bypass test for '/'
						; when first loop
GW_06:          cmp	byte ptr ArgString [bx] , '/'
		je	GW_11
GW_07:          cmp	byte ptr ArgString [bx] , ' '
		je	GW_11
		test	ArgString [bx] , 255
		je	GW_11
		inc	bx
		jmp	GW_06
GW_11:          mov	al , ArgString [bx]
		mov     LastChar , al
		mov	ArgString [bx] , 0
		mov	ArgIndex , bx
		add	si , Offset ArgString

GW_91:		mov	ax , si
		pop	si
;                Leave
                pop     bp
		ret
GetWord		endp



ArgList		proc	near
		arg     aList	:word		= RetBytes
		local	wAddr	:word ,  \
			aType	:byte ,  \
			lAddr	:word	 	= LocBytes

		push	bp
		mov	bp , sp
		sub	sp , LocBytes
		push	si
		push	di
		push	es

		call    CopyArg		; Copy command line arguments to buf.
ArgLoop1:       call	GetWord		; Get word from comand line.
		or	ax , ax		; If end of command line then
		jnz	DoArg1		;     exit from procedure

		xor	ax , ax
AL_001:		pop	es              ; Command line is processed: now
		pop	di		; we can restore some registers and
		pop	si		; return to the caller
		mov	sp , bp
		pop	bp
		ret	RetBytes

DoArg1:		mov	wAddr , ax	; Save address of word
		mov	bx , aList      ; Address of argument descriptions
		mov     lAddr , bx
ArgLoop2:       mov	bx , lAddr
		mov	ax , wAddr
		test	word ptr [bx].arg_txt , 0FFFFh;
		jz      AL_001
AL_006:		mov	si , wAddr		; Address of cmdline word to be tested
		mov	di , [bx].arg_txt
		xor	ch , ch
		mov	cl , [bx].arg_len
		mov	al , [bx].arg_type
		mov     aType , al
		xor	bx , bx
ArgLoop3:       mov	al , [si+bx]
		test	aType , ARG_NOCASE ; Must convert to UPPERCASE before
		jz	AL_011		; comparing?
		cmp     al , 'a'	; Convert byte to uppercase
		jb      AL_011
		cmp	al , 'z'
		ja      AL_011
		xor	al , 20h
AL_011:         cmp     al , ds:[di+bx] ; Compare: if different then take
		jne	AL_016          ;   next from arg. descr.
		inc	bx
		loop    ArgLoop3

		add 	si , bx		; Offset for remaining part of the word
		mov	bx , lAddr	; Address of procedure
		mov	bx , [bx].arg_sub ; to be called
		or	bx , bx         ; If this address is specified then
		je      AL_012		; call procedure
		call	bx
AL_012:         jmp	ArgLoop1        ; Take next word from command line

AL_016:         add	lAddr , size ArgInfo
		jmp	ArgLoop2

ArgList		endp

_TEXT		ends
		end
