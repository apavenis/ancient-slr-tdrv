;-----------------------------------------------------------------------
; INT77.ASM     (C) 1994 A. Pavenis
; AMISLIB       Public Domain 1992 Ralf Brown
;
; IRQ 15 simulator for telescope control card test
;
;-----------------------------------------------------------------------

__TINY__ equ 1				; using Tiny model
	INCLUDE AMIS.MAC

        @Startup 3,00                   ; need DOS 2.00

					; this macro also takes care of declaring
					; all the segments in the required order

;-----------------------------------------------------------------------
;
VERSION_NUM equ 0064h   ; v1.00
VERSION_STR equ "1.00"

;-----------------------------------------------------------------------
;
; useful macros
;
LODSB_ES MACRO
	DB 26h,0ACh	; LODSB ES:
	ENDM

;-----------------------------------------------------------------------
; Put the resident code into its own segment so that all the offsets are
; proper for the new location after copying it into a UMB or down into
; the PSP.
;
TSRcode@
start_TSRcode label byte

;-----------------------------------------------------------------------
; Declare the interrupt vectors hooked by the program, then set up the
; Alternate Multiplex Interrupt Spec handler
;
        HOOKED_INTS 08h
        ALTMPX  'Pavenis','INT77',VERSION_NUM,'Telescope control card interrupt simulation'

;-----------------------------------------------------------------------
; Now the meat of the resident portion: timer tick interrupt handler.
; We can save two bytes by specifying the hardware reset handler set up by
; the ALTMPX macro above
;
time_count  dw 0			; patched to actual timeout tick count
period  dw     1

ISP_HEADER 08h
	sti				; allow interrupts
        push    ax
        in      al , 0A1h
        test    al , 128
        jnz     int08_done

        dec     time_count
        test    byte ptr time_count+1 , 128
        jz      int08_done

        mov     ax , period
        mov     time_count , ax
        int     77h

int08_done:
        pop     ax
        JMP     ORIG_INT08h

resident_code_size equ offset $

TSRcodeEnd@

;-----------------------------------------------------------------------

_TEXT SEGMENT 'CODE'
	ASSUME cs:_TEXT,ds:NOTHING,es:NOTHING,ss:NOTHING

banner     db 'INT77 v',VERSION_STR,'  Telescope control card interrupt simulation  (C) 1994 A.Pavenis',13,10
           db 'AMISLIB v0.91   Public Domain 1992 Ralf Brown',13,10,13,10,'$'
usage_msg  db 'Usage:     INT77 n',9,"(n=1-9) interrupt period in clock ticks",13,10
           db '           INT77 R',9,'remove from memory',13,10
	   db "$"
installed_msg    db "INT77 is installed.",13,10,"$"
already_inst_msg db "Different version already installed.",13,10,"$"
timeout_changed_msg db "Time period changed.",13,10,"$"
cant_remove_msg  db "Can't remove from memory.",13,10,"$"
uninstalled_msg  db "INT77 is removed from memory",13,10,"$"

PP      dw ?

	@Startup2	Y
	push	ds
	pop	es
	ASSUME	ES:_INIT
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	;
	; say hello 
	;
	DISPLAY_STRING banner
	mov	bx,1000h		; set memory block to 64K
	mov	ah,4Ah
	int	21h
	mov	si,81h			; SI -> command line
	cld				; ensure proper direction for string ops
cmdline_loop:
	lodsb_es
	cmp	al,' '			; skip blanks and tabs on commandline
	je	cmdline_loop
	cmp	al,9
	je	cmdline_loop
	cmp	al,'1'			; number of minutes specified?
	jb	not_digit
	cmp	al,'9'			; if digit, go install TSR
	jbe	installing
not_digit:
	and	al,0DFh			; force to uppercase
	cmp	al,'R'
	je	removing
usage:
	mov	dx,offset _TEXT:usage_msg
	jmp     exit_with_error

removing:
	UNINSTALL cant_uninstall

	;
	; finally, announce that the resident part has been removed
	;
	push	cs
	pop	ds
	ASSUME	DS:_TEXT
	DISPLAY_STRING uninstalled_msg
successful_exit:
        mov     ax,4C00h
	int	21h

installing:
        sub     al,'1'
	cbw
        mov     PP , ax
	;
	; place any necessary pre-initialization here
	;
	INSTALL_TSR ,BEST,TOPMEM,inst_patch,already_installed

cant_uninstall:
	mov	dx,offset _TEXT:cant_remove_msg
exit_with_error:
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

already_installed:
	cmp	cx,VERSION_NUM		; same version installed?
	jne	wrong_version
	mov	al,0			; request signature string
	int	2Dh
	mov	es,dx			; ES -> resident code
	ASSUME	ES:RESIDENT_CODE
        mov     ax,PP
	mov	time_count,ax
        mov     period,ax
	DISPLAY_STRING timeout_changed_msg
	jmp	successful_exit

wrong_version:
	ASSUME	ES:NOTHING
	mov	dx,offset _TEXT:already_inst_msg
	jmp 	exit_with_error

inst_patch:
	push	es
	mov	es,ax
	ASSUME	ES:RESIDENT_CODE
        mov     ax,PP
	mov	time_count,ax
        mov     period,ax
	pop	es
	ASSUME	ES:NOTHING
	DISPLAY_STRING installed_msg
	ret

_TEXT ENDS

     end INIT

