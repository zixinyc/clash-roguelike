@echo off
setlocal
chcp 65001 >nul

echo.
echo 余烬交锋
echo.
echo   1. 战斗演示
echo   2. 废林探索
echo   Q. 退出
echo.
choice /c 12Q /n /m "请选择 [1/2/Q] "
set "MENU_CHOICE=%errorlevel%"
if "%MENU_CHOICE%"=="1" goto battle
if "%MENU_CHOICE%"=="2" goto map
if "%MENU_CHOICE%"=="3" exit /b 0
exit /b 1

:battle
call "%~dp0启动战斗演示.cmd" "%~1"
exit /b %errorlevel%

:map
call "%~dp0启动战斗演示.cmd" "%~1" res://exploration_map.tscn
exit /b %errorlevel%
