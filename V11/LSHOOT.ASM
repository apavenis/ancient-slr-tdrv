
		.286
		JUMPS
		.XList
		include TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
		.List

		locals
_TEXT           segment byte public 'CODE'
		assume  cs:_TEXT , ds:_TEXT

LSG_CL		dw	(200000000 Shr 16)

LShootStat	dw	0
			L_ENABLE_SHOOT	equ	08000h

LTrigerMode	dw	1

LWindow		dw	?       ; Window setting in hardware units
WindowWidth	dd	?

LNextTime	dd	?	; Next shoot time

LIncrTime	dw	10	; Time difference between two laser pulses
				; in units of 0.1 second

gateShift	dd	0	; Value to be added to time gate (nanoseconds)

halfWin		dd	?	; Half width for gate correction

LWinWrite	dw	?

;*****************************************************************************
;	Procedure <LShootInit> initializes laser control subsystem:
;*****************************************************************************

LShootInit	proc    near
		xor     ax , ax
		mov     LShootStat , ax		    ; Disable eny shooting

		mov	bx , dftLaserPeriod	    ; Copy default laser
		mov	LIncrTime , bx		    ; shooting period

		mov     word ptr gateShift , ax
		mov     word ptr gateShift+2 , ax   ; GateShift = 0

		mov	ax , word ptr dftWindow
		mov	dx , word ptr dftWindow+2
		call	SetWindow

		mov	LTrigerMode , 1

		retn
LShootInit	endp

;*****************************************************************************
;  Procedure <SetWindow> - sets new value of window width
;  Registers:  AX,DX - new value
;*****************************************************************************

SetWindow	proc	near
		mov	word ptr WindowWidth   , ax
		mov	word ptr WindowWidth+2 , dx
		cmp	dx , fqWin  	; If window is too large then set it
		jb	@@01		; to max. possible value.
		mov	ax , 0FFFFh
		jmp	@@02
@@01:		div	fqWin		; Now convert to hardware units
		cmp	ax , 1		; If 0 then replace it with 1
		jae	@@02
		mov	ax , 1
@@02:		mov	LWindow , ax    ; Save window (instrumental units)
		mov	bl , M_Window	; Mode 1 for I8253 chip
		mov	dx , P_Window	; Base 01B0h , Chanal 2
                call    I8253_WriteC    ; Send window value to hardware
		call	GetWindow
		mov	word ptr halfWin   , ax
		mov	word ptr halfWin+2 , dx
		shr	word ptr halfWin+2 , 1
		rcr	word ptr halfWin   , 1
		retn
SetWindow	endp

;*****************************************************************************
;  Procedure <GetWindow> return apparent value of window used by hardware
;  in register pair AX,DX
;*****************************************************************************

GetWindow	proc	near
		mov	ax , LWindow
		mul	fqWin
		retn
GetWindow	endp

;*****************************************************************************
;  Procedure <I_LaserCtrl> -  TDRV.EXE function 1Ah
;  Registers:  AH - multiplex process number
;	       AL = 1Ah (function code)
;              BH - what to do (00h...0Fh)
;*****************************************************************************

I_LaserCtrl	proc	near
		mov	ax , [bp].r_bx
		cmp	ah , 18h
		jae	@@Unknown
		mov	cx , [bp].r_cx
		mov	dx , [bp].r_dx
		xor	bh , bh
		mov	bl , ah
		shl	bx , 1
		and	byte ptr [bp].r_flags , 254
		jmp	word ptr LC_Fn [bx]

@@Unknown:	or	byte ptr [bp].r_flags , 1
@@Ret1:		ret

LC_Fn		dw      @@Defaults		;  00
		dw	LaserEnable     	;  01
		dw	LaserDisable    	;  02
		dw	@@GetStatus		;  03
		dw	@@SetNext       	;  04
		dw	@@GetNext       	;  05
		dw      @@SetInterval   	;  06
		dw	@@GetInterval   	;  07
		dw	@@StartL        	;  08
		dw	@@SetWin        	;  09
		dw	@@GetWin        	;  0A
		dw	@@Unknown	       	;  0B
		dw	@@SetGMask		;  0C
		dw	@@GetGMask		;  0D
		dw	@@SetGShift     	;  0E
		dw	@@GetGShift		;  0F
		dw	@@GetLasTrigMode	;  10
		dw	@@SetLasTrigMode	;  11
		dw	@@Unknown		;  12
		dw	@@Unknown		;  13
		dw	@@Unknown		;  14
		dw	@@Unknown		;  15
		dw	@@Unknown		;  16
		dw	@@Unknown		;  17


@@Defaults:	call	LShootInit
		retn

LaserEnable:	or	LShootStat , L_ENABLE_SHOOT
		retn

LaserDisable:	and	LShootStat , Not L_ENABLE_SHOOT
		retn

@@GetStatus:	mov	ax , LShootStat
		shr	ax , 15
		mov	[bp].r_ax , ax
		retn

@@SetNext:	mov     word ptr LNextTime , cx
		mov     word ptr LNextTime+2 , dx
		retn

@@GetNext:	mov	ax , word ptr LNextTime
		mov	dx , word ptr LNextTime+2
		jmp	@@RetLong

@@SetInterval:  or	cx , cx
		jle	@@Err1
		mov     LIncrTime , cx
		retn
       @@Err1:  jmp	@@Unknown

@@GetInterval:  mov	cx , LIncrTime
		mov	[bp].r_ax , cx
		retn

@@StartL:       mov     ax , word ptr CURR_TIME
		mov	dx , word ptr CURR_TIME+2
		mov     bx , ShootAlign
		call	IDiv42
		add	ax , 1
		adc	dx , 0
		push	dx
		mul	bx
		mov     word ptr LNextTime , ax
		mov	word ptr LNextTime+2 , dx
		pop     ax
		mul	bx
		add	word ptr LNextTime+2 , ax
		jmp	LaserEnable

@@SetWin:       mov	ax , cx	  	; New value ==> DX:CX
		call	SetWindow
@@RetLong:	mov	[bp].r_ax , ax	; Modify register values saved in
		mov	[bp].r_dx , dx	;       stack
		retn

@@GetWin:	call	GetWindow
		jmp	short @@RetLong

@@SetGMask:     and	cx , 3
		shl	cx , 4
		mov	GateMask , cl
		retn

@@GetGMask:	mov	al , GateMask
		shr	al , 4
		and	ax , 3
		mov	[bp].r_ax , ax
		retn

@@GetGShift:    mov     ax , word ptr gateShift
		mov	dx , word ptr gateShift+2
		jmp	short @@RetLong

@@SetGShift:    push	dx
		or	dx , dx
		jge	@@21
		neg	dx
	@@21:   cmp	dx , 000FFh
		pop	dx
		ja      @@22
		mov	word ptr gateShift   , cx
		mov	word ptr gateShift+2 , dx
		retn
	@@22:	jmp	@@Unknown

@@GetLasTrigMode: mov	ax , LTrigerMode
		mov	[bp].r_ax , ax
	@@26:	retn

@@SetLasTrigMode: mov	ax , [bp].r_cx
		cmp	ax , 3
		jbe	@@31
		mov	ax , 1
	@@31:   mov     LTrigerMode , ax
		cmp	ax , 2
		jb      @@26
		jmp	@@StartL

I_LaserCtrl	endp


;*****************************************************************************
;	Procedure <LCtrlShoot> sets trigger to enable shoot at the next	0.1 sec.
;	and sets value to be written as	the window at the begin	of the next IRQ
;*****************************************************************************

LCtrlShoot	proc    near
		local   @@T0:word , @@T1:word , @@LDist:dword = LocBytes
		enter   LocBytes , 0

;		xor	ax , ax
;		xor 	dx , dx
;-------------------------------------------------------------------------
		lload	dRO	     ; We had 100 ms time bias for
		call    lneg         ; gate start. So let's add increment
				     ; here
;-------------------------------------------------------------------------
;		lload   dRO	     ; Increment of dist. per 0.1 sec.
;		or	dx , dx	     ; Save sign in stack
;		pushf
;		jnl     @@1
;		call    lneg	     ; and take	abs value
;
;@@1:		;------------------------------------------------------;
;		;  Compute time correction for satelite motion         ;
;		;  ³dT1³ ÷ ³dRO³ * (RO shr 16) / (200000000 Shr 16)    ;
;		;------------------------------------------------------;
;
;		push    dx		; Save high word
;		mul     word ptr RO+2   ;
;		mov     @@T0 , ax
;		mov     @@T1 , dx
;		pop     ax		; Restore high word in AX
;		mul     word ptr RO+2
;		add     ax , @@T1	     	; Now {DX,AX,T2} contains ³dRO³*
;		adc     dx , 0	     	; (RO shr 16). (DX-high word)
;		cmp     dx , LSG_CL     ; If overflow then modify high word
;		jb      @@2
;		mov     dx , LSG_CL     ; Divide overflow detected. Reduce
;		dec     dx		; argument to prevent failure
;@@2:		div     LSG_CL	        ; Now we can divide with (RO shr 16)
;		push    ax		; Save high word of result in stack
;		mov     ax , @@T0
;		div     LSG_CL	        ; Low word of result in AX
;		pop     dx	        ; Restore high word from stack
;		popf		        ; Look for sign of dRO
;		jnl     @@6	        ; and change sign if dRO<0
;		call    lneg

@@6:		;-------------------------------------------------------;
		;  Add the distance correction with distance and	;
		; predefined shift to find delay for chanal commutator  ;
		;-------------------------------------------------------;

		ladd    RO
		ladd    gateShift
		lstore  @@LDist	       ; Save corrected distance
		mov     bx , fqCC      ; Convert it to units used for chanal
		call    IDiv42	       ; commatator.
		call    Set_CC_Strobe

		;-------------------------------------------------------;
		;	  Look whether we need to shoot	at next	0.1 sec.     ;
		;-------------------------------------------------------;

		mov     cx , 100	     ;
		xor     dx , dx
@@LCtrl01:	mov     ax , word ptr CURR_TIME+2
		cmp     ax , word ptr LNextTime+2
		jb	@@LCtrl09	     ; We must wait
		ja	@@LCtrl02	     ; Increment time and loop
		mov     ax , word ptr CURR_TIME
		cmp     ax , word ptr LNextTime
		jb	@@LCtrl09
		ja	@@LCtrl02

		mov	bx , LTrigerMode
		and	bx , 3
		add	bx , bx
		jmp     word ptr @@TModeTable [bx]

@@TModeTable:   dw	@@LCtrl09	; Mode 0 - disable triggering at all
		dw      @@Mode1
		dw	@@Mode2
		dw	@@Mode3

@@Mode2:	test	LShootStat , L_ENABLE_SHOOT
		jz      @@LCtrl09
		jmp	@@Mode3

@@Mode1:	test    LShootStat , L_ENABLE_SHOOT
		jz	@@LCtrl09	     ; No shooting allowed
		test	DRV_STAT , LASER_DISABLE
		jnz	@@LCtrl02

@@Mode3:	mov     ax , LWindow	     ; Set window width	to be
		mov     LWinWrite , ax	     ; written at next IRQ
		mov     dx , P_EnableShoot   ; Enable shoot at next
		out     dx , OutRegister     ;    0.1 second
		out	80h, al
		or	LAS_TRIG , LAS_TRIG_REQUESTED
		BTRACE

		lload   @@LDist		     ; Correct distance	for window
		lsub    halfWin		     ; width and send value to the hardware
; -------------- Substract additionally 3600 ns from distance  ------------
		sub 	ax , 3600
		sbb	dx , 0
; -------------------------------------------------------------------------
		mov     bx , fqGate	     ; hardware	to form	time gate
		call    IDiv42
		push	dx                   ; Save high word in the stack
		mov	dx , P_GateLW        ; Write 4 lower bits of gate
		out	dx , OutRegister     ; to output port
		out	80h, al
		BTRACE
		pop	dx                   ; Restore high word from stack
		mov	cx , 4		     ; And divide {DX:AX} with 16
  @@21:		shr	dx , 1		     ; (Shift it 4 bits right)
		rcr	ax , 1
		loop	@@21
		mov	dx , P_GateH
		call	I8253_Write

		cmp	RTC_Funct , BEEP_ON_SHOOT
		jne	@@XX1
		mov	BeepRequested , 255
  @@XX1:        cmp     IsWindows , 255
                jnz     @@LCtrl02
                cmp     RTC_Funct , 101
		jne	@@LCtrl02

  @@RqShootX:   call    DoBeep

@@LCtrl02:	mov     ax , LIncrTime
		add     word ptr LNextTime , ax
		adc     word ptr LNextTime+2 , 0
		or	dx , dx
		jnz     @@LCtrl09
		loop    @@LCtrl01
@@LCtrl08:      call	@@UpdateGateShift
@@LCtrl09:	leave
		retn

@@UpdateGateShift:
		xor	ax , ax
		test	kStatus , NUM_KB_ENABLE
		jz	@@Upd03
		mov	dx , NumKeypadStatus    ; Select '+' and '-' state
		and     dx , 01800h		;      only
		test	dx , 01000h
		jz	@@Upd01
		inc	ax
@@Upd01:	test	dx , 00800h
		jz	@@Upd02
		dec	ax
@@Upd02:        imul	fqWin
		cwd
		add	word ptr gateShift   , ax
		adc	word ptr gateShift+2 , dx
@@Upd03:	retn

LCtrlShoot	endp


Dbg0001		proc	near
		mov     dx , P_EnableShoot   ; Enable shoot at next
		out     dx , OutRegister     ;    0.1 second
		out	80h, al
		jmp	nosound
Dbg0001 	endp

_TEXT	     	ends

		end
