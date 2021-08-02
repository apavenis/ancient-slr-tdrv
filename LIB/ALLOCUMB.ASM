		locals
		include	LIB.INC

_TEXT		segment	byte public 'CODE'
		assume  cs:_TEXT , ds:_TEXT

_MaxUMB		dw	0

_AllocUMB       proc	near
		arg	Size		:Word	= RetBytes
		local	PrevStrategy    :Word , \
			PrevUMBState	:Word , \
			SegAddr		:Word   \
			= LocBytes
                push    bp
                mov     bp , sp
                sub     sp , LocBytes

		mov	SegAddr , 0
		mov     _MaxUMB , 0

		mov	ax , 3000h		; Code below is valid for
		int	21h			; MS DOS 5.0 and higher
		cmp	al, 5			; only
                jae     @@VersionOk
		jmp	@@3

@@VersionOk:	mov	ax , 05800h      	; Save previous memory alloc.
		int	21h			; strategy
		mov	PrevStrategy , ax

		mov	ax , 05802h		; Save provious UMB_linked
		int	21h			; state
		xor	ah , ah
		mov     PrevUMBState , ax

		mov	ax , 05801h		; Set new memory allocation
		mov	bx , 00040h		; strategy (first fit,UMB only)
		int	21h

		mov	ax , 05803h		; Add UMB to memory block
		mov	bx , 00001h		; chain
		int	21h
                jc      @@4

		mov	ax , 04800h		; Now we try to allocate
		mov	bx , Size		; block
		int	21h
		jc	@@1
		mov     SegAddr , ax
		jmp	@@2
@@1:		mov	_MaxUMB , bx
@@2:
		mov	ax , 05803h		; Restore previous UMB linked
		mov	bx , PrevUMBState	;
		int	21h

@@4:            mov     ax , 05801h             ; Restore previus memory alloc.
		mov	bx , PrevStrategy	; strategy
		int	21h
@@3:            mov	ax , SegAddr
                mov     sp , bp
                pop     bp
		retn	RetBytes
_AllocUMB	endp


_GetMaxUMBSize	proc	near
                push    bp
                mov     bp , sp
		push	0FFFFh
		call    _AllocUMB
		mov	ax , _MaxUMB
                pop     bp
		retn
_GetMaxUMBSize	endp

_TEXT		ends
		END
