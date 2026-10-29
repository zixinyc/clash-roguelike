@echo off
setlocal
set "GODOT_EXE=%~1"
if defined GODOT_EXE goto run
if defined GODOT_BIN set "GODOT_EXE=%GODOT_BIN%"
if defined GODOT_EXE goto run
if exist "%~dp0..\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%~dp0..\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if defined GODOT_EXE goto run
for %%G in (godot.exe godot4.exe) do for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
if defined GODOT_EXE goto run
echo Godot was not found. Download the Godot 4.7.2 standard edition.
echo Import battle-demo/project.godot in Godot, then press F5.
echo Or drag the extracted Godot executable onto this launcher.
echo See README.md in this folder for download links and instructions.
pause
exit /b 1

:run
if not exist "%GODOT_EXE%" (
  echo The Godot executable path does not exist.
  exit /b 1
)
set "APPDATA=%~dp0..\.tools\runtime-data"
if not exist "%APPDATA%" mkdir "%APPDATA%"
"%GODOT_EXE%" --path "%~dp0." %2 %3 %4 %5 %6 %7 %8 %9
