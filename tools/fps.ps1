# Mide los FPS de un combate en la ventana real: la IA juega por los dos
# lados a velocidad normal, sin capturas, y al final el juego imprime el FPS
# medio, el 1 % mas lento, el peor cuadro, los tirones de mas de 20 ms y
# cuanto tardo la IA en decidir (scenes/frame_probe.gd).
#   tools\fps.ps1 [-Player fisico_vanguardia] [-Enemy calor_horno] [-Tier EPIC]
#                 [-Seed 1] [-Speed 1] [-Chest canon_pesado_cin] [-AllSkills]
#                 [-NoVsync]
#   toolsps.ps1 -Fight 10   el jefe de la primera zona (IA dificil)
param(
    [string]$Player = 'fisico_vanguardia',
    [string]$Enemy = 'calor_horno',
    [string]$Tier = 'EPIC',
    [int]$Seed = 1,
    [double]$Speed = 1,
    # Arma de pecho del jugador (id del catalogo); vacio = la de su mech.
    [string]$Chest = '',
    # Todas las habilidades, materia oscura incluida.
    [switch]$AllSkills,
    # Sin sincronia vertical: cuanto margen hay por encima del monitor.
    [switch]$NoVsync,
    # Combate de la primera zona de la campana, desde 0 (10 = el jefe); -1 = libre.
    [int]$Fight = -1,
    # Con -Fight: nivel de las piezas del jugador en la clase Basica.
    [int]$Level = 6
)
$root = Split-Path -Parent $PSScriptRoot
$env:MECHFORGE_SHOTS = ''
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
$extra = @()
if ($NoVsync) { $extra += '--disable-vsync' }
& "$PSScriptRoot\godot.ps1" --path $root --resolution 1280x720 @extra '++' --autoplay --fps "--player=$Player" "--enemy=$Enemy" "--tier=$Tier" "--seed=$Seed" "--speed=$Speed" $(if ($Chest) { "--chest=$Chest" }) $(if ($AllSkills) { '--skills=all' }) $(if ($Fight -ge 0) { "--fight=$Fight"; "--level=$Level" }) 2>&1 |
    Select-String -Pattern '^FPS|AUTOPLAY fin|ERROR|SCRIPT'
