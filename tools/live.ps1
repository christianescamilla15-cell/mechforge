# Prueba en vivo: abre el juego real, la IA juega un combate por los dos lados
# y se guardan capturas de los momentos clave. Devuelve la carpeta de capturas.
#   tools\live.ps1 [-Player fisico_vanguardia] [-Enemy calor_horno] [-Tier EPIC]
#                  [-Seed 1] [-Speed 3] [-Shots carpeta]
#   tools\live.ps1 -Fight 10    combate de la primera zona de la campana, desde 0
#                               (10 = el jefe); sustituye a -Enemy y -Tier
param(
    [string]$Player = 'fisico_vanguardia',
    [string]$Enemy = 'calor_horno',
    [string]$Tier = 'EPIC',
    [int]$Seed = 1,
    [double]$Speed = 3,
    # Escenario (data/stages.json); vacio = el que toque.
    [string]$Stage = '',
    # Combate de la primera zona de la campana, desde 0; -1 = combate libre.
    [int]$Fight = -1,
    # El jugador actua a traves de los controles de la interfaz.
    [switch]$Ui,
    [string]$Shots = (Join-Path $env:TEMP 'mechforge-live')
)
$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force $Shots | Out-Null
Get-ChildItem $Shots -Filter *.png | Remove-Item -Confirm:$false
$env:MECHFORGE_SHOTS = $Shots.Replace('\', '/')
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
& "$PSScriptRoot\godot.ps1" --path $root --resolution 1280x720 '++' --autoplay "--player=$Player" "--enemy=$Enemy" "--tier=$Tier" "--seed=$Seed" "--speed=$Speed" $(if ($Stage) { "--stage=$Stage" }) $(if ($Fight -ge 0) { "--fight=$Fight" }) $(if ($Ui) { '--ui' })
$code = $LASTEXITCODE
Write-Output "capturas en: $Shots"
Get-ChildItem $Shots -Filter *.png | ForEach-Object { $_.Name }
exit $code
