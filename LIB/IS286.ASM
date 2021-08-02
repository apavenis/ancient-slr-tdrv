        .8086
        locals
        .XList
        include LIB.INC
        include OUTPUT.INC
        .List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

Is286           proc    near
                call    DetectCPU
                cmp     ax , 2
                jb      @@TooLow
                retn
@@TooLow:       lea     ax , @@BadCPU
                push    ax
                call    PrintString
                mov     ax , 4C03h
                int     21h
@@BadCPU        db      10,'You need at least 80286 to use this program',10,0
Is286           endp

_TEXT	ends
	end

