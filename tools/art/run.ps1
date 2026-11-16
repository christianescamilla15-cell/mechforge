# Ejecuta un script de Python con el entorno de arte (tools\art\setup.ps1).
#   tools\art\run.ps1 tools/art/download_models.py --stage 1
$py = 'C:\Users\DANNY\dev\tools\mechforge-art\env\Scripts\python.exe'
if (-not (Test-Path $py)) {
    Write-Output 'No existe el entorno de arte. Ejecuta primero tools\art\setup.ps1'
    exit 1
}
# Sin esto Python escribe en cp1252 y los acentos rompen la salida.
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUNBUFFERED = '1'
& $py @args
exit $LASTEXITCODE
