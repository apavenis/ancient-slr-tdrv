#include  <dos.h>

unsigned long  RdTime ()
  {
	asm	cli			//   Mask all iterrupts
	asm	push	es
	asm	push	bx
	asm	mov	ax , 0x0040     // Segment where BIOS variables area
	asm	mov	es , ax		// os located
	asm	xor	al , al
	asm	out	0x43 , al	// Command to fix 8254 timer
	asm	mov	dx , es:[0x6C]  // Read lower word of clock counter
	asm	in 	al , 0x40
	asm	xchg	al , ah
	asm	in	al , 0x40
	asm	xchg	al , ah
	asm	not	ax
	asm	cmp	ax , 0x00100
	asm	ja	L2
	asm	push	ax
	asm	mov	al , 0x0A
	asm	out	0x20 , al
	asm	in	al , 0x20
	asm	test	al , 1
	asm	jz      L1
	asm	inc	dx
L1:	asm	pop	ax
L2:	asm	sti
	asm	pop	bx
	asm	pop	es
	return  (unsigned long) MK_FP(_DX,_AX);
  }
