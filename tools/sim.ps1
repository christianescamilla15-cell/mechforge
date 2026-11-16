# Corre el simulador de balance en headless. Los argumentos se pasan tal cual:
#   tools\sim.ps1 --battles=200 --tier=DIVINE
#   tools\sim.ps1 --mode=ai_vs_random --battles=50
# Con -Trace juega un solo combate y lo imprime jugada por jugada:
#   tools\sim.ps1 -Trace --a=calor_horno --b=energia_tempestad --seed=3
# Se usa "++" (no "--") para separar los argumentos del script: PowerShell se
# come el "--" al llamar a otro script.
$root = Split-Path -Parent $PSScriptRoot
$script = 'tools/sim/balance_sim.gd'
$rest = $args
if ($args.Count -gt 0 -and $args[0] -eq '-Trace') {
    $script = 'tools/sim/trace_battle.gd'
    $rest = $args | Select-Object -Skip 1
}
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
& "$PSScriptRoot\godot.ps1" --headless --path $root -s $script '++' @rest
exit $LASTEXITCODE
