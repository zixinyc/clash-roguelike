@echo off
setlocal
chcp 65001 >nul
title 余烬交锋 - 游戏菜单
for %%D in ("%~dp0..") do set "GAME_ROOT=%%~fD"
set "PROJECT_DIR=%GAME_ROOT%\battle-demo"
set "GODOT_EXE=%GODOT_BIN%"
if not defined GODOT_EXE if exist "%GAME_ROOT%\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%GAME_ROOT%\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE for %%G in (godot.exe godot4.exe) do for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
if not exist "%GODOT_EXE%" (
    echo 找不到 Godot 4.7.2。请检查 .tools 目录或 GODOT_BIN 设置。
    pause
    exit /b 1
)

:menu
echo.
echo 余烬交锋
echo.
echo   [1] 废林探索
echo   [2] 单场战斗
echo   [3] 阵容和卡组
echo   [4] 单开好友对战
echo   [5] 运行战斗规则测试
echo   [0] 退出
echo.
choice /c 123450 /n /m "请选择 [1-5/0] "
set "MENU_CHOICE=%errorlevel%"
if "%MENU_CHOICE%"=="6" exit /b 0
if "%MENU_CHOICE%"=="5" goto tests
if "%MENU_CHOICE%"=="4" goto pvp
if "%MENU_CHOICE%"=="3" set "SCENE=res://battle_setup.tscn"
if "%MENU_CHOICE%"=="2" set "SCENE=res://main.tscn"
if "%MENU_CHOICE%"=="1" set "SCENE=res://exploration_map.tscn"
if not defined SCENE exit /b 1
start "" "%GODOT_EXE%" --path "%PROJECT_DIR%" "%SCENE%" %*
exit /b %errorlevel%

:pvp
call "%~dp002-单开好友对战.cmd" %*
exit /b %errorlevel%

:tests
set "TEST_EXE=%GODOT_EXE%"
for %%E in ("%GODOT_EXE%") do if exist "%%~dpnE_console.exe" set "TEST_EXE=%%~dpnE_console.exe"
for %%T in (test_runes_forge test_stagger_overwhelm test_rules) do (
    "%TEST_EXE%" --headless --path "%PROJECT_DIR%" --script tests/%%T.gd
    if errorlevel 1 (
        echo 测试失败：%%T
        pause
        exit /b 1
    )
)
echo 测试通过。
pause
goto menu
