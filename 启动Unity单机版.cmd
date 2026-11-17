@echo off
setlocal
chcp 65001 >nul
set "TOUHOU_REPO_ROOT=%~dp0"
set "TOUHOU_GAME_DIR=%~dp0unity-client\Builds\Windows"
if not exist "%TOUHOU_GAME_DIR%\ClashRoguelike.exe" (
  echo 正在解压 Unity 单机成品，请稍候...
  powershell -NoProfile -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath (Join-Path $env:TOUHOU_REPO_ROOT 'releases\ClashRoguelike-Unity-Windows-touhou.zip') -DestinationPath $env:TOUHOU_GAME_DIR -Force"
  if errorlevel 1 (
    echo 解压失败，请手动解压 releases 内的 Windows ZIP 后运行 EXE。
    pause
    exit /b 1
  )
)
start "" /D "%TOUHOU_GAME_DIR%" "%TOUHOU_GAME_DIR%\ClashRoguelike.exe" -screen-fullscreen 0