@echo off
setlocal
chcp 65001 >nul
call "%~dp0启动战斗演示.cmd" "%~1" res://exploration_map.tscn
exit /b %errorlevel%
