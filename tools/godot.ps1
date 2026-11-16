# Envuelve el ejecutable de consola de Godot. Uso: tools\godot.ps1 --version
$godot = 'C:\Users\DANNY\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot @args
exit $LASTEXITCODE
