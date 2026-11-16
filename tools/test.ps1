# Corre todos los tests GUT en headless. Sale con codigo distinto de 0 si algo falla.
# Primero reimporta el proyecto: sin eso, Godot no ve los class_name nuevos.
$root = Split-Path -Parent $PSScriptRoot
& "$PSScriptRoot\godot.ps1" --headless --path $root --import *> $null
& "$PSScriptRoot\godot.ps1" --headless --path $root -s addons/gut/gut_cmdln.gd '-gdir=res://tests' -ginclude_subdirs -gexit @args
exit $LASTEXITCODE
