#include  "CARD.H"


#define   XC	0x0001
#define   YC    0x0002



class	GotoZP
  {
  public:
		unsigned	done	   :1;
		unsigned	found      :1;
		int		direction;
		int		speed;
		unsigned char   oldstat;
		CardTest        X;

		GotoZP ( enum CoordDef coord , int inv = 0 );
	       ~GotoZP ();
     int        DoStep ();
  };



int	GotoBothZP ( int enableX , int enableY )
  {
      ScreenImage  SI;
      int   done=0;
      clrscr ();
      int  count=0;
      while (!done && (enableX || enableY))
	{
	    int   rc1 , rc2;
	    GotoZP  * X = enableX ? new GotoZP (CoordA,0) : 0;
	    GotoZP  * Y = enableY ? new GotoZP (CoordB,0) : 0;
	    do  // while ( !done && (!X.DoStep() | !Y.DoStep()) )
	      {
		  unsigned  char v = inportb (pRdStatus);
		  rc1 = X ? X->DoStep () : 0;
		  rc2 = Y ? Y->DoStep () : 0;
		  if (enableX) { gotoxy (1,1); cprintf ("%6d",X->speed*X->direction); }
		  if (enableY) { gotoxy (20,1); cprintf ("%6d",Y->speed*Y->direction); }
		  gotoxy (40,1); cprintf ("%3s  %3s ",(v&2) ? "OFF" : "ON ",(v&4) ? "OFF" : "ON ");
                  delay (60);
		  if (kbhit())  switch (getch())
		    {
		       case  0: getch (); break;
		       case 27: done=1; break;
		    }
	      }
	    while ( !done && !rc1 && !rc2 );
	    if (X) delete X;
	    if (Y) delete Y;
	    if (count>2)
	      {
		 unsigned  char v = inportb (pRdStatus);
		 if (v&2) enableX=0;
		 if (v&4) enableY=0;
	      }
	}
      return 0;
  }


GotoZP::GotoZP ( enum CoordDef coord , int inv ) :
		done (0) ,
		found (0) ,
		speed (0) ,
		X (coord)
  {
     X.SetSpeed (0);		//
     oldstat = X.IsZeroPT ();

     direction = oldstat ?  1 : -1;             // *****************************
 /*  direction = oldstat ? -1 :  1;   */        // *****************************

     if (inv) direction=-direction;
  }


GotoZP::~GotoZP ()
  {
     X.SetSpeed (0);
  }


int	GotoZP::DoStep ()
  {
     if (done) return 1;
  L1:if (found)
       {
	   speed = speed - 500;
	   if (speed<=0) { speed=0; done=1; }
	   goto L9;
       }
     if (X.IsZeroPT()!=oldstat) { found=1; goto L1; }
     if (speed<100) speed += 20;
     else if (speed<300) speed += 50;
     else if (speed<1000) speed += 100;
     else if (speed<3400) speed += 200;
     else     speed=3600;
//     else if (speed<7000) speed += 200;
//     else if (speed<7200) speed = 7200;
  L9:X.SetSpeed (direction*speed);
     return 0;
  }
