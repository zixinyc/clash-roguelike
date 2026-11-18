param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath $ProjectRoot).Path
$managedPath=Join-Path $projectPath 'Builds\Windows\ClashRoguelike_Data\Managed'
$compilerPath=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(!(Test-Path -LiteralPath (Join-Path $managedPath 'UnityEngine.CoreModule.dll'))) { throw 'Requires the existing Unity Mono player.' }
$resultPath=Join-Path $projectPath ('TestResults\player-patch-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
$sourcePaths=Get-ChildItem -LiteralPath (Join-Path $projectPath 'Assets\Scripts') -Recurse -File -Filter '*.cs' | ForEach-Object FullName
$references=@('mscorlib.dll','System.dll','System.Core.dll','netstandard.dll') | ForEach-Object { '/reference:'+(Join-Path $managedPath $_) }
$references+=Get-ChildItem -LiteralPath $managedPath -Filter 'UnityEngine*.dll' | ForEach-Object { '/reference:'+$_.FullName }
$outputPath=Join-Path $resultPath 'Assembly-CSharp.dll'
& $compilerPath /nologo /noconfig /nostdlib /target:library /optimize+ /codepage:65001 "/out:$outputPath" @references @sourcePaths
if($LASTEXITCODE -ne 0) { throw 'Compilation failed; existing player was not modified.' }
$compiled=[System.Reflection.Assembly]::LoadFrom($outputPath)
$prototypeCount=$compiled.GetType('ClashRoguelike.PrototypeChecks',$true).GetMethod('Run').Invoke($null,@())
if($prototypeCount -le 0){throw 'Prototype checks did not run.'}
$ruleCount=$compiled.GetType('ClashRoguelike.BattleRuleChecks',$true).GetMethod('Run').Invoke($null,@())
$clickCount=$compiled.GetType('ClashRoguelike.InteractionChecks',$true).GetMethod('Run').Invoke($null,@())
$panelCount=$compiled.GetType('ClashRoguelike.PanelChecks',$true).GetMethod('Run').Invoke($null,@())
$portCount=$compiled.GetType('ClashRoguelike.PortChecks',$true).GetMethod('Run').Invoke($null,@())
$forestCount=$compiled.GetType('ClashRoguelike.ForestChecks',$true).GetMethod('Run').Invoke($null,@())
$coinCount=$compiled.GetType('ClashRoguelike.CoinChecks',$true).GetMethod('Run').Invoke($null,@())
$newCount=$compiled.GetType('ClashRoguelike.NewCharacterChecks',$true).GetMethod('Run').Invoke($null,@())
$roleCount=$compiled.GetType('ClashRoguelike.TouhouChecks',$true).GetMethod('Run').Invoke($null,@())
if($newCount -le 0){throw "New character checks did not run."}
if($roleCount -le 0) { throw 'Role checks did not run; existing player was not modified.' }
if($coinCount -le 0) { throw 'Coin checks did not run; existing player was not modified.' }
if($ruleCount -le 0 -or $clickCount -le 0 -or $panelCount -le 0 -or $portCount -le 0 -or $forestCount -le 0) { throw 'Checks did not run; existing player was not modified.' }
$playerAssembly=Join-Path $managedPath 'Assembly-CSharp.dll'
Copy-Item -LiteralPath $playerAssembly -Destination (Join-Path $resultPath 'Assembly-CSharp.before.dll')
Copy-Item -LiteralPath $outputPath -Destination $playerAssembly -Force
$report="SPEED_RULE_CHECKS_PASSED checks=$ruleCount`r`nDIRECT_CLICK_CHECKS_PASSED checks=$clickCount`r`nDYNAMIC_PANEL_CHECKS_PASSED checks=$panelCount`r`nGODOT_PORT_CHECKS_PASSED checks=$portCount`r`nFOREST_CHECKS_PASSED checks=$forestCount`r`nCOIN_CHECKS_PASSED checks=$coinCount`r`nTOUHOU_CHECKS_PASSED checks=$roleCount`r`nNEW_CHARACTER_CHECKS_PASSED checks=$newCount"
Set-Content -LiteralPath (Join-Path $resultPath 'checks.txt') -Value $report -Encoding UTF8
Write-Output $report
Add-Content -LiteralPath (Join-Path $resultPath 'checks.txt') -Value ("PROTOTYPE_CHECKS_PASSED checks="+$prototypeCount) -Encoding UTF8
Write-Output ("PROTOTYPE_CHECKS_PASSED checks="+$prototypeCount)
