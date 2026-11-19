@echo off
chcp 65001 >nul
title 《余烬交锋》快速启动器
cd /d "%~dp0"

:menu
cls
echo ================================================================
echo               《余烬交锋》Clash Roguelike 快速启动器
echo ================================================================
echo.
echo   [1] 废林探索模式   - 完整走图、随机事件、商店与 Boss 战
echo   [2] 单场战斗演进   - 直接进入战斗舞台（体验失衡、压制与倍速）
echo   [3] 阵容卡组整备   - 自定义队伍（灰烬/东方/ZiXi/ZiXingYC）
echo   [4] 运行演进测试   - 验证 Stage 2 失衡与压制 12 项规则断言
echo   [5] 运行全量测试   - 19 项 Headless 规则测试
echo   [0] 退出
echo.
echo ================================================================
set /p choice=请输入数字 [0-5] 后按回车: 

if "%choice%"=="1" goto launch_exploration
if "%choice%"=="2" goto launch_battle
if "%choice%"=="3" goto launch_setup
if "%choice%"=="4" goto test_stagger
if "%choice%"=="5" goto test_all
if "%choice%"=="0" exit /b
echo 无效输入，请重新选择。
ping 127.0.0.1 -n 2 >nul
goto menu

:launch_exploration
cls
echo 正在启动【废林探索模式】...
start "" "%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0battle-demo" exploration_map.tscn
goto menu

:launch_battle
cls
echo 正在启动【单场战斗演进】...
start "" "%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0battle-demo" main.tscn
goto menu

:launch_setup
cls
echo 正在启动【阵容卡组整备】...
start "" "%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0battle-demo" battle_setup.tscn
goto menu

:test_stagger
cls
echo 正在执行【失衡与压制专属测试】...
echo ----------------------------------------------------------------
"%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0battle-demo" --script tests/test_stagger_overwhelm.gd
echo ----------------------------------------------------------------
echo 测试执行完毕。按任意键返回菜单...
pause >nul
goto menu

:test_all
cls
echo 正在执行【全量测试套件】...
echo ----------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command "$tests = Get-ChildItem -Path battle-demo/tests -Filter 'test_*.gd' | Where-Object { $_.Name -notmatch '_render\.gd' }; foreach ($t in $tests) { $res = & .tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path battle-demo --script tests/$($t.Name) 2>&1; $lastLine = ($res | Select-String -Pattern 'failures=\d+|PASS|FAIL' | Select-Object -Last 1); Write-Host \"$($t.Name): $lastLine\" }"
echo ----------------------------------------------------------------
echo 测试执行完毕。按任意键返回菜单...
pause >nul
goto menu
