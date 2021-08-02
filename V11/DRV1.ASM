
		locals
		.286
		.XList
		include TDRV.INC
		include ARITH.INC
		include HARDWARE.INC
		.List

_TEXT           segment byte public 'CODE'
		assume  CS:_TEXT , DS:_TEXT

;
;=============================================================================
;    INT 2Fh : subfunction 01h
;    Sets chanal commutator delay without setting new destination for coord.
;
;    Arguments:
;	AH	- multiplex process ID currently used by TDRV.EXE
;       AL = 1  - function code
;	DX:CX   - chanal commutator delay in nanoseconds
;
;=============================================================================
;
I_SetCCDelay	proc	near
		mov	ax , [bp].r_cx
		mov	dx , [bp].r_dx
		xor	bx , bx
		mov	word ptr  RO   , ax   ; Set distance to the specified
		mov	word ptr  RO+2 , dx   ; value and clear the increment
		mov     word ptr dRO   , bx   ; of distance per 0.1 second.
		mov	word ptr dRO+2 , bx
		mov	bx , fqCC	      ; Convert to the units used by
		call    IDiv42		      ; chanal commutator
		call	Set_CC_Strobe
		ret
I_SetCCDelay	endp
;
;=============================================================================
;    INT 2Fh : subfunction 02h
;    Sets coordinates where telescope must be in specified time moment.
;
;    Arguments:
;       ES:BX - pointer to structure
;               struct
;                 {
;                    unsigned  Flags;   // Flag word
;                    long      Time;    // Time in 0.1 sec. units
;                    long      X , Y;   // Coordinates in motor steps
;                    long      RO;      // Distance at that time
;                 };
;
;    The following flags are supported:
;       RESET_JCR       = 08000h  - tells thet user took the manulal
;                                   corrections previously requested from
;                                   driver into the account.
;       RESET_PREV_DEST = 04000h  - cancels previous destination before the
;                                   specified time.
;=============================================================================

I_SetDest       proc    near
		pushf                           ; Mask interrupts before copy
		cld

		cli

		;--------------------------------------------------------;
		;  DRV_STAT :        * * 0 *  * * * *  * * * *  * 0 * *  ;
		;                    ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  0.1 second       ÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  1.0 second       ÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  DRIVER_READY     ÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  Is start coord   ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ;
		;  CTRL_BREAK       ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ;
		;  Midnight found   ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ;
		;  Synchr. OK       ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ;
		;                                                        ;
		;--------------------------------------------------------;

		and     DRV_STAT  ,  Not (DRIVER_READY + CTRL_BREAK)

		;--------------------------------------------------------;
		;  DRV_STAT2 :       * * * *  1 0 0 *  * * * *  * * * *  ;
		;                    ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  INTERVAL_DONE    ÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  OUTPUT_READY     ÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  NEW_DEST_READY   ÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  DRV_WAITING      ÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  RESET_DRIVER     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ;
		;                                                        ;
		;--------------------------------------------------------;

		and     DRV_STAT2 , Not (DRV_WAITING + RESET_DRIVER)
		or      DRV_STAT2 , NEW_DEST_READY

		push    ds                      ; Save register DS
		push    ds                      ; Copy register DS to ES
		pop     es                      ; --> es:di now contains
		mov     di , Offset NewDest     ;     far ptr to 'NewDest'
		mov     si , [bp] . r_bx        ; Load source address in
		mov     ds , [bp] . r_es        ;     ds:si
		mov     cx , Size DrvRequest    ; Load length in CX
		mov     ax , word ptr [si]      ; Load flag word from new dest
                rep     movsb                   ; Copy structure
		pop     ds
		test    ax , RESET_PREV_DEST	; Look if previous dest. must
		jz	ISD_011                 ; be canceled. If so then do
		or      DRV_STAT2 , INTERVAL_DONE ; it.
ISD_011:        test	ax , RESET_JCR
		jnz	ISD_012
		lzero   ax , <NewDest._DCorrX,NewDest._DCorrY>
ISD_012:	popf                            ; Restore CPU flags
		ret
I_SetDest       endp

;=============================================================================
;
;    INT 2Fh : Subfunction AX=0C403h
;
;    Sets current coordinates of the telescope
;
;    Arguments:
;       AH      : multiplex process ID used by TDRV.EXE
;       AL      : 03h        - SubFn code
;       BX,CX   : first coordinate (CX-high word)
;       SI,DI   : second coordinate (DI-high word)
;
;    Output:
;       none
;
;    Procedure
;       - sets current coordinates.
;       - sets speed for both coordinates equal to 0
;
;=============================================================================

I_SetCoord      proc    near
		xor     cx , cx
		mov     DisableFlag , 0
                pushf
		cli
		
		mov     ax , [bp] . r_bx
		mov     dx , [bp] . r_cx
		mov     si , Offset DRV_X
		call    DC_SetCoord
		
		mov     ax , [bp] . r_si
		mov     dx , [bp] . r_di
		mov     si , Offset DRV_Y
		call    DC_SetCoord

		and	DRV_Y.DC_Options , Not DC_CorrectStp
		and	DRV_Y.DC_Options , Not DC_CorrectStp
;		test    HRDW_OPT , ENABLE_STEP_CNT
;		jnz	@@11
;		jmp	@@19
 
	@@11:	call	ReadStepCnt
		push	ax
		mov	ax , word ptr DRV_X.CurrX
		mov	dx , word ptr DRV_X.CurrX+2
		call 	rshift8
		pop	cx
		sub	cx , ax
		mov	DRV_X.CntZeroVal , cx
		mov	ax , word ptr DRV_Y.CurrX
		mov	dx , word ptr DRV_Y.CurrX+2
		call	rshift8
		sub	bx , ax
		mov	DRV_Y.CntZeroVal , bx

	@@19:   xor     ax , ax
		mov     word ptr  RO   , ax
		mov     word ptr  RO+2 , ax
		mov     word ptr dRO   , ax
		mov     word ptr dRO+2 , ax

		call	InitCard

		;--------------------------------------------------------;
		;  DRV_STAT :        * * 1 0  0 0 0 1  0 0 0 0  0 0 * *  ;
		;                    ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  0.1 second       ÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  1.0 second       ÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  DRIVER_READY     ÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  Is start coord   ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ;
		;  CTRL_BREAK       ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ;
		;  Midnight found   ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ;
		;  Synchr. OK       ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ;
		;                                                        ;
		;--------------------------------------------------------;

		and     DRV_STAT  ,  MIDNIGHT_FOUND +            \
				     SYNCHRONIZATION_OK +        \
				     TIMER_INT_DETECTED +        \
				     FULL_SECOND_DETECTED

		or      DRV_STAT ,   DRIVER_READY +              \
				     IS_START_COORD

		;--------------------------------------------------------;
		;  DRV_STAT2 :       0 0 1 0  0 0 1 0  0 0 0 0  0 0 0 0  ;
		;                    ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  PREV_DEST_OK     ÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  INTERVAL_DONE    ÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  OUTPUT_READY     ÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  NEW_DEST_READY   ÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  DRV_WAITING      ÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  RESET_DRIVER     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  FO_ENABLE        ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ;
		;                                                        ;
		;--------------------------------------------------------;

		mov     DRV_STAT2 , RESET_DRIVER + 	\
				    INTERVAL_DONE
;				    OUTPUT_READY

		;--------------------------------------------------------;
		;  Clear HOME_POS_USED flag when setting current         ;
		;  coordinates. After that it is user responsibility     ;
		;  to set this flag again when needed                    ;
		;--------------------------------------------------------;

		and 	EXT_OPT , Not HOME_POS_USED

		call	ClearCallBack

		popf
		ret
I_SetCoord      endp

;=============================================================================
;
;       INT 2Fh - subfunction 04h
;
;       Get current position and error
;
;       Arguments:
;          ES:BX  - far pointer to <CurrPos> struct where to place
;                   the result
;
;=============================================================================

I_GetPosition   proc    near
		pushf
		cli
		mov     es , [bp] . r_es
		mov     bx , [bp] . r_bx

		lcopy   es:[bx]._T0  , PREV_TIME

		lea	si , DRV_X
		mov	ax , word ptr DRV_X.CurrX
		mov	dx , word ptr DRV_X.CurrX+2
		call	DC_InvDrvCorr
		mov	word ptr es:[bx]._X0   , ax
		mov	word ptr es:[bx]._X0+2 , dx
		lcopy   es:[bx]._VX0 , DRV_X.CurrV
		lcopy   es:[bx]._RX0 , DRV_X.Residual

		lea	si , DRV_Y
		mov	ax , word ptr DRV_Y.CurrX
		mov	dx , word ptr DRV_Y.CurrX+2
		call	DC_InvDrvCorr
		mov	word ptr es:[bx]._Y0   , ax
		mov	word ptr es:[bx]._Y0+2 , dx
;		lcopy   es:[bx]._Y0  , DRV_Y.CurrX
		lcopy   es:[bx]._VY0 , DRV_Y.CurrV
		lcopy   es:[bx]._RY0 , DRV_Y.Residual

		popf
		ret
I_GetPosition   endp

;=============================================================================
;
;       INT 2Fh :  subfunction 0C405h  :  Reset TDRV.EXE
;
;       Arguments : none
;
;=============================================================================

I_ResetDriver   proc    near
		cli
		call    DisableKbdDriver
		call    ReleaseMouse
		call	DisableIRQ8
                call    nosound
		call    InitCard         ; Immediately stops tracking
		pushf
		cli

		;--------------------------------------------------------;
		;  DRV_STAT :        * * 0 0  0 0 0 0  0 0 0 0  0 0 * *  ;
		;                    ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  0.1 second       ÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  1.0 second       ÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  DRIVER_READY     ÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  Is start coord   ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ;
		;  Midnight found   ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ;
		;  Synchr. OK       ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ;
		;                                                        ;
		;--------------------------------------------------------;

		and     DRV_STAT , ( MIDNIGHT_FOUND +                   \
				     SYNCHRONIZATION_OK +               \
				     TIMER_INT_DETECTED +               \
				     FULL_SECOND_DETECTED )

		;--------------------------------------------------------;
		;  DRV_STAT2 :       0 0 0 0  0 1 1 0  0 0 0 0  0 0 0 0  ;
		;                    ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  PREV_DEST_OK     ÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  INTERVAL_DONE    ÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  OUTPUT_READY     ÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  NEW_DEST_READY   ÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  DRV_WAITING      ÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  RESET_DRIVER     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  FO_ENABLE        ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³  ;
		;  ------------     ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ;
		;                                                        ;
		;--------------------------------------------------------;

		mov     DRV_STAT2 , RESET_DRIVER + DRV_WAITING
		and 	EXT_OPT , Not HOME_POS_USED

		call	LaserDisable

		call	ClearCallBack

		popf
		ret
I_ResetDriver   endp


;=============================================================================
;    Procedure <SetCoordLimits> sets min. and max. allowed coordinates,
; that can be realised by hardware. The driver will stop telescope before
; moving outside this interval.
; INPUT:   ES:BX   - offset of the structure that contains allowed
;                    intervals for both coordinates:
;                       struct { long xMin,xMax,yMin,yMax; }
;
; RETURN CODE:  register DI
;       .... ...1 - first value greater or equal than second one
;       .... ..1. - current coordinate is outside the interval
;       .... .1.. - attempt to set interval when the speed for this coord.
;                   is not zero.
;	..XX X... - the same about the second coordinate
;
; WARNING: Procedure purges segment registers DS and ES (that is not
;          significant because of INT_2F_PROC restore all these registers)
;=============================================================================

InitCoordLimits proc    near                    ; Procedure <InitCoordLimits>
		push    di                      ; expands limits of allowed
		lea     bx , L_FULL_RANGE       ; values of coordinates
		push	cs
		pop	es
		call    SetCoordLimits          ; equal to all range of
		pop     di                      ; long int number
		ret
L_FULL_RANGE    dd      081000000h , 07F000000h
		dd	081000000h , 07F000000h
InitCoordLimits endp


SetCoordLimits  proc    near
		local   @@RetCode:word = LocBytes
		enter	LocBytes,0
		push    si
		push	di
		push	cs
		pop	ds

	; Set limits for the first coordinate and store return code
	; (lower 3 bits)

		lea     si , DRV_X
		mov	di , bx
		mov     ax , word ptr es:[di]
		mov     dx , word ptr es:[di+2]
		mov     bx , word ptr es:[di+4]
		mov     cx , word ptr es:[di+6]
		push	es
		call    DC_SetCoordInterval
		pop	es
		mov     @@RetCode , ax

	; Set limits for the second coordinate and store return code
	; (next 3 bits)

		lea     si , DRV_Y
		mov     ax , word ptr es:[di+8]
		mov     dx , word ptr es:[di+10]
		mov     bx , word ptr es:[di+12]
		mov     cx , word ptr es:[di+14]
		call    DC_SetCoordInterval
		shl     ax , 3
		or      @@RetCode , ax
		pop	di
		pop     si

	; Now we can look whether the current position is inside the
	; new interval for both coordinates and invalidate current
	; position if this is not so

		test    @@RetCode , ((2 Shl 3) Or 2)
		jz      @@Ok
		and	DRV_X.Status , Not DC_StartCoord
		and	DRV_Y.Status , Not DC_StartCoord
		and     DRV_STAT , Not IS_START_COORD

	; Copy the coordinate change limits to another location

	@@Ok:	lload   DRV_X.xMin 	; Now copy current coordinate
		lloadb  DRV_X.xMax	; limits to the configuration
		lstore  MinX
		lstoreb MaxX

		lload   DRV_Y.xMin
		lloadb	DRV_Y.xMax
		lstore	MinY
		lstoreb MaxY

		call	ClearCallBack

		mov	ax , @@RetCode
		leave
		ret
SetCoordLimits  endp

;=============================================================================
;    Procedure <I_InitializeDriver> performs initialization of TDRV.EXE.
;  this procedure is called from INSTALL.ASM while installing driver as TSR.
;  User can do this once more if he wants it.
;=============================================================================

I_InitializeDriver proc near
		call    DisableKbdDriver
		call    ReleaseMouse
		mov     si , Offset DRV_X
		call    DC_Init
		mov     si , Offset DRV_Y
		call    DC_Init
		call    InitCoordLimits
		call	LShootInit		; Disable laser shooting
		call	InitCard
		call	ClearCallBack
		mov	DRV_STAT , 0
		and 	EXT_OPT , Not HOME_POS_USED
		ret
I_InitializeDriver endp

;=============================================================================
;   Procedure:   I_InstrDefFile
;   Returns full path of instrument parameters file in register pair
;            DX:AX
;=============================================================================

I_InstrDefFile	proc	near
		test	InstrDefPath , 255
		jz	@@NoFile
		lea	ax , InstrDefPath
		mov	dx , cs
		mov	bx , InstrDefLen
		jmp	@@Ok
    @@NoFile:   xor	ax , ax
		xor	dx , dx
    @@Ok:	mov	[bp].r_ax , ax
		mov	[bp].r_dx , dx
		mov	[bp].r_bx , bx
		retn
I_InstrDefFile  endp

;=============================================================================
;   Initialization and reset of TDRV callback services. These functions
;   allows to install user event handler on some events.
;
;   Currently is still not supported !!!
;-----------------------------------------------------------------------------
;	AL = 16h	; values at API entry
;-----------------------------------------------------------------------------
;	BX = 0		; Reset callback procedure
;-----------------------------------------------------------------------------
;	BX = 1		; Set callback service
;       CX 		; Event mask for callback service
;	ES:DX		; Address of callback procedure
;=============================================================================

I_CallBack	proc	near
		or      [bp].r_flags , 1
		retn

		cmp     [bp].r_bx , 1
		ja	@@Done
		cmp	[bp].r_bx , 0
		ja      InstallCallBack
		call	ClearCallBack
		and     [bp].r_flags , 0FFFEh
	@@Done: retn
I_CallBack	endp

InstallCallBack proc	near
		mov     ax , [bp].r_cx
		mov     EventMask , ax
		mov	ax , [bp].r_dx
		mov     word ptr CallBackAddr , ax
		mov	ax , [bp].r_es
		mov	word ptr CallBackAddr+2 , ax
		and     [bp].r_flags , 0FFFEh
		retn
InstallCallBack endp

ClearCallBack	proc	near
		xor	ax , ax
		mov     EventMask , ax
		mov	word ptr CallBackAddr , ax
		mov	word ptr CallBackAddr+2 , ax
		retn
ClearCallBack	endp


;=============================================================================
;   Getting addresses of TDRV interval data to be accessed from
;   registration program. Normally this structure must be transfered
;   to the data registration program that will use it to access TDRV
;   interval data (not yet implemented)
;-----------------------------------------------------------------------------
;	AL = 08h	; values at API entry
;-----------------------------------------------------------------------------
;	ES:BX		; Address where to put data
;          ES:[BX]      	volatile unsigned short far * LasTrig
;          ES:[BX+04h]          volatile unsigned long far *  PrevTime
;	   ES:[BX+08h]          volatile unsigned long far *  CurrGate
;	   ES:[BX+0Ch]		volatile signed	  long far *  gateShift
;	   ES:[BX+10h]          volatile unsigned long far *  CurrWindow
;=============================================================================

I_GetRData      proc	near
		mov	di , [bp].r_bx
		mov     ax , [bp].r_es
		mov	es , ax
		xor	bx , bx
		cld
	@@L1:   mov	ax , @@Addr [bx]
		test	ax , 0
		jz	@@L9
		stosw
		mov	ax , cs
		stosw
		add	bx , 2
		jmp	@@L1
	@@L9:	retn

	@@Addr 	dw      LAS_TRIG
		dw	PREV_TIME
		dw	RO
		dw      gateShift
		dw      WindowWidth
		dw	0

I_GetRData	endp


_TEXT           ends
		end
