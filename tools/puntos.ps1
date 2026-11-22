# Regala puntos de habilidad a la partida guardada, aparte de los del nivel
# ("skill_bonus"; SkillTree.points_left los suma). Pedido del usuario el
# 2026-11-21: "me puedes dar 20 puntos de habilidad".
#   tools\puntos.ps1            suma 20
#   tools\puntos.ps1 5          suma esa cantidad
# El juego tiene que estar cerrado: si esta abierto, al guardar pisa el
# archivo. Necesita un juego que ya conozca "skill_bonus" (el de antes lo
# borraria al guardar). Antes de tocar nada deja una copia del guardado.
#   tools\puntos.ps1 20 -Guardado otro.json   sobre otro archivo (para probar)
param([int]$Cantidad = 20, [string]$Guardado = '')
$dir = Join-Path $env:APPDATA 'Godot\app_userdata\MechForge'
$save = Join-Path $dir 'save.json'
if ($Guardado -ne '') {
    $save = $Guardado
    $dir = Split-Path -Parent $Guardado
}
elseif (Get-Process -Name 'MechForge*' -ErrorAction SilentlyContinue) {
    'El juego esta abierto: cierralo y vuelve a correr esto.'
    exit 1
}
if (-not (Test-Path $save)) {
    'No hay partida guardada.'
    exit 1
}
$text = [System.IO.File]::ReadAllText($save)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$copy = Join-Path $dir ('save.antes-de-puntos-' + $stamp + '.json')
Copy-Item $save $copy
$utf8 = New-Object System.Text.UTF8Encoding $false
$bonus = New-Object System.Text.RegularExpressions.Regex '"skill_bonus"\s*:\s*(\d+)'
$match = $bonus.Match($text)
if ($match.Success) {
    $before = [int]$match.Groups[1].Value
    $after = $before + $Cantidad
    $changed = $bonus.Replace($text, ('"skill_bonus": ' + $after), 1)
}
else {
    # Sin el campo: va justo detras de los nucleos unicos, que siempre estan.
    $cores = New-Object System.Text.RegularExpressions.Regex '"unique_cores"\s*:\s*\d+'
    $found = $cores.Match($text)
    if (-not $found.Success) {
        'El guardado no tiene "unique_cores": no se toca.'
        exit 1
    }
    $before = 0
    $after = $Cantidad
    $changed = $text.Insert($found.Index + $found.Length, (', "skill_bonus": ' + $after))
}
[System.IO.File]::WriteAllText($save, $changed, $utf8)
('Puntos de habilidad regalados: ' + $before + ' -> ' + $after)
('Copia del guardado anterior: ' + $copy)
