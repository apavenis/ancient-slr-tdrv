;/////////////////////////////////////////////////////////////////////////////
;	FILE	: ARGLIST.INC
;
;	Contains definitions of procedures that processes command line
;   options
;/////////////////////////////////////////////////////////////////////////////

ArgInfo		struc
arg_sub		dw	?
arg_type	db	?
arg_len		db	?
arg_txt		dw	?
		ends

ARG_NOCASE	equ	80h

	;-------------------------------------------------------------;
	;   'CopyArg' copies argument string specified in command     ;
	; line to internal buffer and appends 0 at the end of string. ;
	; All letters in this string is converted to uppercase.       ;
	; Call to this procedure is necessary before call to other    ;
	; ones.                                                       ;
	;-------------------------------------------------------------;

		global	CopyArg		:near

	;-------------------------------------------------------------;
	;   'GetWord' returns next word from command line. At the     ;
	; 1-st call after 'CopyArg' it returns the 1-st arg. The      ;
	; offset to zero terminated string that contains current      ;
	; item is returned in SI. If SI is equal to 0 then all items  ;
	; are processed.                                              ;
	;-------------------------------------------------------------;

		global	GetWord		:near

	;-------------------------------------------------------------;
	;   Arglist ( ArgInfo w[] ) processes argument list and calls ;
	; procedures specified for each parameter.                    ;
	; Procedure returns 0 on success or near pointer to the first ;
	; invalid parameter.                                          ;
	;-------------------------------------------------------------;

		global	ArgList		:near

