	.XList
	include LIB.INC
	.List

_TEXT	segment	byte public 'CODE'
	assume  cs:_TEXT , ds:_TEXT

                public  DetectCPU

;=============================================================================
;     Procedure <DetectCPU> returns type of CPU that is being used:
;  Returns value in register AX:
;	1:  8086 or 8088
;	2:  80286
;	3:  80386 or 80486 or ...
;=============================================================================
;
DetectCPU	Proc	Near
                pushf
                xor     ax,ax
		push	ax
		popf
		pushf
		pop	ax
		and	ax,0F000h
		cmp	ax,0F000h
		je	L_0046
		mov	ax,0F000h
		push	ax
		popf
		pushf
		pop	ax
		and	ax,0F000h
		je	L_0042
		mov	ax,0003
                popf
		ret
L_0042: 	mov	ax,0002
                popf
		ret
L_0046: 	mov	ax,0001
                popf
		ret
DetectCPU	EndP

_TEXT	ends
	end
