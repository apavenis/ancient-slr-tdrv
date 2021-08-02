#include  "card.h"


void	main (void)
  {
     int  done=0, iy=10;
     ScreenImage  __SI__;  clrscr ();

     char   oldIrqMask2 = inportb (0xA1);
     outportb (0xA1,oldIrqMask2 | 0x80);

     textcolor (WHITE);
     gotoxy (15, 1); cputs ("TELESCOPE CONTROL CARD TESTS");
     textcolor (LIGHTGRAY);
     gotoxy (15,iy++); cputs ("0 - exit");
     gotoxy (15,iy++); cputs ("1 - beep on full second signals");
     gotoxy (15,iy++); cputs ("2 - test step motors");
     gotoxy (15,iy++); cputs ("3 - test sign change (are there jumps when chaging sign?)");
     gotoxy (15,iy++); cputs ("4 - interrupt test 1");

     textcolor (LIGHTRED);
     gotoxy (15,23); cputs ("If TDRV.EXE is loaded then 0.1 sec. timer will not run");
     gotoxy (15,24); cputs ("This program is active");
     textcolor (LIGHTGRAY);
//     gotoxy (15,16); cputs ("3 - move telescope to zero point (1-st. coord)");
//     gotoxy (15,18); cputs ("4 - move telescope to zero point (2-nd. coord)");

     while (!done)
	switch (getch ())
	  {
	     case   0:  getch (); break;
	     case '0':  done=1; break;
	     case '1':  TestFSec (); break;
	     case '2':  TestSpeedA (); break;
	     case '3':  Test_SM_Sign (); break;
	     case '4':  TestTimerA (); break;

//	     case '8':  GotoBothZP (1,0); break;
//	     case '9':  GotoBothZP (0,1); break;
	  }
     outportb (0xA1,oldIrqMask2);
  }