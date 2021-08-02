
	  T_BUF_SIZE	  = 80

TextFile 	struc
Handle		dw	?
LineNo		dw	?
BufPos		dw	?
BufEnd		dw	?
EofFound	db	?
Buffer          db	80 dup (?)
		ends

	global	OpenTextFileP	:near
	global  OpenTextFile	:near
	global  FGetCh		:near
	global  FGetLine	:near
	global	CloseTextFile	:near
	global	TF_Skip		:near
