@echo off
set MASM_BIN=C:\masm32\bin
set IRVINE_DIR=C:\Irvine

if exist main.exe del /f /q main.exe

echo [1/2] Assembling all modules...
%MASM_BIN%\ml.exe /c /coff /Cp /I"%IRVINE_DIR%" main.asm key_schedule.asm des_engine.asm dumper.asm file_io.asm parser.asm
if errorlevel 1 (
    echo [ERROR] Assembly failed!
    pause
    exit /b %errorlevel%
)

echo [2/2] Linking executable with modern security flags...
%MASM_BIN%\link.exe /SUBSYSTEM:CONSOLE /DYNAMICBASE /NXCOMPAT /LIBPATH:"%IRVINE_DIR%" /LIBPATH:"C:\masm32\lib" main.obj key_schedule.obj des_engine.obj dumper.obj file_io.obj parser.obj Irvine32.lib kernel32.lib user32.lib /OUT:main.exe
if errorlevel 1 (
    echo [ERROR] Linking failed!
    pause
    exit /b %errorlevel%
)

echo [SUCCESS] Build complete!
main.exe
pause
