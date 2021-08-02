#include <dos.h>
#include <conio.h>
#include <stdio.h>

void  main (void)
  {
      while (!kbhit())
	{
	   int	X,Y,B,XR,YR;
	   struct REGPACK R;
	   R.r_ax = 0xC019;
	   R.r_bx = 0x0001;
	   intr (0x2F,&R);
	   X = R.r_ax;  Y = R.r_bx;  B = R.r_cx;
	   R.r_ax = 0xC019;
	   R.r_bx = 0x0002;
	   intr (0x2F,&R);
	   XR = R.r_ax;  YR = R.r_bx;
	   printf ("%8d%8d%8d%8d%8d\n",X,Y,XR,YR,B);
	}
      if (!getch()) getch ();
  }