Program WStatTst;

Uses  TscCard, Crt;

Var    i       :Integer;
Begin
  while Not KeyPressed Do
    for i:=0 to 63 do
      port [pGateLW] := i;
  if ReadKey=#0 then ReadKey;
End.