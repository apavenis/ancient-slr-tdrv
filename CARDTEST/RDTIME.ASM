_TEXT           segment byte public 'CODE'
                assume  cs:_TEXT

                locals

                public  RdTime

RdTime          proc    near
                cli                     ; Mask all iterrupts
                push    es
                push    bx
                mov     ax , 040h       ; Segment where BIOS variables area
                mov     es , ax         ; os located
                xor     al , al
                out     43h , al        ; Command to fix 8254 timer
                mov     dx , es:[06Ch]  ; Read lower word of clock counter
                in      al , 40h
                xchg    al , ah
                in      al , 40h
                xchg    al , ah
                not     ax
                cmp     ax , 00100h
                ja      @@2
@@0:            push    ax
                mov     al , 0Ah
                out     20h , al
                in      al , 20h
                test    al , 1
                jz      @@1
                inc     dx
@@1:            pop     ax
@@2:            sti
                pop     bx
                pop     es
                retn
RdTime          endp

                ends
                end
