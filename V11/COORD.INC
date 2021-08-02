;///////////////////////////////////////////////////////////////////////////////
;
;                 FILE:  COORD.INC
;
;///////////////////////////////////////////////////////////////////////////////

	;--------------------------------------------------------;
	;   Structures for tracking both coordinates             ;
	;--------------------------------------------------------;

	;###########  Byte <Status> in <DrvCoord>  ##############

	DC_Starting	equ	01h	; 1 while starting sequence
	DC_Tracking	equ	02h	; 1 when the speed is not 0
	DC_Ready	equ	04h	; 1 when ready for new dest.
	DC_StartCoord	equ	08h     ; 1 when coord. sys. established
	DC_CurrDestOk	equ	20h	; 1 when current dest is Ok
	DC_SignChanged	equ	40h	; 1 when sign must be changed
	DC_RequestReset	equ	80h	;

	;###########  Byte <Options> in <DrvCoord>  #############

        DC_InvertSign   equ     01h     ; 1 - invert sign that is being sent
					;     to hardware card.
	DC_CorrectStp	equ	02h	; 1 - enable step count correction

        DC_InvertLC     equ     04h     ; 1 - invert corrections taken from
                                        ;     table (if exist)

	;##########   Description of structure <DrvCoord>  ######

DrvCoord	STRUC
				;--------------------------------------------
Status		db	?	; Status byte
				;--------------------------------------------
DC_Options	db	?       ; Options byte
				;--------------------------------------------
ErrorDef	dw	?	; Address of CTDef structure (used for
				; coordinate transformation to exclude
				; drive errors)
CurrX		dd	?	; (Current coordinate in motor steps) * 256
CurrV		dd	?	; Current speed (motor steps per 0.1 sec
				; times 256)
Residual	dd	?	; Difference between real and computed
				; values of the coordinates.
PrevDest	dd	?	; Previous destination (motor steps times 256)
				; corrected by manual corrections.
CurrDest	dd	?       ; Current destination at the end of control
				; interval (motor steps times 256)
DestSpeed	dd	?	; Destination speed (motor steps times 256
				;    per 0.1 sec)
DestAcc		dd	?	; Destination acceleration (when known or 0)
				;--------------------------------------------
RsdlX		dd	?	; Current value of coordinate correction
d_RsdlX		dd	?	; Value that must be substracted from RsdlX.
				; This variable is not zero when user took the
				; manual corrections into account while
				; computing ephemeris.
;---------------------------------------------------------------;
; This field is obsolete and will be removed in future versions ;
PrevRsdlX	dd	?	; Value of correction saved at the call to
				; DC_GetCorrection
;---------------------------------------------------------------;
				;--------------------------------------------
IncrX		dd	?	; Number of steps that must be done in the
				; next 0.1 seconds.
				;--------------------------------------------
xMin		dd      ?	; Min. allowed coord. value
xMax		dd	?	; Max. allowed coord. value
				;--------------------------------------------
iCount		dw	?	; Number of control intervals left
				;--------------------------------------------
hrdwStat	db	?	; 00-no motion   01-motion enabled
				; 04-sign
				;--------------------------------------------
hrdwCoeff	dw	?       ; XXXXXXXX XXXXXXXX  - division's coefficient
				;    (unsigned integer number)
				;--------------------------------------------
Remainder	dw	?
dbgInfo		dw	?	;
nDestP		db	?
				;--------------------------------------------
prevCnt		dw	?       ; The length of the previous control interval
				; (in units of 0.1 second)
				;--------------------------------------------
TotalSteps	dd	?	; Total number of steps for this coordinate
				; (the sign is being ignored). User can set
				; this variable to 0 and use it after that
				; for diagnostic purposes
				;--------------------------------------------
DrvCorr		dd	?	; Correction of destination due to drive
				; errors. (0 if not defined)
				;--------------------------------------------
StartShift	dd	?	; Coordinate shift done while setting curr.
				; telescope coordinates
				;--------------------------------------------
CurrSteps	dw	?	; Number of steps that must be done in the
				; current control interval.
				;--------------------------------------------
NextSteps	dw	?	; Number of steps that must be gone in the
				; next control interval (0.1 sec)
				;--------------------------------------------
PrevHrdwStat	db	?	; Value of <hrdwStat> from the previous
				; 0.1 sec.
				;--------------------------------------------
CntZeroVal	dw	?
StepCnt		dw	?
HistArg		dd	?       ; Argument for histeresis (experimental)
HistMin		dd	?       ; Current histeresis width (half)
HistMax		dd	?
_Signature      dw      ?
		ENDS

	;---------------------------------------------------------;
	;    Structure <DrvDescr> describes driving errors for    ;
	;  one coordinate. This structure is being used to remove ;
	;  drive errors from step counts.                         ;
	;---------------------------------------------------------;

DrvDescr	struc
CoordRStart     dd	?	; Reference point of correction table
CoordRStep	dd	?	; Step of correction table
CoordRPeriod	dd	?	; Full period of table
CoordRSize	dw	?	; Number of entries-1 in corections table
CoordRTable	dw	?	; Near pointer to corrections table
		ends

		global	DescrX		:DrvDescr
		global	DescrY		:DrvDescr
		global	CoordDescr0	:word

	;---------------------------------------------------------;
	;    Structure <DrvRequest> is being used to send new     ;
	;  destination to TDRV.EXE.                               ;
	;---------------------------------------------------------;

DrvRequest	struc
_Flags          dw	?	;
_Time		dd	?	; Time in units of 0.1 sec beginning from
				;    midnight.
_DestX          dd	?	; both coordinates and distance to satellite
_DestY		dd	?	;    in specified time moment.
_DestR		dd	?
_FldAngle	dw	?
_DCorrX		dd	?
_DCorrY		dd	?
		ends


RESET_JCR	equ	8000h	; User sets high bit in _Flags when the
				; manual corrections is used to modify
				; ephemeris

RESET_PREV_DEST	equ	4000h	; User sets this bit to 1 if he wants
				; cancel previous destination.

	;---------------------------------------------------------;
	;    Structure <CurrPos> is used to return current        ;
	; position and tracking parameters of the telescope.      ;
	;---------------------------------------------------------;

CurrPos		struc
_T0		dd	?
_X0		dd	?
_VX0		dd	?
_RX0		dd	?
_Y0		dd	?
_VY0		dd	?
_RY0		dd	?
		ends

;*****************************************************************************
;*************    Definitions for the file COORD2.ASM       ******************
;*****************************************************************************

	;--------------------------------------------------------;
	;  Outputs data to hardware if any are pending           ;
	;--------------------------------------------------------;

	global	OutputHrdwData		:near

	;--------------------------------------------------------;
	;  Procedure <DoStep> performs all action that are       ;
	;  that are necesary to output current output data (if   ;
	;  ones exist) and compute new ones for the next control ;
	;  interval. Procedure if called from 0.1 second timer   ;
	;  interrupt procedure only.                             ;
	;--------------------------------------------------------;

	global	DoStep			:near

	;--------------------------------------------------------;
	;  Procedure <SetNewDest> accepts new destination point  ;
	;  when one is available. This procedure is called only  ;
	;  from <DoStep> !!!                                     ;
	;--------------------------------------------------------;

	global	SetNewDest		:near

	;--------------------------------------------------------;
	;  Procedure <GetMCor> returns manual corrections in     ;
	;  registers AX and BX. When no corrections are enabled  ;
	;  then returns zeros.                                   ;
	;--------------------------------------------------------;

	global	GetMCor			:near

	;--------------------------------------------------------;
	;  Procedure <ClrCorrections> clears manual corrections  ;
	;  fields of coordinates for both coordinates and clears ;
	;  range shift (the last one is not yet implemented).    ;
	;--------------------------------------------------------;

	global	ClrCorrections		:near

	;--------------------------------------------------------;

	global	I_StopTracking		:near
	global	StopTracking		:near

;*****************************************************************************
;*************    Definitions for the file COORD.ASM        ******************
;*****************************************************************************

	;--------------------------------------------------------;
	;  Procedure <DC_Init> performs starting initialization  ;
	;  of <DrvCoord> structure.                              ;
	;--------------------------------------------------------;

	global	DC_Init			:near

	;--------------------------------------------------------;
	;  Procedure <DC_ResetCoord> sets coordinate to the      ;
	;  middle of allowed interval and invalidates is. So     ;
	;  mo steps will be done due to being outside interval   ;
	;  or due to instrument error model.                     ;
	;--------------------------------------------------------;

	global	DC_ResetCoord		:near

	;--------------------------------------------------------;
	;  Procedure <DC_DoReset> prepares data for stopping     ;
	;  tracking (immediatelly)                               ;
	;--------------------------------------------------------;

	global	DC_DoReset		:near

	;--------------------------------------------------------;
	;  Procedure 'DC_SetCoordInterval' sets allowed interval ;
	;  of the coordinate.                                    ;
	;  INPUT:                                                ;
	;    AX,DX - min. value (DX-high word)                   ;
	;    BX,CX - max. value (CX-high word)                   ;
	;    SI    - offset of <DrvCoord> struct (seg. reg. DS)  ;
	;  OUTPUT:                                               ;
	;    AX    - return code (0 when OK)                     ;
	;    ........ .......1 - min. value >= max. value        ;
	;    ........ ......1. - current coord. outside interval ;
	;    ........ .....1.. - attempt to set interval when    ;
	;                        telescope is moving             ;
	;  If return code is not 0 then previous interval remains;
	;  unchanged!                                            ;
	;--------------------------------------------------------;

	global	DC_SetCoordInterval	:near

	;********************************************************;
	; Procedure 'DC_GetCoordInterval' returns allowed        ;
	; interval of the coordinate.                            ;
	; INPUT:                                                 ;
	;   SI    - offset of <DrvCoord> struct (seg. reg. DS)   ;
	; OUTPUT:                                                ;
	;   AX,DX - min. value (DX-high word)                    ;
	;   BX,CX - max. value (CX-high word)                    ;
	;********************************************************;

	global	DC_GetCoordInterval 	:near

	;--------------------------------------------------------;
	; Procedure 'DC_SetCoord' sets current coordinate of     ;
	; telescope. It is assumed that current speed of mount is;
	; 0. It is necessary to use this procedure before work.  ;
	; Arguments:                                             ;
	;   SI     - offset of 'DrvCoord' struct                 ;
	;   AX,DX  - new coordinate in motor steps               ;
	;            (DX - high word)                            ;
	; All registers remains intact                           ;
	;--------------------------------------------------------;

	global	DC_SetCoord		:near

	;--------------------------------------------------------;
	; Procedure 'DC_SetToCurr' sets destination coordinate   ;
	; equal to the current position.                         ;
	;--------------------------------------------------------;

	global	DC_SetToCurr		:near

	;--------------------------------------------------------;
	; Procedure 'DC_SetDest' sets new destination for        ;
	; specified coordinate. The following parameters must    ;
	; be specified in the registers:                         ;
	;    SI      - near pointer to <DrvCoord> structure      ;
	;    AX,DX   - new destination coordinate                ;
	;    CX      - number of 0.1 sec. intervals              ;
	;--------------------------------------------------------;

	global	DC_SetDest		:near

	;--------------------------------------------------------;
	; Procedure 'DC_ClearCorrection' clears all fields       ;
	; connected with manual corrections in <DrvCoord> struct.;
	;--------------------------------------------------------;

	global	DC_ClearCorrection	:near

	;--------------------------------------------------------;
	; Procedure 'DC_DoStep' does all computations necessary  ;
	; to perform on telescope control cycle. Many of         ;
	; procedures from COORDPRC.ASM is being called.          ;
	;--------------------------------------------------------;

	global	DC_DoStep		:near

	;--------------------------------------------------------;
	; Procedure 'DC_Stop' requests to immediatelly stop      ;
	; the motion in the next 0.1 second interrupt.           ;
	;--------------------------------------------------------;

	global	DC_Stop			:near

;*****************************************************************************
;*************    Definitions for the file COORDPRC.ASM     ******************
;*****************************************************************************
;    File CORRDPRC.ASM contains different lower level procedures that is
; necessary to perform tracking one object coordinate.
;*****************************************************************************

	;--------------------------------------------------------;
	;  Procedure <DC_BrkAcc> computes braking acceleration.  ;
	;  At the entry register pair {AX,DX} contains speed     ;
	;  difference (or speed, when object doesn't move). At   ;
	;  the exit the same registers contains braking acce-    ;
	;  leration. All other registers remains unchanged.      ;
	;--------------------------------------------------------;

	global  DC_BrkAcc		:near

	;--------------------------------------------------------;
	;  Procedure <DC_IsSmallSpeed> looks if speed specified  ;
	;  in register pair {AX,DX} is small enough to stop      ;
	;  the motion immediatelly. Returns value in flag CF:    ;
	;  0 - when speed is small enough , 1 - if not.          ;
	;  All registers remains intact.                         ;
	;--------------------------------------------------------;

	global  DC_IsSmallSpeed		:near

	;--------------------------------------------------------;
	;  Procedure <DC_OldStep> computes number of steps that  ;
	;  can be done in the last control interval and add them ;
	;  to the current position. Register SI must contain     ;
	;  near pointer to the corresponding <DrvCoord> structure;
	;--------------------------------------------------------;

	global	DC_OldStep		:near

	;--------------------------------------------------------;
	;  Procedure <DC_TestSpeed> tests requested speed for    ;
	;  max allowed speed and acceleration and reduces it to  ;
	;  correct limits when necessary. Register SI must       ;
	;  contain near pointer to the <DrvCoord> structure.     ;
	;  Unreduced speed is taken from the field [SI].IncrX.   ;
	;  The reduced value replaces the old one.               ;
	;--------------------------------------------------------;

	global	DC_TestSpeed		:near

	;--------------------------------------------------------;
	;  Procedure <DC_BrkCond_T> looks if braking is          ;
	;  necessary due to target position and motion. If so    ;
	;  Procedure replaces the requested speed (field         ;
	;  [SI].IncrX) with new value to perform the braking.    ;
	;  At the entry register SI must contain near pointer to ;
	;  <DrvCoord> structure.                                 ;
	;--------------------------------------------------------;

	global	DC_BrkCond_T		:near

	global	DC_BrkCond_T2		:near	; New version
	global	DC_ChkBrkCond		:near

	;--------------------------------------------------------;
	;  Procedure <DC_BrkCond_E> looks if braking is          ;
	;  necessary due to physical limitation of the current   ;
	;  coordinate. If so the requested speed is being redu-  ;
	;  ced to perform the braking.                           ;
	;  At the entry register SI must contain near pointer to ;
	;  <DrvCoord> structure.                                 ;
	;--------------------------------------------------------;

	global  DC_BrkCond_E		:near

	;--------------------------------------------------------;
	;  Procedure <DC_DivCoeff> takes reduced value of speed  ;
	;  and computes division's coefficient and stores it     ;
	;  in field [SI].DivCoeff.                               ;
	;--------------------------------------------------------;

	global	DC_DivCoeff		:near

	;--------------------------------------------------------;
	;  Procedure <DC_UpdateStatus> updates field [SI].Status ;
	;  at the end of step for current coordinate.            ;
	;--------------------------------------------------------;

	global	DC_UpdateStatus		:near

	;--------------------------------------------------------;
	;  Procedure <DC_IsInside> tests if value of the coord.  ;
	;  specified in register pair {AX,DX} is inside (or on   ;
	;  the border) of the allowed interval for this          ;
	;  coordinate. Returns CF=0 when test passed and CF=1    ;
	;  when the value is outside the interval. In this case  ;
	;  the value is replaced with the nearest point of       ;
	;  the allowed interval.                                 ;
	;--------------------------------------------------------;

	global  DC_IsInside		:near

	;--------------------------------------------------------;
	;  Procedure <DC_GetDrvCorrection> returns correction of ;
	;  current coordinate to take drive error into account.  ;
	;  The part depending on one coordinate only can be      ;
	;  taken into account.                                   ;
	;--------------------------------------------------------;

	global	DC_GetDrvCorrection 	:near

	;--------------------------------------------------------;
	;  Procedure <DC_InvDrvCorr> converts internally used    ;
	;  coordinates back to the system defined by limbs       ;
	;--------------------------------------------------------;

	global	DC_InvDrvCorr		:near

	;--------------------------------------------------------;
	;  Procedure <DC_ApplyHistLim> sets limits of hysteresis ;
	;  argument for specified coordinate                     ;
	;--------------------------------------------------------;

	global  DC_ApplyHistLim		:near
