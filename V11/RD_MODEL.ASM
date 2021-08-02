		locals
		.286

		.XList
		include LIB.INC
		include TDRV.INC
		include ARITH.INC
		include MACROS.INC
		include OUTPUT.INC
		include INTVECT.INC
		include HARDWARE.INC
		.List

_TEXT		Segment byte public 'CODE'
		Assume	CS:_TEXT , DS:_TEXT

;==================  Constants  =============================================

HdrLen		= CoordRTable-CoordRStart	; Length of the header of
						; corrections table

;============================================================================
;  Procedure:  ReadInstrModel  - reads instrument model file (new style)
;----------------------------------------------------------------------------
;
;  Arguments:  BX - near address of filename
;	       User must provide at least 87 bytes for argument
;
;============================================================================

ReadInstrModel  PROC	NEAR
		LOCAL   @@FnAddr    :word,   \ ;Address of filename (will be normalized
			@@CIndex    :word,   \ ;0 for 1-st. coord, 1- for 2-nd
			@@CTLoc     :word,   \
			@@ErrCnt    :word,   \
			@@Flags     :word,   \
			@@MaxSize   :word,   \
			@@OutpAddr  :word    \
			= LocBytes

		ENTER   LocBytes , 0

		mov	@@ErrCnt , 0
		mov	@@Flags , 0

		mov	ax , sp			; Check if there is enough
		sub	ax , 00400h		; memory for loading
		push	ax			; instrument model file.
		sub	ax , 00100h
		cmp	ax , Offset EndOfPgm
		pop	ax
		ja      @@001
		push	Offset @@LowMem
		call	_PrintF
		pop	ax

       @@001:					; Find max allowed size of
		sub	ax , Offset EndOfPgm	; corrections table
		shr	ax , 1			; (depends on amount of
		mov	@@MaxSize , ax		; free space in pgm. segment)
		mov	ax , Offset EndOfPgm
		mov	@@OutpAddr , ax

		cmp     word ptr [bx] , 0
		jne	@@IsName

		or	@@Flags , 1
		call	LocatePath	; Find path where TDRV is found
					;  path ==> _PgmPath
					;  name ==> _PgmName
		jnc     @@PathFound
		jmp     @@099		; If path cannot be found exit with
					; error

	;-----------------------------------------------------------;
	;  Generation of the name of instrument model file if one   ;
	;  is not defined explicitly.                               ;
	;-----------------------------------------------------------;

    @@PathFound:push	es		; Save registers to restore it later
		push	di
		push	si
		push	ds		; Copy segment register DS to
		pop	es		;         ES
		cld
		lea     si , _PgmPath	; Copy path where TDRV is found
		mov	di , bx		; (without filename, but with
    @@006:	lodsb			; backslash in the end) to filename
		stosb			; buffer
		or	al , al
		jne	@@006
		dec	di		; Append default name of instrument
		lea     si,DefModelFile	; model file : 'INSTR.DEF' at the
    @@007:	lodsb			; end of path to generate full
		stosb			; path of instrument model file
		or	al , al
		jne	@@007
		pop	si  		; Restore registers after generation
		pop	di              ; of the name of instrument model
		pop	es		; file

    @@IsName:                           ; Now the name is OK

	;-----------------------------------------------------------;
	;   At first convert filename to cannonical form. After     ;
	; that we'll be able to found if current directory will be  ;
	; changed                                                   ;
	;-----------------------------------------------------------;

		mov	@@FnAddr , bx	   ; Save name of model file
		call	TrueName           ; Convert filename to canonic form

	;-----------------------------------------------------------;
	;   Now we try to open instrument model file. Exit          ;
	; immediatelly if file is not opened                        ;
	;-----------------------------------------------------------;

		mov	dx , @@FnAddr
		mov	ax , 03D00h        ; DOS function: open file
		int	21h		   ;       mode 0: read/only
		jnc	@@OpenOk
		test	@@Flags , 1
		jnz	@@E11
		push	@@FnAddr
		push	Offset @@OpenErr
		call	_PrintF
		add	sp , 4
    @@E11:	jmp	@@099		   ; Exit immediatelly if error

	;-----------------------------------------------------------;
	;   File is sucessfully opened. Now try to read first 4     ;
	; bytes. For new style model these bytes must be 'IDEF'     ;
	;-----------------------------------------------------------;

    @@OpenOk:   mov	bx , ax		   ; Put handle for instrument model
		push	bx		   ; file in register BX, push it
					   ; into stack for a while
		push	@@FnAddr	   ; Output message that instrument
		push    Offset @@MReadFmt  ; model file is being read
		call	_PrintF
		add	sp , 4

		pop	bx		   ; Retrieve file handle back from
					   ; the stack
		mov	mHandle , bx	   ; Save file handle for later use
		mov	cx , 4             ; Read first 4 bytes
		lea	dx , @@DBuf        ; These bytes must be C9 C4 C5 C6
		mov	ah , 03Fh          ; for new style model
		int	21h
		jnc	@@012		   ; Jump if no read error
    @@011:      inc	@@ErrCnt
		jmp	@@051
    @@012:      cmp	ax , 4		   ; Is really 4 bytes read. If not
		jne	@@011		   ; then exit
		cmp	word ptr @@DBuf   , 0C4C9h
		jne	@@Old01
		cmp	word ptr @@DBuf+2 , 0C6C5h
		je      @@ReadNew
    @@Old01:    xor	cx , cx
		xor	dx , dx
		mov	ax , 04200h	   ; DOS FN: Seek (from begin of file)
		int	21h
		jc	@@011		   ; Exit if error
		jmp	ReadOld

    @@ReadNew:  mov	dx , 248	   ; Now skip first 248 bytes. User
		xor	cx , cx		   ; can put any information in bytes
		mov	ax , 04200h	   ;  04h...F7h
		int	21h
    @@021:	jc	@@011

	;------------------------------------------------------------;
	;    Read hysteresis width for both coordinates              ;
	;    (Offset 0F8h-0FFh)                                      ;
	;------------------------------------------------------------;

LoadHW:		mov	ah , 03Fh	; DOS FN: read data from file
		mov	cx , 8		; Data length is 8 bytes
		lea	dx , hwx	; Where to put data
		int	21h
		jc	@@021		; Exit if error
		mov	ax , word ptr hwx
		or	ax , word ptr hwx+2
		or	ax , word ptr hwy
		or	ax , word ptr hwy+2
		jz	@@022
		call	SetHW
    @@022:

	;------------------------------------------------------------;
	;    Now read both tables                                    ;
	;------------------------------------------------------------;

		mov	@@CIndex , 0
		mov     InstrDefLen , 256

LoadTable:      mov	ah , 03Fh	; DOS Fn: read data from file
		mov	cx , HdrLen	; Length of data = length of header
		lea	dx , DescrX     ; Dest. address is if CIndex is 0
		cmp	@@CIndex , 0	; then DescrX else DescrY
		je	@@026
		lea	dx , DescrY
    @@026:	mov	si , dx         ; Save address of curr. DrvDescr struct
		int	21h		; Load header
		jc	@@021		; Error exit
		cmp	ax , HdrLen	; Is all bytes read? If not then exit
		jne	@@021

		test	dumpModel , 255
		jz      @@D1
		push	Offset @@MHeader
		call    _PrintF
		mov	cx , HdrLen
		push    cx
		push    si
		call	MemDump
    @@D1:

		add	InstrDefLen , HdrLen ; Add length of header to the
					; position
		push	cx		; Now convert first 3 fields in header
		push	bx		; to internal units. File contains
		mov	cx , 3		; values in motor steps. We must
		xor	bx , bx		; shift these values 8 bits left.
    @@027:      lload   [bx+si]
		call	lshift8
		lstore	[bx+si]
		add	bx , 4
		loop	@@027
		pop	bx
		pop	cx

		mov	al , byte ptr [si].CoordRStep+3
		or	al , byte ptr [si].CoordRPeriod+3
		test 	al , 128
		jnz     @@028
		mov	ax , word ptr [si].CoordRSize
		cmp	ax , 0
		jbe	@@028
		cmp	ax , @@MaxSize
		jbe	@@031
		jmp     @@030

    @@028:	jne	@@029
		jmp	@@042
    @@029:	Message 'ERROR: Invalid data in instrument model file'
		jmp	@@097

    @@030:	push	Offset @@MTooLarge
		call	_PrintF
		pop	ax
		jmp	@@097

    @@031:      mov	cx , [si].CoordRSize ; Load size of table
		sub	@@MaxSize , cx
		shl     cx , 1               ; Convert size from words to bytes
		push	cx
		mov	dx , @@OutpAddr      ; Address where to load data
		mov	[si].CoordRTable,dx  ; Save address of table
		mov	ah , 03Fh	     ; DOS Fn. 3Fh - read data
		int	21h		     ; from file
		pop	cx		     ; Restore length from stack
		jc	@@035		     ; Exit if error is occured
		cmp	ax , cx		     ; Look if all bytes is read
		je	@@036		     ; and exit if less
    @@035:	jmp	@@011

    @@036:	test	dumpModel , 255
		jz	@@D2
		push	Offset @@MData
		call    _PrintF
		pop	ax
		push    cx
		push    word ptr [si].CoordRTable
		call	MemDump
    @@D2:
		add	@@OutpAddr , cx
		add     TSR_END , cx         ; Advance near pointer to the
					     ; end of resident part of TDRV
		add	InstrDefLen , cx     ; Advance current pos. pointer
					     ; in file
		push	di
		lea     di , DRV_X	     ; Save pointer to model table
		cmp	@@CIndex , 0	     ; for current coordinate into
		je	@@041                ; corresponding structure used
		lea	di , DRV_Y	     ; for tracking.
    @@041:	mov	[di].ErrorDef , si
		test	dumpModel , 255
		jz      @@D4
		push	di
		mov	ax , ds
		push    ax
		push	Offset @@TPTR
		call	_PrintF
		add	sp , 6
    @@D4:	pop	di

    @@042:	inc	@@CIndex
		cmp	@@CIndex , 1
		ja	@@046
		jmp	LoadTable

    @@046:      cmp	InstrType , 0		; If InstrType is not specified
		je	@@051			; in section [Main] then skip
						; the check
		mov	ah , 03Fh
		mov	cx , 2
		lea	dx , @@DBuf
		int	21h
		jc	@@050
		cmp	ax , 2
		jne	@@050
		test	dumpModel , 255
		jz	@@D3
		push	Offset @@MSignature
		call	_PrintF
		pop	ax
		push	2
		push	Offset @@DBuf
		call	MemDump
    @@D3:	mov	ax , word ptr @@DBuf
		cmp	ax , InstrType
		je	@@051
		push	Offset @@MConflict
		call	_PrintF
		add	sp , 2
		jmp	@@052
    @@050:      inc     @@ErrCnt
    @@051:      mov	ah , 03Eh
		int	21h

		push	si
		mov	si , DRV_X.ErrorDef
		call	CheckCoordTable
		jc	@@061
		mov	si , DRV_Y.ErrorDef
		call	CheckCoordTable
		jnc	@@065
    @@061:      push	Offset @@InvTable
		call 	_PrintF
		add	sp , 2
		or	@@ErrCnt , 1
    @@065:	cmp	@@ErrCnt , 0
		je	@@056
		push	Offset @@MReadErr
		call	_PrintF
		add	sp , 2
    @@052:	push	di
		mov     DRV_X.ErrorDef , 0
		mov	DRV_Y.ErrorDef , 0
		mov	TSR_END , Offset EndOfPgm        ; Offset CoordDescr0
		mov	di , @@FnAddr
		mov	byte ptr [di] , 0

		pop	di
		jmp 	@@097
    @@056:	jmp	@@098

    @@097:   	stc
		jmp short @@099
    @@098:    	clc
    @@099:	LEAVE
		RET

	;------------------------------------------------------------;
	;   Attempt to load old style instrument model               ;
	;------------------------------------------------------------;

ReadOld:        push	bx
		push	Offset @@MReadOld
		call	_PrintF
		add	sp , 2
		pop	bx
		mov	InstrDefLen , 0		; Set length of tables to 0
		mov	cx , DescrX.CoordRSize	; Get length of table for X
		or	cx , cx			; Is this length zero
		jz	@@116			; If Yes then skip loading

		shl	cx , 1                  ; Convert length to bytes
		push	cx
		mov	dx , @@OutpAddr         ; Where to load
		mov     DescrX.CoordRTable , dx ; Save table address in struct.
		mov	ah , 03Fh		; DOS Fn code: read data
		int	21h			;
		pop	cx
		jnc	@@112			; Read OK ==> cntinue
    @@111:      inc	@@ErrCnt
		jmp	@@051                   ; Read failed ==> exit with msg
    @@112:      cmp	ax , cx			; Is all bytes read. If not
		jne	@@111			; then exit with message
		add	TSR_END , cx
		add	@@OutpAddr , cx
		add	InstrDefLen , cx
		mov     DRV_X.ErrorDef , Offset DescrX

    @@116:	mov	cx , DescrY.CoordRSize
		or	cx , cx
		jz	@@121

		shl	cx , 1
		push	cx
		mov	dx , @@OutpAddr
		mov	DescrY.CoordRTable , dx
		mov	ah , 03Fh
		int	21h
		pop	cx
		jnc	@@118			; Read OK ==> cntinue
    @@117:      inc     @@ErrCnt
		jmp	@@051                   ; Read failed ==> exit with msg
    @@118:      cmp	ax , cx			; Is all bytes read. If not
		jne	@@117			; then exit with message
		add	TSR_END , cx
		add	@@OutpAddr , cx
		add	InstrDefLen , cx
		mov     DRV_Y.ErrorDef , Offset DescrY
    @@121:      jmp	@@051

@@DBuf      	dd	0		; Temporary storage
DefModelFile	db	'INSTR.DEF',0
@@MReadFmt	db	'Reading instrument parameters file ',27h
		db	'%s',27h,13,10,0
@@MReadOld	db	'WARNING: old style instrument model file is '
		db      'being used.',13,10
		db      '         This possibility may be not supported '
		db      'in future versions',13,10
		db	0
@@MConflict	db	'ERROR: Instrument ID specified in TDRV.CFG conflicts '
		db	'with one specified ',13,10
		db	'in instrument model file. Instrument model '
		db	'is ignored',13,10
		db	7,0
@@MReadErr	db	'An error was occured while reading instrument '
		db	'model file',13,10
		db	'Instrument model file is ignored',7,13,10
		db	0
@@InvTable	db	'INSTR.DEF contains invalid correction table for '
		db	'one or both coordinates',13,10
		db      0
@@MHeader 	db	'Reading header of coordinate table:',0
@@MData 	db	'Reading corrections table:',0
@@MSignature	db	'Reading model signature word:',0
@@OpenErr       db	'Cannot open instrument model file "%s"',13,10,0
@@TPTR		db	'Offset of corrections table header stored in '
		db      'structure at %04X:%04X',13,10,0
@@MTooLarge     db	'ERROR: Unable to load instrument model file:',13,10
		db	'       There are not enough space to to load '
		db              'correction tables from',13,10
		db      '       from instrument model file',13,10,0
@@LowMem	db	'ERROR: Memory block is too small. Instrument model'
		db	'cannot be loaded',13,10,0
ReadInstrModel	ENDP

;===========================================================================
;	Checks corrections table for one coordinate:
;---------------------------------------------------------------------------
;   SI  - offset of table header
;---------------------------------------------------------------------------
;   Returns CF=0 if OK
;---------------------------------------------------------------------------

CheckCoordTable PROC	NEAR
		push	cx
		push	di
		or	ax , ax
		jz	@@14
		mov	cx , [si].CoordRSize
		mov     di , [si].CoordRTable
		cmp	cx , 1
		jbe	@@14
       @@11:    dec	cx
       @@12:    mov	ax , cs:[di+2]
		sub	ax , cs:[di]
		jge	@@13
		neg	ax
       @@13:	cmp	ax , 0200h
		ja	@@F1
		add	di , 2
		loop	@@12
       @@14:	clc
		jnc	@@Done
       @@F1:	stc
       @@Done:	pop	di
		pop	cx
		retn
CheckCoordTable	ENDP


SetHW		proc	near
		push	bx
		lea	bx , @@Lim

		mov	ax , word ptr hwx
		mov	dx , word ptr hwx+2
		call	IsInside
		jc	@@1
		mov	word ptr HistWX   , ax
		mov	word ptr HistWX+2 , dx

	@@1:	mov	ax , word ptr hwy
		mov	dx , word ptr hwy+2
		call	IsInside
		jc	@@2
		mov	word ptr HistWY   , ax
		mov	word ptr HistWY+2 , dx

	@@2:	pop	bx
		retn

@@Lim		dd	100,131071

SetHW		endp


mHandle    	dw	-1
dumpModel	db	0
hwx		dd	0
hwy		dd	0

_TEXT		ENDS
		END
