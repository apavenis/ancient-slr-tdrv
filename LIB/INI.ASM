		.286
		.XList
		include	LIB.INC
		include OUTPUT.INC
		include TEXTFILE.INC
		.List
		locals

_TEXT		segment	byte public 'CODE'
		assume  cs:_TEXT , ds:_TEXT

		FI_PRINTED	equ     08000h

IniOptions      dw      000h

IniFile		TextFile ?
LBuffer		db	100 dup (?)
Sign		db	?
DestAddr	dw	?
ErrCol		dw	?
CurrPos		dw	?	; Current position in input line
LastPos		dw	?	; Position where marker will be placed on error

MsgAddr		dw	?
RqGName         dw      ?


LoadIniFile	proc	PASCAL NEAR
		USES 	AX,BX,CX,DX,SI,DI,ES
                ARG     groupDef        :Near Ptr,      \
			fName           :Near Ptr,	\
			Options		:Word
		LOCAL   DataAddr	:word , \
			CurrGroup	:word , \
			Flags		:word ,	\
			ErrCount	:word
		xor	ax , ax
		mov	CurrGroup , ax
		mov	Flags , ax
		mov	ErrCount , 0
		mov	bx , fName
		lea	si , IniFile
		test	Options , 0FFFFh
		jz      @@OpenP
		mov	bx , fName
		call	TrueName
		call	OpenTextFile
		jmp	@@OpenDone
   @@OpenP:     call	OpenTextFileP
   @@OpenDone:	jnc	@@100

@@E01:		push	Offset @@M01
		call	PrintString
		push	fName
		call	PrintString
		test	Options , 0FFFFh
		jnz	@@E01A
		push	Offset @@M02
		call	PrintString
		push	Offset _PgmPath
		call	PrintString
@@E01A:		push	Offset @@M03
		call	PrintString
		inc	ErrCount
		stc
		jmp	@@991

@@M01		db	'Cannot find file ',27h,0
@@M02		db	27h,' in directory ',27h,0
@@M03		db	27h,0Ah,0

@@Eof:          lea	si , IniFile
		call	CloseTextFile
		jmp     @@991

@@100:          call	PrFileInfo
@@101:		call	IL_GetLine
		jc	@@Eof
		mov     DataAddr , bx

		test	IniOptions , INI_LISTALL
		jz	@@NoList1
		mov	al , ':'
		call	PrintChar
		push	Offset LBuffer
		call	PrintString
		call	NewLine
    @@NoList1:

		test	byte ptr [bx],255 ; Bypass line if it does not
		jz	@@101		  ; contains any text.
		cmp	byte ptr [bx],'#' ; Bypass line if it contains
		je	@@101		  ; comment beginning with '#'.
		cmp     byte ptr [bx],';' ; Comment can be begin with ';' too
		je      @@101
		cmp     byte ptr [bx],'[' ; Looking if line contains group stmt.
		jne	@@E02		  ; >>> YES >>> Process it
		jmp	@@111		  ; Process group statement

@@E02:          test	CurrGroup , 0FFFFh
		jnz	@@103
                lea     ax , @@M06
		mov     bx , DataAddr
                xor     cx , cx
		call    PrErrorMsg
		inc	ErrCount
		jmp	@@101		; Read next line
@@M06:          db      'Variable assignment outside active group is ignored',0

@@103:          mov	bx , CurrGroup  ; First word in group descr. contains
		push	word ptr [bx]	; var. list
		push    DataAddr	; Push data address
		call	FindWord
		jnc     @@104
@@E03:          lea     ax , @@M07
                mov     bx , DataAddr
                mov     cx , 1
                call    PrErrorMsg
		inc	ErrCount
		jmp	@@101

@@M07           db      'Unknown variable',0

@@104:          mov	CurrPos , bx	    ; Save current position (from FindWord)
		call	ax		    ; Call procedure that processes
		jnc	@@105		    ; current line of INI file
		xor     cx , cx
		call	PrErrorMsg
		inc	ErrCount
		jmp	@@Eof
@@105:		jmp	@@101

@@111:          push    groupDef
		push	DataAddr
		call	FindWord
		jc	@@112
		mov	CurrGroup , cx
		jmp	@@101
@@112:          lea	ax , @@M11
		xor	cx , cx
		call	PrErrorMsg
		inc	ErrCount
		jmp	@@101

@@M11:		db	'Group statement contains invalid name',10,0

@@991:          test	ErrCount , 0FFFFh
		jz	@@992
		stc
		jmp	@@Done
@@992:		clc
@@Done:         ;       popa
                ;       leave
		ret

PrFileInfo:     test	Flags , FI_PRINTED
		jnz	@@PRFDone
		or	Flags , FI_PRINTED
		push	Offset @@MF1
		call	PrintString
		test	Options , 0FFFFh
		jnz     @@PRF01
		push	Offset _PgmPath
		call	PrintString
@@PRF01:	push	fName
		call	PrintString
		mov	al , 27h
		call	PrintChar
		call	NewLine
@@PRFDone:	retn
@@MF1:		db	'Reading configuration file ',27h,0

PrErrorMsg:     mov	bx , LastPos
		sub	bx , Offset LBuffer ; ERROR: compute column last
		mov	ErrCol , bx	    ;        marked and save it
		mov	MsgAddr , ax
                mov     RqGName , cx
                push    Offset @@ME1
		call	PrintString
		mov     ax , IniFile.LineNo
		call	PrintUnsigned
		push    Offset @@ME2
		call	PrintString
		push	MsgAddr
		call	PrintString
                mov     ax , RqGName
                or      ax , ax
                je      @@39
                push    Offset @@ME5
                call    PrintString
		mov     ax , CurrGroup
                add     ax , 4
                push    ax
                call    PrintString
@@39:           push    Offset @@ME3
		call	PrintString
		push	Offset LBuffer
		call	PrintString
		push	Offset @@ME4
		call	PrintString
		push	si
		lea	bx , CharTable
		lea	si , LBuffer
		inc	LastPos
@@E11:          lodsb
		or	al , al
		je	@@E13
		xlat
		test    al , IS_SPACE
		jnz	@@E11
		cmp	si , LastPos
		jne	@@E12
		mov     byte ptr [si-1] , 1Eh
		jmp	@@E11
@@E12:		mov     byte ptr [si-1] , ' '
		jmp	@@E11
@@E13:          pop	si
		push	Offset LBuffer
		call	PrintString
		call	NewLine
		retn

@@ME1           db      'Error in line ',0
@@ME2           db      ' : ',0
@@ME3           db      10,'>',0
@@ME4           db      10,' ',0
@@ME5           db      ' in group ',0

LoadIniFile	endp

;=============================================================================
;     Procedure: IL_GetLine
;=============================================================================

IL_GetLine	proc	near
		push    cx
		push	si
		mov     cx , 99      	; Read line from input file
		lea     si , IniFile	; and save address of first
		lea	bx , LBuffer	; non space character in
		call	FGetLine	; <DataAddr>
		mov	CurrPos , bx	; Save current position counter
		mov	LastPos , bx	; Set marker to the begin of line
		pop	si
		pop	cx
		retn
IL_GetLine	endp

;=============================================================================
;     Procedure: IL_GetByte
;=============================================================================

IL_GetByte	proc	near
		mov	bx , CurrPos
		mov	al , [bx]	; Get the current byte from input line
@@1:		push	bx		; Save index value in the stack
		xor	ah , ah		; Clear upper byte
		mov	bx , ax		; Index in character table
		mov	ah , CharTable[bx] ; Load value from character table
		pop	bx		; Restore index value from the stack
		cmp	al , '\'	; Continued in the following line?
		jne	@@2		;
		call	IL_GetLine      ; If so then try to read next line
		jc      @@9		; Jump is input failed.
		dec	bx		; Decrement pointer to current byte
		mov     al , ' '	; Load space
		jmp	@@1             ; and load type of this character
@@2:            cmp	al , ';'	; Comment up to the end of line
		jne	@@4		; >> No >>
@@3:		inc	bx              ; Skip data up to exd of line
		mov	al , [bx]	; And jump to start of procedure
		or	al , al
		jnz	@@3
		jmp	@@1
@@4:		or	al , al         ; Is the current byte zero?
		jz	@@5		; If not zero then increment
		inc	bx		; index
@@5:            mov	CurrPos , bx
		clc
		retn
@@9:            lea	ax , @@E1
		stc
		retn
@@E1:           db	'Continuation line not found'
IL_GetByte	endp

;=============================================================================
;     Procedure: IL_TestEol	: Scans text until end of line
;     Procedure: IL_FindNS 	: Looks for next non-space byte
;=============================================================================

IL_TestEol	proc	near
		jmp	@@1
IL_FindNS:	call    IL_GetByte	; Get byte from input
		jc	@@2		; Return if input failed
@@1:		test	ah , IS_SPACE   ; Read next byte
		jnz	IL_FindNS	; if space
		push	ax
		mov	ax , CurrPos
		mov	LastPos , ax
		pop	ax
		clc
@@2:		ret
IL_TestEol	endp

;=============================================================================
;     Procedure: IL_FindEq
;     Looks for next non-space byte and compares is with DL
;=============================================================================

IL_FindEq	proc	near
		jmp	@@1
IL_FindEq0:     cmp	al , dl
		je	@@Ok
@@1:		call	IL_FindNS
		pushf
		mov	bx , CurrPos
		mov	LastPos , bx
		popf
		jc	@@Done		; Jump is error reading byte
@@2:		mov	bx , CurrPos
		mov	LastPos , bx
		cmp	al , dl
		je      @@Ok
		lea	ax , @@E1
		mov	byte ptr @@E1+1 , dl
		stc
		jmp	@@Done
@@Ok:           clc
@@Done:		retn
@@E1		db      27h,20h,27h,' expected',0
IL_FindEq	endp

;=============================================================================
;     Procedure: IL_GetDigit
;  Condition	Error	Digit	Other
;     ZF	  ?       0       1
;     CF          1       0       0
;=============================================================================

IL_GetDigit	proc	near
		call	IL_GetByte	; Get byte
		jc	@@2		; Exit with CF=1 when error
		test	ah , IS_DIGIT	; Look if byte is decimal digit
		jz	@@1		; Exit with ZF=1 CF=0 when not
		pushf			; Save flags and
		and	al , 0Fh	; keep lower 4 bits only
		popf			; Restore flags
@@1:		clc			;
@@2:		retn
IL_GetDigit	endp

;=============================================================================
;     Procedure: IL_GetSign
;     Sets sign and reads the first digit from input stream
;=============================================================================

IL_GetSign	proc	near
		mov	Sign , 0	; Clear sign byte
@@1:		call	IL_GetDigit	; Get byte from input stream
		jc	@@Done		; Jump if error
		jnz	@@Done		; Jump if decimal digit
		cmp     al , '+'	; '+' : Ignore byte and read
		je	@@Plus		;	the next one
		cmp	al , '-'	; '-' : Set sign byte and read
		je	@@Minus		;       next byte from input
		test	ah , IS_SPACE	; If space then skip it
		jnz	@@1
		lea     ax , @@E1       ;
		stc
		retn
@@Minus:        mov	Sign , 1
@@Plus:         call	IL_GetDigit
@@Done:		retn
@@E1:		db	'Number expected ',0
IL_GetSign	endp

;=============================================================================
;     Procedure: IL_GetLong
;     Input:     BX - first byte address
;=============================================================================

IL_GetLong	proc	near
		local   Result	:dword	,  \
			CurrDig :word      \
			= LocBytes
		enter	LocBytes , 0
		mov	word ptr Result   , 0	; At first clear result
		mov	word ptr Result+2 , 0	; field
		call	IL_GetSign
		jmp     @@2
@@1:		call	IL_GetDigit
@@2:		jc	@@E2			; Jump if error
		jz      @@5			; Jump if not digit
@@3:		xor	ah , ah               	; Save current digit
		mov	CurrDig , ax
		push	cx			; Save register CX
		mov	cx , 10
		mov	ax , word ptr Result	; Now process the digit
		mul	cx			; and look whether overflow
		mov     word ptr Result   , ax	; is not occured.
		mov	ax , dx
		xchg	word ptr Result+2 , ax
		mul	cx
		pop	cx			; Restore CX
		add	word ptr Result+2 , ax  ;
		adc	dx , 0
		mov	ax , CurrDig            ; Add digit
		add	word ptr Result   , ax
		adc	word ptr Result+2 , 0
		adc	dx , 0                  ; 3-th word not zero: OVERFLOW
		jnz	@@E1
		test	byte ptr Result+3 , 128	; if 2-nd word is correct then
		jz	@@1			; try to read next digit.
@@E1:           lea	ax , @@M1
		stc
@@E2:           push	ax
		mov	ax , CurrPos
		mov	LastPos , ax
		pop	ax
		jmp     @@Done
@@5:            mov     cx , word ptr Result
		mov	dx , word ptr Result+2
		test    Sign , 255
		jz	@@6
		not     cx
		not     dx
		add     cx , 1
		adc     dx , 0
@@6:		clc
@@Done:		leave
		retn
@@M1:           db	'Overflow while reading long integer number',0
IL_GetLong	endp

;=============================================================================
;     Procedure: IL_IsInt
;     Input:     {CX,DX} - long integer number to be tested
;		           (result of IL_GetLong)
;     Output:    CF=0 - number <=32767 and >=-32767
;	         CF=1 - number >32767 or <-32767
;=============================================================================

IL_IsInt	proc	near
		or	dx , dx
		jl	@@Negative
		jne	@@Failed
		or	cx , cx
		jl	@@Failed
@@Ok:           clc
@@Done:		ret
@@Negative:     cmp	dx , 0FFFFh
		jne	@@Failed
		or	cx , cx
		cmp	cx , 08000h
		ja      @@Ok
@@Failed:	stc
		lea     ax , @@M1
		jmp	@@Done
@@M1:		db	'Integer number out of range [-32767...32767]',0
IL_IsInt	endp

;=============================================================================
;     Procedure: IL_GetIntArray
;     Input:     BX - first byte address
;		 CX - array size
;		 DX - address where to put results
;=============================================================================

IL_GetIntArray	proc	near
		local   arraySize	:word	, \
			arrayAddr	:word	, \
			Count		:word	, \
			RdProc		:word     \
			= LocBytes
		enter   LocBytes , 0
		mov     RdProc , Offset @@RdInt
		jmp	@@Start
IL_GetLongArray:enter	LocBytes , 0
		mov	RdProc , Offset @@RdLong
@@Start:	push	si
		mov	arraySize , cx
		mov	arrayAddr , dx
		mov	Count , cx

		mov	si , dx
		mov	dl , '='	; At first look for '='
		call	IL_FindEq	; Exit with error if not found
		jc      @@1
		mov	dl , '{'	; After that look for '{'
		call	IL_FindEq	; Exit with error if not found
		jc      @@1
		jnc	@@3
@@1:		jmp     @@Done
@@2:            mov	Count , cx
		mov	dl , ','	; If not the first element of array
		call    IL_FindEq0	; then look for ',' at first
		jc	@@1
@@3:		call	word ptr RdProc
		jc	@@Done
		mov	cx , Count
		loop	@@2
		mov     dl , '}'
		call	IL_FindEq0
		jc	@@Done
		call	IL_GetByte
		jc      @@Done
		call	IL_TestEol
		jc	@@Done
		or	al , al
		je	@@Ok
@@Failed:       stc
		lea     ax , @@M1
		jmp	@@Done
@@Ok:		clc
@@Done:		pop	si
		leave
		retn

@@RdLong:       call    IL_GetLong	; Get long number in {CX,DX}
		jc      @@11		; Return when error detected
		mov     [si  ] , cx	; Save value that is read
		mov	[si+2] , dx
		add	si , 4		; Increment output pointer
		clc
@@11:		retn

@@RdInt:	call	IL_GetLong	; Get long number in {CX,DX}
		jc      @@11		; Return when error detected
		call	IL_IsInt	; Check is number is in range
		jc	@@11		; -32767...32767 and return if not
		mov	[si  ] , cx
		add	si , 2
		clc
		retn

@@M1		db	'Unexpected data after ',27h,'}',27h,0
IL_GetIntArray	endp

;=============================================================================
;     Procedure: IL_ReadLongVar
;     Input:     BX - first byte address
;     Output:	 CF=0 , {AX,DX} - the number, when OK
;		 CF=1 , AX - pointer to error message when error
;=============================================================================

IL_ReadLongVar	proc	near
		push	cx
		mov	dl , '=' 	; At first look for '=' and skip it
		call	IL_FindEq	; Error message if no '=' is
		jc	@@Done		;   found or input error
		call	IL_GetLong	; Get number in CX,DX
		jc	@@Done		; Error exit if any error
		call	IL_TestEol	; Scan line until very end
		jc	@@Done		; Exit on error
		or	al , al		; Look if there is any illegal non
		jz	@@Ok		; space character after number
@@E1:           lea     ax , MSG1
		stc
		jmp	@@Done
@@Ok:           mov	ax , cx
		clc
@@Done:         pop	cx
		retn
IL_ReadLongVar	endp

;=============================================================================
;     Procedure: IL_ReadIntVar
;     Input:     BX - first byte address
;     Output:    CF=0 , AX - the number, when OK
;		 CF=1 , AX - pointer to error message when error
;=============================================================================

IL_ReadIntVar   proc    near
		push	cx
                push    dx
		mov	dl , '=' 	; At first look for '=' and skip it
		call	IL_FindEq	; Error message if no '=' is
		jc	@@Done		;   found or input error
		call	IL_GetLong	; Get number in CX,DX
		jc	@@Done		; Error exit if any error
                call    IL_IsInt
                jc      @@Done
		call	IL_TestEol	; Scan line until very end
		jc	@@Done		; Exit on error
		or	al , al		; Look if there is any illegal non
		jz	@@Ok		; space character after number
@@E1:           lea     ax , MSG1
		stc
		jmp	@@Done
@@Ok:           mov	ax , cx
		clc
@@Done:         pop     dx
                pop     cx
		retn
IL_ReadIntVar   endp

MSG1            db      'Unexpected data after number',0

_TEXT		ends
		end
