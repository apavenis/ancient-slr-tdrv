		locals
		.286

		.XList
		include LIB.INC
		include OUTPUT.INC
		.List

_TEXT		Segment byte public 'CODE'
		Assume	CS:_TEXT


IsLine		equ     08000h


MemDump		proc	near
		arg	Loc	:Word,	\
			Len	:Word   \
			= RetBytes
		local	@@Base	:Word,	\
			@@High	:Word,	\
			@@Flags	:Word	\
			= LocBytes
		enter	LocBytes , 0
		push	es
		pusha

		mov 	ax , cs
		mov	es , ax
		lea	dx , @@nwLine
		call	@@WriteStdOut
		mov     @@Flags , 0
		mov     si , Loc
		mov	cx , Len
		or	cx , cx
		jne	@@11
		jmp	@@Done

    @@Loop1:	cmp	si , @@High
		jb	@@InitOK

		call	@@OutputLine
		mov	@@Flags , 0

    @@11:	mov	ax , si		; Copy offset to AX
		and	ax , 0FFF0h	; Round down to paragraph
		mov	@@Base , ax	; Store base offset for line
		add	ax , 16         ; Offset for next line
		mov	@@High , ax
		call	@@ClrBuf
		or	@@Flags , IsLine
		call	@@PutAddr

    @@InitOK:   mov	ax , si
		sub	ax , @@Base
		imul	ax , ax , 13
		shr	ax , 2
		mov	di , ax
		add	di , Offset (@@Buf+12)
		lodsb
		call	@@PutByte
		loop	@@Loop1

		test	@@Flags , IsLine
		jz	@@Done
		call	@@OutputLine
    @@Done:	popa
		pop	es
		leave
		retn    RetBytes

@@ClrBuf:       push	di
		push	cx
		cld
		lea	di , @@Buf
		mov	al , ' '
		mov	cx , 78
		rep	stosb
		mov	byte ptr @@Buf+78 , 0
		mov	cx , 16
   @@CL1:       mov	di , 16
		sub	di , cx
		imul    di , di , 13
		shr	di , 2
		add	di , Offset (@@Buf+12)
		mov	al , '.'
		stosb
		stosb
		loop	@@CL1
		pop	cx
		pop	di
		retn

@@PutAddr:      cld
		lea	di , @@Buf
		mov	ax , ds
		call	@@PutWord
		mov	al , ':'
		stosb
		mov	ax , @@Base
		call	@@PutWord
		mov	al , ' '
		stosb
		stosb
		stosb
		retn

@@PutWord:      push    ax
		xchg	al , ah
		call	@@PutByte
		pop	ax
@@PutByte:      push	ax
		shr	ax , 4
		call	@@PutHDig
		pop	ax
@@PutHDig:      and	ax , 000Fh
		push	bx
		mov     bx , ax
		mov	al , byte ptr @@hDig [bx]
		pop	bx
@@PutChar:	stosb
		retn

@@OutputLine:   lea	di , @@Buf+64
		mov	al , 13
		stosb
		mov	al , 10
		stosb
		mov	al , '$'
		stosb
		lea	dx , @@Buf
@@WriteStdOut:	mov	ah , 09h
		push	ds
		push	cs
		pop	ds
		int	21h
		pop	ds
		retn


@@Buf:		db      80 dup (0)
@@hDig:		db	'0123456789ABCDEF'
@@nwLine:	db	13,10,'$'
MemDump		endp

_TEXT		EndS
		END
