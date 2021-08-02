#include "card.h"

void	PrByteBXY ( int x , int y , unsigned val )
  {
     gotoxy (x,y);
     for (int i=0; i<8; i++, val<<=1)
	putch ( (val & 128U) ? '1' : '0' );
  }


void	WriteI8253 ( unsigned port , unsigned value )
  {
     outportb ( port , value );
     outportb ( port , value >> 8 );
  }


void	WriteI8253_C ( unsigned port , int mode , unsigned value )
  {
     unsigned  cmd = ( (port & 6) << 5 ) + 0x0030U +
		     ( (mode & 7) << 1 );
     unsigned  base = port & 0x03F8;
     outportb ( base+6 , cmd );
     WriteI8253 ( port , value );
  }


int	CheckRdStat ( unsigned mask )
  {
     unsigned  V = inportb (pRdStatus);
     return  (V & mask)==0 ? 1 : 0;
  }



unsigned  CardTest::wStat = 0x0030;

CardTest::CardTest ( enum CoordDef num )
  {
     coord = num;
     switch (num)
       {
	  case CoordA:
		DC_Port = pDivCoeff_A;
		MoveMask = wsMoveA;
		SignMask = wsSignA;
		break;
	  case CoordB:
		DC_Port	= pDivCoeff_B;
		MoveMask = wsMoveB;
		SignMask = wsSignB;
		break;
       }
     Speed = 0;
     moving = 0;
     UpdateStatus ( MoveMask , 0 );
     WriteI8253_C ( DC_Port , 2 , 65535U );
  }


CardTest::~CardTest ()
  {
     UpdateStatus ( MoveMask , 0 );
  }


void	CardTest::UpdateStatus ( unsigned clr , unsigned set )
  {
     wStat &= ~clr;
     wStat |=  set;
     outportb ( pWrStatus , wStat );
  }


int	CardTest::IsZeroPT ()
  {
     switch (coord)
       {
	  case CoordA: return IsZeroA ();
	  case CoordB: return IsZeroB ();
       }
     return 0;
  }


void	CardTest::SetDC ( unsigned _DC )
  {
     moving = 1;
     UpdateStatus ( 0 , MoveMask );
     if (_DC<125) _DC=125;
     WriteI8253 (DC_Port,_DC);
     DC = _DC;
     Speed = 1250000L / DC;
     if (wStat & SignMask) Speed=-Speed;
  }


void	CardTest::SetSpeed ( int V )
  {
     if (V> 14400) V= 14400;
     if (V<-14400) V=-14400;
     Speed = V;
     if (V>-20 && V<20)
       {
	  moving = 0;
	  UpdateStatus ( MoveMask , 0 );
       }
     else
       {
	  moving = 1;
	  Speed = V;
	  if (V<0) V=-V;
	  DC = 1250000L / V;
	  UpdateStatus ( Speed<0 ? 0 : SignMask , MoveMask+(Speed<0 ? SignMask : 0) );
	  WriteI8253_C (DC_Port,2,DC);
       }
  }



ScreenImage::ScreenImage ()
  {
     struct text_info TI;  gettextinfo (&TI);
     sx = TI.screenwidth;  sy = TI.screenheight;
     cx = TI.curx;         cy = TI.cury;
     buffer = (void *) new unsigned [sx*sy];
     gettext (1,1,sx,sy,buffer);
  }


ScreenImage::~ScreenImage ()
  {
     puttext (1,1,sx,sy,buffer);
     gotoxy ( cx , cy );
     delete buffer;
  }

