# Exporta el juego para Windows (preset "Windows Desktop" de export_presets.cfg)
# en build\windows\MechForge.exe: un solo .exe con los datos dentro. Necesita
# las plantillas de exportacion de Godot 4.7.2 en
# %APPDATA%\Godot\export_templates\4.7.2.stable (ver docs/PLAN.md, F9).
#   tools\export.ps1 [-Debug]
param(
    # Con la plantilla de depuracion (errores en consola) en vez de la final.
    [switch]$Debug
)
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'build\windows'
New-Item -ItemType Directory -Force $out | Out-Null
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
$mode = if ($Debug) { '--export-debug' } else { '--export-release' }
& "$PSScriptRoot\godot.ps1" --headless --path $root $mode 'Windows Desktop' (Join-Path $out 'MechForge.exe') 2>&1 |
    Select-String -Pattern 'ERROR|WARNING|savepack|export' 
$code = $LASTEXITCODE
Get-ChildItem $out | Select-Object Name, Length | Format-Table -AutoSize | Out-String
exit $code
