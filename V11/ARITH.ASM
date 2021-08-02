
		.286
		.XList
		include ARITH.INC
		.List

_TEXT           segment byte public 'CODE'
		assume  CS:_TEXT , DS:_TEXT

;       *************************************************************
;       *     Procedure 'IDiv42' divides <long int> number with     *
;       *                  unsigned integer number.                 *
;       *   Input:   AX,DX  - long int number (numerator)           *
;       *            BX     - unsigned int number (denominator)     *
;       *   Output:  AX,DX  - (AX,DX)/BX                            *
;       *************************************************************

IDiv42          proc    near
		push    si		; Save registers SI and CX to restore
		push	cx		; them before exit.
		xor	si , si         ; Clear value to be added for rounding
		jz	ID_001
IDiv42R:	push	si		; ENTRY : IDiv42R (the same but the
		push	cx		; the result is rounded to the nearest
		mov	si , bx		; long int number.
		shr	si , 1
ID_001:		mov     ch , dh		; Save high byte of arg. with sign
		call	labs		; Take abs. value of arg.
		add	ax , si		; Add value for rounding (when not 0)
		adc	dx , 0
		push    ax              ; Save low word.
		mov     ax , dx         ; Make unsigned long number from the
		xor     dx , dx		; high word of abs(argument)
		div     bx              ; Divide and save the high word
		mov     si , ax		; result in SI.
		pop     ax		; Restore low word of arg. into AX.
		div     bx		; Divide and restore high word of
		mov     dx , si		; result in DX.
		or      ch , ch		; Look for argument sign and invert
		jnl     ID_02		; result when negative.
		call	lneg
ID_02:          pop	cx		; Restore registers CX and SI from
		pop     si		; stack and return. AX,DX now
		ret			; contains the result (DX-high word)
IDiv42          endp

;	***************************************************************
;	*   Procedure 'IMod42' computes remainder after division long *
;	* int number with unsigned int one. The remainder is always   *
;	* reduced to positive number.                                 *
;	* INPUT:  AX,DX - long int number , BX - unsigned number      *
;	* OUTPUT: AX - remainder.                                     *
;	***************************************************************

IMod42		proc    near
		push	cx
		mov     ch , dh
		call	labs
		push	ax
		mov	ax , dx
		xor 	dx , dx
		div	bx
		pop	ax
		div	bx
		mov	ax , dx
		or	ch , ch
		jz      IM_001
		neg	ax
		add	ax , bx
IM_001:         xor	dx , dx
		pop	cx
		retn
IMod42		endp


;	*************************************************************
;       *   Procedures <IMlt4RN> and <IMlt4RNU> computes product of *
;	* long int number with rational number. The result is set   *
;	* max. or min. number when overflow is detected.            *
;	* Arguments:						    *
;       *   AX,DX  - long int number                                *
;	*   BX     - numerator        (unsigned for IMlt4RNU and    *
;	*   CX     - denominator       int for IMlt4RN)             *
;	* Result:                                                   *
;       *   AX,DX  = (AX,DX) * (BX/CX)                              *
;	* The result is rounded to the nearest long int number      *
;	*************************************************************

IMlt4RN		proc	near
		local   @@flags	:  word ,	\
			@@arg1	: dword ,	\
			@@num	:  word ,       \
			@@den	:  word         \
			= LocBytes
		enter   LocBytes , 0
		push	si
		mov	@@flags , 0
		jmp     IM_Start

IMlt4RNU:       enter	LocBytes , 0
		push	si
		mov	@@flags , 0
		mov     @@num , bx
		jmp	IM_DenOk

IM_Start:	or	bx , bx
		jnl	IM_NumOk
		neg	bx
		xor	@@flags , 1
IM_NumOk:       mov	@@num , bx
		or	cx , cx
		jnl	IM_DenOk
		neg	cx
		xor	@@flags , 1
IM_DenOk:       or	cx , cx
		jnz	IM_004
		or	@@flags , 2  	; Division by zero error: Set error
		xor	ax , ax		; flag and return  0L
		xor	dx , dx
		jmp	IM_ResultOk
IM_004:		mov	@@den , cx
		mov	si , cx
		shr	si , 1
		or	dx , dx
		jnl     IM_ArgOk
		call	lneg
		xor	@@flags , 1
IM_ArgOk:	mov     word ptr @@arg1 , ax
		mov	word ptr @@arg1+2 , dx

		mul	@@num
		mov	bx , ax
		mov	cx , dx
		mov	ax , word ptr @@arg1+2
		mul	@@num
		add	ax , cx		; Now the product is in registers
		adc	dx , 0		; {BX,AX,DX} (DX_high word)

		adc	bx , si
		add     ax , 0
		add	dx , 0

		cmp	dx , si
		jae     IM_Overflow

		div     @@den
		push	ax
		mov	ax , bx
		div     @@den
		pop	dx
		jmp     IM_006

IM_Overflow:    mov	ax , 0FFFFh
		mov	dx , 07FFFh
		or	@@flags , 2

IM_006:		test	@@flags , 1
		jz      IM_ResultOk

                call    lneg

IM_ResultOk:    clc
		test	@@flags , 2
		jz	IM_Ret
		stc
IM_Ret:         pop	si
		leave
		retn

IMlt4RN         endp

;       ***************************************************************
;       *  Procedure 'ldiv' divides two 32-bit signed integer numbers *
;       *                                                             *
;       *  Input:                                                     *
;       *     DX,AX  - numerator (DX-high word)                       *
;       *     CX,BX  - denominator (CX-high word)                     *
;       *  Output:                                                    *
;       *     DX,AX  - quotient (DX-high word)                        *
;       *     CX,BX  - remainder (CX-high word)                       *
;       ***************************************************************

ldiv            proc    near
		push    bp
		push    si
		push    di

		; Numerator is already in correct registers AX & DX
		; Now move denominator to BP,BX

		mov     bx , bx
		mov     bp , cx

		xor     cx , cx
		xor     si , si                 ; Zero low word of high 32
						; bits of 64-bit remainder
		;  Signed division should be done:
		;  -- convert negative values to positive ones and do an
		;     unsigned division. Store the sign value in the next
		;     higher bit of CL ( test mask of 4). Thus when we are
		;     done, testing this bit will determine the sign of the
		;     result

		or      dx , dx                 ; Negate numerator if negative
		jns     PosNumer                ; number
		neg     dx
		neg     ax
		sbb     dx , si
		inc     cl
PosNumer:
		or      bp , bp                 ; Negate denominator if
		jns     PosDenom                ; negative number
		neg     bp
		neg     bx
		sbb     bp , si
		xor     cl , 1

PosDenom:       push    cx              ; Save sign of the result

		mov     di , bp         ; Use machine divide if high words
		or      di , dx         ; are both zero
		jnz     noQuickDiv
		div     bx
		xchg    si , dx
		jmp     commonOut

noQuickDiv:     mov     cx , 32         ; Shift counter
		mov     di , si         ; Fake a 64 bit dividend (clear high
					;  word)
xLoop:          shl     ax , 1
		rcl     dx , 1
		rcl     si , 1
		rcl     di , 1
		cmp     di , bp         ; Dividend larger
		jb      noSub
		ja      Substract
		cmp     si , bx         ; Maybe
		jb      noSub

Substract:      sub     si , bx
		sbb     di , bp         ; Substarct the divisor
		inc     ax              ; Build quotient
noSub:          loop    xLoop

		; When done with the loop the four registers look like:
		;
		;  |  di  |  si  |  dx  |  ax  |
		;  |  remainder  |  quotient   |

commonOut:      pop     cx              ; Restore sign of the result
		jcxz    Divided
		neg     di              ; Negate remainder
		neg     si
		sbb     di , 0
		neg     dx              ; Negate quotient
		neg     ax
		sbb     dx , 0

Divided:        ; Quotient is already where it must be (AX & DX)
		; Now move remainder to (BX & CX)

		mov     cx , di
		mov     bx , si

		pop     di
		pop     si
		pop     bp
		ret
ldiv            endp


;[]-----------------------------------------------------------------[]
;|      N_LXMUL.ASM -- long multiply routine                         |
;|                                                                   |
;|      C/C++ Run Time Library        Version 4.0                    |
;|                                                                   |
;|      Copyright (c) 1987, 1991 by Borland International Inc.       |
;|      All Rights Reserved.                                         |
;[]-----------------------------------------------------------------[]

;       INCLUDE RULES.ASI

; calls to this routine are generated by the compiler to perform
; long multiplications.

; There is no check for overflow.  Consequently, the same routine
; is used for both signed and unsigned long multiplies.

;
; in:
;       (dx:ax) - 32bit arg1
;       (cx:bx) - 32bit arg2
; out:
;       (dx:ax) - 32bit product
;
; reg use: bx,cx destroyed, all others preserved or contain result.
;
; hi(result) := lo(hi(arg1) * lo(arg2)) +
;               lo(hi(arg2) * lo(arg1)) +
;               hi(lo(arg1) * lo(arg2))
; lo(result) := lo(lo(arg1) * lo(arg2))
;

N_LXMUL         PROC    NEAR
		push    si
		xchg    si, ax          ; save lo1
		xchg    ax, dx
		test    ax, ax          ; skip mul if hi1==0
		jz      nohi1
		mul     bx              ; hi1 * lo2

nohi1:          ; if we jumped here, ax==0 so the following swap works
		jcxz    nohi2           ; skip mul if hi2==0
		xchg    cx, ax          ; result <-> hi2
		mul     si              ; lo1 * hi2
		add     ax, cx          ; ax = hi1*lo2 + hi2*lo1
nohi2:
		xchg    ax, si
		mul     bx              ; lo1 * lo2
		add     dx, si          ; hi order result += partials
		pop     si
		ret
N_LXMUL         ENDP

;
;       ************************************************************
;       *    Procedure 'labs' finds absolute value of long         *
;       * integer number placed in registers DX and AX. The result *
;       * is returned in the the same registers                    *
;       ************************************************************
;
labs            proc    near
		or      dx , dx
		jns     labs_done
lneg:           not     ax
		not     dx
		add     ax , 1
		adc     dx , 0
labs_done:      ret
labs            endp

;
;       *********************************************************
;       *   Procedure  'lsort2'  returns min. of two long       *
;       * integer numbers in register pair DX & AX and max one  *
;       * in CX & BX. Arguments must be specified in register   *
;       * pairs (DX & AX) and (CX & BX)                         *
;       *********************************************************
;
lsort2          proc    near
		cmp     dx , cx
		jl      ls_done
		jg      ls_swap
		cmp     ax , bx
		jbe     ls_done
ls_swap:        xchg    ax , bx
		xchg    dx , cx
ls_done:        ret
lsort2          endp

;
;       *********************************************************
;       *   Procedure 'lshift8' shifts register pair (DX,AX)    *
;       * 8 bits left. Procedure 'rshift8' does the same on the *
;       * other side.                                           *
;       *********************************************************

lshift8         proc    near
		mov     dh , dl
		mov     dl , ah
		mov     ah , al
		xor     al , al
		ret
rshift8:        test    al , 128        ; Look if rounding is necessary
		je      rs_02
		add     ah , 1
		adc     dx , 0
rs_02:          mov     al , ah
		mov     ah , dl
		sar     dx , 8
		ret
lshift8         endp


;       *************************************************************
;       *   Procedure <IsInside> tests if value value in register   *
;       * pair {AX,DX} is inside interval between two long int      *
;       * numbers that address is  DS:BX. ( long edges[2] )         *
;       * Returns:  CF=1 when value is outside the interval         *
;       *           CF=0 - when inside or on the border             *
;       *           {AX,DX} contains nearest to specified value     *
;       *                   point in the interval                   *
;       *   All registers except AX and DX remains intact.          *
;       *   Interval description must contain at first the minimal  *
;       * value then the maximal one. No test is done for this      *
;       * condition!                                                *
;       *************************************************************

IsInside        proc    near
		cmp     dx , word ptr [bx+2]
		jg      II_Test2
		jl      II_Failed1
		cmp     ax , word ptr [bx]
		jae     II_Test2
II_Failed1:     mov     ax , word ptr [bx]
		mov     dx , word ptr [bx+2]
		stc
		ret
II_Test2:       cmp     dx , word ptr [bx+6]
		jl      II_Done
		jg      II_Failed2
		cmp     ax , word ptr [bx+4]
		jbe     II_Done
II_Failed2:     mov     ax , word ptr [bx+4]
		mov     dx , word ptr [bx+6]
		stc
		ret
II_Done:        clc
		ret
IsInside        endp



_TEXT           ends
		end
