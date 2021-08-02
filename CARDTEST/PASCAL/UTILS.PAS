unit  Utils;

Interface

  Uses  Crt;

  Procedure  PrHexByte ( x : Byte );
  Procedure  PrHexWord ( x : Word );
  Procedure  PrBByte ( x : Byte );


Implementation

  Var
  	hDig		:String;

  Procedure  PrHexByte ( x : Byte );
    Var   low , high	:Word;
    Begin
       low := x And 15;
       high := (x Shr 4) And 15;
       Write (hDig[1+high],hDig[1+low]);
    End;


  Procedure  PrHexWord ( x : Word );
    Begin
       PrHexByte ( x Shr 8 );
       PrHexByte ( x );
    End;


  Procedure  PrBByte ( x : Byte );
    Var    i 	:Integer;
    Begin
       for i:=1 to 8 do
         Begin
           Write (hDig[1+(x Shr 7) And 1]);
           x := x Shl 1;
         End;
    End;


Begin
   hDig := '0123456789ABCDEF';
End.