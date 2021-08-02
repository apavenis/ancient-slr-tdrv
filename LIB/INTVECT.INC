;/////////////////////////////////////////////////////////////////////////////
;       FILE	: INTVECT.INC
;
;	Defines procedures for setting interrupt vectors while installing
;   TSR and restoring old ones when removing TSR from memory (if it is
;   possible. Procedures outputs messages about changes done to the standard
;   output.
;/////////////////////////////////////////////////////////////////////////////

	;-------------------------------------------------------------;
	;     Structure for information about interrupt vectors that  ;
	; have to be changed and the changes actually made.           ;
	;-------------------------------------------------------------;

IntInfo		struc
Num		db	?      ;; Number of interrupt
SaveMask	db	?      ;; Must IRQ be anabled (valid for IRQ's only)
NewVectOff	dw	?      ;; Offset of the new interrupt vector.
NewVectSeg      dw	?      ;; Segment of the new interrupt vector.
OldVect 	dd 	?      ;; Old interrupt vector (fills <ReplaceVect>)
PrevMask	db	?      ;; Previos IRQ mask (when saved).
		ends


	;------------------------------------------------------------;
	;    Procedure <ReplaceVect> replaces interrupt vectors with ;
	; new ones and saves previous vectors. The interrupt contro- ;
	; ller mask is changed for IRQ's when that is requested.     ;
	;    ARGUMENT:  WORD [BP+4] - offset of the array of type    ;
	;               <IntInfo> that contains information about    ;
	;               interrupts to be changed. 0 in Num field     ;
	;               is interpretted as the end of table          ;
	;------------------------------------------------------------;

		global	ReplaceVect		:near

	;------------------------------------------------------------;
	;    Procedure <RestoreVect> test whether all interrupt      ;
	; vectors previously set by <ReplaceVect> are not changed.   ;
	; If so procedure undoes all that is done by <ReplaceVect>.  ;
	; Vectors are restored in reverse order. Returns AX=0 if     ;
	; all vectors are restored or -1 if one or more interrupt    ;
	; vectors are changed and cannot be restored.                ;
	;    ARGUMENT:  DWORD [BP+4] - far pointer to <IntInfo>      ;
	;               array previously used for call to            ;
	;               <ReplaceVect>.                               ;
	;------------------------------------------------------------;

		global	RestoreVect		:near

        ;------------------------------------------------------------;
        ;    Global variable <IV_Silent> suppresses informative      ;
        ; messages about interrupt vector changes when not zero      ;
        ;------------------------------------------------------------;

                global  IV_Silent               :byte

