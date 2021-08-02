		.286
		locals
		.XList
		include LIB.INC
		include TDRV.INC
                include ARITH.INC
                include HARDWARE.INC
                .List

_TEXT		segment	byte public 'CODE'
		assume	cs:_TEXT , ds:_TEXT


;*****************************************************************************
;   INT 2Fh function 0C41Eh : query/modify TDRV.EXE parameters
;   Arguments:
;       AX = 0C4..h	- function code
;       BL              - index
;       BH              - operation ( 0-query , 1-set )
;*****************************************************************************

UpdOptions	proc	near
		mov	bx , [bp].r_bx		; Load index
		or	bh , bh
		je	@@GetOpt
		cmp	bh , 1
		je	@@SetOpt
@@Err:          stc
@@Done:		jnc	@@D2
		or	[bp].r_flags , 1
@@D2:		retn

@@GetOpt:	xor	bh , bh		    ; Clear operation code
		cmp	bh , GOptTableSize  ; Is the index inside the range ?
		ja      @@Err               ; >> Error exit if not
		shl	bx , 1              ;
		mov	bx , GetOptTable [bx]  ;
@@2:		or	bx , bx
		jz	@@Err
		jmp	bx

@@SetOpt:       xor	bh , bh
		cmp     bh , SOptTableSize
		ja	@@Err
		shl	bx , 1
		mov     bx , SetOptTable [bx]
		jmp	@@2

SOptTableSize	db      16
GOptTableSize   db	16

SetOptTable	dw      @@SetMaxSpeed		; 00h
		dw	@@SetMaxAcc		; 01h
		dw	@@SetLimits		; 02h
		dw	@@SetRTCOpt     	; 03h
		dw	@@SetFLDOpt     	; 04h
		dw	@@SetKbSensitivity	; 05h
		dw	@@SetMoSensitivity     	; 06h
		dw	@@SetTrkOpt		; 07h
		dw	@@SetJsSensitivity     	; 08h
		dw	@@Err           	; 09h
		dw	@@Err           	; 0Ah
		dw	@@Err           	; 0Bh
		dw	@@SetExtOpt           	; 0Ch
		dw	@@SetHistWX     	; 0Dh
		dw	@@SetHistWY     	; 0Eh
		dw	@@SetCorrections	; 0Fh

GetOptTable	dw      @@GetMaxSpeed		; 00h
		dw	@@GetMaxAcc     	; 01h
		dw	@@GetLimits		; 02h
		dw	@@GetRTCOpt    		; 03h
		dw	@@GetFLDOpt     	; 04h
		dw	@@GetKbSensitivity	; 05h
		dw	@@GetMoSensitivity	; 06h
		dw	@@GetTrkOpt     	; 07h
		dw	@@GetJsSensitivity    	; 08h
		dw	@@Err           	; 09h
		dw	@@Err           	; 0Ah
		dw	@@Err           	; 0Bh
		dw	@@GetExtOpt           	; 0Ch
		dw	@@GetHistWX     	; 0Dh
		dw	@@GetHistWY     	; 0Eh
		dw	@@GetCorrections	; 0Fh

;*****************************************************************************
;  AX = 0C41Eh
;  BX = 00000h - get value of max. allowed speed (Hz)
;  BX = 00100h - set new value of max. allowed speed (Hz)
;*****************************************************************************

@@SetMaxSpeed:  mov	ax , [bp].r_cx          ;  BX = 00000h - get MaxSpeed
		call	_SetMaxSpeed            ;	in register CX (Hz)
		jmp	@@Done			;  BX = 00100h - set MaxSpeed
@@GetMaxSpeed:	mov     cx , MaxSpeed		;       equal to CX
        @@W1:   imul    cx , cx , 10
                mov     [bp].r_cx , cx
		jmp	@@D2

;*****************************************************************************
;   AL = 1Eh
;   BX = 00001h - get value of max. allowed change of step frequency (Hz)
;   BX = 00101h - set value of max. allowed change of step frequency (Hz)
;*****************************************************************************

@@SetMaxAcc:	mov	ax , [bp].r_cx          ;  BX = 00001h - get max. acc.
		call	_SetMaxAcc		;       in reg. CX (in Hz)
		jmp	@@Done			;  BX = 00101h - set max. acc.
@@GetMaxAcc:	mov	cx , MaxAcc		;       equal to CX
		jmp     @@W1

;*****************************************************************************
;   AL = 1Eh
;   BX = 00002h - get value of coord change limits in motor steps
;   BX = 00102h - set value of coord change limits in motor steps
;   ES:DX must contain address of source or destination depending on the
;         requested function (register values at INT 2Fh)
;*****************************************************************************

@@SetLimits:	mov	bx , [bp].r_dx
		mov	es , [bp].r_es
		call    SetCoordLimits
		mov	[bp].r_ax , ax
		or      ax , ax
		jz	@3
		stc
@3:		jmp	@@Done

@@GetLimits:    mov	di , [bp].r_dx
		mov     es , [bp].r_es
		lea	si , DRV_X
		call	DC_GetCoordInterval
		mov	word ptr es:[di]    , ax
		mov	word ptr es:[di+ 2] , dx
		mov	word ptr es:[di+ 4] , bx
		mov	word ptr es:[di+ 6] , cx
		lea	si , DRV_Y
		call	DC_GetCoordInterval
		mov	word ptr es:[di+ 8] , ax
		mov	word ptr es:[di+10] , dx
		mov	word ptr es:[di+12] , bx
		mov	word ptr es:[di+14] , cx
		jmp	@@D2
;*****************************************************************************
;   AL=1Eh	BL=3     BH=0/1 - query/set RTC options
;*****************************************************************************

@@GetRTCOpt:    mov     dx , BeepFq
		mov	cx , BeepLen
		mov	ch , RTC_Funct
		mov	[bp].r_cx , cx
		mov	[bp].r_dx , dx
		jmp	@@D2
@@SetRTCOpt:    mov	dx , [bp].r_dx
		cmp	dx , 100
		jl 	@@Err1
		cmp	dx , 15000
		jg      @@Err1
		mov	cx , [bp].r_cx
		cmp	cl , 2
		jl      @@Err1
		cmp	cl , 100
		jge     @@Err1
		mov     BeepFq , dx
		mov	RTC_Funct , ch
		xor	ch , ch
		mov	BeepLen , cx
		jmp	@@D2
@@Err1:		jmp	@@Err

;*****************************************************************************
;   AL=1Eh      BL=4    BH=0/1 - query/set field orientation settings
;*****************************************************************************

@@GetFLDOpt:	mov	ax , f_Options    ; Gets current field orientation
		mov	bx , f_argShift   ; settings in register pair AX,BX
		mov	[bp].r_ax , ax
		mov	[bp].r_bx , bx
		jmp	@@D2
@@SetFLDOpt:    mov	ax , [bp].r_cx	  ;
		mov	bx , [bp].r_dx
		mov     f_Options , ax
		mov	f_argShift , bx
		jmp	@@D2

;*****************************************************************************
;   AL=1Eh      BL=5    BH=0/1 - query/set numeric keypad sensitivity
;*****************************************************************************

@@GetKbSensitivity:
		mov	ax , kbSensitivity
		mov	[bp].r_cx , ax
		retn
@@SetKbSensitivity:
		mov	ax , [bp].r_cx
		or	ax , ax
		je      @@41
		cmp	ax , 255
		ja  	@@41
		mov	kbSensitivity , ax
	@@41:	retn

;*****************************************************************************
;   AL=1Eh      BL=6    BH=0/1 - query/set mouse sensitivity in tracking mode
;*****************************************************************************

@@GetMoSensitivity:
		mov	ax , moSensitivity
		mov	[bp].r_cx , ax
		retn
@@SetMoSensitivity:
		mov     ax , [bp].r_cx
		or	ax , ax
		je	@@42
		cmp	ax , 16384
		jae	@@42
		mov	moSensitivity , ax
	@@42:	retn

;*****************************************************************************
;   AL=1Eh      BL=7	BH=0/1 - query/set tracking options
;*****************************************************************************

@@GetTrkOpt:    mov	ax , DRV_OPT
		mov	[bp].r_cx , ax
		retn
@@SetTrkOpt:    mov     DRV_OPT , cx
		call	ApplyTrackingOpt
		retn

;*****************************************************************************
;   AL=1Eh      BL=8    BH=0/1 - query/set joystick sensitivity in tracking mode
;*****************************************************************************

@@GetJsSensitivity:
		mov	ax , jsSensitivity
		mov	[bp].r_cx , ax
		retn
@@SetJsSensitivity:
		mov     ax , [bp].r_cx
		or	ax , ax
		je	@@42
		cmp	ax , 16384
		jae	@@42
		mov	jsSensitivity , ax
	@@43:	retn

;*****************************************************************************
;   AL=1Eh      BL=12	BH=0/1 - query/set ext. status
;*****************************************************************************

@@GetExtOpt:    mov	ax , EXT_OPT
		mov	[bp].r_cx , ax
		retn
@@SetExtOpt:    mov	ax , [bp].r_cx
		mov     EXT_OPT , ax
		retn

;*****************************************************************************
;   AL=1Eh      BL=13,14 BH=0/1 - query/set total value of hist. width
;*****************************************************************************

@@GetHistWX:	mov	ax , word ptr HistWX
		mov	dx , word ptr HistWX+2
		jmp	@@44
@@GetHistWY:	mov	ax , word ptr HistWY
		mov	dx , word ptr HistWY+2
	@@44:	mov	[bp].r_cx , ax
		mov	[bp].r_dx , dx
		retn

@@SetHistWX:    lea	bx , HistWX
		jmp	@@45
@@SetHistWY:	lea	bx , HistWY
	@@45:	mov	ax , [bp].r_cx
		mov	dx , [bp].r_dx
		call	labs
		mov	word ptr [bx  ] , ax
		mov	word ptr [bx+2] , dx
		retn

;*****************************************************************************
;   AL=1Eh      BL=15	BH=0/1 - query/set total value of manual corrections
;*****************************************************************************

@@GetCorrections:
		mov	ax , word ptr DRV_X.RsdlX
		mov	dx , word ptr DRV_X.RsdlX+2
		call	rshift8
		mov	[bp].r_cx , ax
		mov	ax , word ptr DRV_Y.RsdlX
		mov	dx , word ptr DRV_Y.RsdlX+2
		call	rshift8
		mov	[bp].r_dx , ax
		ret

@@SetCorrections:
		mov	ax , [bp].r_cx
		cwd
		call	lshift8
		mov	word ptr DRV_X.RsdlX   , ax
		mov	word ptr DRV_X.RsdlX+2 , dx
		mov	ax , [bp].r_dx
		cwd
		call	lshift8
		mov	word ptr DRV_Y.RsdlX   , ax
		mov	word ptr DRV_Y.RsdlX+2 , dx
		ret

;*****************************************************************************
UpdOptions	endp
;*****************************************************************************


_SetMaxAcc	proc	near
		push	bx
		cmp	ax , 20
		jb	@@Err
		cmp	ax , 2000
		ja	@@Err
@@AccOk:	cwd
		mov	bx , 10
		div	bx
		mov	MaxAcc , ax
		mov	bx , 256
		mul 	bx
		mov	word ptr MaxAcc_D   , ax
		mov	word ptr MaxAcc_D+2 , dx

		mov     cx , 3  		;  MaxAcc_W =
@@1:        	sar     dx , 1			;   max ( 20*256 ,
		rcr     ax , 1			;         MaxAcc_D>>3 )
		loop    @@1
		mov     bx , 01400h
		mov     cx , 00000h
		call    lsort2
		mov	word ptr MaxAcc_W   , ax
		mov	word ptr MaxAcc_W+2 , dx

		mov	ax , MaxAcc
		mov	bx , 192
		mul	bx
		mov	word ptr MaxAcc_W2   , ax
		mov	word ptr MaxAcc_W2+2 , dx

		mov	ax , MaxAcc
		mov	bx , 248
		mul	bx
		mov	word ptr MaxAcc_W3   , ax
		mov	word ptr MaxAcc_W3+2 , dx

		clc
		jmp	@@Done
@@Err:		stc
@@Done:		pop	bx
		retn
_SetMaxAcc	endp


_SetMaxSpeed    proc	near
		push	bx
		cmp     ax , 100
		jl	@@Err
		cmp	ax , 14400
		jg	@@Err
		cwd
		mov     bx , 10
		div     bx
		mov	MaxSpeed , ax
		cwd
		call	lshift8
		mov	word ptr MaxSpeed_D   , ax
                mov     word ptr MaxSpeed_D+2 , dx
		clc
		jmp	@@Done
@@Err:          stc
@@Done:		pop	bx
		retn
_SetMaxSpeed	endp

;*****************************************************************************
;   	ApplyTrackingOpt
;*****************************************************************************

ApplyTrackingOpt proc	near
		test	DRV_STAT2 , DRV_TRACKING
                jz      @@Disable
@@Keyboard:	test    DRV_OPT , D_TAKE_KB
		jz	@@12
	@@11:   call	EnableKbdDriver
		jmp	@@Mouse
	@@12:	call	DisableKbdDriver
@@Mouse:	test	DRV_OPT , D_TAKE_MOUSE
		jz	@@22
	@@21:   call	TakeMouse
		jmp	@@Joystick
	@@22:   call	ReleaseMouse
@@Joystick:     test	HRDW_OPT , ENABLE_JOYSTICK
		jz	@@Done
		test	DRV_OPT , D_USE_JOYSTICK
		jz	@@32
	@@31:   call	TakeJoystick
		jmp	@@Done
	@@32:	call	ReleaseJoystick
@@Done: 	and	DRV_STAT , Not LASER_DISABLE
		or	DRV_STAT2 , FO_ENABLE
		jmp	@@Ret
@@Disable:	call	DisableKbdDriver
		call	ReleaseMouse
		call	ReleaseJoystick
		or	DRV_STAT , LASER_DISABLE
		and	DRV_STAT2 , Not FO_ENABLE
@@Ret:		retn
ApplyTrackingOpt endp

_TEXT		ends
		end
