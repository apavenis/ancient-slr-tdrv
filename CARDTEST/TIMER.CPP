#include  "CARD.H"


unsigned long	cTimer::clk;
int	   	cTimer::detected;
int	   	cTimer::fullSec;


cTimer::cTimer ( int fq )
  {
      ok = 0;
      if (fq<10) return;
      dc = 625000L / fq;
      oldmask = inportb (0xA1);
      oldVect = getvect (0x77);
      setvect (0x77,&cTimer::Timer);
      outportb (pClearIrq15,0);
      outportb (0xA1,oldmask & 0x7F);
      ok = 1;
      detected = 0;
      WriteI8253_C (pTimer,2,dc);
      outportb (pResetClkCounter,0);
  }


cTimer::~cTimer ()
  {
      outportb (0xA1,oldmask);
      setvect (0x77,oldVect);
  }


void	interrupt	cTimer::Timer (...)
  {
      unsigned char c[2];
      clk = RdTime ();
      detected = 1;
      fullSec = (inportb(pRdStatus) & 1)==0 ? 1 : 0;
      outportb (pClearIrq15,0);
      (* (char far *) 0xB8000000) ++;
  }


