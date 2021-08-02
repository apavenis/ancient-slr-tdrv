                Locals
		.XList
		include	OUTPUT.INC
		include INTVECT.INC
		.List

_TEXT		Segment Byte Public 'CODE'
		Assume	CS:_TEXT , DS:_TEXT

RESTORE		equ	80h
TEST_FAILED	equ	40h

IV_Silent       db      0

;=============================================================================
;
;	ReplaceVect ( IntInfo near * _IntTable )
;
;       Procedure replaces interrupt vector with new one. It saves
;   information about changes that are done to restore old vectors later.
;
;   ARGUMENTS:
;   [BP+4]  - 	pointer to the array of type IntInfo that contains
;		information about all interrupts used by this program
;
;=============================================================================
;
ReplaceVect	Proc	Near
		ARG	_IntTable:Word	= RetBytes
                push    bp
                mov     bp , sp
		push	ds
		push	es
		push	si

		mov	si , Offset _IntTable
ReplaceLoop:    test    [si].Num , 255          ; Look if end of interrupt
                jne     @@1                     ; vector list is reached.
						; If so then exit to
		pop	si			; caller.
		pop	es
		pop	ds
                pop     bp
		ret	RetBytes

@@1:            cmp     [si].Num , 255
                jne     @@1B
                jmp     @@7

@@1B:           mov     MaskChanged , 0
		mov	ah , 35h                ; At first get previous
		mov	al , [si].Num		; interrupt vector and save
		int	21h			; it.
		mov	word ptr [si].OldVect , bx
		mov	word ptr [si].OldVect+2 , es

                push    ds
                mov     ah , 25h
		mov	al , [si].Num
                test    [si].NewVectSeg , 0FFFFh
                jnz     @@SegOk
                mov     [si].NewVectSeg , cs
@@SegOk:        mov     dx , [si].NewVectOff
                mov     ds , [si].NewVectSeg
		int	21h
                pop     ds

		;-------------------------------------------------------;
		;    When it is necessary to update IRQ mask then save  ;
		; previous value and enable corresponding IRQ           ;
		;-------------------------------------------------------;

		test	[si].SaveMask , 255	; Test flag
                je      @@2                     ; We don't need to save mask
		mov	al , [si].Num           ; Get INT number
		call	GetMask			; Try to get mask
                je      @@2                     ; NOT IRQ --> Ignore
		in	al , dx			; Read IRQ mask
		mov	OldMask , al
		mov	[si].PrevMask , al
		not	ah
		and	al , ah			; Enable IRQ
		out	dx , al                 ; Update interrupt mask
		mov	NewMask , al
		mov	MaskChanged , 1

@@2:            ;------------------------------------------------------;
		;   Now output message about changes                   ;
		;------------------------------------------------------;

		test    IV_Silent , 255
                jne     @@7

		push	si
		push	word ptr [si].NewVectOff
		push    word ptr [si].NewVectSeg
		push	word ptr [si].OldVect
		push	word ptr [si].OldVect+2
		mov	al , [si].Num
		xor	ah , ah
		push	ax
		lea	ax , @@RV_Format
                push    ax
                call    _PrintF
		add	sp , 12
		test	MaskChanged , 255
                je      @@6
		call    MaskChangedMsg
@@6:            pop     si

@@7:            add     si , size IntInfo
		jmp     ReplaceLoop

@@RV_Format	db	'Interrupt %02Xh : Old vector = %04X:%04X   '
                db      'New vector = %04X:%04X'
		db	10 , 0

ReplaceVect	EndP

;=============================================================================
;	Output message about updating IRQ mask
;=============================================================================

MaskChangedMsg	proc	near
		xor	ah , ah
		mov	al , NewMask
		push	ax		; New mask
		mov	al , OldMask
		push	ax
		push	MaskPort
		push	Offset @@RM_Format
		call	_PrintF
		add	sp , 8
		ret

@@RM_Format	db	'IRQ mask changed : port=%02Xh   old mask:%08B   '
		db	'new mask:%08B'
		db	10,0

MaskChangedMsg	endp
;
;=============================================================================
;
PAddr		dw	?
VectFlags	db	0
;
;=============================================================================
;
;  PROCEDURE :  RestoreVect ( IntInfo far * VI )
;
;	Procedure 'RestoreVect' at first looks whether vectors for interrupts
;  previously changed by 'ReplaceVect' aren't modified and can be restored to
;  the previous values. If one or more vectors cannot be restored a message is
;  displayed about each vector that is changed.
;	If no vectors are changed the program restores all them.
;
;  Arguments:
;       Paragraph VI   :  far pointer to <IntInfo> structure which was used by
;               'ReplaceVect' to save information about changed interrupt
;		vectors
;
;  Returns:
;	AX =  0	: All vectors are restored to the old velues
;	AX = -1 : One or more vectors are changed and therefore no vectors
;		  are restored
;
;  Changed registers:
;
;
;=============================================================================
;
RestoreVect	PROC	NEAR
		ARG     VectInfo:DWORD = RetBytes
                push    bp
		mov     bp , sp
		push	es
		push	si

		mov	RestFlags , 0
@@1:     	les     si , VectInfo
		mov	StartOfTable , si
FindEdge_01:	test	es: [si].Num , 255
		je	@@2
		add	si , size IntInfo
		jmp	FindEdge_01

@@2:            cmp     si , StartOfTable
		jne	@@6
		test	RestFlags , RESTORE
		jne	@@4
		test	RestFlags , TEST_FAILED
		je	@@3
		jmp	CannotRestore
@@3:     	or	RestFlags , RESTORE
		jmp	@@1
@@4:            xor     ax , ax
@@5:		pop     si
		pop	es
		pop     bp
		ret

@@6:            sub     si , size IntInfo
		mov	MaskChanged , 0
		mov     al , es: [si].Num
                test    RestFlags , RESTORE     ; Already restoring vectors ?
		je	@@16			; NO, testing.

                cmp     al , 255
                je      @@15

                test    es: [si].SaveMask,255   ; Must we restore IRQ mask
		je	@@7			; No : restore vector
		mov	al , es: [si].Num
		call	GetMask
		je	@@7			; Not IRQ
		mov	MaskChanged , 1
		in	al , dx
		mov	OldMask , al
		mov	al , es: [si].PrevMask
		out	dx , al
		mov	NewMask , al

@@7:		push	ds
		mov	ah , 25h
		mov	al , es: [si].Num
		lds     dx , es: [si].OldVect
		int	21h
		pop	ds

		test    IV_Silent , 255
                jnz     @@15

                xor     ah , ah
		push    word ptr es:[si].OldVect
		push    word ptr es:[si].OldVect+2
		mov     al , es:[si].Num
                push    ax
		push    Offset @@RV2F
                call    _PrintF
                add     sp , 8

@@11:           test    MaskChanged , 255
                je      @@15
		call	MaskChangedMsg
@@15:           jmp     @@21

@@16:           cmp     al , 255
                je      @@21

                push    es
		mov	ah , 35h
		int	21h
		mov	dx , es
		pop	es
                cmp     bx , es: [si].NewVectOff
		jne	VectChanged
		cmp     dx , es: [si].NewVectSeg
		jne	VectChanged
@@21:           jmp     @@2

VectChanged:    or	RestFlags , TEST_FAILED
                xor     ah , ah
                mov     al , es:[si].Num
                push    ax
                push    Offset @@ME1
                call    _PrintF
                add     sp , 4
                jmp     @@21

CannotRestore:  push    Offset @@ME2
                call    PrintString
                mov     ax , 0FFFFh
		jmp     @@5

@@ME1           db      'Interrupt %02Xh vector is modified and cannot '
		db      'be restored' , 10 , 0
@@ME2           db      'One or more interrupt vectors are modified.',10
		db      'Program cannot be removed from memory.',10,0
@@RV2F          db      'Restoring interrupt %02Xh vector to %04X:%04X',10,0

RestoreVect	ENDP

RestFlags	db	0
StartOfTable	dw	?


;
;=============================================================================
;	Procedure 'GetMask' finds mask for interrupt (of course only for IRQ)
;=============================================================================
;
GetMask		proc	near
		push	cx
		xor	dx , dx
		mov	cl , al
		and	al , 0F8h
		cmp     al , 008h	; Look for IRQ 0...7
		jne	GM_01		; Other INT specified
		mov	dx , 021h
		jmp	GM_02
GM_01:          cmp	al , 070h	; Look for IRQ 8...15
		jne	GM_03    	; Outside interval
		mov	dx , 0A1h
GM_02:		and	cl , 07h
		mov	al , 1
		shl	al , cl
GM_03:		mov	ah , al
		pop	cx
		mov	MaskPort , dx
		or	dx , dx
		ret
GetMask		endp

MaskPort	dw	?
OldMask		db	?
NewMask		db	?
MaskChanged	db	0

_TEXT		EndS

		END
