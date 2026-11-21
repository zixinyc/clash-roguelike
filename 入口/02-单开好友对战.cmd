@echo off
setlocal
chcp 65001 >nul
for %%D in ("%~dp0..") do set "GAME_ROOT=%%~fD"
set "GODOT_EXE=%GODOT_BIN%"
if not defined GODOT_EXE if exist "%GAME_ROOT%\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%GAME_ROOT%\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE for %%G in (godot.exe godot4.exe) do for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
if not exist "%GODOT_EXE%" (
    echo 找不到 Godot 4.7.2。请检查项目的 .tools 目录或 GODOT_BIN 设置。
    pause
    exit /b 1
)
if not exist "%GAME_ROOT%\battle-demo\pvp_lobby.tscn" (
    echo 找不到好友对战大厅，请确认入口文件夹位于游戏项目根目录。
    pause
    exit /b 1
)
start "" "%GODOT_EXE%" --path "%GAME_ROOT%\battle-demo" res://pvp_lobby.tscn %*
exit /b %errorlevel%
