# Suma celdas de plasma a la partida guardada, para probar el juego.
#   tools\celdas.ps1            suma 100000
#   tools\celdas.ps1 25000      suma esa cantidad
# El juego tiene que estar cerrado: si esta abierto, al guardar pisa el
# archivo. Antes de tocar nada deja una copia del guardado al lado.
# Una partida de antes de los tipos de robot (version 8 o menos) sin nada
# ganado vuelve a elegir robot al abrirla; con celdas dejaria de hacerlo, asi
# que en ese caso se escribe una partida nueva sin robot, con las celdas y el
# historial, y el juego sigue pidiendo elegir robot.
param([int]$Cantidad = 100000)
$dir = Join-Path $env:APPDATA 'Godot\app_userdata\MechForge'
$save = Join-Path $dir 'save.json'
if (Get-Process -Name 'MechForge*' -ErrorAction SilentlyContinue) {
    'El juego esta abierto: cierralo y vuelve a correr esto.'
    exit 1
}
if (-not (Test-Path $save)) {
    'No hay partida guardada: abre el juego una vez y elige robot.'
    exit 1
}
$text = [System.IO.File]::ReadAllText($save)
$data = $text | ConvertFrom-Json
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$copy = Join-Path $dir ('save.antes-de-celdas-' + $stamp + '.json')
Copy-Item $save $copy
$before = [int]$data.gold
$after = $before + $Cantidad
$utf8 = New-Object System.Text.UTF8Encoding $false
$played = [int]$data.wins + [int]$data.losses + $before + [int]$data.xp + [int]$data.zone + [int]$data.fight
if ([int]$data.schema_version -lt 9 -and $played -eq 0) {
    $lines = @(
        '{',
        '  "schema_version": 9,',
        ('  "gold": ' + $after + ','),
        '  "xp": 0,',
        '  "skills": [],',
        '  "shop_levels": {},',
        '  "parts": {},',
        '  "unique_cores": 0,',
        '  "owned": [],',
        '  "mechs": [],',
        '  "active": 0,',
        '  "mech": "",',
        '  "zone": 0,',
        '  "fight": 0,',
        '  "campaign_on": false,',
        '  "protections": {},',
        '  "wins": 0,',
        '  "losses": 0,',
        '  "boss_wins": 0,',
        ('  "runs_lost": ' + [int]$data.runs_lost + ','),
        ('  "best_boss_wins": ' + [int]$data.best_boss_wins),
        '}'
    )
    [System.IO.File]::WriteAllText($save, ($lines -join "`n"), $utf8)
    'Partida de antes sin nada ganado: al abrir el juego eliges robot y empiezas con las celdas.'
}
else {
    # Solo cambia el numero: el resto del archivo queda byte a byte como estaba.
    $pattern = New-Object System.Text.RegularExpressions.Regex '"gold"\s*:\s*-?\d+'
    if (-not $pattern.IsMatch($text)) {
        'El guardado no tiene celdas ("gold"): no se toca.'
        exit 1
    }
    $changed = $pattern.Replace($text, ('"gold": ' + $after), 1)
    [System.IO.File]::WriteAllText($save, $changed, $utf8)
}
('Celdas: ' + $before + ' -> ' + $after)
('Copia del guardado anterior: ' + $copy)
