        LOCALS
        .XList
	include LIB.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <CopyAsciiZ> copies zero terminated string from DS:SI to
;   ES:DI. Not more then CX-1 bytes will be copied. Returns CF=1 if string
;   is truncated.
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

CopyAsciiZ proc near
	dec     cx
	cld
@@1:	lodsb     		; Load byte
	stosb			; Store it in resulting string
	or	al , al		; Zero found ?
	jz	@@2		; If found then exit with CF=0
	loop	@@1		; Process next byte
	xor	al , al		; Source is too long:
	stosb			;  -- put zero byte in dest. string
	stc 			;  -- set CF=1 and return
	retn			;
@@2:    clc 			; All OK:
	retn			;  -- set CF=0 and return
CopyAsciiZ endp

_TEXT	ends
	end
