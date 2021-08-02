#include  "CARD.H"

#pragma   hdrstop
#include  <alloc.h>
#include  <stdio.h>

void	TestTimerA ()
  {
      ScreenImage  SI;   clrscr ();
      gotoxy (1,1); textcolor (WHITE); cputs ("TELESCOPE CONTROL CARD INTERNAL TIMER IRQ TEST (A)");
      textcolor (LIGHTGRAY); gotoxy (1,3);
      cputs ("This tests collects statistics about telescope control card timer IRQ's\r\n");
      cputs ("The interrupt repeat rate is set to more higher value than one used\r\n");
      cputs ("while real telescope control (100Hz)\r\n");
      cputs ("Press ESC to stop\r\n\r\n");

      unsigned long  count=0;
      unsigned       prev , curr;
      int	     start = 1;
      int	     done = 0;
      long	     j;
      unsigned long huge * ta =
		(unsigned long huge *) farmalloc (0x00020000L);
      cTimer   T (100);

      while (count<32768LU)
	if (!T.detected)
	  {
	     if (kbhit()) switch (getch())
	       {
		   case 0: getch(); break;
		   case 27: done=1; break;
	       }
	  }
	else
	  {
	     ta [count++] = T.clk;
	     if ((count % 100) == 0) sound (1000); else nosound ();
	     T.detected = 0;
	  }

      FILE  * Lst = fopen ("IRQTESTA.LST","at");
      for (j=0; j<32768L; j+=5)
	{
	   fprintf (Lst,"\n\n");
	   for (unsigned k=0; k<5; k++)
	      fprintf (Lst,"%15ld",ta[j+k]);
	   fprintf (Lst,"\n");
	}
      fclose (Lst);
      delete  ta;
      if (!getch()) getch ();
  }