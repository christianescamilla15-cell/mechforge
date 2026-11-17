# Graba un combate automatico del juego real y saca un GIF corto de la arena,
# para revisar animaciones (PLAN F5, revision con el usuario).
#   tools\clip.ps1 -Out art_raw\clips\disparo.gif [-From 0] [-To 12]
#                  [-Player fisico_vanguardia] [-Enemy calor_horno] [-Seed 1] [-Speed 2]
# Sin -From/-To sale el combate entero. -Full no recorta la zona de la arena.
# -Showcase graba la muestra de movimientos (scenes/battle/moves_showcase.gd).
# -Cycle graba los ciclos de movimiento de cerca (tools/rig_cycle.gd).
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [double]$From = 0,
    [double]$To = 100000,
    [string]$Player = 'fisico_vanguardia',
    [string]$Enemy = 'calor_horno',
    [string]$Tier = 'EPIC',
    [int]$Seed = 1,
    [double]$Speed = 2,
    [int]$Width = 800,
    [double]$Fps = 12,
    [switch]$Full,
    [switch]$Showcase,
    [switch]$Cycle
)
$root = Split-Path -Parent $PSScriptRoot
$py = 'C:\Users\DANNY\dev\tools\mechforge-art\env\Scripts\python.exe'
$movie = Join-Path $env:TEMP 'mechforge-clip.avi'
Remove-Item $movie -ErrorAction SilentlyContinue
$env:MECHFORGE_SHOTS = (Join-Path $env:TEMP 'mechforge-clip-shots').Replace('\', '/')
New-Item -ItemType Directory -Force $env:MECHFORGE_SHOTS | Out-Null
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
$run = @('--autoplay', "--player=$Player", "--enemy=$Enemy", "--tier=$Tier", "--seed=$Seed", "--speed=$Speed")
if ($Showcase) { $run = @('--showcase') }
if ($Cycle) {
    & "$PSScriptRoot\godot.ps1" --path $root --resolution 1280x720 --write-movie $movie --fixed-fps 30 -s tools/rig_cycle.gd *> $null
} else {
    & "$PSScriptRoot\godot.ps1" --path $root --resolution 1280x720 --write-movie $movie --fixed-fps 30 '++' @run *> $null
}
if (-not (Test-Path $movie)) { Write-Output 'no se grabo el combate'; exit 1 }
$crop = @('--crop', '0', '138', '1280', '350')
if ($Showcase) { $crop = @('--crop', '0', '0', '1280', '660') }
if ($Cycle) { $crop = @('--crop', '240', '0', '800', '700') }
if ($Full) { $crop = @() }
& $py "$root\tools\art\movie_to_gif.py" $movie $Out --start $From --end $To --width $Width --fps $Fps @crop
exit $LASTEXITCODE
