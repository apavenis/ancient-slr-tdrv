

MCB             struc
_type            db      ?
_owner           dw      ?
_length         dw      ?
		ends

GR_COLOR	=	7


_TEXT           segment byte public 'CODE'
                assume  CS:_TEXT , DS:_TEXT

		public	_MemInfo

_MemInfo        proc	far
		push    bp
		mov	bp , sp
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es

		push	cs
		pop	ds
		mov     ah , 052h	; Get segment of first memory control
		int	021h		; block from dos variable's block
		mov	ax , es:[bx-2]
		mov	CS:FirstBlk , ax

		mov     ah , 030h 	; Get MS DOS version number
		int	021h
		xchg	ah , al
		mov	CS:DosVer , ax

		mov	ah , 062h       ; Get current PSP and save it
		int	021h
		mov	CS:CurrPSP , bx

		xor	ax , ax
		mov     es , ax
		mov	al , es: [0462h]
		mov     CS:VideoPage , al

		call	near ptr NewLine

		lea	si , _title_
		call	near ptr PrString

		mov	es , CS:FirstBlk

Loop01:		call	near ptr NewLine
		mov	byte ptr CS: IsPgm , 0
		mov	byte ptr CS: GrColor , GR_COLOR

		mov	ax , es          	; Get data address in field
		inc	ax			;   	BlockSeg
		mov	CS: BlockSeg , ax

                mov     bx , ES:0 . _owner      ; Look for owner of block.
		cmp	bx , CS:CurrPSP		; If current PSP then output
		jne	FindType                ; '***' at begin of the
		lea     si , txt_Curr		; display line
		call	near ptr PrString
		mov	byte ptr CS: GrColor , 15

;-----------------------------------------------------------------------------
;	   Now we try to find type of memory block
;-----------------------------------------------------------------------------

FindType:	mov	al , 4			; Now set position to 4
		call	near ptr SetPos

                mov     bx , ES:0 . _owner       ; Test owner
		or	bx , bx
		jne     PrType_1
		lea     si , txt_Free1          ; Owner field contain 0 -
		jmp	PrType_9		;     block is free

PrType_1:       cmp     bx , 00050h
		jnc     PrType_2
		lea	si , txt_Sys1
		jmp	PrType_9

PrType_2:       cmp	bx , BlockSeg
		jne	PrType_3
		mov	byte ptr CS: IsPgm , 255
		lea	si , txt_Prog1
		jmp	PrType_9

PrType_3:       mov     bx , ES: [0] . _owner
		call	near ptr IsCorrectBlk
		jnc     PrType_4
		lea	si , txt_Inv1
		jmp     PrType_9

PrType_4:       mov	si , es
		inc	si
		push	es
		mov	es , bx
		cmp     ES: [02Ch] , si
		jne	PrType_5
		lea     si , txt_Env1
		call	near ptr PrString
PrType_5:	pop	es

PrType_8:	jmp	OutAddr_

PrType_9:	call	near ptr PrString

;------------------------------------------------------------------------------
; 	Output first and last paragraph numbers in hexadecimal form
;------------------------------------------------------------------------------

OutAddr_:       mov	al , 10
		call	near ptr SetPos
		mov	ax , CS: BlockSeg	; Now output hexadecimal
		call	near ptr PrWordHex	; first and last paragraph
		mov	al , '-'		; number for current block
		call 	near ptr PrChar		; and find begin of the next
		mov	ax , es			; block
                add     ax , es: [0] . _length
		call	near ptr PrWordHex
		mov	al , 'h'
		call	near ptr CS:PrChar

;------------------------------------------------------------------------------
;       Output length of the block in bytes (in decimal form)
;------------------------------------------------------------------------------

		mov	al , 21
		call	near ptr SetPos
                mov     ax , word ptr ES:[0] . _length
		xor	dx , dx
		mov	cx , 4
_w007:          shl	ax , 1
		rcl	dx , 1
		loop	_w007
		call	near ptr ConvDWord
		lea	si , CS:ConvBuf + 3
		call	PrString

;------------------------------------------------------------------------------
;       Output owner field for the current block
;------------------------------------------------------------------------------

		mov	al , 30
		call	near ptr SetPos
                mov     ax , word ptr ES:[0] . _owner
		push	ax
		call    near ptr PrWordHex
		mov	al , 'h'
		call	near ptr PrChar
		pop	ax

;------------------------------------------------------------------------------
;       Now we try to find owner's name
;------------------------------------------------------------------------------

		push	ax
		mov	al , 37
		call	near ptr SetPos
		pop	ax

PrName_1:	or	ax , ax
		ja	PrName_2
		lea     si , txt_Free2
		jmp     PrName_8

PrName_2:	cmp     ax , 00050h
		ja	PrName_3
		lea	si , txt_Sys2
		jmp     PrName_8

PrName_3:       cmp     CS:DosVer , 00400h	; MS DOS 4.00+ ?
		jnb     PrName_6

		cmp	ax , CS:BlockSeg
		jne     PrName_9
		lea     si , txt_Prog2
		jmp     PrName_8

PrName_6:       push	es
		dec	ax
		mov     es , ax
		mov     si , 8
		mov	cx , 8
		call	near ptr PrStringES
PrName_7a:	pop	es
		jmp	PrName_9

PrName_8:       call	near ptr PrString
PrName_9:

;------------------------------------------------------------------------------

		mov	al , 47
		call	near ptr SetPos

		test    byte ptr CS: IsPgm , 255
		jne	PrPath_1
PrPath_0:	jmp	fNext

PrPath_1:       mov	bx , ES: [0003Ch]
		call	near ptr IsCorrectBlk
		jc	PrPath_9

		push	es
		mov	ax , word ptr CS: BlockSeg
		dec	bx
		mov     es , bx
		inc	bx
                cmp     word ptr ES: [0] . _owner , ax
		pop	es
		jne	PrPath_9

		cld
		push	es
		mov	es , bx
		xor	di , di
		xor 	al , al
		mov	cx , 0FFFFh
PrPath_2:	repne   scasb
		test	byte ptr ES: [di] , 255
		jne	PrPath_2

		cmp	word ptr ES: [di+1] , 0007fh
		ja	PrPath_8

		add	di , 3
		mov	si , di
		mov	cx , 0FFFFh
		call	near ptr PrStringES

		mov	al , ' '
		call	near ptr PrChar
PrPath_8:	pop	es
PrPath_9:

;------------------------------------------------------------------------------

		xor	ch , ch
		mov	cl , ES: [00090h]
		mov	si , 00091h
		call	near ptr PrStringES

;------------------------------------------------------------------------------

fNext:		call	FindNextBlk
		jc	done1
		jmp	Loop01

done1:          call	near ptr NewLine
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		pop	bp
		retf
_MemInfo	endp

;-----------------------------------------------------------------------------

IsCorrectBlk    proc	near			; Procedure 'IsCorrectBlk'
		push	es			; looks MCB chain for
		mov	es , CS: FirstBlk	; specified block. If block is
_t021:          mov	ax , es			; found CF=1 is returned.
		inc	ax			;
		cmp     ax , bx                 ; Argument : BX - block to
		je	_t022			;   	     look for
		call	near ptr FindNextBlk
		jnc     _t021
		pop	es
		ret
_t022:		pop	es
		clc
		ret
IsCorrectBlk    endp

;-----------------------------------------------------------------------------

FindNextBlk     proc	near
                cmp     ES: [0] . _type , 'M'
		jne	EndOfChain
		push	ax
		mov	ax , es
		inc	ax
                add     ax , ES: [0] . _length
		mov	es , ax
		pop	ax
		clc
		ret
EndOfChain:	stc
		ret
FindNextBlk     endp

;-----------------------------------------------------------------------------

PrString	proc	near            ; DS:SI - string
		push	cx
		mov	cx , 0FFFFh
		call	near ptr PrStringN
		pop	cx
PrRet1:		ret
PrStringES:     or 	cx , cx
		je      PrRet1
_d008:		mov	al , byte ptr ES: [si]
		or	al , al
		je	PrRet1
		cmp     byte ptr CS: xPos , 76
		je	PrEolMark
		ja	PrRet1
		call	near ptr PrChar
		inc	si
		Loop	PrStringES
		ret
PrEolMark:      lea     si , EolMark
		mov	cx , 4
PrStringN:      lodsb                   ; DS:SI - string , CX - max length
		or	al , al
		je      _d009
		call    near ptr PrChar
		loop    PrStringN
_d009:          ret
PrWordHex:	push	ax		; AX - word
		xchg	al , ah
		call    near ptr PrByteHex
		pop     ax
PrByteHex:      push	ax		; AL - byte
		shr     al , 1
		shr	al , 1
		shr	al , 1
		shr	al , 1
		call	near ptr PrDigitHex
		pop	ax
PrDigitHex:	and	al , 15		; AL & 15 - digit
		cmp	al , 10
		cmc
		adc	al , 48
		daa
PrChar:         mov	ah , 14		; AL - byte
		mov	bl , CS:GrColor
		mov	bh , CS:VideoPage
		int 	10h
		inc     byte ptr CS:xPos
		ret
NewLine:	mov	al , 10
		call	near ptr PrChar
		mov     al , 13
		call    near ptr PrChar
		mov     byte ptr CS:xPos , 0
		ret
SetPos:         mov	cl , al
		dec	cl
_l001:		mov	al , ' '
		call	near ptr PrChar
		cmp     cl , CS:xPos
		jnc     _l001
		ret
PrString	endp

ConvDWord       proc	near		; AX,DX - dword
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		cld
		lea	bx , ConvBuf
		mov	cx , 10
		mov	al , ' '
Loop05:		mov	byte ptr CS: [bx] , al
		inc	bx
		Loop	Loop05
		mov     si , ax
		mov     di , dx
		mov	cx , 10
		mov	bx , 9
		mov	byte ptr CS:ConvBuf+10 , 0

Loop06:         mov     ax , di
		xor	dx , dx
		div	word ptr CS:Ten
		mov     di , ax
		mov	ax , si
		div	word ptr CS:Ten
		mov	si , ax
		or	dl , 48
		mov     byte ptr CS:ConvBuf [bx] , dl
		dec	bx
		mov	ax , di
		or	ax , si
		je	_c001
		Loop	Loop06
_c001:		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
ConvDWord	endp

;-----------------------------------------------------------------------------

FirstBlk	dw	0
DosVer		dw	0
NextBlk		dw	0
BlockSeg	dw	0
CurrPSP		dw	0
xPos		db	0
VideoPage	db	0
GrColor		db      0
ConvBuf		db	'              ',0
IsPgm		db	0		; 1 if the block begins with PSP

EolMark		db	'...',0

_title_         db	'----------------------  Memory information  -----------------------',10,13
		db	'           Segments    Bytes      Owner',10,13
		db	'          ---- -----  ------  -----  --------',0

txt_Curr        db      '***',0
txt_Free1	db	'Free',0
txt_Sys1	db	'Sys',0
txt_Env1	db	'Env',0
txt_Prog1	db	'Prog',0
txt_Inv1	db	'????',0

txt_Free2	db	'<FREE>',0
txt_Sys2	db	'<DOS>',0
txt_Prog2	db      '<Itself>',0

Ten		dw	10

;-----------------------------------------------------------------------------

_TEXT           ENDS

		end
