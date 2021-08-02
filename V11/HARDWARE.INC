
;OutRegister     =       AX
 OutRegister     =       AL


OutInfo		struc
port            dw      ?
value   	db      ?
		ends

;	*************************************************************
;	*     Port addresses and masks for telescope control card   *
;	*************************************************************

P_ResetClkCounter    equ     01A0h  ; Disables 5 MHz until next full second
				    ; (Can be used for synchronization)

P_EnableShoot        equ     01A2h  ; Enables laser shoot at next 0.1 sec.
				    ; (of course when chanal commutator is
				    ; OK)

P_ClearIRQ15	     equ     01A6h  ; Output to this port resets IRQ15 request
				    ; line if one is set.

P_GateLW             equ     01A8h  ; Lower 4 bits in this port contains
				    ; gate delay mod 16 (in units of 0.2 mks)
				    ; The remaining 16 bits must be written
				    ; to I8253 chanal 2 (Port 01BEh)

P_WriteStatus	     equ     01AAh  ; Byte written in this port specifies
				    ; the current speed and gate types:
				    ; .... ...X : 1 enables motion for 1-st.
				    ;             coordinate
				    ; .... ..X. : 1 enables motion for 2-nd.
				    ;             coordinate
				    ; .... .X.. : sign for 1-st. coord.
				    ; .... X... : sign for 2-nd. coord.
				    ; ...X .... : enable gate for calibration
				    ; ..X. .... : enable gate for ranging

P_RdStatus	     equ     01ACh  ; Reading this port returns status of
				    ; full second signal and one of zero
				    ; points. The following bits are defined:
				    ;  .... ...X - 0 - the first 20 ms  after
				    ;              full second
				    ;  .... ..X. - 0 - Zero point for coord 1.
				    ;  .... .X.. - 0 - Zero point for coord 2.

;================== Ports for first I8253 chip ===============================

P_DivCoeff_1        equ      01B0h  ; Port where to write division coeff.
				    ; for coord 2. (Chanal 0, Mode 2)
P_DivCoeff_2	    equ      01B2h  ; Port where to write word that contains
				    ; division coeff. for 1-st. coord
				    ; (Chanal 1, Mode 2)
P_Window	    equ      01B4h  ; Window width in units of 1.6 mks.
				    ; (Chanal 2, Mode 5)
P_CmdA		    equ	     01B6h

M_DivCoeff	    equ	     2      ; Mode for chanels 0,1
M_Window	    equ	     1	    ; Mode for chanel  2

;================== Ports for second I8253 chip ==============================

P_ChanalCommutator  equ      01B8h  ; Port where to write delay for chanal
				    ; commutator (Chanal 0, Mode 5)
P_Timer		    equ      01BAh  ; Port where to write division coeff. for
				    ; 0.1 sec. timer. (Chanal 1, Mode 2,
				    ; correct value is 62500 for 0.1 sec.)
P_GateH	    	    equ      01BCh  ; Port where to write delay of the begin
				    ; of the time gate. (Upper 16 bits of 20)
P_CmdB		    equ      01BEh  ; Port where to write I8253 commands

M_ChanalCommutator  equ	     5
M_Timer		    equ	     2
M_GateH		    equ	     5

;	*************************************************************
;	*     Bit masks for port [P_RdStatus]                       *
;	*************************************************************

P_IS_FULL_SECOND	equ     001h	; 0 - when full second
P_IS_ZERO_1		equ	002h	; 0 - when active
P_IS_ZERO_2		equ	003h	; 0 - when active

;	*************************************************************
;	*     Bit masks for port [P_WriteStatus]                    *
;	*  All these options are active when bit is 1               *
;	*************************************************************

P_CoordA_ON		equ	001h
P_CoordB_ON		equ	002h
P_CoordA_SIGN		equ	004h
P_CoordB_SIGN		equ	008h
P_EnableCalibrGate      equ	010h
P_EnableSatGate		equ	020h

;	*************************************************************
;	*     Bit masks for I8253 commands (P_I8253_Command)        *
;	*************************************************************

I8253_SELECT_0	equ	00h	; Select chanal 0
I8253_SELECT_1  equ     40h	; Select chanal 1
I8253_SELECT_2  equ	80h	; Select chanal 2

I8253_LATCH	equ	00h	; Request to fix value for specified chanal
I8253_LOW_BYTE	equ	10h	; R/W low byte only
I8253_HIGH_BYTE equ	20h	; R/W high byte only
I8253_WORD	equ	30h	; R/W low byte then high byte

I8253_MODE_0	equ	00h
I8253_MODE_1    equ	02h
I8253_MODE_2    equ     04h	; Genarate frequency using counter
I8253_MODE_3	equ     06h
I8253_MODE_4	equ	08h
I8253_MODE_5	equ	0Ah	; Generate single strobe. Auxiliary start

I8253_BINARY	equ     00h
I8253_DECIMAL	equ	01h


ClockDivisor	equ	0F424h	; = 1000000.0 / 1.6 = 62500

;	*************************************************************
;	*     Module  HARDWARE.ASM                                  *
;	*************************************************************

		global	OutputDC		:near

		global	FillOutpBuffer		:near

		global	IsFullSecond?		:near

		global  InitCard                :near

		;------------------------------------------------------------
		; Procedure <InitializeTimer> starts 0.1 second timer
		; initialization sequence. User can watch bit
		; SYNCHRONIZATION_OK in DRV_STAT for end of this sequence.
		;------------------------------------------------------------

		global	InitializeTimer		:near

		;------------------------------------------------------------
		; Procedure <ReadCardStatus> returns value read from port
		; 0x01AC in register _AL.
		;------------------------------------------------------------

		global	ReadCardStatus		:near

		;------------------------------------------------------------
		; Procedure <Set_CC_Strobe> sets delay for chanal commutator
		;------------------------------------------------------------

		global	Set_CC_Strobe		:near

		;------------------------------------------------------------
		; Procedures <I8253_WriteC> and <I8253_Write> performs
		; outputs word to I8253 chip.
		;------------------------------------------------------------

		global	I8253_WriteC		:near
		global	I8253_Write		:near

;	***************************************************************
;	*    Module LSHOOT.ASM                                        *
;	***************************************************************

		global	LNextTime		:dword
		global	LIncrTime		:word
		global	LAlign			:word
		global	WindowWidth		:dword
		global  gateShift		:dword
		global  LShootStat		:word
			L_ENABLE_SHOOT=08000h

		global	LShootInit		:near
		global	I_LaserCtrl		:near
                global  LaserEnable             :near
                global  LaserDisable            :near

		global	LCtrlShoot		:near
		global  LWriteWindow		:near

		global	SetWindow		:near



;=============================================================================
;	The definitions of symbolic constants and data for second telescope
;   control card.
;=============================================================================

P2_FixTime	equ	0120h	; Any write to this address reads time from
				; sinchronometer, that can be later accessed
				; through ports 120h and 122h (both 16 bit!)
P2_Clk1		equ	0120h	; *10 ns as BCD
P2_Clk2		equ	0122h	; *100 mks as BCD

P2_Coord1	equ	0124h   ; L:   H,A (low)
P2_Coord2	equ	0126h   ; L:   H,A (high)    0.1:  H,A (high)
P2_Coord3	equ	0128h   ; 0.1: H,A (low)

P2_ResetCA	equ	012Ah	; Reset step counter for 1-st coord
P2_ResetCB	equ     012Ch	; Reset step counter for 2-nd coord

P2_RdStatus     equ     012Eh   ; Get status for 2-nd card

	C2_Stop		equ	1   ; Stop line caused time registration
	C2_Start	equ	2   ; Start line caused time registration
	C2_CPU		equ	4   ; Write to 12Xh caused time registration
	C2_Error	equ	8   ; Error line is active


		global	ReadStepCnt	:Near

;	************************************************************
;	*    Module : IRQ12                                        *
;	************************************************************

		global	IRQ_0C_PROC		:FAR
		global	I_TmFunct		:Near
		global	ClearTMBuf		:Near
		global	TM_GetRaw		:Near
		global	TM_Get			:Near
