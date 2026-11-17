# Mide la economia de todas las zonas de la campana, cada una empezando con lo
# que tendria el jugador al salir de la anterior: piezas en el tope de la zona
# previa y la armeria al nivel que se indica. Ver tools/sim/economy_sim.gd.
#   tools\economy_sweep.ps1 [-Battles 16] [-Wins '10;25;50'] [-Zones '1,2,3']
param(
    [int]$Battles = 16,
    [string]$Wins = '10;25;50',
    # Zonas a medir, contando desde 1; vacio = todas.
    [string]$Zones = '',
    # Mide sin arma de pecho, como antes de abrirse.
    [switch]$NoChest
)
$root = Split-Path -Parent $PSScriptRoot
# Estado al llegar a cada zona: clase y nivel de las piezas, y nivel de la armeria.
$entry = @(
# El arma de pecho se abre en el nivel 10 del jugador, que con unas 50
# victorias por zona llega durante la zona 2: se compra en la 3 (la primera
# zona que vende armas de pecho) y se trae a las siguientes.
    @{ Tier = 'COMMON';    Level = 0;  Armory = 0;  Chest = 'none' },
    @{ Tier = 'COMMON';    Level = 3;  Armory = 5;  Chest = 'none' },
    @{ Tier = 'COMMON';    Level = 6;  Armory = 7;  Chest = 'bought' },
    @{ Tier = 'RARE';      Level = 6;  Armory = 8;  Chest = 'owned' },
    @{ Tier = 'RARE';      Level = 12; Armory = 9;  Chest = 'owned' },
    @{ Tier = 'EPIC';      Level = 9;  Armory = 10; Chest = 'owned' },
    @{ Tier = 'EPIC';      Level = 18; Armory = 10; Chest = 'owned' },
    @{ Tier = 'LEGENDARY'; Level = 12; Armory = 10; Chest = 'owned' },
    @{ Tier = 'LEGENDARY'; Level = 24; Armory = 10; Chest = 'owned' },
    @{ Tier = 'MYTHIC';    Level = 15; Armory = 10; Chest = 'owned' }
)
$list = if ($Zones) { $Zones.Split(',') | ForEach-Object { [int]$_ } } else { 1..10 }
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
foreach ($zone in $list) {
    $e = $entry[$zone - 1]
    & "$PSScriptRoot\godot.ps1" --headless --path $root -s tools/sim/economy_sim.gd '++' "--zone=$($zone - 1)" "--start-tier=$($e.Tier)" "--start-level=$($e.Level)" "--start-armory=$($e.Armory)" "--chest=$(if ($NoChest) { 'none' } else { $e.Chest })" "--battles=$Battles" "--wins=$Wins" 2>&1 |
        Select-String -NotMatch '^Godot|^$'
    ''
}
