
                locals
                include LIB.INC

_TEXT           segment byte public 'CODE'
                assume  CS:_TEXT , DS:_TEXT

Pause           proc    near
                pushf
                push    ax
                push    bx
                push    dx

                lea     bx , @@PM
        @@1:    mov     ah , 2
                mov     dl , [bx]
                or      dl , dl
                je      @@2
                int     21h
                inc     bx
                jmp     @@1
        @@2:    mov     ah , 0
                int     16h

                pop     dx
                pop     bx
                pop     ax
                popf
                retn

@@PM            db      10,13
                db      'Program paused...  Press any key to continue'
                db      10,13
                db      0

Pause           endp

                ENDS
                END
