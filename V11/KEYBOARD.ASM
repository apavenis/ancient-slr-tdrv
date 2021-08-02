		.286
		.XList
		include TDRV.INC
		.List

		Locals
_TEXT           Segment Byte Public 'CODE'
		Assume  CS:_TEXT , DS:_TEXT
;
;=============================================================================
;
NumKeypadStatus dw      0
;
;=============================================================================
;     This Keyboard interrupt procedure interprets keys from numeric
;  keyboard for telescope control.
;=============================================================================
;
INT_09_PROC     Proc    Far
		cli
;
;    At very start test if processing of keys from numeric keypad is
; enabled. If disabled then drop through to original driver.
;
		test    byte ptr CS: kStatus , NUM_KB_ENABLE
		je      DoOldKb2
;
;    If previous key was 0E0h (Additional keys for 101-keys keyboard) then
; drop through to original keyboard driver. After that save AX in stack and
; read key from port 060h
;
		push    ax
		in      al , 060h
		test    byte ptr CS: kStatus , IS_E0_CODE ; Was the previous code 0E0h?
		jne     DoOldKb1        ; Yes >>> call prev. int.
;
;    If current key is 0E0h, then set corresponding flag and pass it
; to original driver.
;
		cmp     al , 0E0h       ; Is current key 0E0h ?
		jne     NoE0            ; No >>> Continue testing
;
;   The value read from port 060h is 0E0h: set corresponding flag and
; call previous interrupt procedure
;
		or      CS: kStatus , IS_E0_CODE
		pop     ax
		jmp     DoOldKb3
;
;   Test value that we get from port 060h. If the value corresponds to
; numeric keypad then process the key. Otherwise pass the key to
; previous keyboard interrupt procedure
;
NoE0:           mov     CS: CurrKey , al
		and     al , 07Fh
		cmp     al , 047h
		jc      DoOldKb1
		cmp     al , 054h
		jnc     DoOldKb1
		jmp     ProcessNumKey
;
;   The code must be passed to previous keyboard interrupt procedure:
; restore register AX from stack and call this procedure
;
DoOldKb1:       pop     ax
DoOldKb2:       and     CS:kStatus , Not IS_E0_CODE
DoOldKb3:       jmp     CS:INT_09 . OldVect
;
;   The following code processes events caused by numeric keypad.
;
ProcessNumKey:  push    bx
		push    si              ;  Compute offset in table that shows
		xor     ah , ah         ; the status of the keys from numeric
		sub     al , 047h       ; keypad.
		mov     si , ax         ;
		shl     si , 1          ; Offset in Num KBD stauts mask table
		mov     si , cs: KeyMaskTable [si]
		test    CS: CurrKey , 080h ; Is the key pressed or released?
		je      KeyPressed
KeyReleased:    not     si
		and     cs: NumKeypadStatus , si
		jmp     KeyProcessed
KeyPressed:     or      cs: NumKeypadStatus , si
KeyProcessed:   in      al , 061h       ; Get value of keyboard ctrl. lines
		mov     ah , al         ;  save it
		or      al , 080h       ; Set the 'enable kbd' bit
		out     061h , al       ;  and write it out the control port
		xchg    ah , al         ; fetch the original control port val.
		out     061h , al       ;  and write it back
		mov     al , 020h       ; Send end of interrupt signal
		out     020h,al         ;  to the 8259 Interrupt Controller.
		pop     si
		pop     bx
		pop     ax
		iret
INT_09_PROC     EndP
;
		;---------------------------------------------------;
                ;  Procedure <EnableKbdDriver> sets flags to enable ;
                ;  keyboard interface for telescope control.        ;
                ;  Procedure <DisableKbdDriver> reverses actions    ;
		;  done by <EnableKbdDRiver>.                       ;
		;---------------------------------------------------;

EnableKbdDriver Proc    Near
		or      cs: kStatus , NUM_KB_ENABLE
		mov     cs: NumKeypadStatus , NK_ENABLED
		ret
EnableKbdDriver EndP
;
DisableKbdDriver Proc    Near
		 and     CS: kStatus , Not NUM_KB_ENABLE
		 and     cs: NumKeypadStatus , Not NK_ENABLED
		 ret
DisableKbdDriver EndP
;
;-----------------------------------------------------------------------------
;  Procedure:   GetKbCorrections
;  Parameters:  None
;  Returns manual corrections corresponding to status of numeric keypad
;      AX - direction X  , BX - direction Y
;-----------------------------------------------------------------------------
;
mKey            struc
mask            dw      ?
d_X             dw      ?
d_Y             dw      ?
		ends
;
;-----------------------------------------------------------------------------
;
GetKbCorrections proc   near
		push    si
		xor     ax , ax                 ; Clear X correction
		xor     bx , bx                 ; Clear Y correction
		test    byte ptr CS: kStatus , NUM_KB_ENABLE
		jz	C91			; Return 0,0 when disabled
		xor     cx , cx                 ; Clear counter
		lea     si , cKeyList           ; Address of key list
Loop_C:         mov     dx , [si].mask          ; Load key mask
		or      dx , dx                 ; Zero value -->
		jz      C02                     ;     end of list
		and     dx , NumKeypadStatus    ; If the requested key isn't
		jz      C01                     ; pressed go to end of loop
		add     ax , [si].d_X           ; Key pressed: update
		add     bx , [si].d_Y           ; correction values and
		inc     cx                      ; counter
C01:            add     si , TYPE cKeyList      ; Take next list element and
		jmp     Loop_C                  ; go to begin of loop

C02:            or      cx , cx                 ; If there are no pressed keys
		je      C91                     ; on numeric keypad then
						; return

		cwd				; If more than one arrow key
		idiv    cx			; is pressed on numeric keypad
		push    ax			; then divide sum of correc-
		mov     ax , bx			; tions by number of keys
		cwd				; pressed
		idiv    cx
		mov     bx , ax
		pop     ax

		push	es
		mov	es , BIOS_Seg
		test    byte ptr es:[17h] , 4	; Look if <Ctrl> is pressed
		jz	C_NoCtrl
		shl     ax , 4
		shl	bx , 4
C_NoCtrl:	test	byte ptr es:[17h] , 8	; Look if <Alt> is pressed
		jz	C_NoAlt
		shl	ax , 2
		shl	bx , 2
C_NoAlt:	pop	es

C91:            pop     si
		ret
GetKbCorrections endp
;

;
cKeyList        mKey    < NK_9 ,  18 ,  18 >
		mKey    < NK_6 ,  25 ,   0 >
		mKey    < NK_3 ,  18 , -18 >
		mKey    < NK_2 ,   0 , -25 >
		mKey    < NK_1 , -18 , -18 >
		mKey    < NK_4 , -25 ,   0 >
		mKey    < NK_7 , -18 ,  18 >
		mKey    < NK_8 ,   0 ,  25 >
		dw      0
;
;=============================================================================
;
kStatus         db      0
CurrKey         db      0
;
KeyMaskTable    dw      NK_7
		dw      NK_8
		dw      NK_9
		dw      NK_MINUS
		dw      NK_4
		dw      NK_5
		dw      NK_6
		dw      NK_PLUS
		dw      NK_1
		dw      NK_2
		dw      NK_3
		dw      NK_0
		dw      NK_POINT
;
;=============================================================================
;
_TEXT           EndS
		END
