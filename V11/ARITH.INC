;/////////////////////////////////////////////////////////////////////////////
;	FILE	: ARITH.INC
;
;	Contains the descriptions of various procedures for manipulations
;   on 32-bit integer numbers
;/////////////////////////////////////////////////////////////////////////////

	;-------------------------------------------------------------;
	;   Procedures <IDiv42> and <IDiv42R> divides 32 bit signed   ;
	; integer number with unsigned integer number.                ;
	; INPUT:  AX(low) and DX(high) - long int number (numerator)  ;
	;         BX - unsigned int number (denomenator)              ;
	; OUTPUT: AX(low) and DX(high) - the result (long int too)    ;
	;                                                             ;
	; <IDiv42> ignores the remainder.                             ;
	; <IDiv42R> rounds result to the nearest long int number.     ;
	;-------------------------------------------------------------;

		global	IDiv42		:Near
		global	IDiv42R		:Near

	;-------------------------------------------------------------;
	;   Procedure <IMod42> finds remainder after dividing long    ;
	; int number in register pair {AX,DX} with unsigned number    ;
	; that is specified in register BX. The remainder is returned ;
	; in register AX. Procedure changes AX and DX. Other          ;
	; registers remain intact.                                    ;
	;-------------------------------------------------------------;

		global	IMod42		:Near


	;-------------------------------------------------------------;
	;   Procedures <IMlt4RN> and <IMlt4RNU> computes product of   ;
	; long int number with rational number. The result is set     ;
	; max. or min. number when overflow is detected.              ;
	; Arguments:						      ;
	;    AX,DX  - long int number                                 ;
	;    BX     - numerator        (unsigned for IMlt4RNU and     ;
	;    CX     - denominator       int for IMlt4RN)              ;
	; Result:                                                     ;
	;    AX,DX  = (AX,DX) * (BX/CX)                               ;
	; The result is rounded to the nearest long int number        ;
	;-------------------------------------------------------------;

		global	IMlt4RN		:near
		global	IMlt4RNU	:near

	;-------------------------------------------------------------;
	;   Procedure <ldiv> divides two long int numbers and returns ;
	; quotient and remainder                                      ;
	; INPUT:                                                      ;
	;    DX(high) , AX(low)  : numerator                          ;
	;    CX(high) , BX(low)  : denominator                        ;
	; OUTPUT:                                                     ;
	;    DX(high) , AX(low)  : quotient                           ;
	;    CX(high) , BX(low)  : remainder                          ;
	;-------------------------------------------------------------;

		global	ldiv		:near

	;-------------------------------------------------------------;
	;   Procedure <N_LXMUL> performs 32 bit multiplication        ;
	; INPUT:   (DX,AX) - arg1  and  (CX,BX) - arg2                ;
	; OUTPUT:  (DX,AX) - result                                   ;
	;-------------------------------------------------------------;

		global	N_LXMUL		:near

	;-------------------------------------------------------------;
	;   Procedure <labs> takes absolute value of long int number  ;
	; in registers (DX,AX). The return value is in (DX,AX) too.   ;
        ; <lneg> changes sign of the value in registers (DX,AX)       ;
        ;-------------------------------------------------------------;

		global	labs		:near
                global  lneg            :near

	;-------------------------------------------------------------;
	;   Procedure <lsort2> takes as arguments two long integer    ;
	; numbers [register pairs (DX,AX) and (CX,BX)] and returns    ;
	; the greater of them in (CX,BX), the lesser one in (DX,AX).  ;
	;-------------------------------------------------------------;

		global	lsort2		:near

	;-------------------------------------------------------------;
	;   Procedure <lshift8> (<rshift8>) performs shift of long int;
	; number 8 bits left (right). Argument must be placed in reg. ;
	; (DX,AX). <rshift8> round the result to nearest number too   ;
	;-------------------------------------------------------------;

		global	lshift8		:near
		global	rshift8		:near

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
	;-------------------------------------------------------------;

		global	ltoax		:near

			SIGNED_LONG	equ	8000h
			LEADING_ZEROS	equ	4000h
			DEF_LENGTH	equ	2000h
			PLUS_SIGN	equ	1000h
			CHECK_SIZE	equ	0800h


	;--------------------------------------------------------------;

		global  IsInside	:near

	;--------------------------------------------------------------;
	;    Procedures ISIN and ICOS computes trigonmetric functions  ;
	; using integer arithmetic only (3 significant digits)         ;
	;   ARGUMENTS:                                                 ;
	;      AX - argument of function in units of 0ø.1              ;
	;   RETURNS value of function times 10000 in register AX.      ;
	;   Other registers remains intact.                            ;
	;--------------------------------------------------------------;

		global	ISIN		:near
		global	ICOS		:near

