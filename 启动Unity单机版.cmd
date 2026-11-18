@echo off
setlocal
chcp 65001 >nul
set "TOUHOU_REPO_ROOT=%~dp0"
set "TOUHOU_GAME_DIR=%~dp0unity-client\Builds\Windows"
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1'); Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Archive\Microsoft.PowerShell.Archive.psd1'); $release=Join-Path $env:TOUHOU_REPO_ROOT 'releases'; $manifest=Get-Content -Raw -LiteralPath (Join-Path $release 'build-manifest.json') | ConvertFrom-Json; $dll=Join-Path $env:TOUHOU_GAME_DIR 'ClashRoguelike_Data\Managed\Assembly-CSharp.dll'; $exe=Join-Path $env:TOUHOU_GAME_DIR 'ClashRoguelike.exe'; if (!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath $dll) -or (Get-FileHash -LiteralPath $dll).Hash -ne $manifest.assembly_sha256) { $zip=Join-Path $release $manifest.archive; if ((Get-FileHash -LiteralPath $zip).Hash -ne $manifest.archive_sha256) { throw 'Windows ZIP checksum mismatch' }; Expand-Archive -LiteralPath $zip -DestinationPath $env:TOUHOU_GAME_DIR -Force; if ((Get-FileHash -LiteralPath $dll).Hash -ne $manifest.assembly_sha256) { throw 'Game assembly checksum mismatch' } }"
if errorlevel 1 (
  echo 无法校验或安装试玩版，请重新下载 releases 内的 Windows ZIP。
  pause
  exit /b 1
)
start "" /D "%TOUHOU_GAME_DIR%" "%TOUHOU_GAME_DIR%\ClashRoguelike.exe" -screen-fullscreen 0 %*
