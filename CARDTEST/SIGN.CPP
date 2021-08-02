#include <dos.h>
#include <conio.h>
#include "card.h"


void	Test_SM_Sign (void)
  {
       ScreenImage  SM;
       clrscr ();
       gotoxy (10, 6); cprintf ("Test change of stepper motor sign");
       gotoxy (10, 7); cprintf ("This test allows to check sign lines for both stepper motors");
       gotoxy (10, 8); cprintf ("There must be no motion of any stepper motor");
       gotoxy (10,12); cprintf ("1 - first  coordinate");
       gotoxy (10,14); cprintf ("2 - second coordinate");
       gotoxy (10,16); cprintf ("0 - quit");

       for (int Done=0; Done==0; )
	 {
	    char * str = "";
	    CardTest * T = 0;
	    switch (getch())
	      {
	      case   0: getch(); break;

	      case '0': Done=1; break;

	      case '1': str = "Testing sign change for first coordinate";
			T = new CardTest (CoordA);
			break;

	      case '2': str = "Testing sign change for second coordinate";
			T = new CardTest (CoordB);
			break;
	      }

	    if (T)
	      {
		  ScreenImage  SM2;
		  clrscr ();
		  gotoxy (10,10);  cprintf (str);
		  gotoxy  (10,20); cprintf ("Press any key to quit test");
		  gotoxy  (10,12); cprintf ("Sign   :");
		  T->UpdateStatus (0x0C,0x00);
		  while (!kbhit())
		    {
			T->UpdateStatus (T->SignMask,0);
			gotoxy (20,12);
			putch ('-'); cprintf ("   %02X",T->wStat);
			delay (200);
			T->UpdateStatus (0,T->SignMask);
			gotoxy (20,12);
			putch ('+'); cprintf ("   %02X",T->wStat);
			delay (200);
		    }
		  if (!getch()) getch();
		  delete T;
	      }
	 }
  }
