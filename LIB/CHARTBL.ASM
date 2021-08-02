	.XList
	include LIB.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;   Character table used for processing input data
;   The following values are defined:
;
;		IS_SPACE	equ	001h
;		IS_SPEC		equ	002h
;		IS_EQ		equ	004h	; '='
;		IS_DIGIT	equ	008h
;		IS_HEXDIG	equ	010h
;		IS_ALPHA	equ	020h
;		IS_COMMA	equ	040h
;		IS_EOL		equ	080h
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

CharTable  db   080h, 000h, 000h, 000h, 000h, 000h, 000h, 000h  ; 00-07
	   db	000h, 001h, 001h, 000h, 000h, 001h, 000h, 000h	; 08-0F
	   db	000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h	; 10-17
	   db	000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h	; 18-1F
	   db   001h, 002h, 002h, 002h, 002h, 002h, 002h, 002h  ; 20-27
	   db   002h, 002h, 002h, 002h, 042h, 002h, 002h, 002h  ; 28-2F
	   db   018h, 018h, 018h, 018h, 018h, 018h, 018h, 018h  ; 30-37
	   db	018h, 018h, 002h, 002h, 002h, 006h, 002h, 002h  ; 48-3F      ; 3
	   db   002h, 030h, 030h, 030h, 030h, 030h, 030h, 020h  ; 40-47
	   db   020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h  ; 48-4F
	   db   020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h  ; 50-57
	   db	020h, 020h, 020h, 000h, 000h, 000h, 000h, 000h	; 58-5F
	   db   002h, 020h, 020h, 020h, 020h, 020h, 020h, 020h  ; 60-67
	   db	020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h	; 68-6F
	   db   020h, 020h, 020h, 020h, 020h, 020h, 020h, 020h	; 70-77
	   db	020h, 020h, 020h, 002h, 002h, 002h, 002h, 000h  ; 78-7F
	   db	128 dup (0)

_TEXT	ends
	end
