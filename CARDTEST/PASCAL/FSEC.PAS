Program  FSec;

Uses   Crt, TscCard;

Begin
  While Not KeyPressed Do
    If IsFullSecond Then Sound(1000) Else Nosound;
  if ReadKey=#0 Then ReadKey;
End.