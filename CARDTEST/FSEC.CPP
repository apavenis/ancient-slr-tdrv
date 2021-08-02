#include  "CARD.H"


void	TestFSec ()
  {
      ScreenImage  SI;
      clrscr ();
      gotoxy (1,10); cputs ( "This test generates beep when hardware full second signal is active" );
      gotoxy (1,12); cputs ( "RdStat = " );
      gotoxy (1,24); textcolor (LIGHTRED);
      cprintf ( "Press any key to return" );
      textcolor (LIGHTGRAY);
      _setcursortype (_NOCURSOR);
L0:   while (!kbhit())
	{
	    unsigned  val = inportb (pRdStatus) & 255U;
	    if ((val & 1)==0) sound (1000); else nosound ();
	    PrByteBXY (10,12,val);
	}
      if (!getch()) getch ();
      _setcursortype (_NORMALCURSOR);
      nosound ();
  }