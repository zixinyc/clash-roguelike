@echo off
chcp 65001 >nul
title 启动 - 废林探索模式
cd /d "%~dp0"
echo 正在启动《余烬交锋》废林探索模式...
start "" "%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0battle-demo" exploration_map.tscn
