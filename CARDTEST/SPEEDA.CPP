#include  "Card.H"


void	TestSpeedA ()
  {
     ScreenImage  SI;
     clrscr ();
     int   index=1 , show=1 , done=0;
     int   incr=10 , y[5] = {3,6,7,10,11};
     CardTest  A (CoordA) , B (CoordB );
     textcolor (LIGHTGRAY);
     gotoxy (1, 1); cprintf ("Test step motors's frequencies (A)");
     gotoxy (1, 3); cprintf ("Increment             = ");   // Pos=25
     gotoxy (1, 5); cprintf ("First coordinate:");
     gotoxy (1, 6); cprintf ("   Speed              = ");
     gotoxy (1, 7); cprintf ("   DivCoeff           = ");
     gotoxy (1, 9); cprintf ("Second coordinate:");
     gotoxy (1,10); cprintf ("   Speed              = ");
     gotoxy (1,11); cprintf ("   DivCoeff           = ");

     gotoxy (1,15);
     cputs
     (
     "UpArrow , DownArrow               - select\r\n"
     "Left , Right                      - decr/incr\r\n"
     "Ctrl-Left , Ctrl-Right            - decr/incr ( *10 !!! )\r\n"
     "Home                              - zero speed\r\n"
     "\r\n"
     "Esc                               - quit"
     );

     while (!done)
       {
	  int   value;
	  if (show)
	    {
	       show=0;
	       _setcursortype (_NOCURSOR);
	       textcolor (WHITE);

	       gotoxy (25,3);
	       cprintf (" %5u",incr);
	       PrByteBXY (40,3,CardTest::wStat);

	       gotoxy (25,6);
	       cprintf ("%6d",A.Speed);

	       gotoxy (25,7);
	       if (A.moving)
		 {
		     cprintf (" %5u",A.DC);
		     PrByteBXY (45,7,A.DC>>8); PrByteBXY (54,7,A.DC);
		 }
	       else
		 {
		     cprintf ("<None>  ");
		     clreol ();
		 }

	       gotoxy (25,10);
	       cprintf ("%6d",B.Speed);

	       gotoxy (25,11);
	       if (B.moving)
		 {
		     cprintf (" %5u",B.DC);
		     PrByteBXY (45,11,B.DC>>8);
		     PrByteBXY (54,11,B.DC);
		 }
	       else
		 {
		     cprintf ("<None>  ");
		     clreol ();
		 }

	       textcolor (LIGHTGRAY);
	       _setcursortype (_NORMALCURSOR);
	       gotoxy (25,y[index]);
	    }
	  switch (getch ())
	    {
	       case 0 : goto ExtKey;
	       case 27: done=1; break;
	    }
	  continue;
ExtKey:	  switch (getch ())
	    {
	       case 72: index=index>0 ? index-1 : 4; show=1; break;
	       case 80: index=(index+1)%5; show=1; break;
	       case 75: value=-1; goto Change;
	       case 77: value= 1; goto Change;
	       case 115: value=-10; goto Change;
	       case 116: value= 10; goto Change;
	       case 71: switch (index)
			{
			   case 0: incr=10; break;
			   case 1:
			   case 2: A.SetSpeed(0); break;
			   case 3:
			   case 4: B.SetSpeed(0); break;
			}
			show=1;
	    }
	  continue;
Change:   switch (index)
	    {
	       case  0: incr += value;
			if (incr<1) incr=1;
			if (incr>3000) incr=3000;
			break;
	       case  1: value *= incr;
			A.SetSpeed (A.Speed+value);
			break;
	       case  2: if (A.moving) A.SetDC (A.DC+value);
			break;
	       case  3: value *= incr;
			B.SetSpeed (B.Speed+value);
			break;
	       case  4: if (B.moving) B.SetDC (B.DC+value);
			break;
	    }
	  show=1;
       }
  }