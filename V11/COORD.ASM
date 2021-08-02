		locals
		.286
		.XList
		include TDRV.INC
		include ARITH.INC
                include HARDWARE.INC
		.List

_TEXT           segment byte public 'CODE'
		assume  CS:_TEXT , DS:_TEXT

;       ************************************************************
;       *    Procedure 'DC_Init' initializes initializes struct.   *
;       *  used for telescope control (one coordinate).            *
;       *  Here and below SI must contain offset of this structure *
;       *  Procedure sets min. and max. allowed value of the       *
;       *  coordinate equal to min. and max. <long int> number.    *
;       ************************************************************
;
DC_Init         proc    near
		xor	ax , ax
		mov     [si].Status , 0
		mov     word ptr [si].xMin   , 00000h
		mov     word ptr [si].xMin+2 , 08000h
		mov     word ptr [si].xMax   , 0FFFFh
		mov     word ptr [si].xMax+2 , 07FFFh
		mov	word ptr [si].nDestP , 0
		mov     [si]._Signature , 23761
		call	DC_ResetCoord
		ret
DC_Init         endp

;	*************************************************************
;       *    Procedure <DC_ResetCoord> sets coordinate to the       *
;       *  middle of allowed interval and invalidates is. So        *
;       *  mo steps will be done due to being outside interval      *
;       *  or due to instrument error model.                        *
;       *************************************************************

DC_ResetCoord	PROC	Near
		Local   @@W1:word , 	\
			@@W2:word ,     \
			@@W3:word ,	\
			=LocBytes
		Enter	LocBytes , 0
		mov	ax , word ptr [si].xMin
		mov	@@W1 , ax
		mov	ax , word ptr [si].xMin+2
		cwd
		mov	@@W2 , ax
		mov	@@W3 , dx

		mov	cx , word ptr [si].xMax
		mov	ax , word ptr [si].xMax+2
		cwd					; { DX,AX,CX }
		add	cx , @@W1
		adc	ax , @@W2
		adc	dx , @@W3
		sar	dx , 1
		rcr	ax , 1
		rcr	cx , 1
		mov	dx , ax
		mov	ax , cx
		call	DC_SetCoord
		and     [si].Status , Not DC_StartCoord
		and	EXT_OPT , Not HOME_POS_USED
		Leave
		retn
DC_ResetCoord	ENDP

;	*************************************************************
;	*    Procedure 'DC_DoReset' clears all variables connected  *
;	*  with satellite tracking for the current coordinate.      *
;	*  --> Set <DC_RequestReset> flag                           *
;   	*  --> Prepare data for output to hardware (hrdwStat=0)     *
;	*  --> Set current speed to 0                               *
;	*************************************************************

DC_DoReset	proc	near
		pushf
		cli
		xor	ax , ax
		or	[si].Status , DC_RequestReset
		and	[si].hrdwStat , Not 1	    ; No motion
		mov	word ptr [si].CurrV   , ax  ; CurrV = 0
		mov 	word ptr [si].CurrV+2 , ax  ;
;		mov	word ptr [si].NextSteps , ax
		and	EXT_OPT , Not HOME_POS_USED
		popf
		retn
DC_DoReset	endp

;       *************************************************************
;       *    Procedure 'DC_SetCoordInterval' sets allowed interval  *
;       *  of the coordinate.                                       *
;       *  INPUT:                                                   *
;       *    AX,DX - min. value (DX-high word)                      *
;       *    BX,CX - max. value (CX-high word)                      *
;       *    SI    - offset of <DrvCoord> struct (seg. reg. DS)     *
;       *  OUTPUT:                                                  *
;       *    AX    - return code (0 when OK)                        *
;       *      ........ .......1 - min. value >= max. value         *
;       *      ........ ......1. - current coord. was outside the   *
;	*                          interval.                        *
;       *      ........ .....1.. - attempt to set interval when     *
;       *                          telescope is moving              *
;       *    If return code is not 0 then previous interval remains *
;       *    unchanged!                                             *
;       *************************************************************

DC_SetCoordInterval proc near
		pushf
		cli

		test    [si].Status , DC_Tracking
		jz      S_NoTracking

		mov     ax , 4          ; The telescope is now tracking some
		popf                    ; object. Return with corresponding
		retn                    ; error code without changing interval

		;---------------------------------------------------;
		;     At first look whether the coord. interval is  ;
		;  correct ( {min. value} >= {max. value} ).        ;
		;---------------------------------------------------;

S_NoTracking:   cmp     dx , cx
		jg      S_InvIntrvl
		jl      S_IntrvlOk
		cmp     ax , bx
		jb      S_IntrvlOk

S_InvIntrvl:    mov     ax , 1          ; Invalid interval is specified.
		popf                    ; return with AX=1
		ret

S_IntrvlOk:	;---------------------------------------------------;
		;  Add correction for cogwheals errors to treat     ;
		;  the input values as given in coordinate system   ;
		;  defined by limbs                                 ;
		;  This correction is added at 96-11-10             ;
		;---------------------------------------------------;

		mov	word ptr @@CurrLim   , ax
		mov	word ptr @@CurrLim+2 , dx
		call	DC_GetDrvCorrection
		add	ax , word ptr @@CurrLim
		adc	dx , word ptr @@CurrLim+2
		xchg	ax , bx
		xchg	dx , cx
		mov	word ptr @@CurrLim   , ax
		mov	word ptr @@CurrLim+2 , dx
		call	DC_GetDrvCorrection
		add	ax , word ptr @@CurrLim
		adc	dx , word ptr @@CurrLim+2
		xchg	ax , bx
		xchg	dx , cx

		;---------------------------------------------------;
		;     If the starting coordinate value is not known ;
		;  then all is already done: we can save new        ;
		;  interval and exit. Otherwise we have to test     ;
		;  whether corrent coordinate is not outside the    ;
		;  interval                                         ;
		;---------------------------------------------------;

		test    [si].Status , DC_StartCoord
		jz      S_SetInterval   ; No starting coordinates. Test is
					; not necessary.

		;---------------------------------------------------;
		;    Now look whether the current position is       ;
		;  inside the new interval.                         ;
		;---------------------------------------------------;

		cmp     word ptr [si].CurrX+2 , dx
		jl      S_Outside
		jg      S_Test2
		cmp     word ptr [si].CurrX   , ax
		jl      S_Outside
S_Test2:        cmp     word ptr [si].CurrX+2 , cx
		jg      S_Outside
		jl      S_SetInterval
		cmp     word ptr [si].CurrX   , bx
		jg      S_Outside

		;---------------------------------------------------;
		;    The current position is inside the new         ;
		;  interval. Therefore we can use it.               ;
		;---------------------------------------------------;

S_SetInterval:  mov     word ptr [si].xMin   , ax
		mov     word ptr [si].xMin+2 , dx
		mov     word ptr [si].xMax   , bx
		mov     word ptr [si].xMax+2 , cx
		xor     ax , ax
		je      S_AllDone

		;---------------------------------------------------;
		;     The current coordinates is outside the coord. ;
		;  interval. Therefore these coordinates cannot be  ;
		;  used more. Invalidate them and exit.             ;
		;---------------------------------------------------;

S_Outside:      call	DC_ResetCoord
		mov     ax , 2

		;---------------------------------------------------;
		;     Setting limits for coordinate change area:    ;
		;  all is done and we can return to caller.         ;
		;---------------------------------------------------;

S_AllDone:      popf
		ret

@@CurrLim	dd	?


DC_SetCoordInterval endp

;       *************************************************************
;       *    Procedure 'DC_GetCoordInterval' returns allowed        *
;	*  interval of the coordinate.                              *
;       *  INPUT:                                                   *
;       *    SI    - offset of <DrvCoord> struct (seg. reg. DS)     *
;       *  OUTPUT:                                                  *
;       *    AX,DX - min. value (DX-high word)                      *
;       *    BX,CX - max. value (CX-high word)                      *
;       *************************************************************

DC_GetCoordInterval proc near
		mov	ax , word ptr [si].xMax
		mov	dx , word ptr [si].xMax+2
		call	DC_InvDrvCorr
		xchg	ax , bx
		xchg	dx , cx
		mov	ax , word ptr [si].xMin
		mov 	dx , word ptr [si].xMin+2
		call	DC_InvDrvCorr
		retn
DC_GetCoordInterval endp

;       *************************************************************
;       *    Procedure 'DC_SetCoord' sets current coordinate of     *
;       *  telescope. It is assumed that current speed of mount is  *
;       *  0. It is necessary to use this procedure before work.    *
;       *    Arguments:                                             *
;       *       SI     - offset of 'DrvCoord' struct                *
;       *       AX,DX  - new coordinate in motor steps              *
;       *                 (DX - high word)                          *
;       *    All registers remains intact
;       *************************************************************

DC_SetCoord     proc    near
		cli
		pusha

		and	EXT_OPT , Not HOME_POS_USED

	;------------------------------------------------------------;
	;    At the very begin look whether the new is inside the    ;
	;  allowed interval. If outside then reduce value to the     ;
	;  allowed interval.                                         ;
	;------------------------------------------------------------;

		call    DC_IsInside     ; We do not need look for the
					; result here (only reduce the val.)

	;------------------------------------------------------------;
	;  At first set status of current coordinate:                ;
	;    {  DC_StartCoord=1; DC_Starting=1;                      ;
	;       DC_Ready=1; DC_Tracking=0; }                         ;
	;------------------------------------------------------------;

		mov     [si].Status , DC_StartCoord + DC_Starting + DC_Ready

	;------------------------------------------------------------;
	;  Store new value of current coordinate (times 256 !) from  ;
	;  registers {DX,AX}:                                        ;
	;   - at first round value to nearest step                   ;
	;   - after that store it as current coordinate (The value   ;
	;     will be later corrected for instrument model)          ;
	;   - store it as current destination. The value of previous ;
	;     destination will be stored a bit later (corrected      ;
	;     value needed)                                          ;
	;------------------------------------------------------------;

		test	al , 128 	; Round the value to nearest
		jz      @@11		; integer value
		add	ah , 1
		adc	dx , 0
	@@11:	xor     al , al

		mov	word ptr [si].CurrX       , ax	; Save value as curr.
		mov	word ptr [si].CurrX+2     , dx	; value of coordinate
		mov	word ptr [si].CurrDest    , ax  ;
		mov	word ptr [si].CurrDest+2  , dx

		;-----------------------------------------------;
		;  Set current speed to 0                       ;
		;  Set manual corrections to 0 and return.      ;
		;-----------------------------------------------;

		xor	ax , ax
		mov	word ptr [si].CurrV       , ax
		mov	word ptr [si].CurrV+2     , ax
		mov	word ptr [si].RsdlX       , ax
		mov	word ptr [si].RsdlX+2     , ax
		mov	word ptr [si].d_RsdlX     , ax
		mov	word ptr [si].d_RsdlX+2   , ax
		mov	word ptr [si].Remainder   , ax
		mov	word ptr [si].HistArg     , ax
		mov	word ptr [si].HistArg+2   , ax
		mov	word ptr [si].iCount      , 1
		mov	[si].hrdwStat , al
		mov	[si].NextSteps , ax
                mov     [si].dbgInfo , ax
                mov     [si].hrdwCoeff , 07FFFh

		call	DC_ApplyHistLim

		mov     [si]._Signature , 23761

		mov	ax , word ptr [si].CurrX
		mov     dx , word ptr [si].CurrX+2

		call	DC_GetDrvCorrection

		mov	word ptr [si].DrvCorr      , ax
		mov	word ptr [si].DrvCorr+2    , dx
		mov	word ptr [si].StartShift   , ax
		mov	word ptr [si].StartShift+2 , dx
		add     ax , word ptr [si].CurrX
		adc     dx , word ptr [si].CurrX+2
		mov	word ptr [si].CurrX        , ax
		mov	word ptr [si].CurrX+2      , dx
		mov	word ptr [si].PrevDest     , ax
		mov	word ptr [si].PrevDest+2   , dx

		xor	ax , ax
		mov     word ptr [si].DestSpeed    , ax
		mov	word ptr [si].DestSpeed+2  , ax
		mov	word ptr [si].DestAcc      , ax
		mov	word ptr [si].DestAcc+2    , ax
		mov	word ptr [si].Residual     , ax
		mov	word ptr [si].Residual+2   , ax

		popa
		stc
		ret
DC_SetCoord     endp

;
;       *************************************************************
;       *    Procedure 'DC_SetToCurr' sets destination equal to     *
;       * current position.                                         *
;       *************************************************************
;
DC_SetToCurr    proc    near
		lload   [si].CurrX
		call	DC_InvDrvCorr
                push    ax
                push    dx
                call    DC_ClearCorrection
		pop     dx
                pop     ax
                xor     cx , cx
		jmp     DC_SetDest
DC_SetToCurr    endp
		;    Now the parameters for <DC_SetDest> are ready.
		; and we can continue with <DC_SetDest>
;
;       *************************************************************
;       *    Procedure 'DC_SetDest' sets coordinates where sate-    *
;       * lite must be after (CX*0.1 seconds) to (AX,DX) [DX-high   *
;       * word]. SI must contain address of 'DrvCoord' structure.   *
;       * This coordinate can be outside the allowed interval. The  *
;       * test will be performed in the control loop later          *
;       *************************************************************
;
DC_SetDest      proc    near
		LOCAL   @@PrevDestSpeed:dword     \
			= _Space
		enter   _Space , 0
		push    bx

		;-----------------------------------------------;
		;  Ignore destination when start coordinates    ;
		;  are not known.                               ;
		;-----------------------------------------------;

		test    [si].Status , DC_StartCoord
		jnz     SD_01

		jmp     @@AllDone

SD_01:          ;-----------------------------------------------;
		;  At first test the number of intervals that   ;
		;  is specified in register CX at the call      ;
		;  If this number is negative then              ;
		;  ignore call , if zero then interpret it as   ;
		;  the start of new sequence. New sequence will ;
		;  be begun if no destination is active at      ;
		;  this time.                                   ;
		;-----------------------------------------------;

		test	[si].Status , DC_CurrDestOk
		jz	SD_03

		or      cx , cx
		je      SD_03
                cmp     cx , 64000
                jbe     SD_06
		jmp     @@AllDone

SD_03:          ;-----------------------------------------------;
		;  CX==0 : Interpret call as the start of       ;
		;          new sequence.                        ;
		;-----------------------------------------------;

		or      [si].Status , DC_Starting
		call    DC_ClearCorrection
		mov	[si].nDestP , 0

		;-----------------------------------------------;
		;   @@PrevDestSpeed = [si].DestSpeed              ;
		;-----------------------------------------------;

SD_06:		mov     bx , word ptr [si].DestSpeed
		mov     word ptr @@PrevDestSpeed , bx
		mov     bx , word ptr [si].DestSpeed+2
		mov     word ptr @@PrevDestSpeed+2 , bx

		;------------------------------------------------;
		;  if (Status.DC_Starting)                       ;
		;    {                                           ;
		;       PrevDest={new value};                    ;
		;       CurrDest=PrevDest;                       ;
		;    }                                           ;
		;------------------------------------------------;

		test    [si].Status , DC_Starting
		je      SD_11

		mov     word ptr [si].PrevDest    , ax
		mov     word ptr [si].PrevDest+2  , dx

		mov     word ptr [si].CurrDest    , ax
		mov     word ptr [si].CurrDest+2  , dx

SD_11:          or	[si].Status , DC_CurrDestOk

		;------------------------------------------------;
		;   iCount = i;                                  ;
		;   DestSpeed = ( {AX,DX} - (CurrDest+d_RsdlX))  ;
		;                / Max (1,iCount);               ;
		;------------------------------------------------;

		mov     [si].iCount , cx
		sub     ax , word ptr [si].CurrDest
		sbb     dx , word ptr [si].CurrDest+2

		sub	ax , word ptr [si].d_RsdlX
		sbb	dx , word ptr [si].d_RsdlX+2

		mov     bx , cx
		or      bx , bx
		jne     SD_13
		inc     bx
SD_13:          call    IDiv42R
		mov     word ptr [si].DestSpeed , ax
		mov     word ptr [si].DestSpeed+2 , dx

		;--------------------------------------------------;
		;   Now we try to get destination acceleration     ;
		; and set to 0 if something can be wrong           ;
		;--------------------------------------------------;
                ;   if (nDestP>1)                                  ;
		;     {                                            ;
		;       DestAcc = 2*(DestSpeed - @@PrevDestSpeed) /  ;
		;               (iCount+prevCnt)                   ;
		;       if ( Abs(DestAcc > MaxAcc_W2 )             ;
		;               goto @@AccInv                      ;
		;       nDestP = 2
		;       goto @@AccOk                               ;
		;     }                                            ;
		;   @@AccInv: DestAcc = 0                          ;
		;   @@AccOk:                                       ;
		;--------------------------------------------------;

		mov	ax , word ptr [si].d_RsdlX
		or	ax , word ptr [si].d_RsdlX+2
                jz      @@4
		mov	[si].nDestP , 0
        @@4:    cmp     [si].nDestP , 1         ; Look is prev. dest. is
		ja      @@ChkAcc                ; available. Skip computing
		jmp     @@AccInv		; dest. acc if not available

@@ChkAcc:       ;--------------------------------------------------;
		;   @@PrevDestSpeed is available                     ;
		;--------------------------------------------------;

		lload   [si].DestSpeed
		lsub    @@PrevDestSpeed
		mov	bx , [si].prevCnt
		add	bx , [si].iCount
		shl	ax , 1
		rcl	dx , 1
		call	IDiv42R
                mov     word ptr [si].DestAcc   , ax
                mov     word ptr [si].DestAcc+2 , dx
		call	labs

		cmp	dx , word ptr MaxAcc_W2+2
		ja	@@AccInv
                jb      @@8
		cmp	ax , word ptr MaxAcc_W2
                ja      @@AccInv
@@8:            mov     [si].nDestP , 2
                jmp     @@AccOk
@@AccInv:       xor     ax , ax
		mov     word ptr [si].DestAcc , ax
		mov     word ptr [si].DestAcc+2 , ax
@@AccOk:
		;---------------------------------------------------;
		;  DC_Starting = 0                                  ;
		;  DC_Ready = iCount ? 0 : 1                        ;
		;---------------------------------------------------;

		and     [si].Status , Not (DC_Starting + DC_Ready)
		test    [si].iCount , 0FFFFh
		jne     @@11
		or      [si].Status , DC_Ready
		and	[si].Status , Not DC_CurrDestOk
		jmp	@@AllDone
@@11:           inc     [si].nDestP
		mov	ax , [si].iCount
		mov	[si].prevCnt , ax
@@AllDone:      pop     bx
		leave
		ret
DC_SetDest      endp

;	************************************************************
;	*   Procedure 'DC_ClearCorrection'                         *
;	************************************************************

DC_ClearCorrection proc near
                push    ax
		lzero 	ax , <[si].RsdlX, [si].d_RsdlX>  ; , [si].PrevRsdlX>
                pop     ax
		retn
DC_ClearCorrection endp

;	************************************************************
;	*   Procedure 'DC_Stop'                                    *
;	************************************************************

DC_Stop		proc	near
		cli
		and     [si].Status , NOT (DC_Tracking+DC_CurrDestOk)
		or	[si].Status , DC_Ready
		lzero   ax , <[si].CurrV , [si].DestSpeed , [si].DestAcc >
		and     [si].hrdwStat , 4
		mov	[si].iCount , 1
;		mov	[si].NextSteps , 0
		sti
		retn
DC_Stop		endp

;       ************************************************************
;       *   Procedure 'DC_DoStep'                                  *
;       ************************************************************

DC_DoStep       proc    near
                enter   0,0

		lpush			; Save value for manual corection for
					; this step in the stack.

		;----------------------------------------------;
		; PrevDest = CurrDest + (RsdlX+DrvCorr)        ;
		; Residual = PrevDest - CurrX                  ;
		; RsdlX = RsdlX + {AX,DX at entry} - d_RsdlX   ;
		; CurrDest = CurrDest + d_RsdlX
		; d_RsdlX = 0                                  ;
		;----------------------------------------------;

		lload   [si].CurrDest   ; Take destination coordinates
		ladd	[si].RsdlX	; Add total value of correction
		ladd	[si].DrvCorr	; Add corrections due to drive errors
		lstore  [si].PrevDest	; and store the result in <PrevDest>
		lsub    [si].CurrX      ; After that compute difference
		lstore  [si].Residual	; between this coord and current one.
		lpop			; Restore increment of the corection
		ladd	[si].RsdlX	; Add current correction

		mov	bx , word ptr [si].d_RsdlX
		mov	cx , word ptr [si].d_RsdlX+2
		sub	ax , bx
		sbb	dx , cx
		add	word ptr [si].CurrDest   , bx
		adc	word ptr [si].CurrDest+2 , cx
		mov	word ptr [si].RsdlX   , ax
		mov	word ptr [si].RsdlX+2 , dx
		xor	ax , ax
		mov     word ptr [si].d_RsdlX , ax
		mov	word ptr [si].d_RsdlX+2 , ax

		;----------------------------------------------;
		; CurrDest += DestSpeed                        ;
		; temp = DC_IsInside (CurrDest+RsdlX)          ;
		; IncrX = temp - CurrX                         ;
		;----------------------------------------------;

Stp_101:	lload   [si].DestSpeed  ; Compute destination for next 0.1
		ladd    [si].CurrDest	; second and save it. After that add
		lstore	[si].CurrDest	; manual correction for this coord.
		ladd	[si].RsdlX	; and reduce the result to allowed
		call	DC_IsInside	; range.
		lpush
		call	DC_GetDrvCorrection  ; Do corrections
		lstore  [si].DrvCorr
		mov	bx , ax
		mov	cx , dx
		lpop
		add	ax , bx
		adc	dx , cx
		lsub	[si].CurrX      ; Compute distance to that must be
		lstore	[si].IncrX      ; done in next 0.1 second

		;-------------------------------------------------;
		;   Reduce speed to take the max. allowed speed   ;
		;   and acceleration into the account.            ;
		;-------------------------------------------------;

		call    DC_TestSpeed

		;-------------------------------------------------;
		;  Look whether braking is necessary because of   ;
		;  target tracking.                               ;
		;-------------------------------------------------;

		call    DC_BrkCond_T

		;-------------------------------------------------;
		;   Reduce speed to avoid exit outside the limits ;
		;   for the coordinate value.                     ;
		;-------------------------------------------------;

		call    DC_BrkCond_E

		;-------------------------------------------------;
		;   Compute division's coefficient                ;
		;-------------------------------------------------;

		call    DC_DivCoeff

		;-------------------------------------------------;
		;   At least update status and return to caller   ;
		;-------------------------------------------------;

		call    DC_UpdateStatus

		leave
		ret
DC_DoStep       endp

;*****************************************************************************
;    Procedure  <DC_BrkAcc>  computes braking acceleration
;    Returns this acceleration in registers AX and DX (high word in DX).
;
;    ARGUMENTS:
;       AX,DX    - current speed difference (or speed if target doesn't move)
;
;    RESULT:
;       AX,DX    - Braking acceleration
;
;    Used global variables:
;       MaxAcc
;
;    Called procedures:
;       labs       (ARITH.ASM)          lneg       (ARITH.ASM)
;       lshift8    (ARITH.ASM)          lsort2     (ARITH.ASM)
;*****************************************************************************
;   a = Min ( MaxAcc<<8 , Abs(d_V) )
;   a = d_V<0 ? -a : a
;*****************************************************************************

DC_BrkAcc       proc    near
		lpushb
		push    dx              ; Save sign of d_V
		call    labs            ; abs(d_V)
		lloadb  MaxAcc_D        ;
		call    lsort2          ;
		pop     bx              ; Test sign of d_V. (The high word
		or      bx , bx         ; is saved in stack at the begin)
		jl      BA_001          ; Change sign of result when
		call    lneg            ; d_V is less than 0
BA_001:         lpopb
		ret
DC_BrkAcc       endp

;*****************************************************************************
;
;  Procedure   <DC_IsSmallSpeed>  returns  CF=0 when the absolute value of
;  the increment of the coordinate is less or equal then maximal possible
;  acceleration. (This is when the motion can be stopped immediatelly).
;
;  ARGUMENTS:
;       AX,DX  - the increment of coordinate per interval
;
;  RESULT:
;       CF=0   - abs(increment) <= (MaxAcc<<8)
;       CF=1   - abs(increment) >  (MaxAcc<<8)
;       All registers remains intact.
;
;  Used global variables:  MaxAcc
;
;  Called procedures:
;       labs           (ARITH.ASM)         rshift8              (ARITH.ASM)
;
;*****************************************************************************

DC_IsSmallSpeed proc    near
		lpush
		call    labs
		cmp     dx , word ptr MaxAcc_D + 2
		jb      ISS_LE                      ; LE
		ja      ISS_GT                      ; GT
		cmp     ax , word ptr MaxAcc_D
		ja      ISS_GT                      ; GT
ISS_LE:         clc
		jmp     ISS_Done
ISS_GT:         stc
ISS_Done:       lpop
		ret
DC_IsSmallSpeed endp

;*****************************************************************************
;
;  Procedure   <DC_TestSpeed> reduces coordinate increment to the allowed
;  interval to avoid the motion of the telescope with too large speed.
;
;  ARGUMENTS:
;       SI  - near address of <DrvCoord> structure for current coordinate.
;       [SI].IncrX - unreduced increment of coordinate for the next interval
;
;  RESULT:
;       [SI].IncrX - the reduced value of coordinate increment
;
;  Used global variables:
;       MaxAcc_D , MaxSpeed_D
;
;  Called procedures:
;       ARITH.ASM    : labs , lneg , lsort2 , IsInside
;
;*****************************************************************************

DC_TestSpeed    proc    near
		enter   0 , 0
		lload   [si].CurrV

		call    labs                  ; abs(CurrV)
		lpush                         ; Save it for later use
		ladd    MaxAcc_D              ; abs(CurrV) + MaxAcc_D
		lloadb  MaxSpeed_D            ; Load max. allowed speed
		call    lsort2                ; Get min. of {AX,DX} and
		lstore  maxv                  ; {BX,CX} and store it
		lpop                          ; Restore abs(CurrV) from stack
		lsub    MaxAcc_D              ; <minv> in register pair
TS_003:		test    byte ptr [si].CurrV+3,128
		jz      TS_006
		call    lneg                  ; change sign and swap <minv>
		lswap   maxv                  ; and <maxv> when prev. speed
		call    lneg                  ; was negative
TS_006:         lstore  minv
		lea     bx , minv             ; Now interval is ready.
		lload   [si].IncrX            ; Load new speed and reduce
		call    IsInside              ; it to the valid interval
TS_007:		lstore  [si].IncrX

		leave
		ret
minv            dd      ?
maxv            dd      ?
DC_TestSpeed    endp

;*****************************************************************************
;
;  Procedure   <DC_BrkCond_E> reduces coordinate increment when braking
;  is necessary to avoid exit outside the allowed interval for current
;  coordinate. (Coordinate increment is measured in motor steps times 256 !).
;
;  ARGUMENTS:
;       SI  - near address of <DrvCoord> structure for current coordinate.
;       [SI].IncrX - unreduced increment of coordinate for the next interval
;
;  RESULT:
;       [SI].IncrX  - reduced value of the increment
;
;  Used global variables:
;       MaxAcc
;
;  Called procedures:
;       DC_IsSmallSpeed                 DC_IsInside
;       DC_BrkAcc                       labs            (ARITH.ASM)
;       rshift8         (ARITH.ASM)     N_LXMUL         (ARITH.ASM)
;       lneg            (ARITH.ASM)
;
;*****************************************************************************

DC_BrkCond_E    proc    near
		enter   0,0

		lload   [si].IncrX
		call    DC_IsSmallSpeed         ;    Look whether we can stop
		jc      BCE_001                 ; immediatelly. If so then we
		jmp     BCE_991                 ; don't need this test and
						; reduction
BCE_001:        call    labs                    ; Look how long we need to
		call    rshift8                 ; brake until stop (in units
		mov     bx , ax                 ; of 0.1 sec)
		mov     cx , dx                 ; {BX,CX} = abs(xIncr)>>8
		sar     dx , 1
		rcr     ax , 1                  ; {AX,DX} = abs(xIncr)>>9
		call    N_LXMUL                 ; (xIncr*xIncr)>>17

		mov	bx , MaxAcc
		call    IDiv42
		call	lshift8

		test    byte ptr [si].IncrX+3 , 128
		jz      BCE_006
		call    lneg                    ; Restore sign
BCE_006:        ladd    [si].IncrX              ; Compute coordinate after
		ladd    [si].CurrX              ; current interval and
		call    DC_IsInside             ; braking and look whether
						; we don't go outside the
		jnc     BCE_991                 ; interval and exit without
						; actions when no reduction is
		lload   [si].CurrV              ; necessary. Otherwise change
		call    DC_BrkAcc               ; the increment.
		ladd    [si].CurrV
		lstore  [si].IncrX

BCE_991:        leave
		ret
DC_BrkCond_E    endp

;=============================================================================
;  Procedure 'DC_UpdateStatus' updates status after division's coefficient
;  is computed:
;       : looks whether the requested number of intervals is done.
;       : updates current speed for next step.
;  This procedure must be called at the end of the step!
;
;  ARGUMENTS:
;       DS:[SI]   - address of <DrvCoord> structure
;
;=============================================================================

DC_UpdateStatus proc    near
		lload   [si].IncrX
		lstore  [si].CurrV
		mov     ax , [si].iCount       ; Test interval counter.
                or      ax , ax                ; If exhausted then set
                je      U_NextInterv           ; <DC_Ready> flag
                cmp     ax , 64000
                jbe     U_ContInterv
U_NextInterv:   and     [si].Status , Not DC_CurrDestOk
		jmp     U_SetReady
U_ContInterv:	dec     ax
		mov     [si].iCount , ax
		jne     U_NotReady
U_SetReady:     or      [si].Status , DC_Ready
U_NotReady:     ret
DC_UpdateStatus endp

;=============================================================================
;
;  Procedure 'DC_BrkCond_T' reduces coordinate increment [si].IncrX to
;  take braking that is necessary to track object into the account.
;
;=============================================================================

DC_BrkCond_T	proc	near
		local	@@H	:dWord \
			=LocBytes
		enter	LocBytes , 0

		mov	ax , word ptr [si].IncrX	; Check requested
		mov	dx , word ptr [si].IncrX+2	; increment.
		call    DC_ChkBrkCond
		jc      BCT2_06
BCT2_05:	jmp	BCT2_Done                       ; No braking necessary

BCT2_06:        mov	ax , word ptr [si].IncrX
		mov	dx , word ptr [si].IncrX+2
		mov	word ptr @@H   , ax
		mov	word ptr @@H+2 , dx
                mov     ax , word ptr [si].CurrV
                mov     dx , word ptr [si].CurrV+2
		sub	ax , word ptr [si].DestSpeed
		sbb	dx , word ptr [si].DestSpeed+2
		call    DC_BrkAcc
		add     ax , word ptr [si].CurrV
		adc     dx , word ptr [si].CurrV+2

		mov	cx , dx				; Save sign of IncrX
		call	labs				; Take abs. value
                cmp     dx , word ptr MaxSpeed_D+2      ; Now we compare abs.
                ja      BCT2_11                         ; value of speed with
		jb	BCT2_12				; max. allowed one.
                cmp     ax , word ptr MaxSpeed_D        ; and replace with it
		jbe	BCT2_12				; when too large.
BCT2_11:        mov     ax , word ptr MaxSpeed_D
                mov     dx , word ptr MaxSpeed_D+2
BCT2_12:        or	cx , cx				; Restore sign of
		jge	BCT2_13				; IncrX and store the
		call	lneg				; result
BCT2_13:	mov	word ptr [si].IncrX   , ax
		mov	word ptr [si].IncrX+2 , dx

		; Here the test for max. allowed speed must be inserted

		call	DC_ChkBrkCond
		jc      BCT2_05

		mov	ax , word ptr [si].IncrX
		mov	dx , word ptr [si].IncrX+2
		sub	word ptr @@H   , ax
		sbb	word ptr @@H+2 , dx

		mov	cx , 3
DCT2_Loop:      mov	ax , word ptr [si].IncrX
		mov	dx , word ptr [si].IncrX+2
		add	ax , word ptr @@H
		adc	dx , word ptr @@H+2
		push	ax
		push	dx
		call	DC_ChkBrkCond
		pop	dx
		pop	ax
		jc	DCT2_L9
		mov	word ptr [si].IncrX   , ax
		mov	word ptr [si].IncrX+2 , dx
DCT2_L9:        sar     word ptr @@H+2 , 1
		rcr     word ptr @@H   , 1
		loop	DCT2_Loop

BCT2_Done:	leave
		retn
DC_BrkCond_T    endp

;=============================================================================
;
;  Procedure 'DC_ChkBrkCond' looks whether the next speed specified in
;  register pair {AX,DX} is too large to catch satellite. Procedure returns
;  CF=1 if the speed is too large or CF=0 - if not.
;
;=============================================================================

DC_ChkBrkCond	proc	near
;		local   dXP	  :dword, \
		local	@@dVP	  :dword, \
			@@VV	  :dword, \
			@@BrkAcc  :dword, \
			@@IntNum  :word,  \
			@@IntNum2 :word,  \
			@@BPath	  :dword  \
			=LocBytes
		enter   LocBytes , 0
		push	bx
		push	cx

		mov	word ptr @@VV   , ax		; Save speed value
		mov	word ptr @@VV+2 , dx		; to be tested.

		mov	bx , word ptr [si].CurrDest	; CurrDest-CurrX
		mov	cx , word ptr [si].CurrDest+2	; (in {BX,CX})

                add     bx , word ptr [si].RsdlX        ;++++++++++++++++
                adc     cx , word ptr [si].RsdlX+2
                add     bx , word ptr [si].DrvCorr
		adc     cx , word ptr [si].DrvCorr+2    ;++++++++++++++++

                sub     bx , word ptr [si].CurrX
		sbb	cx , word ptr [si].CurrX+2

		mov	ax , word ptr [si].DestSpeed    ; Find speed difference:
		mov	dx , word ptr [si].DestSpeed+2	; and save it in @@dVP
		sub     ax , word ptr @@VV                ; @@dVP=DestSpeed-@@VV;
		sbb	dx , word ptr @@VV+2
		mov	word ptr @@dVP   , ax
		mov	word ptr @@dVP+2 , dx

		call	labs 			     ; abs(@@dVP)
		cmp	dx , word ptr MaxAcc_D+2     ; if (abs(@@dVP)<=MaxAcc_D)
		ja      CB_11			     ;     return (CF=0)
		jb	CB_06
		cmp	ax , word ptr MaxAcc_D
		ja	CB_11
CB_06:          jmp	CB_TestPassed

CB_11:          xor	ch , byte ptr @@dVP+3		; Compare signs:
		test	ch , 128			; if different then
		jz	CB_06				;  test is passed

		mov	ax , word ptr MaxAcc_W3		; @@BrkAcc =
		mov	dx , word ptr MaxAcc_W3+2	;    @@dVP>0 ?
		test	byte ptr @@dVP+3 , 128		;       MaxAcc_W3 :
		jz      CB_16                           ;      -MaxAcc_W3 ;
		call	lneg				; Braking acceleration

CB_16:          sub	ax , word ptr [si].DestAcc	; @@BrkAcc -= DestAcc
		sbb	dx , word ptr [si].DestAcc+2	; { We must use
		mov     word ptr @@BrkAcc   , ax          ;   relative accele-
		mov	word ptr @@BrkAcc+2 , dx		;   ration }

		mov	bx , word ptr @@dVP		; {AX,DX} <-- @@dVP
		mov	cx , word ptr @@dVP+2		; {BX,CX} <-- @@BrkAcc

		xchg	ax , bx
                xchg    dx , cx
		call    ldiv                            ; n=@@dVP/(@@BrkAcc)
		or	dx , dx				; # n<=0    : passed
		jnz     CB_06				; # n>1500  : passed
		or 	ax , ax                         ;
		jz	CB_06
		cmp	ax , 1500
		ja	CB_06
		mov	@@IntNum , ax

		mov	bx , ax                         ; Now we compute
		inc	bx				; braking path:
@@1:            mov     @@IntNum2 , bx
		mov     ax , word ptr @@VV+2              ;
		mul	bx                              ; BPath = (n+1)*@@VV;
		mov     word ptr @@BPath+2 , ax
		mov	ax , word ptr @@VV
		mul	bx
		mov	word ptr @@BPath   , ax
		add	word ptr @@BPath+2 , dx

		mov	ax , @@IntNum			; n*(n+1)/2
		mul	bx
		shr	dx , 1
		rcr	ax , 1

		mov	bx , word ptr @@BrkAcc            ; BPath +=
		mov	cx , word ptr @@BrkAcc+2          ;    (n*(n+1)/2)*
		call	N_LXMUL                         ;       BrkAcc;
		add     word ptr @@BPath   , ax
		adc     word ptr @@BPath+2 , dx

		mov	bx , word ptr [si].PrevDest     ; BPath =
		mov	cx , word ptr [si].PrevDest+2   ;   PrevDest -
		sub	bx , word ptr [si].CurrX	;   CurrX -
		sbb	cx , word ptr [si].CurrX+2      ;   BPath;
		sub	bx , word ptr @@BPath
		sbb	cx , word ptr @@BPath+2
		mov	word ptr @@BPath   , bx
		mov	word ptr @@BPath+2 , cx

		mov     bx , @@IntNum                     ; n+1
                inc     bx
		mov	ax , word ptr [si].DestSpeed    ; BPath +=
		mul	bx				;     (n+1)*DestSpeed;
		add	word ptr @@BPath   , ax
		adc	word ptr @@BPath+2 , dx
		mov	ax , word ptr [si].DestSpeed+2
		mul	bx
		add	word ptr @@BPath+2 , ax
		mov     ax , word ptr @@BPath
		mov	dx , word ptr @@BPath+2

		test    byte ptr @@BrkAcc+3 , 128	; if (BrkAcc<0)
		jnz     CB_21                           ;   BPath=-BPath;
		call	lneg
CB_21:          or	dh , dh				; BPath>0 : passed
		jl      CB_TestFailed                   ; BPath<0 : failed
CB_TestPassed:	clc
		jmp	CB_Done
CB_TestFailed:	stc
CB_Done:        pop	cx
		pop	bx
		leave
		retn
DC_ChkBrkCond	endp

;=============================================================================
;
;  Procedure 'DC_IsInside' looks whether the specified value of the coord.
;  is inside the interval between <DS:[SI].xMin>  and  <DS:[SI].xMax> and
;  returns in CF=0 if the test is passed or CF=1 when not.
;    All registers remains intact if the test is passed. If the specified
;  value is outside the interval then one is replaced by nthe nearest end
;  of the interval.
;
;  ARGUMENTS:
;       SI      - near pointer to <DrvCoord> structure
;       AX,DX   - the value of the coordinate to be tested.
;
;  RESULT:
;       CF      - 0: test Ok , 1: the value was outside the interval and is
;                 replaced by the nearest edge if this interval.
;       AX,DX   - the value of the coord. (possibly replaced by one of the
;                 edges of the allowed interval.
;
;  Used global variables: none
;
;  Called procedures: none
;
;*****************************************************************************

DC_IsInside     proc    near
		push    bx                      ; Prepare parameters in the
		lea     bx , [si].xMin          ; registers and call IsInside
		call    IsInside                ; (in ARITH.ASM)
		pop     bx
		ret
DC_IsInside     endp

;*****************************************************************************
;
;  Procedure <DC_GetDrvCorrection> returns value that is added to
;  destination coordinates to compensate drive errors. The value is returned
;  in register pair {AX,DX}. Other registers remains unchanged.
;  At entry {AX,DX} must contain coordinate to be corrected.
;
;*****************************************************************************

DC_GetDrvCorrection proc near
		local   @@TOffset		:word ,	 \
			@@TRem		:dword , \
			@@XCorr		:dword , \
			@@XIncr		:dword   \
			= LocBytes
		test	[si].ErrorDef,0FFFFh	; Look if coordinate transf.
		jnz	GDC_Start		; data is defined. If not
		xor	ax , ax			; then immediately return 0
		xor	dx , dx
		retn
GDC_Start:	enter	LocBytes , 0
		push	bx                      ; Save registers in the stack
		push	cx			; to restore them later before
		push	di			; return
		mov	di , [si].ErrorDef	; Offset of <DrvDescr> struct.
                test    [di].CoordRSize , 0FFFFh
		jz	@@10
		test    [di].CoordRTable , 0FFFFh
		jnz     @@11
	@@10:	xor	ax , ax
		xor	dx , dx
		jmp     GDC_Done1

	;------------------------------------------------------------;
	;   Reduce coordinate relative to reference point to the     ;
	; definition area by removing full periods                   ;
	;------------------------------------------------------------;
	;     [di].CoordRStart   - start point of corrections table  ;
	;     [di].CoordRPeriod  - full period for coordinate        ;
	;------------------------------------------------------------;
	; Difference is reduced to interval [ 0...[di].CoordRPeriod [;
	;------------------------------------------------------------;

	@@11:	sub	ax , word ptr [di].CoordRStart
		sbb	dx , word ptr [di].CoordRStart+2
		mov     bx , word ptr [di].CoordRPeriod
		mov	cx , word ptr [di].CoordRPeriod+2
		call	ldiv
		or	cx , cx			; Test sign of remainder
		jge	@@12			; and reduce it to positive
		add	bx , word ptr [di].CoordRPeriod		; value
		adc	cx , word ptr [di].CoordRPeriod+2
	@@12:   jmp     GDC_RmOk1

	;----------------------------------------------------------;
	;   If relative coordinate is out of area covered by       ;
	; corrections table, simply return zeros as corrections    ;
	; values.                                                  ;
	;----------------------------------------------------------;

GDC_OutOfInt:   xor	ax , ax
		xor	dx , dx
		jmp	GDC_Done1

	;----------------------------------------------------------;
	;   Now coordinate (relative to reference point of         ;
	; corrections table) if reduced to 1-st period. Now we can ;
	; divide it with table step ([di].CoordRStep) and get      ;
	; index in table and remainder used for interpolation      ;
	; If the index fits in table then offset in table is       ;
	; stored in @@TOffset and remainder in @@TRem              ;
	;----------------------------------------------------------;

GDC_RmOk1:      mov	ax , bx			; Copy variable to registers
		mov	dx , cx			; pair {AX,DX}
		mov	bx , word ptr [di].CoordRStep
		mov	cx , word ptr [di].CoordRStep+2
		call	ldiv
		or	dx , dx     		; Look if quotient is small
		jnz	GDC_OutOfInt		; enough to fit in the
		cmp     ax , [di].CoordRSize	; table
		jae	GDC_OutOfInt
		shl	ax , 1    		; Convert index to offset
		mov	@@TOffset , ax		; in the table.
		mov	word ptr @@TRem   , bx
		mov	word ptr @@TRem+2 , cx

	;--------------------------------------------------------;
	;    Get corrections from correct table interval and     ;
	; find increment for interpolation. Convert both to      ;
	; units used internally by TDRV:                         ;
	; Store value at start of interval into @@XCorr and      ;
	; increment per interval into @@XIncr                    ;
	;--------------------------------------------------------;

		push	di
		mov	di , [di].CoordRTable	; Extract table address
		mov	bx , @@TOffset
		mov	ax , [bx+di]		; Extract first value from table
		mov	bx , [bx+di+2]		; Extract next value from table
		sub	bx , ax			; and find difference
		cwd
		call	lshift8
		mov	word ptr @@XCorr   , ax
		mov	word ptr @@XCorr+2 , dx
		mov	ax , bx
		cwd
		call	lshift8
		mov	word ptr @@XIncr   , ax
		mov	word ptr @@XIncr+2 , dx
		pop	di

	;--------------------------------------------------------;
	;   Now shift remainder of last division tith table step ;
	; and table step left (both are positive integers) until ;
	; the highest bit of the second one is 1                 ;
	;--------------------------------------------------------;

		mov     ax , word ptr @@TRem
		mov	dx , word ptr @@TRem+2
		mov	bx , word ptr [di].CoordRStep
		mov	cx , word ptr [di].CoordRStep+2
GCD_RedRN1:	test    ch , 0C0h
		jnz     GCD_RedRN2
		shl	ax , 1
		rcl	dx , 1
		shl	bx , 1
		rcl     cx , 1
		jmp	GCD_RedRN1

	;---------------------------------------------------------;
	;   Now we can finish interpolation and get correction    ;
	; value coordinate we got in input                        ;
	;---------------------------------------------------------;

GCD_RedRN2:	mov	bx , dx
		mov	ax , word ptr @@XIncr
		mov	dx , word ptr @@XIncr+2
		call	IMlt4RN
		add	ax , word ptr @@XCorr
		adc	dx , word ptr @@XCorr+2

	;---------------------------------------------------------;
	;   If entry InvertLC in corresponding [Coord?] group is  ;
	; 1 then invert corrections got from table                ;
	;---------------------------------------------------------;

GDC_Done1:      test    [si].DC_Options , DC_InvertLC
		jz      GDC_Done2
		call    lneg
GDC_Done2:      pop     di
		pop	cx
		pop	bx
		leave
		retn
DC_GetDrvCorrection endp
;
;*****************************************************************************
;
;   Procedure <DC_InvDrvCorr> performs inverse correction: from system
;   connected with motor steps to one connected with limbs.
;
;*****************************************************************************

DC_InvDrvCorr	proc	near
		local   @@MCoord:dword ,	\
			@@LCoord:dword    \
			= LocBytes
		enter	LocBytes , 0
		push	bx
		push	cx
		mov	cx , 4
		mov	word ptr @@MCoord   , ax
		mov	word ptr @@MCoord+2 , dx
		mov	word ptr @@LCoord   , ax
		mov 	word ptr @@LCoord+2 , dx
DCI_Loop1:	call	DC_GetDrvCorrection
		call	lneg
		add	ax , word ptr @@MCoord
		adc	dx , word ptr @@MCoord+2
		push    ax
		push	dx
		xor	bx , bx
		sub	ax , word ptr @@LCoord
		sbb	dx , word ptr @@LCoord+2
		jge	DCI_dfOk1
		call	lneg
		or      dx , dx
		jnz     DCI_dfCont1
		cmp	ax , 64
		jb	DCI_dfOk1
DCI_dfCont1:    dec     cx
DCI_dfOk1:      pop	dx
		pop	ax
                or      cx , cx
                jz      DCI_Done
		loop    DCI_Loop1
DCI_Done:       pop	cx
		pop	bx
		leave
		retn
DC_InvDrvCorr	endp

;*****************************************************************************
;   Procedure <DC_ApplyHistLim>
;*****************************************************************************

DC_ApplyHistLim	proc	near
		cmp	si , Offset DRV_X
		je	@@12
		lload	HistWY
		jmp	@@13
	@@12:	lload	HistWX
	@@13:   lstore	[si].HistMax
		call	lneg
		lstore	[si].HistMin
		retn
DC_ApplyHistLim	endp

;*****************************************************************************
;               <<<<  END OF MODULE  >>>>
;*****************************************************************************

_TEXT           ends
		end


