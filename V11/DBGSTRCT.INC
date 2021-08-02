
		global  I_GetDbgInfo		:near

GI_STAT		equ	0
GI_OPT		equ	1
GI_PREV_TIME	equ	2
GI_CURR_TIME	equ	3
GI_DRV_X	equ	4
GI_DRV_Y	equ	5
GI_DRV_RO	equ	6
GI_TIMING	equ	7
GI_NUM_KB_STAT  equ	8
GI_PORT_INFO	equ	9

                If IOTRACE Ne 0
                        global  InitDbgBuffer           :near
                EndIf

                IF IOTRACE Eq 1
                        global  Dbg_ReadB               :near
			global	Dbg_PortB		:near
			global	Dbg_PortW		:near
			global  Dbg_I8253Data		:near
			global	Dbg_I8253Cmd		:near
			global  Dbg_NextStp             :near
		ElseIf IOTRACE Eq 2
			global	Dbg_IRQ_Time		:near
		ElseIf IOTRACE Eq 3
                        global  Dbg_CoordInfo           :near

			CoordInfo  struc
			  NErr     dw   0
			  NSteps   dw   0
			  DivCoeff dw   0
			  ends

		ENDIF

INITTRACE	macro
		IF IOTRACE Ne 0
			call	InitDbgBuffer
		ENDIF
		endm


RBTRACE		macro
		IF IOTRACE Eq 1
			call	Dbg_ReadB
		ENDIF
		endm

WTRACE		macro
		IF IOTRACE Eq 1
			call 	Dbg_PortW
		ENDIF
		endm


BTRACE		macro
		IF IOTRACE Eq 1
			call	Dbg_PortB
		ENDIF
		endm


TTRACE		macro
		IF IOTRACE Eq 1
			call    Dbg_I8253Data
		ENDIF
		endm


CTRACE		macro
		IF IOTRACE Eq 1
			call	Dbg_I8253Cmd
		ENDIF
		endm

NSTEPS          macro
		if IOTRACE Eq 1
			call    Dbg_NextStp
		ENDIF
		endm

IRQTIME		macro
		if IOTRACE Eq 2
			call	Dbg_IRQ_Time
		ENDIF
		endm

COORD_TRACE	macro
		if IOTRACE Eq 3
			call	Dbg_CoordInfo
		EndIf
		endm
