@echo off
REM Uncomment next line and set destination drive to match mbed device
REM SET LPC_DEPLOY=copy PROJECT.bin f:\

SET PATH=%~dp0\build\win32;%PATH%

@cmd.exe /K gccvar.bat
