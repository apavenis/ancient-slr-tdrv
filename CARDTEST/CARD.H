#ifndef  __DOS_H
#  include <Dos.H>
#endif

#ifndef  __CONIO_H
#  include <ConIo.H>
#endif


void	TestFSec ();	// FSCE.CPP
void	TestSpeedA ();
void	TestTimerA ();
int	GotoBothZP ( int enableX , int enableY );
void	Test_SM_Sign (void);


enum	CardPorts
	{
	   pResetClkCounter	= 0x01A0,
	   pEnableShoot		= 0x01A2,
	   pClearIrq15		= 0x01A6,
	   pGateLW		= 0x01A8,
	   pWrStatus		= 0x01AA,
	   pRdStatus		= 0x01AC,
	   pDivCoeff_A		= 0x01B0,
	   pDivCoeff_B		= 0x01B2,
	   pWindow		= 0x01B4,
	   pCmdA		= 0x01B6,
	   pCCDelay		= 0x01B8,
	   pTimer		= 0x01BA,
	   pGateH               = 0x01BC,
	   pCmdB		= 0x01BE
	};

#define	  rsFullSecond	   0x0001
#define	  rsZeroA	   0x0002
#define   rsZeroB	   0x0004


#define   wsMoveA	   0x0001
#define	  wsMoveB	   0x0002
#define   wsSignA	   0x0004
#define   wsSignB	   0x0008
#define	  wsEnableCG	   0x0010
#define   wsEnableSG	   0x0020


#define   mCC		   5
#define   mTimer	   2
#define   mGateH	   5
#define   mWindow	   1


unsigned long RdTime ();

void	PrByteBXY ( int x , int y , unsigned val );
void	WriteI8253 ( unsigned port , unsigned value );
void	WriteI8253_C ( unsigned port , int mode , unsigned value );
int	CheckRdStat ( unsigned mask );


inline	int	IsFullSecond () { return CheckRdStat(rsFullSecond); }
inline  int	IsZeroA () { return CheckRdStat(rsZeroA); }
inline  int	IsZeroB () { return CheckRdStat(rsZeroB); }


enum	CoordDef
	{
	    CoordA 	= 1,
	    CoordB	= 2
	};


class	ScreenImage
  {
	int    cx , cy;
	int    sx , sy;
	void * buffer;
  public:
	ScreenImage ();
	~ScreenImage ();
  };


class   CardTest
  {
  public:
	enum CoordDef   coord;
	unsigned	DC_Port;
	unsigned char	MoveMask;
	unsigned char	SignMask;
	unsigned	moving		:1;
	unsigned	sign		:1;
	unsigned	DC;
	int		Speed;
	static unsigned wStat;

	CardTest ( enum CoordDef num );
       ~CardTest ();
	static void UpdateStatus ( unsigned clr , unsigned set );
	int	IsZeroPT ();
	void	SetDC ( unsigned DC );
	void	SetSpeed ( int V );
  };


class	cTimer
  {
  public:
	unsigned  		ok	:1;
	int	  		fq;
	unsigned  		dc;
	static unsigned long 	clk;
	static int	 	detected;
	static int       	fullSec;
	unsigned         	oldmask;
	void interrupt        (*oldVect) (...);

	cTimer ( int fq );
	~cTimer ();
	static void interrupt   Timer (...);
  };
