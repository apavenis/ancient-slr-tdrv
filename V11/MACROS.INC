
Message         macro   text
		local   W1,W2
		jmp     W2
W1              db      text,0
W2:             push    Offset W1
		call    PrintString
		call    NewLine
		endm

;------------------------------------------------------------------------------

ExitPgm         macro   RetCode
		mov     ah , 4Ch
		mov     al , RetCode
		int     21h
		endm

;------------------------------------------------------------------------------

GetPSP          macro
		mov     ah , 062h
		int     021h
		endm


ReadCMOS	macro   addr
		mov	al , addr
		out	70h , al
		jmp	short $+2
		jmp	short $+2
		in	al , 71h
		endm


WriteCMOS	macro	addr
		xchg	ah , al
		mov	al , addr
		out	70h , al
		jmp	short $+2
		jmp	short $+2
		xchg    ah , al
                out     71h , al
		endm

;------------------------------------------------------------------------------

lload           macro   addr
;               .erre  type  addr eq 4
		mov     ax , word ptr addr
		mov     dx , word ptr addr+2
		endm

lloadb          macro   addr
;               .erre  type addr eq 4
		mov     bx , word ptr addr
		mov     cx , word ptr addr+2
		endm

lsub            macro   addr
;               .erre  type addr eq 4
		sub     ax , word ptr addr
		sbb     dx , word ptr addr+2
		endm

ladd            macro   addr
;               .erre  type addr eq 4
		add     ax , word ptr addr
		adc     dx , word ptr addr+2
		endm

lstore          macro   addr
;               .erre  type addr eq 4
		mov     word ptr addr , ax
		mov     word ptr addr+2 , dx
		endm

lstoreb         macro   addr
;               .erre  type addr eq 4
		mov     word ptr addr , bx
		mov     word ptr addr+2 , cx
		endm

lpush           macro
		push    ax
		push    dx
		endm

lpop            macro
		pop     dx
		pop     ax
		endm

lpushb          macro
		push    bx
		push    cx
		endm

lpopb           macro
		pop     cx
		pop     bx
		endm

lswap           macro   addr
;               .erre   type addr eq 4
		xchg    word ptr addr , ax
		xchg    word ptr addr+2 , dx
		endm

lcopy           macro   dest,src
		mov     ax , word ptr src
		mov     dx , word ptr src+2
		mov     word ptr dest , ax
		mov     word ptr dest+2 , dx
		endm

lzero   	macro	reg , lst
		xor	reg , reg	;; clear register
		irp     temp , <lst>
		mov	word ptr temp , reg
		mov	word ptr temp+2 , reg
		endm
		endm

;------------------------------------------------------------------------------

IntInfo         struc
Num             db      0
SaveMask        db      0
NewVectOff      dw      0
NewVectSeg      dw      0
OldVect         dd      0
PrevMask        db      ?
		ends

;------------------------------------------------------------------------------

chbits          macro   address , clrmask , setmask
		and     address , not (clrmask)
		or      address , (setmask)
		endm
