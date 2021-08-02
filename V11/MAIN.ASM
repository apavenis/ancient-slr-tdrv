		locals
		.8086           ; At first we have to be sure whether we
				; are not working on 8086. Therefore start
				; of program must bwork on 8086
		.XList
                include LIB.INC
                include TDRV.INC
		include OUTPUT.INC
		include INTVECT.INC
		include ARGLIST.INC
		.List


_TEXT		segment byte public 'CODE'
		assume	CS:_TEXT , DS:_TEXT

;*****************************************************************************
;*   Code that copies both correction tables overwritting the non resident
;*   part of program and leaves TDRV memory resident
;*****************************************************************************

FinishLoading   proc	near
		Local   CurrOutp:word  	\
			= LocBytes
		Enter	LocBytes , 0
		push    dx			; Length of code to be
						; leaved resident
		lea	di , MainPgm		; Offset of code to be
		mov	CurrOutp , di		; overwritten
		lea	bx , DRV_X
		call	MoveCorrTable
		lea	bx , DRV_Y
		call	MoveCorrTable
		pop	dx
		mov	ax , 03100h
		int	21h
FinishLoading	endp

MoveCorrTable   proc	near
		mov	bx , [bx].ErrorDef
		or	bx , bx
		jz      @@Done
		cld
		mov	cx , [bx].CoordRSize
		mov	si , [bx].CoordRTable
		push	di
		rep movsw
		pop	ax
		mov     [bx].CoordRTable , ax
	@@Done:	retn
MoveCorrTable	endp

;*****************************************************************************
;* Here the headers of correction tables for both coordinates will be placed
;*****************************************************************************

__N__           =       331776000  ; 360*3600*256
DescrX		DrvDescr <0 , 165888000 , __N__ , 2 , 0 >
DescrY		DrvDescr <0 , 165888000 , __N__ , 2 , 0 >

;
;================   Field  CmdOpt   ==========================================
;
O_OPT_FOUND	equ     8000h		; One or more options are found
O_INSTALL	equ     4000h		; Request to install the driver
O_UNINSTALL     equ	2000h		; Request to uninstall the driver
;
;=============================================================================
;
MainPgm         proc    near
		push	bp
		mov	bp , sp

		push	cs		;   Set DS equal to CS for
		pop	ds		; further use

		mov	IV_Silent , 1	; Suppress inst. messages

		;--------------------------------------------------------;
		;  Clear area (75 bytes) which will contain name         ;
		; of instrument model file. The default value INSTR.DEF  ;
		; in directory where TDRV.EXE is found will be used      ;
		; unless explicitly defined by command line option       ;
		;   /M=<model file>                                      ;
		;--------------------------------------------------------;

		mov	byte ptr InstrDefPath , 0

		;--------------------------------------------------------;

		mov     DRV_X.ErrorDef , 0		; Offset DescrX
		mov     DRV_Y.ErrorDef , 0		; Offset DescrY

		;--------------------------------------------------------;
		;  Print identification's string at the very start. This ;
		; part does not depend on CPU. Therefore string will be  ;
		; outputed on 8086 or 8088 too.                          ;
		;--------------------------------------------------------;

                mov     ax , Offset HeadLine
		push	ax
		call    PrintString

		;---------------------------------------------------------;
		;    Now look whether DOS or CPU isn't to weak.           ;
		; At least 80286 and MS DOS 3.0 or higher is necessary.   ;
		;---------------------------------------------------------;

		call    Is286		; Look is we have at least 80286
					; 	and fail if lower CPU
		.286                    ; Now we know that we can use any
					; 286 real mode commands.
		mov	ax , 031Eh	; Look if we have at least DOS 3.30
		call	DosMin		; Fail if we have older one.


                ;---------------------------------------------------------;
                ;    Look for CPU speed                                   ;
                ;---------------------------------------------------------;

                call    GetCpuSpeed     ;   Find CPU speed. This value
		add	ax , 255	; will be used to form some
		shr	ax , 8		; microseconds delays while
		mov     cpuSpeed , ax	; writting data to hardware

		;---------------------------------------------------------;
		;    Save PSP address of this instance. This address will ;
		; be necessary if this instance will stay in memory after ;
		; exit to uninstall it later.                             ;
		;---------------------------------------------------------;

		mov	ah , 62h 	; Get paragraph address of PSP
		int	21h		; and save it for later use
		mov	PspSeg , bx

		;---------------------------------------------------------;
		;    Look if there is resident instance of this telescope ;
		; control driver. If one is found TSR_PSP will contain    ;
		; segment of PSP of that instance                         ;
		;---------------------------------------------------------;

		call	DetectInstance	;   Tries to detect resident instance
		mov	TSR_PSP	, ax	; of this program. Returns paragraph
		mov	TSR_SEG , es	; address of resident instance in AX.

		;---------------------------------------------------------;
		;   Now analize the command line and detect conflicts     ;
		; between the options                                     ;
		;---------------------------------------------------------;

		push	Offset OptionsList
		call	ArgList
		mov	RC_ArgList , ax

		;---------------------------------------------------------;
		;   Now look if there are any other conflicts between     ;
		; different command line options                          ;
		;---------------------------------------------------------;

		call	CheckOptions

		test	CmdOpt , O_UNINSTALL
		jz      M_021
		jmp	UnInstall	; Remove resident instance from the
M_021:					; memory and exit


		test	CmdOpt , O_INSTALL
		jz      M_026

                ;    Look for running version of MS Windows. Don't        ;
                ; activate any sound effects if started from DOS window   ;

                mov     ax , 01600h
                int     2Fh
                cmp     al , 0
                je      @@W1
                cmp     al , 080h
                je      @@W1
                or      IsWindows , 1
                push    Offset MSWIN_MSG
                call    _PrintF
        @@W1:   call    Install         ; Set new interrupt vectors, look for
M_026:					; mouse and initialize driver

		; Here the manipulations with resident instance or (one that
		; will be resident) can be done.

		test	CmdOpt , O_INSTALL
		jz      M_031
		jmp	StayResident
M_031:

Exit1:          mov     ax , 04C03h
		int	21h
MainPgm		endp

TSR_PSP		dw	0
TSR_SEG 	dw	0

TSR_END		dw	MainPgm

CmdOpt          dw      0

SkipModel       db      0

HeadLine        db      'ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป',10
		db      'บ     Telescope control driver (Version 1.2.2  Date:',??date,')         บ',10
		db      'บ   (C) A.Pavenis, Astronomical Observatory of University of Latvia   บ',10
		db      'ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ',10
                db      0

MSWIN_MSG:      db      13,10,7
                db      'WARNING: TDRV.EXE is loaded from MS-WINDOWS ',13,10
		db      'It is recommended to do this from MS-DOS',13,10
                db      'All sound effects will be disabled',13,10
                db      7,13,10
                db      0

;
;-----------------------------------------------------------------------------
;	Descriptions of command line options
;-----------------------------------------------------------------------------

OptionsList	ArgInfo < A_Install   , ARG_NOCASE ,  3 , T_Install_A    >
		ArgInfo < A_Install   , ARG_NOCASE ,  9 , T_Install_B    >
		ArgInfo < A_UnInstall , ARG_NOCASE ,  3 , T_UnInstall_A  >
		ArgInfo < A_UnInstall , ARG_NOCASE , 11 , T_UnInstall_B  >
		ArgInfo < A_SHOWVECT  , ARG_NOCASE ,  3 , T_SHOWVECT     >
		ArgInfo < A_LISTINI   , ARG_NOCASE ,  9 , T_LISTINI      >
		ArgInfo < A_NOMODEL   , ARG_NOCASE ,  4 , T_NOMODEL      >
		ArgInfo < A_DUMPMODEL , ARG_NOCASE ,  4 , T_DUMPMODEL    >
		ArgInfo < A_CFGNAME   , ARG_NOCASE ,  7 , T_CFGNAME      >
		ArgInfo < A_MODELNAME , ARG_NOCASE ,  2 , T_MODELNAME    >
		ArgInfo < A_MODELNAME , ARG_NOCASE ,  6 , T_MODELNAME2   >
		ArgInfo < 0           , ARG_NOCASE ,  0 , 0              >

T_Install_A	db	'/I',0
T_Install_B	db	'/INSTALL',0
T_UnInstall_A	db	'/U',0
T_UnInstall_B	db	'/UNINSTALL',0
T_SHOWVECT	db	'/V',0
T_LISTINI       db      '/LISTINI',0
T_DUMPMODEL     db      '/DM',0
T_NOMODEL       db      '/NM',0
T_MODELNAME 	db	'M=',0
T_MODELNAME2 	db	'MODEL=',0
T_CFGNAME	db	'CONFIG=',0

;=============================================================================
;	This procedure will be called while processing command line if one
;  of the options '/I' or '/INSTALL' is found.
;=============================================================================
A_Install       proc	near
		or      CmdOpt , O_OPT_FOUND
		test	CmdOpt , O_UNINSTALL
		jz	AI_011
AI_Conflict1:	lea     bx , ErrMsg_01    ; Conflict ( /Install & /UnInstall )
		jmp	A_Error
AI_011:		test    TSR_PSP , 0FFFFh
		jz	AI_012
		lea	bx , ErrMsg_02
		jmp	A_Error
AI_012:         or	CmdOpt , O_INSTALL
		ret
A_Install	endp

;=============================================================================
;	This procedure will be called while processing command line if one
;  of the options '/U' or '/UNINSTALL' is found.
;=============================================================================
A_UnInstall     proc	near
		or	CmdOpt , O_OPT_FOUND
		test	CmdOpt , O_INSTALL
		jnz	AI_Conflict1
		test	TSR_PSP , 0FFFFh
                jnz     AU_011
		lea	bx , ErrMsg_03
		jmp	A_Error
AU_011:		or	CmdOpt , O_UNINSTALL
		ret
A_UnInstall	endp

A_LISTINI       proc    near
                or      IniOptions , INI_LISTALL
                ret
A_LISTINI       endp

A_SHOWVECT	proc	near
		mov	IV_Silent , 0
		retn
A_SHOWVECT      endp

A_Error		proc	near
		push    bx
		call	PrintString
		mov	ax , 4C01h
		int	21
A_Error		endp

A_NOMODEL       proc    near
                mov     SkipModel , 1
                retn
A_NOMODEL       endp

A_DUMPMODEL	proc	near
		mov	dumpModel , 1
		retn
A_DUMPMODEL	endp

A_CFGNAME	proc	near
		push	cx di es
		mov	cx , cs
		mov	es , cx
		mov	cx , 85
		lea	di , ConfigName
		cld
		rep	movsb
		mov	al , 0
		stosb
		mov	ConfigOptions , 1
		pop	es di cx
		retn
A_CFGNAME	endp

A_MODELNAME	proc	near
		push	cx di es
		mov	cx , cs
		mov	es , cx
		mov	cx , 74
		lea	di , InstrDefPath
		cld
		rep	movsb
		mov	al , 0
		stosb
		pop	es di cx
		retn
A_MODELNAME	endp

;-----------------------------------------------------------------------------
;	Check if the combination of the command line options is correct.
;   Output messages if it isn't so.
;-----------------------------------------------------------------------------

CheckOptions	proc	near
		enter	0,0

		;------------------------------------------------------;
		;   Look if there is anything we must do. If not       ;
		; then output help string.                             ;
		;------------------------------------------------------;

		test	RC_ArgList , 0FFFFh
		jnz	InvOpt

		test	CmdOpt , O_OPT_FOUND
		jz	NoActions

		leave
		ret

InvOpt:         push	RC_ArgList
		push	Offset ErrMsg_92
		call	_PrintF
		add	sp , 4
		jmp	CheckFailed

NoActions:	push    Offset ErrMsg_91
		call	PrintString
CheckFailed:    call    LocatePath
		push    Offset _PgmName
		push    Offset SyntaxDescr
		call    _PrintF
		add	sp , 4
		ExitPgm 0FDh

RC_ArgList	dw 	0
ConfigOptions	dw	0	; Non zero if config file specified in
				; command line
ConfigName	db	'TDRV.CFG'
		db	80 dup (0)

ErrMsg_01	db      'Command line must not contain options '
		db	'/Install and /Uninstall at one time',10,0

ErrMsg_02	db	'TDRV.EXE is already installed. ',10,0

ErrMsg_03 	db	'There are no resident copy of TDRV.EXE to uninstall.',10,0

ErrMsg_06	db	'Command line options /IRQ12 and /IRQ15 are valid '
		db	'only together with /Install',10,0

ErrMsg_91	db	'There are no command line options that requires '
		db	'any actions',10,0

ErrMsg_92	db	'Invalid command line option ',27h
		db	'%s',27h,' is found',10,0

SyntaxDescr     db      'Command line format: %s /opt1 /opt2 ... /optn',10
		db	'The following options are supported (letter case is not significant):',10
		db	'   /I or /INSTALL   - install this program as TSR in memory',10
		db	'   /U or /UNINSTALL - remove resident copy of this program from memory',10
		db	'   /V               - display information about manipulations on',10
		db      '                      interrupt vectors',10
                db      '   /NM              - ignore instrument model file',10
		db	'   /DM              - dump information read from instrument model in',10
		db      '                      hexadecimal format',10
		db      '   /LISTINI         - output all lines read from file TDRV.CFG',10
		db	'   MODEL=file       - use <file> as instrument model file instead of INSTR.DEF',10
		db	'   CONFIG=file      - use <file> as configuration file instead of TDRV.CFG',10
		db	'Many program options are read from file "TDRV.CFG" that must be in the same',10
		db	'directory where TDRV.EXE is found.',10
		db	10,0

CheckOptions	endp


_TEXT		ends

;*****************************************************************************
;*   Code included to generate label at the real end of TDRV.EXE code.       *
;*   <Offset EndOfPgm> is the offset of first free byte. User must take care *
;*   not to overwrite stack that is located directly below end of 64K        *
;*   area                                                                    *
;*****************************************************************************

CGROUP		GROUP   _TEXT,_TEXTZ
_TEXTZ          segment byte public 'CODE'
		public	EndOfPgm
EndOfPgm        db      0
		ends


		end
