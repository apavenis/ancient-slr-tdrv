#ifndef __CALLTDRV_H
  #define __CALLTDRV_H

  #ifndef __cplusplus
  #error Must use C++ with CallTDRV.H
  #endif

  #ifndef __FCNTL_H
  #  include <fcntl.h>
  #endif

  typedef struct
    {
       long	   T;
       long	   X , VX , d_X;
       long	   Y , VY , d_Y;
    }
    tdrvCurrPos;


  typedef struct
    {
       long        xMin , xMax;
       long        yMin , yMax;
    }
    tdrvCoordLimits;


  typedef struct
    {
	unsigned   Year;
	unsigned   Month	:8;
	unsigned   Day          :8;
	unsigned   Hours        :8;
	unsigned   Minutes      :8;
	unsigned   Seconds	:8;
	unsigned   Tenths       :8;
    }
    tdrvTimeStruct;

  enum __tdrvBeepType
     {
	tdrvNoBeep            =  0,
	tdrvBeepOnHardwSec    =  1,
	tdrvBeepOnSoftwSec    =  2,
	tdrvBeepOnLaserTrig   = 16,
	tdrvBeepOnTimerIRQ    = 32
     };



  typedef struct
    {
    public:
       enum StatusBits
	  {
	     Starting     = 0x01 ,   // 1 while starting sequence
	     Tracking     = 0x02 ,   // 1 when the speed is not 0
	     Ready        = 0x04 ,   // 1 when ready for a new destination
	     StartCoord   = 0x08 ,   // 1 when start coordinates are defined
	     CurrDestOk   = 0x20 ,   // 1 when curr dest is OK
	     SignChanged  = 0x40 ,   // 1 when sign must be changed
	     RequestReset = 0x80     //
	  };

       enum OptionsBits
	  {
	     InvertSign	  = 0x01 ,   // 1 when invering sign for hardware
	     CorrectStp   = 0x02 ,   // 1 when step count correction from
				     // second card is allowed
	     InvertLC     = 0x04     // 1 when inverting corrections taken
				     // from table (if one exist)
	  };

       enum hrdwStatBits
	  {
	     hrdwMove	  = 0x01,
	     hrdwSign	  = 0x04,
	     hrdwReset1   = 0x10,
	     hrdwReset2   = 0x80
	  };

       unsigned char  	Status;      // Status byte
       unsigned char	Options;     // Tracking options for this coordinate
       unsigned 	ErrorDef;    // Offset to CTDef structure
       long		CurrX;	     // Current coordinate
       long		CurrV;	     // Current speed
       long		Residual;    //
       long		PrevDest;    //
       long		CurrDest;    //
       long		DestSpeed;   //
       long		DestAcc;     //
       long		RsdlX;       //
       long		d_RsdlX;     //
       long		prevRsdlX;   //
       long		IncrX;	     //
       long		xMin;        //
       long		xMax;        //
       int		iCount;      //
       unsigned char	hrdwStat;    //
       unsigned		DivCoeff;    //
       unsigned		Remainder;   //
       unsigned		c2Val;       //
       unsigned char    nDestP;	     //
       unsigned   	PrevCnt;     //
       unsigned long	TotalSteps;  //
       long             DrvCorr;     //
       long 		StartShift;  //
       int		CurrSteps;   //
       int		NextSteps;   //
       unsigned char    PrevHrdwStat;//
       unsigned		CntZeroVal;  //
       unsigned		StepCnt;     //
       long		HistArg;     // Argument of hysteresis
       long		HistMin;
       long		HistMax;
       unsigned		Signature;   // Check value (must be 23761)
    }
    DrvCoord;

  typedef struct
    {
       unsigned long	CurrRO;	     //
       unsigned long    IncrRO;	     //
    }
    DrvRO;

  typedef struct
    {
       unsigned long	irqStart [2];  // 8-bit integer number !!!
       unsigned long    irqEnd [2];
       unsigned long	irqDiffMin;
       unsigned long 	irqDiffMax;
    }
    DrvTiming;

  //**************************************************************************

  enum	tdrvStatBits
    {
	TimerIntDetected   = 0x8000U ,
	FullSecondDetected = 0x4000U ,
	DriverReady	   = 0x2000U ,
	isStartCoord	   = 0x0100U ,
	LaserDisable	   = 0x0080U ,
	ManualTracking     = 0x0040U ,
	mtModeChanged	   = 0x0020U ,
	isHardwareIRQ15    = 0x0008U ,
	isCtrlBreak	   = 0x0004U ,
	MidnightFound	   = 0x0002U ,
	SynchronizationOk  = 0x0001U
    };

  enum  tdrvStat2Bits
    {
	PrevDestOK	   = 0x4000U ,
	IntervalDone       = 0x2000U ,
	OutputReady	   = 0x1000U ,
	NewDestReady       = 0x0800U ,
	DrvWaiting         = 0x0400U ,
	ResetDriver        = 0x0200U ,
	foEnable 	   = 0x0100U ,
	DrvTracking        = 0x0080U ,
	jsButton4	   = 0x0040U ,
	jsButton3          = 0x0020U ,
	jsButton2          = 0x0010U ,
	jsButton1          = 0x0008U ,
	moLeftButtonDown   = 0x0001U ,
	moRightButtonDown  = 0x0002U ,
	moCenterButtonDown = 0x0004U
    };

  enum  tdrvOptionsBits
    {
	dTakeNumKB	   = 0x0001U ,
	dTakeMouse	   = 0x0002U ,
	dInstrCoord        = 0x0004U ,
	dUserRotation      = 0x0008U ,
	dConvCoord	   = 0x0010U ,
	dUseJoystick	   = 0x0020U
    };

  enum  tdrvHrdwOptBits
    {
        tdrvEnableBeeps      = 0x0001U,
        tdrvEnableLaserCtrl  = 0x0002U,
        tdrvEnableStepCnt    = 0x0004U,
	tdrvStrictIRQ15      = 0x0008U,
	tdrvEnableJoystick   = 0x0010U,
    };

  class	 tdrvTimeSync
    {
    public:
	unsigned TimeSyncType;
	int      MinIndex;
	int	 index;
	int	 hlStart;
	int	 hlStop;
        char     buffer [50];

	tdrvTimeSync (); //{ index=0; }
	unsigned  event (unsigned key);
    };

  //**************************************************************************

  extern            unsigned   	    	MultiplexID;

  extern   volatile unsigned far *	tdrvStat;
  extern   volatile unsigned far *      tdrvStat2;
  extern   volatile unsigned far * 	tdrvOpt;
  extern   volatile long far *		tdrvCurrTime;
  extern   volatile DrvCoord far *      tdrvX;
  extern   volatile DrvCoord far * 	tdrvY;
  extern   volatile DrvRO far *		tdrvRO;
  extern   volatile DrvTiming far *	tdrvTiming;
  extern   volatile unsigned far *	tdrvNKStat;
  extern   volatile void far *		tdrvDbgBuf;

  //**************************************************************************

  unsigned   tdrvOk (void);

  int        tdrvReady (void);
  int	     tdrvIsStartCoord (void);
  int	     tdrvIsTimerInt (void);
  int        tdrvIsFullSecond (void);

  void	     tdrvSetCoord ( long newX , long newY );

  void	     tdrvSetDest  ( long T , long X , long Y , long RO , long dCX , long dCY );
  void	     tdrvSetDestR ( long T , long X , long Y , long RO , double rAngle );
  void	     tdrvSetDest  ( long T , long X , long Y , long RO );
  void	     tdrvClearDest ( unsigned cnt=3 );
  void	     tdrvSetCCStrobe ( long ro );
  void	     tdrvGetPos ( tdrvCurrPos & P );

  unsigned   tdrvGetTrackingOpt (void);
  unsigned   tdrvSetTrackingOpt ( unsigned newOpt );

  unsigned   tdrvGetKbSensitivity (void);
  unsigned   tdrvSetKbSensitivity ( unsigned newVal );
  unsigned   tdrvGetMoSensitivity (void);
  unsigned   tdrvSetMoSensitivity ( unsigned newVal );
  unsigned   tdrvGetJsSensitivity (void);
  unsigned   tdrvSetJsSensitivity ( unsigned newVal );

  void	     tdrvCenterJoystick (void);
  void	     tdrvResetTimer (void);
  int        tdrvSetSystemTime (void);
  long       tdrvGetTime (void);
  double     tdrvGetCurrMJD (void);
  int        tdrvGetTimeExt ( tdrvTimeStruct & ts );
  int        tdrvGetTimeStr ( char * buffer );
  void	     tdrvNormalizeTime (void);
  long       tdrvIncrTime ( long Increment );
  int        tdrvWaitTimerInt (void);
  int        tdrvWaitFullSec (void);

  void       tdrvGetCorrections ( int & Xc , int & Yc ) ;
  void       tdrvSetCorrections ( int Xc , int Yc );

  void       tdrvReset (void);
  void       tdrvStopTracking ( int stopMode );
  void       tdrvInitialize (void);

  unsigned   tdrvGetMaxSpeed (void);
  unsigned   tdrvSetMaxSpeed ( unsigned newVal );

  unsigned   tdrvGetMaxAcc (void);
  unsigned   tdrvSetMaxAcc ( unsigned newVal );

  void       tdrvGetCoordLimits ( tdrvCoordLimits & L );
  void       tdrvSetCoordLimits ( tdrvCoordLimits & L );

  void       tdrvGetBeepOpt ( int & type , int & len , unsigned & fq );
  void       tdrvSetBeepOpt ( int type , int len , unsigned fq );

  void       tdrvLaserEnable (void);
  void       tdrvLaserDisable (void);
  int        tdrvGetLaserStat (void);
  long       tdrvNextShoot ();
  void       tdrvLaserStart (void);
  void       tdrvLaserStartAt ( long t );
  unsigned   tdrvGetLaserPeriod (void);
  unsigned   tdrvSetLaserPeriod ( unsigned newVal );
  long       tdrvGetWindow (void);
  long       tdrvSetWindow ( unsigned newVal );
  long       tdrvGetGateShift (void);
  long       tdrvSetGateShift (long newVal);
  int        tdrvGetLaserTriggeringMode (void);
  void	     tdrvSetLaserTriggeringMode (int newVal);

  /* WARNING: the value set by this function is take into account only
     after next call to tdrvSetCoord */
  void	     tdrvSetHistWidth (int coord, long Width);
  long	     tdrvGetHistWidth (int coord);

  double     tdrvGetIRQTime (void);

  //*******   opens current instrument model file  *******************

  const char far * tdrvGetModelLoc (void);

  int        tdrvGetInstrDefFile ( int mode = O_RDONLY );

  //*******   accesses information about instrument model from TDRV **

  int	     tdrvGetModelInfo ( int  index ,
				long & StartPos , long & Step ,
				long & Period , unsigned & Size ,
				int far * & Table );

  long	     tdrvGetModelCorr ( long Coord , int index );
				// Coord : value of coord in internal units
				// index : non 0 for 2nd coord, 0 for 1st

  //******************************************************************
  //   4 procedures defined in INSTRSYS.H for loading current
  //   instrument models and to compute model corrections
  //******************************************************************

  enum  instrModelType
    {
	mtNoModel   = 0,
	mtLS105     = 101,
	mtULISS     = 630
    };

  class   InstrModelBase;

  extern  InstrModelBase * InstrDef;	// Active instrument model file

  int   LoadLS105Model ();

  int   LoadULISSModel ();

  void  RemoveInstrModel ();

  void  GetCorr ( double X , double Y , double & d_X , double & d_Y );

  //******************************************************************

  class   PushBeepOpt
    {
		int	 beepType;
		int	 beepLen;
		unsigned beepFq;
    public:
		PushBeepOpt ()
		  {
		      tdrvGetBeepOpt (beepType,beepLen,beepFq);
		  }

		PushBeepOpt ( int newType , int newLen , unsigned newFq )
		  {
		      tdrvGetBeepOpt (beepType,beepLen,beepFq);
		      tdrvSetBeepOpt (newType,newLen,newFq);
		  }

	       ~PushBeepOpt ()
		  {
		      tdrvSetBeepOpt (beepType,beepLen,beepFq);
		  }
    };

  #ifdef Uses_ModelFile

  class	  ModelFile
    {
    public:
		int	  handle;
		unsigned  good		:1;
			ModelFile (int _h) : handle (_h) , good (1) {}
			~ModelFile () { _close(handle); }
    };


  template <class T>
  ModelFile & operator >> ( ModelFile & M , T & Dest )
    {
	unsigned  len = _read ( M.handle , (void *) & Dest , sizeof(T) );
	if (len!=sizeof(T)) M.good=0;
	return M;
    }

  #endif

#endif
