#include <stdio.h>

long test (long RO, long dRO)
{
	asm     mov	ax , word ptr RO
	asm	mov	dx , word ptr RO+2
	asm	add	ax , word ptr dRO
	asm	adc	dx , word ptr dRO+2
	asm	jl      Inv1
	asm	or	dx , dx
	asm	jne     rOk
	asm	cmp	ax , 2000
	asm	ja	rOk
Inv1: 	asm	mov	ax , 2000
	asm	mov     dx , 0
	asm	mov     word ptr dRO   , ax
	asm	mov     word ptr dRO+2 , dx
rOk:    asm     mov     word ptr RO   , ax
	asm	mov	word ptr RO+2 , dx
	return RO;
}


int main (void)
{
	long  RO = 100000L;
	for (int i=0; i<10000; i++)
	  {
	      RO = test(RO,-123);
	      printf ("  %8ld",RO);
	  }
	printf ("\n");
}
