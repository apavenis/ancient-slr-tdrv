
		.286
		LOCALS
		.XList
		INCLUDE  TDRV.INC
		INCLUDE  DBGSTRCT.INC
		INCLUDE  HARDWARE.INC
		.List

_TEXT           Segment Byte Public 'CODE'
		Assume  CS:_TEXT

		TM_BUFFER_SIZE  =   20
		TM_Overflow 	=    1
		TM_InvDigit	=    2
		TM_SyncErr	=    4

IRQ_0C_PROC	proc	far
		pusha
		push	ds
		push	es
		mov	ax , cs
		mov	ds , ax
		mov	es , ax

		mov	bx , TM_WrOffset ; Offset in buffer
		lea	di , TM_Buffer [bx]

		mov     dx , P2_RdStatus
		in	al , dx
		out	80h, al
		and	al , 7
		stosb			; Why interrupt occurred
		mov	dx , P2_Clk1
		in	ax , dx         ; Get low word of BCD coded time
		out	80h, al
		stosw
		mov	dx , P2_Clk2    ; Get high word of BCD coded time
		in	ax , dx		; and convert it binary format
		out	80h, al
		stosw
		mov	ax , word ptr PREV_TIME
		stosw
		mov	al , byte ptr PREV_TIME+2
		stosb
		add	bx , 8
		cmp	bx , (8*TM_BUFFER_SIZE)
		ja      @@11
		xor	bx , bx
	@@11:   mov     TM_WrOffset , bx
		mov	cx , TM_RdOffset
		cmp	bx , cx
		jne	@@13
		add	cx , 8
		cmp	cx , (8*TM_BUFFER_SIZE)
		jb	@@12
		xor	cx , cx
	@@12:	mov	TM_RdOffset , cx
		or	TM_Status , TM_Overflow
	@@13:
		mov	al , 20h 	; Send EOI signal to
		out	020h , al	; interrupt controler
		out     0A0h , al

		pop	es
		pop	ds
		popa
		iret
IRQ_0C_PROC     endp

V_10		dw	10
V_10000		dw	10000

TM_Status	db	0
TM_Result	db	0
TM_WrOffset	dw	0
TM_RdOffset	dw	0
TM_Buffer	db	(8*TM_BUFFER_SIZE) dup (0)

;-----------------------------------------------------------------------------
;       Procedure <I_TmFunct> provides INT 2Fh services for TDRV.EXE time
;       registrator.
;-----------------------------------------------------------------------------

		Assume  CS:_TEXT , DS:_TEXT
		MAX_TM_FUNCT  =  2

I_TmFunct	proc	near
		and	[bp].r_flags , 0FFFEh
		mov	bx , [bp].r_bx
		cmp	bx , MAX_TM_FUNCT
		jbe	@@10
		or	[bp].r_flags , 1
		retn
	@@10:	shl	bx , 1
		jmp	T_TmFunct [bx]

T_TmFunct	dw      TM_Get
		dw	TM_GetRaw
		dw	ClearTMBuf

I_TmFunct	endp

;-----------------------------------------------------------------------------
;	Procedure : ClearTMBuf
;-----------------------------------------------------------------------------

ClearTMBuf	proc	near
		xor	ax , ax
		mov     TM_WrOffset   , ax
		mov	TM_WrOffset+2 , ax
		mov	TM_Status , al
		retn
ClearTMBuf	endp

;-----------------------------------------------------------------------------
; Procedure : TM_GetRaw  returns time registrator data in raw format
; If CF=1 then there is no data in the buffer. If CF=0 then data is returned
; The following registers is being used:
;       CX       - BCD coded integer (units 10 ns)
;	DX       - BCD coded integer (units 100 mks)
;	SI & DI  - Long integer number (the value of 0.1 sec. timer)
;	AX       - Look description of <TM_Get> (not all bits in return code
;                  is being used
;-----------------------------------------------------------------------------

TM_GetRaw	proc	near

	; At first look if there is there was any IRQ 12 since the last
	; call to this function. If NOT then return CF=1

		and	[bp].r_flags , 0FFFEh
		mov	ax , TM_RdOffset
		cmp	ax , TM_WrOffset
		jne	@@1
		or	[bp].r_flags , 1	; CF=1 after return:
		ret				;   No data available

	; Now return time registrator data in raw format

	@@1:    mov	bx , TM_RdOffset
		mov	TM_Result , 0
		mov	ax , word ptr TM_Buffer [bx+1]
		mov	[bp].r_cx , ax
		mov	ax , word ptr TM_Buffer [bx+3]
		mov	[bp].r_dx , ax
		mov 	ax , word ptr TM_Buffer [bx+5]
		mov	[bp].r_si , ax
		mov	al , byte ptr TM_Buffer [bx+7]
		xor	ah , ah
		mov	[bp].r_di , ax
		jmp     TMGetDone
TM_GetRaw	endp

;-----------------------------------------------------------------------------
; Procedure : TM_Get	[ INT 2Fh : AX=....h  BX=0001h ]
; Registers after return from INT 2Fh:
;    CF=1    - there is no new data in the buffer. Registers remains
;		  unchanged
;    CF=0    - data retrieved from buffer
;	AH   - return code. The following bits are defined
;	          .......1 - buffer overflow. The oldest data are
;			     deleted.
;	          ......1. - BCD value read from ports is invalid.
;	                     In this case. CX & DX contains this
;			     invalid value.
;		  .....1.. - Synchronization error was detected.
;
;	AL   - why interrupt was occurred
;		  .......1 - stop line
;		  ......1. - start line
;	          .....1.. - registration request from computer
;
;    CF=0 & (AX==0 || AX==1) - data retrieved from buffer is correct
;	CX & DX   - the parts of second (in units of 10 ns)
;       SI & DI   - full seconds
;-----------------------------------------------------------------------------

TM_Get		proc	near

	; At first look if there is there was any IRQ 12 since the last
	; call to this function. If NOT then return CF=1

		and	[bp].r_flags , 0FFFEh
		mov	ax , TM_RdOffset
		cmp	ax , TM_WrOffset
		jne	@@1
		or	[bp].r_flags , 1	; CF=1 after return:
		ret				;   No data available

	; The buffer contains new data. Clear result status and look
	; buffer overflow

	@@1:    mov	TM_Result , 0
		mov	bx , TM_RdOffset

	; After that get data obtained from ports and check if these data
	; are correct BCD numbers. If the number is invalid then return it
	; in registers CX & DX (after IRET only!!!)

		mov	ax , word ptr TM_Buffer [bx+1]
		mov	dx , word ptr TM_Buffer [bx+3]
		call	CheckBCDW
		xchg	ax , dx
		call	CheckBCDW
		xchg	ax , dx
		test	TM_Result , TM_InvDigit
		jz	@@11
		mov     [bp].r_cx , ax
		mov	[bp].r_dx , dx
		jmp	@@Done

	; The values read from ports 0120h & 0122h are correct BCD numbers.
	; Convert these values to <long int> number

	@@11:	xchg	ax , dx		; Get high word in AX again
		mov	cx , ax
		shr	cx , 12		; Extract high digit only
		push	dx		; Save low word
		call	ConvBCDW
		mul	V_10000
		mov	[bp].r_cx , ax
		mov	[bp].r_dx , dx
		pop	dx
		mov	ax , dx
		call	ConvBCDW
		add	[bp].r_cx , ax
		adc	[bp].r_dx , 0

	; Now look for 0.1 sec. timer value saved in buffer

		mov	al , byte ptr TM_Buffer [bx+7]
		cbw
		cwd
		div	V_10
		mov	[bp].r_di , ax
		mov	ax , word ptr TM_Buffer [bx+5]
		div	V_10
		mov     [bp].r_si , ax
		mov	ah , cl
		mov	[bp].r_bx , ax

	; All values are stored in stack. So these values will be returned
	; in registers after IRET

	TMGetDone:
	@@Done: test	TM_Status , TM_Overflow
		jz	@@91
		or	TM_Result , TM_Overflow
		and  	TM_Status , Not TM_Overflow
	@@91:	mov     ah , TM_Result
		mov	al , byte ptr TM_Buffer [bx]
		mov     [bp].r_ax , ax
		mov	bx , TM_RdOffset
		add	bx , 8
		cmp	bx , (8*TM_BUFFER_SIZE)
		jb	@@92
		xor	bx , bx
	@@92:   mov	TM_RdOffset , bx
		retn
TM_Get		endp


;-----------------------------------------------------------------------------
;	Procedure 'ConvBCDW' converts number in AX from BCD form
;			to binary form
;	Input:		AX - number to be converted
;	Output:		AX - result in binary form (other registers remains
;			     unchanged)
;-----------------------------------------------------------------------------

ConvBCDW	proc	near
		push	cx
		mov     cl , ah
		mov     ah , al
		and     al , 15
		shr     ah , 4
		aad
		xchg    al , cl
		xor     ch , ch
		mov     ah , al
		and     al , 15
		shr     ah , 4
		aad
		imul    ax , ax , 100
		add     ax , cx
		pop	cx
		retn
ConvBCDW	endp

;-----------------------------------------------------------------------------
;	Procedure 'CheckBCDW' checks if BCD number in AX is correct
;       (it is all digits are in range 0...9)
;	On failure sets <TM_InvDigit> bit in TM_Result
;	All registers remains unchanged.
;-----------------------------------------------------------------------------

CheckBCDW       proc	near
		push	ax
		push	bx
		push	cx
		xor	bh , bh
		mov	cx , 4
	@@1:	mov	bl , al
		and	bl , 15
		cmp	bl , 10
		jb	@@2
		or	bh , 1
	@@2:	shr	ax , 4
		loop	@@1
		or	bh , bh
		je	@@3
		or	TM_Result , TM_InvDigit
	@@3:	pop	cx
		pop	bx
		pop	ax
		retn
CheckBCDW	endp

_TEXT		EndS
		End
