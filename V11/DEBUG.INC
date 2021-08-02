R_CheckSum	macro	addr
                mov     CS:addr , ss
                xor     CS:addr , sp
                xor     CS:addr , ax
                xor     CS:addr , bx
                xor     CS:addr , cx
                xor     CS:addr , dx
                xor     CS:addr , bp
                xor     CS:addr , si
                xor     CS:addr , di
		push	ax
		mov	ax , ds
                xor     CS:addr , ax
		mov	ax , es
                xor     CS:addr , ax
		pop	ax
		endm
