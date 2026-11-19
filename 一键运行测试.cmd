@echo off
chcp 65001 >nul
title 运行 - 自动化测试
cd /d "%~dp0"
echo ================================================================
echo 正在运行《余烬交锋》自动化测试套件...
echo ================================================================
echo.
"%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0battle-demo" --script tests/test_stagger_overwhelm.gd
echo.
echo ================================================================
echo 测试执行完毕。按任意键关闭窗口...
pause >nul
