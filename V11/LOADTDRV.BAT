@echo off
c:\satcomp\tdrv /i /v
if errorlevel 1 goto Done
c:\satcomp\timesync.exe
:Done
