param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'BuildLocalPlayer.ps1') -ProjectRoot $ProjectRoot
