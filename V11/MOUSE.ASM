
		.XList
		include	TDRV.INC
		.List

_TEXT		segment	byte public	'CODE'
		assume  cs:_TEXT , ds:_TEXT

TakeMouse       proc	near
		test	MOUSE_STAT , MOUSE_OK
		jz      TKM_Done
		test	MOUSE_STAT , MO_STATUS_SAVED
		jnz	TKM_Done
		IF MO_SAVE Ne 0
		   mov	ax , 00016h	; At first save old mouse
		   les	dx , MoBuffer	; status to restore it later
		   int	33h		;
		   mov	ax , 00021h	; After that we reset mouse
		   int	33h
		ENDIF
		or	MOUSE_STAT , MO_STATUS_SAVED
		call	GetMoMotion
TKM_Done:	ret
TakeMouse	endp


ReleaseMouse	proc	near
		test    MOUSE_STAT , MO_STATUS_SAVED
		jz	RLSE_Done
		and	DRV_STAT2 , Not MO_LEFT_DOWN+MO_RIGHT_DOWN+MO_CENTER_DOWN
		IF MO_SAVE Ne 0
		   mov	ax , 00017h
		   les  dx , MoBuffer
		   int 	33h
		ENDIF
		and	MOUSE_STAT , Not MO_STATUS_SAVED
RLSE_Done:	ret
ReleaseMouse	endp



GetMoMotion     proc	near
		test	MOUSE_STAT , MO_STATUS_SAVED
		jz      GM_0011

		;--------------------------------------------------------;
		;   Query mouse motion distance since the last call to   ;
		; <GetMoMotion>.                                         ;
		;--------------------------------------------------------;

		mov	ax , 0000Bh	; Get mouse motion distance in mickeys
		int	33h             ; CX - horizontal distance (+:Right)
		neg	dx		; DX - vertical distance (+:Up)
		mov     MoDX , cx
		mov	MoDY , dx


		;--------------------------------------------------------;
		;   Query mouse button status. If no button is pressed   ;
		; then ignore the last mouse motion. If only one button  ;
		; is pressed then divide MoDX with 4.                    ;
		;--------------------------------------------------------;

		mov	ax , 00003h       ; Query mouse button status
		int	33h               ; When no buttons are pressed then
		and	bx , 7
		and     DRV_STAT2 , 0FFF8h
		or	DRV_STAT2 , bx
		test	bx , 3		  ; ignore all mouse motions.
		jz	GM_0011		  ; if no buttons pressed
		cmp	bx , 3
		jne     GM_0006
		shl     MoDX , 2
		shl	MoDY , 2
GM_0006:	mov	ax , MoDX
		mov	bx , MoDY
		ret
GM_0011:        xor	ax , ax		  ; Processing of the mouse events is
		xor	bx , bx		  ; disabled. Return 0 as the mouse
		ret			  ; corrections
	public  MoDX , MoDY
MoDX            dw      ?
MoDY            dw      ?
GetMoMotion     endp

_TEXT		ends
		end
