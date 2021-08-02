	.286
	locals
	.XList
	include LIB.INC
	include TEXTFILE.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure  <OpenTextFile> tries to open text file for input.
;   File must be located in the same directory where current programm is
;   found.
;   Arguments:
;       SI  - contain offset of <TextFile> structure.
;       BX  - offset of ASCIIZ string
;   Results:
;	CF=0 - file is sucessfully opened
;       CF=1 - open is failed
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

OpenTextFileP proc near
	mov	[si].LineNo , 0		; Initialize
	call	OpenFileP
	jnc	@@Start
	mov	ax , 0FFFFh
@@Start:mov	[si].Handle , ax        ; Save handle
	mov	[si].BufPos , 0		; Set position in buffer
	mov     [si].BufEnd , 0         ; Set number of bytes currently in buf.
	mov	[si].EofFound , 0
	retn
OpenTextFileP endp


OpenTextFile proc near
	mov	[si].LineNo , 0
	push	bx dx
	mov	ax , 03D00h		; DOS Fn: Open (R/O)
	mov	dx , bx			; Offset of filename
	int	21h			; Call DOS function
	jnc	@@Start			; Exit if error
	mov	ax , 0FFFFh
@@Start:mov	[si].Handle , ax
	mov	[si].BufPos , 0
	mov	[si].BufEnd , 0
	mov	[si].EofFound , 0
	pop	dx bx
	retn
OpenTextFile endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <FGetCh> tries to read byte from text file
;   Arguments:
;	SI    - near pointer to <TextFile> structure
;   Results:
;	AL    - output byte
;       CF=1  - when EOF or ERROR
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

FGetCh  proc near
	push	bx
@@Start:mov	ax , [si].BufPos   ; Look if there is any more byte in buffer
	cmp	ax , [si].BufEnd   ; and return it when found
	jb      @@3
	test	[si].EofFound , 255
	jnz     @@Eof
	push    bx
	push	cx
	push	dx
	mov	ah , 3Fh	   ; DOS Fn 3Fh : read from file via handle
	mov	bx , [si].Handle   ; File handle
	lea	dx , [si].Buffer   ; Buffer address
	mov	cx , T_BUF_SIZE	   ; Buffer size
	int	21h		   ; Invoke DOS call
	pop	dx
	pop	cx
	pop	bx
	jnc	@@1		   ; Jump if not error
@@Err:
@@Eof:  stc			   ; EOF or ERROR : Set CF=1 and return
	jmp	@@Done
@@1:    or	ax , ax		   ; How many byte is read
	je	@@Eof		   ; 0 bytes ==> EOF
	cmp	ax , T_BUF_SIZE
	je	@@2
	or	[si].EofFound , 1
@@2:	mov     [si].BufEnd , ax   ; Save number of bytes actually read
	mov	[si].BufPos , 0	   ; Set pointer to the begin of buffer
@@3:    mov	bx , [si].BufPos
	inc	[si].BufPos
	mov	al , [si+bx].Buffer
	cmp	al , 13
	je	@@Start
	clc
@@Done: mov	ah , 0
	pop	bx
	retn
FGetCh  endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <FGetLine> tries to read line from text file
;   Arguments:
;	SI    	- near pointer to <TextFile> structure
;       BX	- pointer to buffer where to put string
;	CX	- length of buffer (including trailig 0)
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

FGetLine proc near
        local   MaxBytes:word   = LocBytes
        enter   LocBytes , 0
        mov     MaxBytes , cx
	dec	MaxBytes
	push	di
	xor     di , di
@@Read: call	FGetCh
	jc      @@Err
	cmp     al , 10		; LF ?
	je      @@Eol
	cmp	al , 13		; CR ?
	je	@@Read
	cmp     al , 1Ah	; End of file byte found ?
	je	@@EofCh
	cmp	di , MaxBytes
	jae     @@Read
	mov	[di+bx] , al
	inc	di
	jmp	@@Read
@@EofCh:mov	[si].BufEnd , 0
	mov	[si].EofFound , 1
	jmp	@@Eol
@@Err:  or	di , di
	jnz	@@Eol
	stc
	jmp	@@Done
@@Eol:  inc	[si].LineNo
	mov	byte ptr [di+bx] , 0	; Append trailing 0
	push	cx
	mov	cx , 00001h             ; Skip starting space
	call	TF_Skip			; in line
	pop	cx
	clc
@@Done: pop     di
        leave
	retn
FGetLine endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <CloseTextFile> closes text file
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

CloseTextFile proc near
	push	ax
	push	bx
	mov	ah , 3Eh        ; DOS Fn 3Eh : close a file handle
	mov     bx , [si].Handle
	int	21h
	pop	bx
	pop	ax
	retn
CloseTextFile endp

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Procedure <TF_Skip> skips data until condition is true
;   Argument:  CH - invert mask , CL - test mask
;	       BX - start of string
;   Examples:  CX=0001h - skip until not space
;	       CX=0101h - skip until space
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

TF_Skip proc	near
	push	si
	xor	ah , ah
@@1:	mov	al , [bx]		; Load byte
	or	al , al                 ; End of string reached?
	jz	@@2			; >> YES >> Quit procedure
        mov     si , ax                 ; Offset in character table
	mov	al , CharTable[si]	; Load byte from character table
	xor	al , ch
	and	al , cl
	jz	@@2
	inc	bx
	jmp	@@1
@@2:	pop	si
	retn
TF_Skip	endp

_TEXT	ends
	end
