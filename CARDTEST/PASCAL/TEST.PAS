program Test;

{$N+}

Uses TscCard,TscIrq,Crt;

Var
   GateH, GateL, Width :Word;


Begin
  GateH := 2;
  Width := 10;
  GateL := 1;
  SetV (1,2500);
  SetV (2,5000);
  While Not KeyPressed Do
    if IsIrq Then
      Begin
{       GateL := (GateL + 1) Mod 16; }
        WriteI8253_C (pGateH,mGateH,GateH);
        port [pGateLW] := GateL;
        WriteI8253_C (pWindow,mWindow,Width);
        WriteI8253_C (pCCDelay,mCC,1000);
      End;
  ReadKey;
End.