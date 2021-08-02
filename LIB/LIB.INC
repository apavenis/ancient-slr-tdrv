

        ;-------------------------------------------------------------;
        ;  Reads time (lower word of BIOS timer and 8253/4 chanal 0   ;
        ;  counter in AX,DX) as unsigned long number. This procedure  ;
	;  provides time interval of about 1 hour without overflow    ;
        ;  (The frequency is 1193180 Hz)                              ;
        ;-------------------------------------------------------------;

        global  GetTime0        :near   ; RDTIME.ASM

        ;-------------------------------------------------------------;
        ;  Performs system compatibility tests                        ;
        ;-------------------------------------------------------------;

	global	DetectCPU 	:near	; WHICHCPU.ASM

        global  Is286           :near   ; IS286.ASM
        global  Is386           :near   ; IS386.ASM

        global  DosMin          :near   ; DOSMIN.ASM

	;-------------------------------------------------------------;
	;  Description of ASCII codes                                 ;
	;-------------------------------------------------------------;

	global	CharTable	:byte 	; CHARTBL.ASM

		IS_SPACE	equ	001h
		IS_PUNCT	equ	002h
		IS_EQ		equ	004h	; '='
		IS_DIGIT	equ	008h
		IS_HEXDIG	equ	010h
		IS_ALPHA	equ	020h
		IS_COMMA	equ	040h
		IS_EOL		equ	080h

	;------------------------------------------------------------;
	;  Copy zero terminated ASCII string                         ;
	;------------------------------------------------------------;

	global	CopyAsciiZ	: near	; STRCPY.ASM

;----------------------------------------------------------------------------;
;  Some manipulations with environment area  : GETENV.ASM                    ;
;----------------------------------------------------------------------------;

		ENV_RELEASED	equ	08000h
		PATH_FOUND	equ	04000h
		PATH_ERROR	equ	02000h

	global	EnvStatus	:word
	global _PgmPath		:byte:86
	global _PgmName		:byte:13

	global	GetEnvSeg	:near	; GETENV.ASM
	global	FreeEnvSeg	:near	; GETENV.ASM
	global	LocatePath	:near	; GETENV.ASM

;----------------------------------------------------------------------------;
;  Open file in directory where current program is found                     ;
;----------------------------------------------------------------------------;

	global	OpenFileP	:near
        global  GetFName        :near

;----------------------------------------------------------------------------;
;  Search for name in list : FINDWORD.ASM                                    ;
;----------------------------------------------------------------------------;

WInfo   	macro	w1 , w2 , text
		dw	w1		; first data word
		dw	w2		; second data word
		db	text		; zero terminated string
		db	0
		endm

	global	FindWord	:near	; long FindWord (char * , WInfo *)

;----------------------------------------------------------------------------
;   Load INI file : INI.ASM
;----------------------------------------------------------------------------

	global	IniOptions	:word

		INI_LISTALL	equ	08000h

	global	LoadIniFile	:near

	global	IL_GetLine	:near
	global	IL_GetByte	:near
	global	IL_TestEol	:near
	global	IL_FindNS	:near
	global	IL_FindEq	:near
	global	IL_FindEq0	:near
	global	IL_GetDigit	:near
	global	IL_GetSign	:near
	global	IL_GetLong	:near
	global	IL_IsInt	:near
	global  IL_GetIntArray	:near
	global	IL_GetLongArray :near
	global	IL_ReadLongVar	:near
        global  IL_ReadIntVar   :near

;----------------------------------------------------------------------------
;   Allocate UMB block : ALLOCUMB.ASM
;----------------------------------------------------------------------------

	global	_AllocUMB	:near
	global	_GetMaxUMBSize	:near

;----------------------------------------------------------------------------
;   Debugging tools
;----------------------------------------------------------------------------

        global  Pause           :near

;----------------------------------------------------------------------------
;   TrueName - returns filename in cannonical form
;----------------------------------------------------------------------------

        global  TrueName        :near   ; DS:BX filename to be processed

;--------------------<<<  FILEUTIL.ASM  >>>----------------------------------
;   _tell - returns current position in file
;   _seek - sets new position in file
;----------------------------------------------------------------------------

	global	_tell		:near
	global	_seek		:near

;--------------------<<<  MEMDUMP.ASM  >>>-----------------------------------
;   MemDump ( unsigned offset , unsigned len )
;----------------------------------------------------------------------------

	global	MemDump 	:near