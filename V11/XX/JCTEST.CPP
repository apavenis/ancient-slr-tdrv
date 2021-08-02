#include  <dos.h>
#include  <conio.h>


extern "C" long	ReadJoystick (void);


int	X0 = 0 , Y0 = 0 , W = 4;



unsigned  GetKey (void)
  {
      if (!kbhit()) return 0U;
      unsigned  Key = getch ();
      if (!Key) Key = getch () << 8;
      return Key;
  }

long   jCorr (int value, int center, int width)
  {
      asm    mov    ax , value;
      asm    mov    bx , center;
      asm    mov    cx , width;

      asm    sub    ax , bx
      asm    push   ax
      asm    shl    ax , 1
      asm    pop    ax
      asm    pushf

      asm    jnc    L1
      asm    neg    ax
 L1:  asm    sub    ax , cx
      asm    jnc    L2
      asm    xor    ax , ax
 L2:  asm    nop

      asm    mov    bx , ax
      asm    mul    bx
      asm    shr    dx , 1
      asm    rcr    ax , 1
      asm    shr    dx , 1
      asm    rcr    ax , 1
      asm    shr    dx , 1
      asm    rcr    ax , 1
      asm    add    ax , bx
      asm    adc    dx , 0

      asm    popf

      asm    jnc    L11
      asm    not     ax
      asm    not     dx
      asm    add     ax , 1
      asm    adc     dx , 0
 L11: asm    nop

      return  (long) MK_FP (_DX,_AX);
  }


void main (void)
  {
      while (!kbhit())
	{
	    long  val = ReadJoystick ();
	    int   x = (int) val;
	    int   y = (int) (val>>16);
	    gotoxy (1,1);
	    cprintf ("%6d  %6d ",x,y);
	}
      if (!getch()) getch();
  }