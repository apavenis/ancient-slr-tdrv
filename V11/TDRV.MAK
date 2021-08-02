.AUTODEPEND

#		*Translator Definitions*
CC = bcc +TDRV.CFG
TASM = TASM
TLIB = tlib
TLINK = tlink
LIBPATH = .;..\LIB
INCLUDEPATH = .;..\LIB


#		*Implicit Rules*
.c.obj:
  $(CC) -c {$< }

.cpp.obj:
  $(CC) -c {$< }

#		*List Macros*


EXE_dependencies =  \
 c0t.obj \
 arith.obj \
 const.obj \
 coord.obj \
 coord2.obj \
 dbgstrct.obj \
 drv1.obj \
 hardware.obj \
 int2f.obj \
 irq12.obj \
 itrig.obj \
 joystick.obj \
 keyboard.obj \
 lshoot.obj \
 mouse.obj \
 options.obj \
 rdtime.obj \
 rtc.obj \
 timer0.obj \
 util.obj \
 vfield.obj \
 main.obj \
 install.obj \
 rd_model.obj \
 ..\lib\asmlib.lib

#		*Explicit Rules*
tdrv.exe: tdrv.cfg $(EXE_dependencies)
  $(TLINK) /v/m/c/P-/L$(LIBPATH) @&&|
c0l.obj+
c0t.obj+
arith.obj+
const.obj+
coord.obj+
coord2.obj+
dbgstrct.obj+
drv1.obj+
hardware.obj+
int2f.obj+
irq12.obj+
itrig.obj+
joystick.obj+
keyboard.obj+
lshoot.obj+
mouse.obj+
options.obj+
rdtime.obj+
rtc.obj+
timer0.obj+
util.obj+
vfield.obj+
main.obj+
install.obj+
rd_model.obj
tdrv,tdrv
..\lib\asmlib.lib+
emu.lib+
mathl.lib
|


#		*Individual File Dependencies*
c0t.obj: tdrv.cfg tdrv.asm 
	$(TASM) /MX /ZI /O TDRV.ASM,C0T.OBJ

arith.obj: tdrv.cfg arith.asm 
	$(TASM) /MX /ZI /O ARITH.ASM,ARITH.OBJ

const.obj: tdrv.cfg const.asm 
	$(TASM) /MX /ZI /O CONST.ASM,CONST.OBJ

coord.obj: tdrv.cfg coord.asm 
	$(TASM) /MX /ZI /O COORD.ASM,COORD.OBJ

coord2.obj: tdrv.cfg coord2.asm 
	$(TASM) /MX /ZI /O COORD2.ASM,COORD2.OBJ

dbgstrct.obj: tdrv.cfg dbgstrct.asm 
	$(TASM) /MX /ZI /O DBGSTRCT.ASM,DBGSTRCT.OBJ

drv1.obj: tdrv.cfg drv1.asm 
	$(TASM) /MX /ZI /O DRV1.ASM,DRV1.OBJ

hardware.obj: tdrv.cfg hardware.asm 
	$(TASM) /MX /ZI /O HARDWARE.ASM,HARDWARE.OBJ

int2f.obj: tdrv.cfg int2f.asm 
	$(TASM) /MX /ZI /O INT2F.ASM,INT2F.OBJ

irq12.obj: tdrv.cfg irq12.asm 
	$(TASM) /MX /ZI /O IRQ12.ASM,IRQ12.OBJ

itrig.obj: tdrv.cfg itrig.asm 
	$(TASM) /MX /ZI /O ITRIG.ASM,ITRIG.OBJ

joystick.obj: tdrv.cfg joystick.asm 
	$(TASM) /MX /ZI /O JOYSTICK.ASM,JOYSTICK.OBJ

keyboard.obj: tdrv.cfg keyboard.asm 
	$(TASM) /MX /ZI /O KEYBOARD.ASM,KEYBOARD.OBJ

lshoot.obj: tdrv.cfg lshoot.asm 
	$(TASM) /MX /ZI /O LSHOOT.ASM,LSHOOT.OBJ

mouse.obj: tdrv.cfg mouse.asm 
	$(TASM) /MX /ZI /O MOUSE.ASM,MOUSE.OBJ

options.obj: tdrv.cfg options.asm 
	$(TASM) /MX /ZI /O OPTIONS.ASM,OPTIONS.OBJ

rdtime.obj: tdrv.cfg rdtime.asm 
	$(TASM) /MX /ZI /O RDTIME.ASM,RDTIME.OBJ

rtc.obj: tdrv.cfg rtc.asm 
	$(TASM) /MX /ZI /O RTC.ASM,RTC.OBJ

timer0.obj: tdrv.cfg timer0.asm 
	$(TASM) /MX /ZI /O TIMER0.ASM,TIMER0.OBJ

util.obj: tdrv.cfg util.asm 
	$(TASM) /MX /ZI /O UTIL.ASM,UTIL.OBJ

vfield.obj: tdrv.cfg vfield.asm 
	$(TASM) /MX /ZI /O VFIELD.ASM,VFIELD.OBJ

main.obj: tdrv.cfg main.asm 
	$(TASM) /MX /ZI /O MAIN.ASM,MAIN.OBJ

install.obj: tdrv.cfg install.asm 
	$(TASM) /MX /ZI /O INSTALL.ASM,INSTALL.OBJ

rd_model.obj: tdrv.cfg rd_model.asm 
	$(TASM) /MX /ZI /O RD_MODEL.ASM,RD_MODEL.OBJ

#		*Compiler Configuration File*
tdrv.cfg: tdrv.mak
  copy &&|
-ml
-v
-vi-
-wpro
-weas
-wpre
-I$(INCLUDEPATH)
-L$(LIBPATH)
| tdrv.cfg


