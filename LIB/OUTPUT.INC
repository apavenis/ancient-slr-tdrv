
	;-------------------------------------------------------------;
	;   Procedure <ltoax> converts long int or long unsigned      ;
	; number to ASCII form. Arguments must be pushed in the stack.;
	; procedure cleans stack itself after return.                 ;
	;   ARGUMENTS:                                                ;
	;     Value:dword	- double word to be converted         ;
	;     Buffer:dword	- far pointer to the buffer where the ;
	;                         result will be placed.              ;
	;     Type:word		- the high byte of this argument      ;
	; 			  contains different flags that sets  ;
	;	                  how to convert number. The low one  ;
	;                         contains radix (2...36 , 10 - for   ;
	;                         decimal system)                     ;
	;     Len:word		- minimal length of output. It is the ;
	;	                  maximal one too when the bit        ;
	;	                  DEF_LENGTH is set to 1.             ;
	;  !!! 286+ necessary
	;-------------------------------------------------------------;

	global	ltoax		:near	; LTOAX.ASM

			SIGNED_LONG	equ	8000h
			LEADING_ZEROS	equ	4000h
			DEF_LENGTH	equ	2000h
			PLUS_SIGN	equ	1000h
			CHECK_SIZE	equ	0800h

;/////////////////////////////////////////////////////////////////////////////
;	FILE	: PRINTF.ASM
;////////////////////////////////////////////////////////////////////////////

	global	_PrintF		:near	;

;/////////////////////////////////////////////////////////////////////////////
;	FILE	: PRINTF.ASM
;////////////////////////////////////////////////////////////////////////////

        global  Print_R         :near   ;

PrMessage       macro   Text
                call    Print_R
                db      Text
                db      0
                endm

;/////////////////////////////////////////////////////////////////////////////
;	FILE 	: OUTPUT.INC
;
;	This file contains descriptions of different assembler language
;   procedures that can be used to output data to <stdout>.
;/////////////////////////////////////////////////////////////////////////////

	;---------------------------------------------------------------;
	;    Macrodefinition to output a message                        ;
	;---------------------------------------------------------------;

Message		macro	text
		local	W1,W2
		jmp	W2
W1              db      text,0
W2:		push    Offset W1
		call	PrintString
		call	NewLine
		endm

	;---------------------------------------------------------------;
	; <PrintString> outputs zero terminated ASCII string to  STDOUT.;
	; USE:		push 	Offset <ASCII string>                   ;
	;		call	near ptr PrintSTring                    ;
	;---------------------------------------------------------------;

		global	PrintString		:Near

	;---------------------------------------------------------------;
	; <PrintFarPtr> outputs far pointer that is placed in registers ;
	; AX and DX(high word)  [in form DX:AX]                         ;
	;---------------------------------------------------------------;

		global  PrintFarPtr		:Near

	;---------------------------------------------------------------;
	; Procedures <PrintHexWord>, <PrintHexByte>, <PrintHexDigit>    ;
	; outputs word,byte or 1 digit in hexadecimal form. The word    ;
	; must be placed in register AX, byte in AL but digit in four   ;
	; lower bits of AL.                                             ;
	;---------------------------------------------------------------;

		global  PrintHexWord		:Near
		global	PrintHexByte		:Near
		global	PrintHexDigit		:Near

	;---------------------------------------------------------------;
	; Procedures <PrintUnsigned>, <PrintInteger>, <PrintLong> and   ;
	; <PrintUnsignedLong> outputs numbers in decimal form. Long     ;
	; numbers must be placed in registers AX and DX(high word),     ;
	; other numbers in register AX                                  ;
	;---------------------------------------------------------------;

		global	PrintUnsigned		:Near
		global	PrintInteger		:Near
		global	PrintUnsignedLong	:Near
		global	PrintLong		:Near

	;---------------------------------------------------------------;
	; Procedure <PrintBByte> outputs byte from AL in bit form       ;
	;---------------------------------------------------------------;

		global  PrintBByte		:Near

	;---------------------------------------------------------------;
	; Procedure <NewLine> outputs bytes  CR and LF                  ;
	;---------------------------------------------------------------;

		global  NewLine			:Near

	;---------------------------------------------------------------;
	; Procedure <PrintChar> outputs selected byte to STDOUT. When   ;
	; byte is LF then at first CR is being written.                 ;
	;---------------------------------------------------------------;

		global  PrintChar		:Near

