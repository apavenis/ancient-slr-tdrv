	.286
	LOCALS
	.XList
	include LIB.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <OpenFileP> tries to open file (for input only) that is located
;   in directory where currently executed program is found.
;   At entry BX must contain offset of name of file without path
;   Procedure returns file handle in register AX.
;   Returns CF=1 when failed.
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

_FPath	  db     86 dup (' '), 0	; Buffer where to place filename

OpenFileP proc near
	push	cx
	push	dx
	push	si
	push	di
	push    es

	test	EnvStatus,PATH_FOUND ; Look whether path of current module is
	jnz	@@P1		; available. If not then try to find it.
	call	LocatePath	; Return CF=1 when unable to find this path
	jc	@@E1
@@P1:	push	cs		; Copy CS to ES
	pop	es
	mov	cx , 86h	; Max length of filename
	lea	si , _PgmPath
	lea	di , _FPath
@@1:    lodsb			; Copy path of current module to the
	or	al , al		; filename field. Don't append trailing
	jz	@@2		; zero.
	stosb
	loop    @@1
@@E1:	jmp	@@Err1
@@2:    mov	si , bx		; Offset of filename
@@3:    lodsb         		; Now append filename at the end of path
	stosb			; After that put trailing 0
	or	al , al
	jz	@@4
	loop    @@3
@@Err1:	stc			; Result too large : ERROR
	jmp     @@999
@@4:    mov	ax , 3D00h	; DOS FN 3Dh : open file
	lea	dx , _FPath	; Attrib=0 --> R/O
	int	21h
        jnc     @@999
@@999:	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	retn
OpenFileP endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure GetFName copies the full path of file last opened by
;   OpenFileP to the memory are at DS:DI. All registers remains intact.
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

GetFName proc   near
        push    cx
        push    si
        push    di
        push    es
        lea     si , _FPath
        push    ds
        pop     es
        cld
        mov     cx , 85
        rep     movsb
        mov     byte ptr es:[di] , 0
        pop     es
        pop     di
        pop     si
        pop     cx
        retn
GetFName endp

_TEXT	ends
	end
