@echo off
chcp 65001 >nul
title 启动 - 单场战斗演进
cd /d "%~dp0"
echo 正在启动《余烬交锋》单场战斗演进舞台...
start "" "%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0battle-demo" main.tscn
