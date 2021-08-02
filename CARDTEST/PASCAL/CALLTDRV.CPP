#include  <Io.H>
#include  <Dos.H>
#include  <Fcntl.H>
#include  <StdIo.H>
#include  <String.H>
#include  "CallTDRV.H"


//////////////////////////////////////////////////////////////////////////////
//   Define some undocumented stuff about 86+ CPUs
//////////////////////////////////////////////////////////////////////////////

#define  setalc()       __emit__(0xD6,0x98)
#define  ReturnCarryFlag   { __emit__(0xD6,0x98); return _AX; }

//////////////////////////////////////////////////////////////////////////////

static	const char  * PgmIdent = "Telescope control driver : Version 1.12";

static	unsigned char   tdrvTested	    = 0;
	unsigned   	MultiplexID         = 0U;

//////////////////////////////////////////////////////////////////////////////
//   Destination structure
//////////////////////////////////////////////////////////////////////////////

typedef struct
  {
      unsigned 	flags;	     // Flag word: 0x8000U when dCX & dCY are valid
      long 	T;           // Time in units of 0.1 second
      long	X;	     // 1-st coord. in motor steps times 256
      long	Y;	     // The same for the 2-nd one
      long	R;           // Distance in nanoseconds
      int       RotAngle;    //
      long	dCX;
      long	dCY;
  }
  NewDest;

//////////////////////////////////////////////////////////////////////////////
//   Pointers to TDRV.EXE internal data areas
//////////////////////////////////////////////////////////////////////////////

volatile unsigned far *	 tdrvStat;
volatile unsigned far *  tdrvStat2;
volatile unsigned far *  tdrvOpt;
volatile long far *      tdrvCurrTime;
volatile DrvCoord far *  tdrvX;
volatile DrvCoord far *  tdrvY;
volatile DrvRO far *     tdrvRO;
volatile DrvTiming far * tdrvTiming;
volatile unsigned far *	 tdrvNKStat;
volatile void far *	 tdrvDbgBuf;

//////////////////////////////////////////////////////////////////////////////
//   Queries TDRV.EXE and returns non zero if OK
//   At the first call <tdrvOk> performs scanning multiplex interrupt ID's
//   for TDRV and sets addresses of TDRV.EXE internal data areas on success.
//////////////////////////////////////////////////////////////////////////////

unsigned   tdrvOk (void)
  {
      if (!tdrvTested)
	{
	  for (MultiplexID=0xC000U; MultiplexID!=0x0000U; MultiplexID+=0x0100)
	    {
		struct REGPACK  R;
		R.r_ax = MultiplexID;
		R.r_es = 0;
		R.r_bx = 0;
		intr (0x2F,&R);
                if ((R.r_ax & 255U)!=0xFF) continue;
                if (R.r_bx<0x0003U || R.r_bx>0x0200U) continue;
		char far * id = (char far *) MK_FP (R.r_es,R.r_bx);
		if (_fstrcmp(id,PgmIdent)) continue;
		break;
	    }
	  tdrvTested = 1;
	  if (MultiplexID)
	    for (int i=0; i<10; i++)
	      {
		struct REGPACK R;
		R.r_ax = MultiplexID | 0x000F;
		R.r_bx = i << 8;
		intr (0x2F,&R);
		void far * addr = MK_FP (R.r_es,R.r_bx);
		switch (i)
		  {
		     case  0: tdrvStat      = (volatile unsigned far *) addr;
			      tdrvStat2     = tdrvStat + 1;  break;
		     case  1: tdrvOpt       = (volatile unsigned far *) addr;
			      break;
		     case  2: break;
		     case  3: tdrvCurrTime  = (volatile long far *) addr;
			      break;
		     case  4: tdrvX         = (volatile DrvCoord far *) addr;
			      break;
		     case  5: tdrvY         = (volatile DrvCoord far *) addr;
			      break;
		     case  6: tdrvRO        = (volatile DrvRO far *) addr;
			      break;
		     case  7: tdrvTiming    = (volatile DrvTiming far *) addr;
			      break;
		     case  8: tdrvNKStat    = (volatile unsigned far *) addr;
			      break;
		     case  9: tdrvDbgBuf    = (volatile void far *) addr;
			      break;
		  }
	      }
	}
      return  MultiplexID;
  }


//////////////////////////////////////////////////////////////////////////////
//  Procedure:   int   tdrvReady (void)
//
//  Input:       none
//
//  Returns:     non zero integer if TDRV.EXE is ready to receive new
//               destination
//////////////////////////////////////////////////////////////////////////////

int	tdrvReady  (void)
  {
      return  (*tdrvStat & DriverReady) ? 1 : 0;
  }

//////////////////////////////////////////////////////////////////////////////
//  Procedure:   int   tdrvIsStartCoord (void)
//
//  Input:       none
//
//  Returns:     non zero integer coordinate system is defined for TDRV.EXE
//               (This condition is necessary for tracking any object)
//////////////////////////////////////////////////////////////////////////////

int	tdrvIsStartCoord (void)
  {
      return  (*tdrvStat & isStartCoord) ? 1 : 0;
  }

//////////////////////////////////////////////////////////////////////////////
//  Procedure:   int   tdrvIsTimerInt (void)
//
//  Input:       none
//
//  Output:      returns non zero integer if IRQ 15 is occurred since the
//               previous call to this procedure
//////////////////////////////////////////////////////////////////////////////

int	tdrvIsTimerInt (void)
  {
      unsigned  rc;
      disable ();
	 rc = *tdrvStat;
	 *tdrvStat &= ~TimerIntDetected;
      enable ();
      return  (rc & TimerIntDetected) ? 1 : 0;
  }

//////////////////////////////////////////////////////////////////////////////
//  Procedure:   int   tdrvIsFullSecond (void)
//
//  Input:       none
//
//  Output:      returns non zero integer if full second signal is occurred
//	         since the previous call to this procedure
//////////////////////////////////////////////////////////////////////////////

int	tdrvIsFullSecond (void)
  {
      unsigned  rc;
      disable ();
	 rc = *tdrvStat;
	 *tdrvStat &= ~FullSecondDetected;
      enable ();
      return  (rc & FullSecondDetected) ? 1 : 0;
  }

//////////////////////////////////////////////////////////////////////////////
//  Procedure:   void	tdrvSetCoord ( long newX , long newY )
//
//  Sets telescope coordinates to the specified value
//////////////////////////////////////////////////////////////////////////////

void	tdrvSetCoord ( long newX , long newY )
  {
      asm   push   si;
      asm   push   di;
      asm   mov	   bx , word ptr newX;
      asm   mov    cx , word ptr newX+2;
      asm   mov    si , word ptr newY;
      asm   mov    di , word ptr newY+2;
      _AX = MultiplexID | 0x0003;
      geninterrupt (0x2F);
      asm   pop	   di;
      asm   pop	   si;
  }


void	tdrvSetDest ( long T , long X , long Y , long RO )
  {
      NewDest   D;
      D.flags    = 0x0000;
      D.T        = T;
      D.X        = X;
      D.Y        = Y;
      D.R        = RO;
      D.RotAngle = 0;
      D.dCX      = 0;
      D.dCY      = 0;
      struct REGPACK  R;
      R.r_es = FP_SEG ((void far *) & D);
      R.r_bx = FP_OFF ((void far *) & D);
      R.r_ax = MultiplexID | 0x0002;
      intr (0x2F,&R);
  }



void	tdrvSetDest ( long T , long X , long Y , long RO , long dCX , long dCY )
  {
      NewDest   D;
      D.flags    = 0x8000;
      D.T        = T;
      D.X        = X;
      D.Y        = Y;
      D.R        = RO;
      D.RotAngle = 0;
      D.dCX      = dCX;
      D.dCY      = dCY;
      struct REGPACK  R;
      R.r_es = FP_SEG ((void far *) & D);
      R.r_bx = FP_OFF ((void far *) & D);
      R.r_ax = MultiplexID | 0x0002;
      intr (0x2F,&R);
  }


void	tdrvSetDestR ( long T , long X , long Y , long RO , double rAngle )
  {
      NewDest   D;
      D.flags    = 0x8000;
      D.T        = T;
      D.X        = X;
      D.Y        = Y;
      D.R        = RO;
      D.RotAngle = rAngle*10.0;
      D.dCX      = 0;
      D.dCY      = 0;
      struct REGPACK  R;
      R.r_es = FP_SEG ((void far *) & D);
      R.r_bx = FP_OFF ((void far *) & D);
      R.r_ax = MultiplexID | 0x0002;
      intr (0x2F,&R);
  }


void 	tdrvClearDest (unsigned cnt)
  {
      if (cnt<3) cnt=3;			// Set minimal interval to 0.3 sec.
      disable ();			// Disable interrupts to avoid
      if (tdrvX->iCount > cnt)		// unexpected IRQ 15 that could
		tdrvX->iCount = cnt;	// make same problems, set counters
      if (tdrvY->iCount > cnt)		// in TDRV.EXE internal data structures
		tdrvY->iCount = cnt;	// and clear 'NewDestReady' flag
      *tdrvStat2 &= ~ NewDestReady;
      enable ();
  }


void	tdrvSetCCStrobe ( long RO )
  {
      asm   mov   cx , word ptr RO;
      asm   mov   dx , word ptr RO+2;
      _AX = MultiplexID | 0x0001;
      geninterrupt (0x2F);
  }


void    tdrvGetPos ( tdrvCurrPos & P )
  {
      struct REGPACK R;
      R.r_ax = MultiplexID | 0x0004;
      R.r_bx = FP_OFF ((tdrvCurrPos far *) & P);
      R.r_es = FP_SEG ((tdrvCurrPos far *) & P);
      intr (0x2F,&R);
  }


//////////////////////////////////////////////////////////////////////////////

unsigned  tdrvGetTrackingOpt (void)
  {
      return  *tdrvOpt;
  }


unsigned  tdrvSetTrackingOpt ( unsigned newOpt )
  {
      unsigned  rc = * tdrvOpt;
      _AX = MultiplexID | 0x001E;
      _BX = 0x0107;
      _CX = newOpt;
      geninterrupt (0x2F);
      return  rc;
  }

//////////////////////////////////////////////////////////////////////////////

unsigned  tdrvGetKbSensitivity (void)
  {
      _AX = MultiplexID | 0x001E;
      _BX = 0x0005;
      geninterrupt (0x2F);
      return _CX;
  }

unsigned  tdrvSetKbSensitivity ( unsigned newVal )
  {
      unsigned rc = tdrvGetKbSensitivity ();
      _AX = MultiplexID | 0x001E;
      _BX = 0x0105;
      _CX = newVal;
      geninterrupt (0x2F);
      return rc;
  }

//////////////////////////////////////////////////////////////////////////////

unsigned  tdrvGetMoSensitivity (void)
  {
      _AX = MultiplexID | 0x001E;
      _BX = 0x0006;
      geninterrupt (0x2F);
      return _CX;
  }

unsigned  tdrvSetMoSensitivity ( unsigned newVal )
  {
      unsigned rc = tdrvGetMoSensitivity ();
      _AX = MultiplexID | 0x001E;
      _BX = 0x0106;
      _CX = newVal;
      geninterrupt (0x2F);
      return rc;
  }

//////////////////////////////////////////////////////////////////////////////

unsigned  tdrvGetJsSensitivity (void)
  {
      _AX = MultiplexID | 0x001E;
      _BX = 0x0008;
      geninterrupt (0x2F);
      return _CX;
  }

unsigned  tdrvSetJsSensitivity ( unsigned newVal )
  {
      unsigned rc = tdrvGetMoSensitivity ();
      _AX = MultiplexID | 0x001E;
      _BX = 0x0108;
      _CX = newVal;
      geninterrupt (0x2F);
      return rc;
  }

//////////////////////////////////////////////////////////////////////////////

void	  tdrvResetTimer (void)
  {
      _AX = MultiplexID | 0x001F;
      _BH = 8;
      geninterrupt (0x2F);
  }


int       tdrvSetSystemTime (void)
  {
      _AX = MultiplexID | 0x001F;
      _BH = 9;
      geninterrupt (0x2F);
      ReturnCarryFlag;
  }


long	  tdrvGetTime (void)
  {
      disable ();
      long  value = *tdrvCurrTime - 1L;
      enable ();
      return  value;
  }


double	  tdrvGetCurrMJD (void)
  {
      double  mjd;
      _AX = MultiplexID | 0x001F;
      _BH = 1;   geninterrupt (0x2F);
      asm  FSTP  mjd;
      return  mjd;
  }


int      tdrvGetTimeExt ( tdrvTimeStruct & ts )
  {
      struct REGPACK R;
      R.r_ax = MultiplexID | 0x01F;
      R.r_bx = 0x0200;
      intr (0x2F,&R);
      setalc ();
      if (R.r_flags & 1) return -1;
      ts.Year    = R.r_ax;
      ts.Month   = R.r_bx >> 8;
      ts.Day     = R.r_bx & 255U;
      ts.Hours   = R.r_cx >> 8;
      ts.Minutes = R.r_cx & 255U;
      ts.Seconds = R.r_dx / 10;
      ts.Tenths  = R.r_dx % 10;
      return 0;
  }


void	tdrvNormalizeTime (void)
  {
      _AX = MultiplexID | 0x001F;
      _BX = 0x0500;
      geninterrupt (0x2F);
  }

int     tdrvGetTimeStr ( char * buffer )
  {
      const char * mnth[12] = {"Jan","Feb","Mar","Apr","May","Jun",
			       "Jul","Aug","Sep","Oct","Nov","Dec"};
      tdrvTimeStruct  ts;
      int  rc = tdrvGetTimeExt (ts);
      if (!rc)
        sprintf (buffer,"%04u %3s %02u   %02u:%02u:%02u.%1u",
                 ts.Year , mnth[ts.Month-1] , ts.Day ,
                 ts.Hours , ts.Minutes , ts.Seconds , ts.Tenths );
      else
        *buffer = 0;
      return rc;
  }


tdrvTimeSync::tdrvTimeSync ()
  {
      struct  REGPACK  R;
      R.r_ax = MultiplexID | 0x001FU;
      R.r_bx = 0x1200;
      intr (0x2F,&R);
      TimeSyncType = R.r_ax;
      if (TimeSyncType==1)
	{
	    index = 0;
	    MinIndex = 0;
	}
      else
	{
	    index = 1;
	    MinIndex = 1;
	}
  }


unsigned  tdrvTimeSync::event (unsigned key)
  {
      struct REGPACK R;
      switch (key)
	{
	  case 0x4B00: key=0; if (index<5) index++; break;

	  case 0x4D00: key=0; if (index>MinIndex) index--; break;

	  case 0x002B:
	  case 0x003D: R.r_ax = MultiplexID | 0x001F;
		       R.r_bx = 0x0600 | index;
		       intr (0x2F,&R);
		       key=0; break;

	  case 0x002D:
	  case 0x005F: R.r_ax = MultiplexID | 0x001F;
		       R.r_bx = 0x0700 | index;
		       intr (0x2F,&R);
		       key=0; break;
	}
      /* int rc = */ tdrvGetTimeStr (buffer);
      switch (index)
	{
	  case 0: hlStart=20; hlStop=21; break;
	  case 1: hlStart=17; hlStop=18; break;
	  case 2: hlStart=14; hlStop=15; break;
	  case 3: hlStart= 9; hlStop=10; break;
	  case 4: hlStart= 5; hlStop= 7; break;
	  case 5: hlStart= 0; hlStop= 3; break;
	}
      return key;
      //  012345678901234567890123456789
      //  YYYY MMM DD   HH:MM:SS.D
  }


int       tdrvWaitTimerInt (void)
  {
      _AX = MultiplexID | 0x001F;
      _BH = 16;
      geninterrupt (0x2F);
      ReturnCarryFlag;
  }

int       tdrvWaitFullSec (void)
  {
      _AX = MultiplexID | 0x001F;
      _BH = 17;
      geninterrupt (0x2F);
      ReturnCarryFlag;
  }

///////////////////////////////////////////////////////////////////////////////

void	  tdrvGetCorrections ( int & Xc , int & Yc )
  {
      _AX = MultiplexID | 0x001E;
      _BX = 0x000F;
      geninterrupt (0x2F);
      Xc = _CX;
      Yc = _DX;
  }

void	  tdrvSetCorrections ( int Xc , int Yc )
  {
      _AX = MultiplexID | 0x001E;
      _BX = 0x010F;
      _CX = Xc;
      _DX = Yc;
      geninterrupt (0x2F);
  }

//////////////////////////////////////////////////////////////////////////////

void	  tdrvCenterJoystick (void)
  {
     _AX = MultiplexID | 0x0019;
     geninterrupt (0x2F);
  }

void	  tdrvReset (void)
  {
     _AX = MultiplexID | 0x0005;
     geninterrupt (0x2F);
  }

void	  tdrvStopTracking ( int stopMode )
  {
     _AX = MultiplexID | 0x0007;
     _BX = stopMode;
     geninterrupt (0x2F);
  }

void	  tdrvInitialize (void)
  {
     _AX = MultiplexID | 0x0012;
     geninterrupt (0x2F);
  }

//////////////////////////////////////////////////////////////////////////////

unsigned   tdrvGetMaxSpeed (void)
  {
     _AX = MultiplexID | 0x001E;
     _BX = 0x0000;
     geninterrupt (0x2F);
     return _CX;
  }

unsigned   tdrvSetMaxSpeed ( unsigned newVal )
  {
     unsigned rc = tdrvGetMaxSpeed ();
     _AX = MultiplexID | 0x001E;
     _BX = 0x0100;
     _CX = newVal;
     geninterrupt (0x2F);
     return  rc;
  }

//////////////////////////////////////////////////////////////////////////////

unsigned   tdrvGetMaxAcc (void)
  {
     _AX = MultiplexID | 0x001E;
     _BX = 0x0001;
     geninterrupt (0x2F);
     return _CX;
  }

unsigned   tdrvSetMaxAcc ( unsigned newVal )
  {
     unsigned rc = tdrvGetMaxAcc ();
     _AX = MultiplexID | 0x001E;
     _BX = 0x0101;
     _CX = newVal;
     geninterrupt (0x2F);
     return  rc;
  }

//////////////////////////////////////////////////////////////////////////////

void	  tdrvGetCoordLimits ( tdrvCoordLimits & L )
  {
      struct  REGPACK  R;
      R.r_ax = MultiplexID | 0x001E;
      R.r_bx = 0x0002;
      R.r_es = FP_SEG ( & L );
      R.r_dx = FP_OFF ( & L );
      intr (0x2F,&R);
  }

void 	  tdrvSetCoordLimits ( tdrvCoordLimits & L )
  {
      struct  REGPACK  R;
      R.r_ax = MultiplexID | 0x001E;
      R.r_bx = 0x0102;
      R.r_es = FP_SEG ( & L );
      R.r_dx = FP_OFF ( & L );
      intr (0x2F,&R);
  }

//////////////////////////////////////////////////////////////////////////////

void	  tdrvGetBeepOpt ( int & type , int & len , unsigned & fq )
  {
      struct REGPACK R;
      R.r_ax = MultiplexID | 0x001E;
      R.r_bx = 0x0003;
      intr (0x2F,&R);
      type = 255U & (R.r_cx>>8);
      len  = 255U & R.r_cx;
      fq   = R.r_dx;
  }

void	  tdrvSetBeepOpt ( int type , int len , unsigned fq )
  {
      _AX = MultiplexID | 0x001E;
      _BX = 0x0103;
      _CH = type;
      _CL = len;
      _DX = fq;
      geninterrupt (0x2F);
  }

//////////////////////////////////////////////////////////////////////////////

void	  tdrvLaserEnable (void)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 1;
      geninterrupt (0x2F);
  }

void	  tdrvLaserDisable (void)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 2;
      geninterrupt (0x2F);
  }

int	  tdrvGetLaserStat (void)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 3;
      geninterrupt (0x2F);
      return _AX;
  }


long      tdrvNextShoot ()
  {
      _AX = MultiplexID | 0x001A;
      _BH = 5;
      geninterrupt (0x2F);
      return (long) MK_FP(_DX,_AX);
  }


void	  tdrvLaserStart (void)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 8;
      geninterrupt (0x2F);
  }


void	  tdrvLaserStartAt ( long t )
  {
      _AX = MultiplexID | 0x001A;
      _BH = 4;
      asm   mov  cx , word ptr t;
      asm   mov  dx , word ptr t+2;
      geninterrupt (0x2F);
  }


unsigned   tdrvGetLaserPeriod (void)
  {
     _AX = MultiplexID | 0x001A;
     _BH = 7;
     geninterrupt (0x2F);
     return _AX;
  }


unsigned   tdrvSetLaserPeriod ( unsigned newVal )
  {
     unsigned rc = tdrvGetLaserPeriod ();
     _AX = MultiplexID | 0x001A;
     _BH = 6;
     _CX = newVal;
     geninterrupt (0x2F);
     return rc;
  }


long    tdrvGetWindow (void)
  {
      _AX = MultiplexID | 0x001A;
      asm     mov    bh , 10;
      asm     int    0x2F;
      return (long) MK_FP (_DX,_AX);
  }


long    tdrvSetWindow ( unsigned newVal )
  {
     long   rc = tdrvGetWindow ();
     _AX = MultiplexID | 0x001A;
     asm     mov    bh , 9;
     asm     mov    cx , word ptr newVal;
     asm     mov    dx , word ptr newVal+2;
     asm     int    0x2F;
     return rc;
  }


long	tdrvGetGateShift (void)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 15;
      geninterrupt (0x2F);
      return (long) MK_FP (_DX,_AX);
  }


long    tdrvSetGateShift (long newVal)
  {
      long   rc = tdrvGetGateShift ();
      _AX = MultiplexID | 0x001A;
      _BH = 14;
      asm    mov   cx , word ptr newVal;
      asm    mov   dx , word ptr newVal+2;
      geninterrupt (0x2F);
      return  rc;
  }

int        tdrvGetLaserTriggeringMode (void)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 16;
      geninterrupt (0x2F);
      asm   jnc	   Done;
      asm   mov    AX , 0xFFFF;
Done: return _AX;
  }


void	     tdrvSetLaserTriggeringMode (int newVal)
  {
      _AX = MultiplexID | 0x001A;
      _BH = 17;
      _CX = newVal;
      geninterrupt (0x2F);
  }


void	tdrvSetHistWidth ( int coord , long newWidth )
  {
      if (coord<1 || coord>2) return;
      asm     mov    CX , word ptr newWidth;
      asm     mov    DX , word ptr newWidth+2;
      asm     mov    ax , MultiplexID
      asm     mov    al , 0x1E;
      asm     mov    bx , 0x010D;
      asm     cmp    coord , 2;
      asm     cmc;
      asm     adc    bx , 0;
      asm     int    2Fh;
  }


long	tdrvGetHistWidth ( int coord )
  {
      if (coord<1 || coord>2) return 0;
      asm     mov    ax , MultiplexID;
      asm     mov    al , 0x1E;
      asm     mov    bx , 0x000D;
      asm     cmp    coord , 2;
      asm     cmc;
      asm     adc    bx , 0;
      asm     int    2Fh
      asm     mov    ax , cx;
      return  (long) MK_FP (_DX,_AX);
  }

//////////////////////////////////////////////////////////////////////////////

double  tdrvGetIRQTime (void)
  {
      long   fq = 1193180;
      double value;
      void far * WW = (void far *) tdrvTiming;
      asm    les   BX , dword ptr WW;
      asm    FILD  qword ptr ES:[BX]
      asm    FIDIV dword ptr fq;
      asm    FSTP  value;
      return value;
  }


const char far * tdrvGetModelLoc (void)
  {
      _AX = MultiplexID | 0x001D;
      geninterrupt (0x2F);
      return (const char *) MK_FP (_DX,_AX);
  }


int	tdrvGetInstrDefFile ( int mode )
  {
      unsigned   pos;
      char far * fName;
      _AX = MultiplexID | 0x001D;
      geninterrupt (0x2F);
      asm   mov	  word ptr fName   , ax;
      asm   mov   word ptr fName+2 , dx;
      asm   mov   pos , bx;
      if (!fName) return -1;
      int  handle = _open ( fName , mode | O_BINARY );
      if (handle<0) return handle;
      if (pos!=lseek(handle,pos,SEEK_SET)) { close(handle); return -1; }
      return handle;
  }


//*******   accesses information about instrument model from TDRV **

struct   ErrorModelInfo
		{
		    long	CoordRStart;
		    long	CoordRStep;
		    long	CoordRPeriod;
		    unsigned	CoordRSize;
		    unsigned	CoordRTable;
		};

int	     tdrvGetModelInfo ( int  index ,
				long & StartPos , long & Step ,
				long & Period , unsigned & Size ,
				int far * far & Table )
  {
      volatile DrvCoord far * curr;
      switch (index)
	{
	   case 'X': case 'x': case 0:
		curr = tdrvX; break;
	   case 'Y': case 'y': default:
		curr = tdrvY; break;
	}
      unsigned	segment = FP_SEG (curr);
      if (!curr->ErrorDef) return -1;	// Return with rc=-1 if no model

      struct  ErrorModelInfo  far * P =
		(struct ErrorModelInfo far *) MK_FP (segment,curr->ErrorDef);

      StartPos 	  = P->CoordRStart;
      Step	  = P->CoordRStep;
      Period	  = P->CoordRPeriod;
      Size	  = P->CoordRSize;
      Table	  = (int far *) MK_FP (segment,P->CoordRTable);
      return 0;
  }


long     tdrvGetModelCorr ( long X , int index )
  {
      asm   mov  CX , word ptr X+2	// Load upper word of coord. in CX
      asm   mov  DX , word ptr X	// Load lower word of coord. in DX
      asm   mov	 AX , MultiplexID       // TDRV multiplex int. ID
      asm   mov  AL , 24		// Function code
      asm   mov  BX , 8                 // 1st coord
      asm   cmp  index , 1              // Look if index is not zero
      asm   cmc				// If so than take the second coord
      asm   adc  BX , 0
      asm   int  0x2F
      return (long) MK_FP(_DX,_AX);
  }