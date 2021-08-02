; [fold]  (

; [fold]  )
		.XList
		include TDRV.INC
		include	DBGSTRCT.INC
		.List

_TEXT		Segment	Byte Public 'CODE'
		Assume 	CS:_TEXT , DS:_TEXT


I_GetDbgInfo	proc	near
		mov	bx , [bp].r_bx
		cmp     bh , 16
		jb      DI_001
		mov	bh , 15
DI_001:         shr	bx , 7
		and	bl , 7Eh
		mov	ax , AddrInfo [bx]
		mov	[bp].r_bx , ax
                mov     [bp].r_es , cs
		ret
I_GetDbgInfo	endp

AddrInfo	dw      DRV_STAT       		; 0
		dw      DRV_OPT                 ; 1
		dw	0                       ; 2
		dw	CURR_TIME               ; 3
		dw	DRV_X                   ; 4
		dw	DRV_Y                   ; 5
		dw	RO                      ; 6
		dw	irqStart                ; 7
		dw	NumKeypadStatus         ; 8
		dw      DbgBuffer		; 9
		dw	0
		dw 	0
		dw	0
		dw	0
		dw 	0
		dw	0



IF IOTRACE Eq 0

DbgBuffer    dw	0

ELSE
		;********************************************************;
		; The following block is included only when IOTRACE is   ;
		; not zero to perform I/O tracking (look TDRV.INC)       ;
		;********************************************************;

DbgBufLen       equ     32000

DbgBuffer    	dw	0
DbgInfo         db      DbgBufLen dup (?)

InitDbgBuffer	proc	near
		mov	DbgBuffer , 0
		retn
InitDbgBuffer	endp

EndIf

If IOTRACE Eq 1

Dbg_ReadB	proc	near
		push	cx
		push	ax
		mov	ah , 3
		xor	ah , ah
		call	Dbg_PortInfo
		pop	ax
		pop	cx
		retn
		endp

Dbg_PortB	proc	near
		push	cx
		push	ax
		mov	ch , 1
		xor	ah , ah
		call	Dbg_PortInfo
		pop	ax
		pop	cx
		retn
Dbg_PortB	endp

Dbg_PortW	proc	near
		push	cx
		mov	ch , 2
		call	Dbg_PortInfo
		pop	cx
		retn
Dbg_PortW	endp


Dbg_I8253Data	proc	near
		push	cx
		mov	ch , 16
		call	Dbg_PortInfo
		pop	cx
		retn
Dbg_I8253Data	endp


Dbg_I8253Cmd	proc	near
		push	ax
		push	cx
		xor	ah , ah
		mov	ch , 17
                call    Dbg_PortInfo
		pop     cx
		pop	ax
		retn
Dbg_I8253Cmd	endp


Dbg_PortInfo	proc	near
		push	bx
		mov     bx , DbgBuffer
		cmp	bx , DbgBufLen-5
		jae	DP9
		mov	byte ptr DbgInfo   [bx] , ch	; WORD:2 , BYTE:1
		mov	word ptr DbgInfo+1 [bx] , dx	; Port address
		mov	word ptr DbgInfo+3 [bx] , ax	; Value
		add	DbgBuffer , 5
DP9:		pop	bx
		retn
Dbg_PortInfo	endp

Dbg_NextStp     proc    near
		push    ax
		push    dx
		mov     ch , 37
		mov     ax , DRV_X.NextSteps
		mov     dx , DRV_Y.NextSteps
		call    Dbg_PortInfo
		pop     dx
		pop     ax
		retn
Dbg_NextStp     endp

ElseIf IOTRACE Eq 2

FSaveArea	db	94 dup (?)
ClkCoeff	dd	119318
C001            dd       65536
C002            dd      100000
WS1		dd	?

Dbg_IRQ_Time	proc	near
		push	ax
		push	cx
		push	dx
		mov	ch , 38
		mov	dx , word ptr irqStart
		mov	ax , word ptr irqStart+2
		call    Dbg_PortInfo
		pop	dx
		pop	cx
		pop	ax
		retn
Dbg_IRQ_Time	endp

ElseIf IOTRACE Eq 3

Dbg_CoordInfo	proc	near
		push	ax
		push	bx
		push	dx
	@@01:	mov	bx , DbgBuffer
		cmp	bx , DbgBufLen-8
		jae	@@99
		mov	ax , DRV_X.dbgInfo
		mov     word ptr DbgInfo [bx   ] , ax
		mov     ax , DRV_X.NextSteps
		mov	word ptr DbgInfo [bx+ 2] , ax
		mov	ax , DRV_X.DivCoeff
		mov	word ptr DbgInfo [bx+ 4] , ax
		add	DbgBuffer , 6
	@@99:   pop	dx
		pop	bx
		pop	ax
		retn
Dbg_CoordInfo	endp

ENDIF

_TEXT		ends
		end
; [fold]  1
