	       .XList
               include LIB.INC
	       .List
               .286

_TEXT		segment	byte public 'CODE'
		assume  cs:_TEXT , ds:_TEXT

;==============================================================================
;
;  Procedure:     TrueName
;
;  Returns normalized path of file
;  Input:   DS:BX   - filename
;  Output:  DS:BX   - filename in cannonical form
;
;==============================================================================

TrueName	proc	near
		local	@@buffer:byte:128	= LocBytes
		enter	LocBytes , 0
		push	es
		push	si
		push	di
		push	cx
		push	ss
		pop	es		; Copy SS to ES
		mov	ah , 60h	; True Name function (UNDOCUMENTED)
		mov	si , bx
		lea	di , @@buffer
		int	21h
		mov	cx , 100
		push	es
		push	ds
		pop	es
		pop	ds
		xchg	si , di
		mov	cx , 86
		call	CopyAsciiZ
		pop	cx
		pop	di
		pop	si
		pop	es
		leave
		ret
TrueName	endp

_TEXT           ends
                end

;=============================================================================


main            proc    near
                push    cs
                pop     ds
                lea     bx , ntest
                call    TrueName
                mov     ax , 4C00h
                int     21h

ntest           db      '..\v11\tdrv.asm                                  '
                db      '                                                 '
                db      0

main            endp
_TEXT		ends
                end     main
