@echo off
setlocal
chcp 65001 >nul
call "%~dp002-单开好友对战.cmd" %*
if errorlevel 1 exit /b 1
call "%~dp002-单开好友对战.cmd" %*
exit /b %errorlevel%
