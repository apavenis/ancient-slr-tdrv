        locals
        .XList
        include LIB.INC
        include OUTPUT.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

DosMin          proc    near
                mov     MinVer,ax       ; Save min. version number
                mov     ah , 30h        ; DOS Fn 30h : Get DOS version
                int     21h
                cmp     al , byte ptr MinVer+1
                ja      @@DosOk
                jb      @@DosTooLow
                cmp     ah , byte ptr MinVer
                jb      @@DosTooLow
@@DosOk:        retn
@@DosTooLow:    lea     ax , @@M1
                push    ax
                call    PrintString
                mov     al , byte ptr MinVer+1
                call    PrintHexDigit
                mov     al , '.'
                call    PrintChar
                mov     al , byte ptr MinVer
                aam
                xchg    al , ah
                call    PrintHexDigit
                xchg    al , ah
                call    PrintHexDigit
                call    NewLine
                mov     ax , 4C03h
                int     21h

@@M1            db      'You need at least DOS version ',0
MinVer          dw      ?
DosMin          endp


_TEXT	ends
	end

