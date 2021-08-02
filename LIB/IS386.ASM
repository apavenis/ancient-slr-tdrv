        .8086
        locals
        .XList
        include LIB.INC
        include OUTPUT.INC
        .List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

Is386           proc    near
                call    DetectCPU
                cmp     ax , 3
                jb      @@TooLow
                retn
@@TooLow:       lea     ax , @@BadCPU
                push    ax
                call    PrintString
                mov     ax , 4C03h
                int     21h
@@BadCPU        db      10,'You need at least 80386 to use this program',10,0
Is386           endp

_TEXT	ends
	end

