# Abre el juego para jugar a mano.
$root = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Users\DANNY\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64.exe'
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
Start-Process -FilePath $godot -ArgumentList '--path', "`"$root`""
