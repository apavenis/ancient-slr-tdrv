#include  <dos.h>
#include  <stdio.h>

unsigned   ReadCMOS (int address);
void	   I8259_Info (void);
void	   RTC_Info (void);


void main (void)
  {
       printf ("------------------------------------------------------------------------\n");
       I8259_Info ();
       RTC_Info ();
  }


void	I8259_Info (void)
  {
      int        irq;
      unsigned   IR , IS , IM , MASK;
      disable ();
      IM  =   (unsigned) inportb (0x21);
      IM |=  ((unsigned) inportb (0xA1))<<8;
      outportb (0x20,0x0A);  IR  =  (unsigned) inportb (0x20);
      outportb (0xA0,0x0A);  IR |= ((unsigned) inportb (0xA0))<<8;
      outportb (0x20,0x0B);  IS  =  (unsigned) inportb (0x20);
      outportb (0xA0,0x0B);  IS |= ((unsigned) inportb (0xA0))<<8;
      enable ();

      printf ("Interrupt : ");
      for (irq=0; irq<16; irq++) printf (" %2d ",irq);
      printf ("\n");

      printf ("8259: IR  : ");
      for (irq=0,MASK=1 ; MASK ; irq++,MASK<<=1 )
		printf ("  %c ",(IR & MASK) ? '+' : '-');
      printf ("\n");

      printf ("8259: IS  : ");
      for (irq=0,MASK=1 ; MASK ; irq++,MASK<<=1 )
		printf ("  %c ",(IS & MASK) ? '+' : '-');
      printf ("\n");

      printf ("Enabled   : ");
      for (irq=0,MASK=1 ; MASK ; irq++,MASK<<=1 )
		printf ("  %c ",(IM & MASK) ? '-' : '+');
      printf ("\n\n");
  }


void	RTC_Info (void)
  {
      unsigned char RTC_StatA = ReadCMOS (0x8A);
      unsigned char RTC_StatB = ReadCMOS (0x8B);
      unsigned char RTC_StatC = ReadCMOS (0x8C);

      printf ("RTC Status byte A (R/W): %02X\n",RTC_StatA);
      if (RTC_StatA & 0x0080U) printf ("     Timer update cycle in progress\n");
      printf ("     22 stage divider is %d (default 2)\n",(RTC_StatA>>4)&7);
      printf ("     Rate selection its for interrupt is %d (default 6)\n",RTC_StatA&15);

      printf ("RTC Status byte B (R/W): %02X\n",RTC_StatB);
      printf ("     Cycle update              : %s   (0-OK to read CMOS)\n",(RTC_StatB & 128) ? "Enabled" : "Disabled");
      printf ("     Periodic interrupts       : %s   (default 0)\n",(RTC_StatB &  64) ? "Enabled" : "Disabled");
      printf ("     Alarm interrupts          : %s   (default 0)\n",(RTC_StatB &  32) ? "Enabled" : "Disabled");
      printf ("     Update ended interrupts   : %s   (default 0)\n",(RTC_StatB &  16) ? "Enabled" : "Disabled");
      printf ("     Square wave output        : %s   (default 0)\n",(RTC_StatB &   8) ? "Enabled" : "Disabled");
      printf ("     Data mode                 : %s   (default 0)\n",(RTC_StatB &   4) ? "Binary" : "BCD");
      printf ("     24/12 hours selection     : %s   (default 1)\n",(RTC_StatB &   2) ? "24 hours" : "12 hours");
      printf ("     Daylight savings          : %s   (default 0)\n",(RTC_StatB &   1) ? "Enabled" : "Disabled");

      printf ("RTC Status byte C (R/O): %02X\n",RTC_StatC);
      printf ("     RTC interrupt is %s requested\n", (RTC_StatC & 128) ? "" : "not");
      printf ("     RTC periodic interrupt flag       : %s\n",(RTC_StatC &  64) ? "On " : "Off");
      printf ("     RTC alarm interrupt flag          : %s\n",(RTC_StatC &  32) ? "On " : "Off");
      printf ("     RTC clock update ended            : %s\n",(RTC_StatC &  16) ? "On " : "Off");
  }



unsigned   ReadCMOS (int address)
  {
      disable ();
      outportb (0x70,address);
      unsigned  rc = inportb (0x71);
      enable ();
      return rc;
  }
