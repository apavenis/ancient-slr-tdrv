
		.286
		.XList
		include	TDRV.INC
		include ARITH.INC
		.List

DEBUG=1

_TEXT		segment	byte public 'CODE'
		assume  cs:_TEXT , ds:_TEXT

;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
;
;	Procedure <VField> converts manual corrections from the coordinate
;  system connected with the field of view to the instrumental system.
;
;  Input data:
;       AX,DX - coordinate increment in X direction (integer)
;	BX,CX - coordinate increment in Y direction (integer)
;       fOpt - structure that contains description of transformation
;	DRV_X.CurrX - the first coordinate
;	DRV_Y.CurrY - the second coordinate
;
;  Output data:
;       AX,DX - correction for X
;	BX,CX - correction for Y
;
;ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ
;
VField		proc	near
		local   @@dx0:dword , @@dy0:dword , @@dx:dword  , 	\
			@@dy:dword , @@argX:dword , argY:dword , _arg_:dword  ,           \
			cArg:word , sArg:word , denX:word , denY:word	   \
			= LocBytes
		enter	LocBytes , 0

IF DEBUG EQ 1
	;####  DEBUG CODE  #####
		cmp     ax , 0
	       jnz     VF_NotZero
		cmp     dx , 0
	       jnz     VF_NotZero
		cmp     bx , 0
	       jnz     VF_NotZero
		cmp     cx , 0
	       jnz     VF_NotZero
	       jmp     @@Start
  VF_NotZero:  nop
	       jmp     @@DBG1
	       public  CORRX1,CORRY1
  CORRX1:      dd      ?
  CORRY1:      dd      ?
  @@DBG1:      lstore  CORRX1
	       lstoreb CORRY1
ENDIF

@@Start:	;###################

		test	DRV_STAT2 , FO_ENABLE	; Look whether manual
		jnz     @@6			; corrections are enabled.
						; If not then return
		xor	ax , ax			; zeros.
		xor	bx , bx
		xor	cx , cx
		xor	dx , dx
		jmp	@@Done
@@6:

	;-----------------------------------------------------------;
	;   At first save manual corrections (current step only)    ;
	;   for later use (invert them if necessary).               ;
	;-----------------------------------------------------------;

@@10:		test    f_Options , FO_XINV         ; Look if we must invert
		jz	@@11			    ; the X corection
		call	lneg
@@11:		lstore	@@dx0

		mov	ax , bx                     ; Do the same with Y
		mov	dx , cx                     ; correction
		test    f_Options , FO_YINV
		jz	@@12
		call	lneg
@@12:		lstore  @@dy0

@@13:

	;-----------------------------------------------------------;
	;   Convert both coordinates to the units used by ISIN and  ;
	;   ICOS functions. The coefficients are in config. struct. ;
	;-----------------------------------------------------------;

		lload	DRV_X.CurrX		; Convert first coord.
		call    rshift8
		mov	bx , f_divX		; to units of 0.1¯
		call	IDiv42R
		lstore	@@argX

		lload	DRV_Y.CurrX		; Convert second coord.
		call    rshift8
		mov	bx , f_divY		; to units of 0.1¯
		call	IDiv42R
		lstore	argY

	;--------------------------------------------------------------;
	;   Look if field rotation angle is specified by user. If so   ;
	;   than don't compute it but take the ready value.            ;
	;--------------------------------------------------------------;

		test	DRV_OPT , D_USER_ROTATION
		jz      @@R06
		mov	ax , FldRotAngle
		cwd
		jmp	@@26

	;--------------------------------------------------------------;
	;   Now look whether field rotation is neccesary at all and    ;
	;   set rotation angle to 0 if so.                             ;
	;--------------------------------------------------------------;

@@R06:		test	DRV_OPT , D_INSTR_COORD
		jz	@@R11
		xor	ax , ax
		xor	dx , dx
		jmp	@@26

	;--------------------------------------------------------------;
	;   Now find the angle to rotate the field of view: no special ;
	;   variants are requested                                     ;
	;--------------------------------------------------------------;
	;   At first load constant part of position's angle and        ;
	;   convert it to long int                                     ;
	;--------------------------------------------------------------;

@@R11:		mov	ax , f_argShift		; Constant part of the
		cwd				; argument

	;--------------------------------------------------------------;
	;   Now look what we must do with the first coordinate         ;
	;--------------------------------------------------------------;

		test    f_Options , FO_XDEF      ; Do we need this coord?
		jz	@@17			; No >>> bypass
                test    f_Options , FO_XSIGN ; Look for sign we need
		jnz     @@16
		ladd	@@argX
		jmp	@@17
@@16:		lsub	@@argX
@@17:

	;--------------------------------------------------------------;
	;   Now look for dependence on the second coordinate           ;
	;--------------------------------------------------------------;

		test    f_Options , FO_YDEF
		jz	@@22
                test    f_Options , FO_YSIGN
		jnz     @@21
		ladd	argY
		jmp	@@22
@@21:		lsub	argY
@@22:

	;-------------------------------------------------------------;
	;   Look whether we must invert the position's angle          ;
	;-------------------------------------------------------------;

		test    f_Options , FO_INVARG
		jz	@@26
		call	lneg

@@26:   ;--------------------------------------------------------------;
	;   Now reduce the angle to interval [0¯...360¯[ and store it. ;
	;--------------------------------------------------------------;

		mov	bx , 3600
		call	IMod42
		xor	dx , dx
		lstore  _arg_		; Rotation angle in units of 0.1¯

	;--------------------------------------------------------------;
	;  Find numerators for conversion coefficients                 ;
	;--------------------------------------------------------------;

		push	ax
		push	dx
		call	ICOS
		mov     cArg , ax
		pop	dx
		pop	ax
		call    ISIN
		mov     sArg , ax

	;--------------------------------------------------------------;
	;  Find denominators for coordinate transformation             ;
	;--------------------------------------------------------------;

		mov	ax , 10000
		test    f_Options , FO_SEL_COORD
		jnz     @@31
		mov	ax , f_dShift
		cwd
		ladd	argY
		call	ICOS
		or	ax , ax
		jnz	@@31
		mov	ax , 10000
@@31:           mov     denX , ax

		mov	ax , 10000
		test    f_Options , FO_SEL_COORD
		jz      @@36
		mov	ax , f_dShift
		cwd
		ladd	@@argX
		call	ICOS
		or	ax , ax
		jnz     @@36
		mov	ax , 10000
@@36:		mov	denY , ax

	;--------------------------------------------------------------;
	;  Now all data are ready to compute final coordinates         ;
	;--------------------------------------------------------------;

		lload   @@dx0
		mov	bx , cArg
		mov	cx , denX
		call    IMlt4RN
		jnc	@@41
		xor	ax , ax
		xor	dx , dx
@@41:           lstore  @@dx

		lload	@@dy0
		mov	bx , sArg
		mov	cx , denX
		neg	bx
		call	IMlt4RN
		jnc	@@42
		xor	ax , ax
		xor	dx , dx
@@42:		add	ax , word ptr @@dx
		adc	dx , word ptr @@dx+2

		lea	bx , f_cLow
		call	IsInside
		lstore  @@dx

		lload   @@dx0
		mov	bx , sArg
		mov	cx , denY
		call    IMlt4RN
		jnc	@@46
		xor	ax , ax
		xor	dx , dx
@@46:           lstore  @@dy

		lload	@@dy0
		mov	bx , cArg
		mov	cx , denY
		call	IMlt4RN
		jnc	@@47
		xor	ax , ax
		xor	dx , dx
@@47:		add	ax , word ptr @@dy
		adc	dx , word ptr @@dy+2

		lea	bx , f_cLow
		call	IsInside
		lstore  @@dy

		lload	@@dx
		lloadb  @@dy

	;--------------------------------------------------------------;
	;  All is done. We can return to caller.                       ;
	;--------------------------------------------------------------;

@@Done:		leave
		ret
VField		endp

_TEXT		ends
		end
