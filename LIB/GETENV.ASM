.286
LOCALS
.XList
include LIB.INC
.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

EnvStatus dw	0
_PgmPath  db    86 dup (' '), 0
_PgmName  db    13 dup (' '), 0

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <GetEnvSeg> loads register ES with segment address of current
;   environment. All other registers remains unchanged.
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

GetEnvSeg proc near
	push	ax
	push	bx
	test	EnvStatus , ENV_RELEASED
	jnz	@@1
	mov	ah , 062h	; DOS function 62h : Get segment of
	int	21h		; current PSP in register BX
	mov	es , bx		; and copy it to ES.
	mov	es , es:[002Ch] ; Load address of current environment in ES
	clc
	jmp	short @@2
@@1:	stc
@@2:	pop	bx		; and return.
	pop	ax              ; WARNING: be sure that ENV block is not
	retn			; freed with DOS FN 49h!!!
GetEnvSeg endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <FreeEnvSeg> releases current environment. This function
;   can be called before staying resident. No registers are changed.
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

FreeEnvSeg proc	near
	push	ax
	push	es
	call    GetEnvSeg	; Get environment segment in ES
	jc	@@1
	mov	ah , 49h	; DOS FN 49h : release memory
	int	21h
	or      EnvStatus , ENV_RELEASED
@@1:	pop	es
	pop	ax
	retn
FreeEnvSeg endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <LocatePath> stores path where current module is found
;   into string <PgmPath>. Program name
;   Returns CF=1 if failed.
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

LocatePath proc	near
	pusha
	push	ds
	push	es
	clc
	test	EnvStatus , PATH_FOUND
	jnz	@@0
	call	GetEnvSeg	; Get segment of current environment
	jnc	@@1             ; When environment is released then return
@@0:	jmp	@@999		; with CF=1
@@1:    xor	al , al		; We'll looking for 0
	xor	di , di		; Initial offset is 0
	cld			; Increment mode for scasb
	mov	cx , 0FFFFh
@@2:	repne	scasb		; Find first zero byte
	scasb     		; Is the last environment string skipped?
	jnz	@@2		; If not then skip the next one
	mov	ax , es		; Now swap registers ES and DS to perform
	mov	bx , ds		; copying full pathname of current program
	mov	es , bx
	mov	ds , ax
	lea	si , [di+2]	; Source offset (and bypass string count)
	lea	di , _PgmPath    ; Destination offset
	mov	cx , 86		; Max. allowed length
	call	CopyAsciiZ	; Copy string
	jc	@@Err1
	xor	bx , bx
        mov     cx , 14
@@11:	dec	di
	cmp     byte ptr es:[di] , '\'
	je	@@12
	loop	@@11
	jmp	@@Err1
@@12:   mov	cx , 13
	xor	ah , ah
@@14:   inc	di
	mov	al , es:[di]
	mov	es:[di] , ah
	mov     es:_PgmName[bx] , al
	inc	bx
	or	al , al
	jnz	@@14
	jmp	@@Ok
@@Err1: stc
	jmp	@@999
@@Ok:   clc
        or      es:EnvStatus , PATH_FOUND
@@999:	pop	es
	pop	ds
	popa
	retn
LocatePath endp


_TEXT	ends
	end
