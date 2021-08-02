
		.286
		Locals
		.XList
		include	TDRV.INC
		include	ARITH.INC
		include HARDWARE.INC
		.List

_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:Nothing


PeriodicInt	=	040h
Alarm		=  	020h
UpdateDone	=       010h


RTC_STAT_A	=       08Ah		; 00Ah
RTC_STAT_B	=       08Bh		; 00Bh
RTC_STAT_C	=	08Ch		; 00Ch


IRQ_08_PROC	proc	far
		cli
		test    CS:RTC_FLAGS , RTC_InUse
		jnz     @@10
		jmp     dword ptr cs:IRQ_08.OldVect

	@@10:	push	ax
		push	bx
		push	cx
                mov     ah , RTC_STAT_B         ; Read RTC status B
		call	ReadCMOSByte            ; and save it in register
		mov	bh , al			; BH

        @@L1:   mov     ah , RTC_STAT_C         ; Read status C (why interrupt
		call	ReadCMOSByte		; occurred)
		and	al , bh			; Extract only non masked
		mov	bl , al			; sources of interrupt

                je      @@19                    ; No interrupts to service
                test    al , PeriodicInt        ; If this is NOT a periodic
		jz	@@11			; interrupt then skip the
						; following section
		mov     cx , CS:RTC_COUNT	; Load interrupt counter
		dec	CS:RTC_COUNT		; Decrement it in memory
		loop    @@11			; Skip terminating of count
						; if zero is not reached
		mov	al , bh			; RTC Status B
		mov	ah , RTC_STAT_B		; It's address in CMOS
		and	al , 03Fh		; Switch off periodic INT mask
		call	WriteCMOSByte           ; Write status to CMOS and
		call	nosound			; switch of the sound
                and     cs:RTC_FLAGS , Not RTC_InUse
	@@11:   test	bl , Alarm
                jz      @@12
		int     04Ah
        @@12:   ;jmp     @@L1
                mov     ah , RTC_STAT_C
                call    ReadCMOSByte
        @@19:   pop     cx
		pop	bx
		mov	cs:RTC_REQ , 0
		mov	al , 20h
		out	0A0h , al
		jmp	short $+2
		jmp	short $+2
		out	020h , al
		pop	ax
		iret

IRQ_08_PROC	endp


EnableIRQ8	proc  	near
		pushf
		cli
		mov	al , 26h
		mov	ah , RTC_STAT_A         ; 	mov	ax , 00A26h
		call	WriteCMOSByte		; Set RTC register A to 26h
                mov     ah , RTC_STAT_B         ; mov   al , 0Bh
		call	ReadCMOSByte
		and	al , 7Fh
		or      al , 42h
		and     al , Not 03Dh
		mov	ah , RTC_STAT_B		; 	mov	ah , 0Bh
		call	WriteCMOSByte
		call	ClearIRQ8
		or      cs:RTC_FLAGS , RTC_InUse
		popf
		ret
EnableIRQ8	endp


ClearIRQ8	proc	near
		mov	al , 8Ch
		jmp	ReadCMOSByte
ClearIRQ8	endp


DisableIRQ8	proc	near
		pushf
		cli
                mov     ah , RTC_STAT_B         ;       mov     al , 00Bh
		call	ReadCMOSByte
                and     al , 03Fh               ; Disable periodic & alarm int-s
		mov	ah , RTC_STAT_B		; 	mov	ah , 00Bh
		call	WriteCMOSByte
                and     cs:RTC_FLAGS , Not RTC_InUse
		popf
		ret
DisableIRQ8	endp


DoBeep		proc	near
                test    CS:HRDW_OPT , ENABLE_BEEPS
                jz      www
                test    CS:IsWindows , 255
		jnz     www
                mov     ax , CS:BeepFq
		call	sound
                mov     cx , CS:BeepLen
                mov     CS:RTC_COUNT , cx
                call    EnableIRQ8
		mov	RTC_REQ , 255
www:            ret
DoBeep		endp

;----------------------------------------------------------------------------
;   Procedure RTC_Check tests whether sound efects using RTC periodic
;   interrups actually work (They usually don't work in multitasking
;   environment - Windows , DOSEMU under LINUX e.t.c). Therefore we have
;   to switch them off when tests fails
;----------------------------------------------------------------------------

		assume  CS:_TEXT, DS:_TEXT
RTC_Check	proc	near
		test	RTC_REQ , 255
		jz	@@99
		or      IsWindows , 4
		call	nosound
	@@99:	retn
RTC_Check	endp

RTC_REQ		db	0
RTC_FLAGS	db	RTC_Enable
RTC_COUNT	dw	?

_TEXT		ENDS
		END
