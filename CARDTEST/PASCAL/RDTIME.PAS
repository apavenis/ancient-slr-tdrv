Unit  RDTIME;

{$N+}

Interface

  Uses      Crt;

  Const	    rdtFq 	= 1193180.0;

  Function  ReadTime :LongInt;
  Function  ReadSec :Double;


Implementation

  Var    HW	:Word;

  Function  ReadSec :Double;
  Var    clk	:Double;
  Begin
     clk := ReadTime;
     clk := clk + 65536.0*HW;
     ReadSec := clk / rdtFq;
  End;


  Function  ReadTime :LongInt;
    Begin
      Asm
	        cli			{   Mask all iterrupts  }
	        push	es
	        push	bx
	        mov	ax , 0040h      { Segment where BIOS variables area }
	        mov	es , ax		{ is located }
	        xor	al , al
	        out	43h , al	{ Command to fix 8254 timer }
	        mov	dx , es:[6Ch]   { Read lower word of clock counter }
                mov	ax , es:[6Eh]   { Upper word of clock counter }
                mov     HW , ax
	        in 	al , 40h
	        xchg	al , ah
	        in	al , 40h
	        xchg	al , ah
	        not	ax
	        cmp	ax , 0100h
	        ja	@L2
	        push	ax
	        mov	al , 0Ah
	        out	20h , al
	        in	al , 20h
	        test	al , 1
	        jz      @L1
	        add	dx , 1
                adc     HW , 0
        @L1:    pop	ax
        @L2:    sti
	        pop	bx
	        pop	es
                mov     word ptr @Result , ax
                mov	word ptr @Result+2 , dx
      End
    End;


Begin
End.