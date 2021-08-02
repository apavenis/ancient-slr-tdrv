
		.286

		.XList
		INCLUDE  TDRV.INC
		INCLUDE  DBGSTRCT.INC
		INCLUDE  HARDWARE.INC
		.List

_TEXT           Segment Byte Public 'CODE'
		Assume  CS:_TEXT


IF IOTRACE Eq 0
     InitDbgBuffer  equ   0
ENDIF

INT_2F_PROC     Proc    Far
		pushf
                cmp     ah , cs:INT_2F_IDENT    ; Call to this process ?
                jne     @@W00                   ; NO --> Call old handler
		test    al , 0E0h               ; SubFn number correct ?
		jne     CallOld3                ; NO --> Call old handler

API_Entry1:	push    bx                      ; Save BX in stack
		xor     bh , bh
		mov     bl , al                 ; Find offset in subfunctions
		shl     bx , 1                  ; table
		mov     bx , cs: SubFnTable [bx] ; Get address of procedure
		or      bx , bx
		jne     CallFunct

CallOld1:       pop     bx                      ; Resore bx when necessary
                jmp     CallOld3                ; Unsupported TDRV call.
                                                ; We don't nead to look for
                                                ; WINDOWS
CallOld2:       pop     bx                      ; Restore register BX
         @@W00:

                ; The following code is included to switch off all TDRV
                ; sound effects when MS-WINDOWS is starting and to restore
                ; the previous state after WINDOWS is finished

                cmp     ax , 1605h              ; is Windows starting ?
                jne     @@W01                   ; No >> look if Windows is ending
                or      CS:IsWindows , 2        ; Set windows entered flag
                push    ax
                call    nosound                 ; Switch of sound
                call    DisableIRQ8             ; Disable use of RTC
                pop     ax
                jmp     CallOld3
	@@W01:  cmp     ax , 1609h              ; is Windows ending
                jne     CallOld3
                and     CS:IsWindows , Not 2    ; Clear WIndows active flag
CallOld3:       popf
		jmp     CS:INT_2F . OldVect

CallFunct:	push    es                      ; Save registers in stack
		push    ds
		push    bp
		push    di
		push    si
		push    dx
		push    cx
		push    ax
		mov     bp , sp

		push    cs                      ; Set DS equal to CS
		pop     ds
		call    bx                      ; Call requested subfunction

		test    [bp].r_flags , 0200h
                jnz     @@44
                nop
        @@44:

		pop     ax
		pop     cx
		pop     dx
		pop     si
		pop     di
		pop     bp
		pop     ds
		pop     es
		pop     bx
		popf
		iret

API_ENTRY:	pushf
		test	al , 0E0h
		jne     @@61
		jmp	API_Entry1
	@@61:	popf
		iret

INT_2F_PROC     EndP
;
;==============================================================================
SubFnTable      dw      GetIdent                ; 0
		dw      I_SetCCDelay            ; 1
		dw      I_SetDest               ; 2
		dw      I_SetCoord              ; 3
		dw      I_GetPosition           ; 4
		dw      I_ResetDriver           ; 5
                dw      I_DisableTDRV           ; 6
		dw      I_StopTracking          ; 7
		dw      I_GetRData              ; 8
		dw      0                       ; 9
		dw      0                       ; 10
		dw      0                       ; 11
		dw      I_ConvManCor            ; 12
		dw      0                       ; 13
		dw      0                       ; 14
		dw      I_GetDbgInfo            ; 15  - Get debug information
		dw      0                       ; 16
		dw      0                       ; 17
		dw      I_InitializeDriver      ; 18
		dw      0			; 19
		dw      InitDbgBuffer           ; 20
		dw      0                       ; 21
		dw      I_CallBack              ; 22
		dw      I_GetTempBufferAddr     ; 23
		dw      I_ModelInfo             ; 24
		dw      I_Joystick              ; 25 Center joystick (if exist)
		dw      I_LaserCtrl             ; 26
		dw      I_TmFunct               ; 27
		dw      I_ManCorrections        ; 28
		dw      I_InstrDefFile          ; 29
		dw      UpdOptions              ; 30
		dw      TimerFunct              ; 31
;=============================================================================
;
I_GetTempBufferAddr proc near
		mov	ax , cs
		mov	[bp].r_dx , ax
		mov	[bp].r_ax , Offset TempBufStart
		mov	[bp].r_cx , TempBufEnd - TempBufStart
		and	[bp].r_flags , 0FFFEh
		retn
		endp

TempBufStart	dw	128 dup (0)
TempBufEnd	dw	0

_TEXT           ENDS
		END

