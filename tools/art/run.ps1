# Ejecuta un script de Python con el entorno de arte (tools\art\setup.ps1).
#   tools\art\run.ps1 tools/art/style_test.py --only heat
#
# Los scripts que usan la GPU necesitan toda la VRAM. En esta laptop el
# vigilante de transcripciones de NexusForge (tarea programada
# "NexusForge-TranscriptionWatcher") mantiene Whisper cargado y ocupa 2 GB
# aunque este en reposo. Por eso, para esos scripts, este lanzador:
#   1. espera a que el vigilante termine si esta transcribiendo,
#   2. detiene la tarea,
#   3. ejecuta el script,
#   4. vuelve a arrancar la tarea, pase lo que pase.
# Con -KeepWatcher no toca la tarea.
# Con la variable MECHFORGE_PYTHON usa otro Python (el del generador de musica,
# que tiene su propio entorno):
#   $env:MECHFORGE_PYTHON = <python.exe>; tools\art\run.ps1 tools/audio/music.py
# (No es un parametro: uno de texto se quedaria con la ruta del script.)
param(
    [switch]$KeepWatcher,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)
$py = 'C:\Users\DANNY\dev\tools\mechforge-art\env\Scripts\python.exe'
if ($env:MECHFORGE_PYTHON) { $py = $env:MECHFORGE_PYTHON }
if (-not (Test-Path $py)) {
    Write-Output 'No existe el entorno de arte. Ejecuta primero tools\art\setup.ps1'
    exit 1
}
if (-not $Rest -or $Rest.Count -eq 0) {
    Write-Output 'Uso: tools\art\run.ps1 [-KeepWatcher] <script.py> [argumentos]'
    exit 1
}

$taskName = 'NexusForge-TranscriptionWatcher'
$watcherLog = 'C:\Users\DANNY\Syncthing\watcher.log'
# Scripts que no usan la GPU: no hace falta pausar nada.
$cpuOnly = @('download_models.py', 'contact_sheet.py', 'blockout.py', 'cut_body.py', 'export_assist.py', 'export_weapons.py', 'export_parts.py', 'extract_overlay.py', 'recolor.py')
$scriptName = Split-Path -Leaf $Rest[0]
$pausedWatcher = $false
# Marca de que este lanzador pauso el vigilante. Si una corrida muere sin
# llegar a su finally (matada a mano), la marca queda y la siguiente corrida
# lo rearranca: asi no se queda caido en silencio durante dias (paso el
# 2026-11-21). Sin marca no se toca: si el vigilante esta parado por otra
# razon, no es cosa de este lanzador.
$pauseMark = Join-Path $env:TEMP 'mechforge-art-vigilante-pausado.txt'

# La GPU es compartida con la granja de render del museo (blender -b). Un
# script de GPU espera a que no haya Blender: la granja toma trabajos nuevos
# aunque su cola parezca vacia (el 2026-11-19 arranco uno a mitad de una tanda).
# Entre un trabajo y el siguiente la granja deja unos minutos libres: si estaba
# activa, hacen falta 10 minutos seguidos sin Blender.
if ($cpuOnly -notcontains $scriptName) {
    $quiet = 10
    if (Get-Process -Name blender -ErrorAction SilentlyContinue) {
        Write-Output 'Blender esta usando la GPU (granja de render); espero a que termine...'
        $quiet = 0
    }
    while ($quiet -lt 10) {
        Start-Sleep -Seconds 60
        if (Get-Process -Name blender -ErrorAction SilentlyContinue) { $quiet = 0 } else { $quiet += 1 }
    }
}

# Una junta en vivo (puente de transcripcion: trabajador_gpu.py en la GPU)
# va antes que el arte: no se arranca mientras dure. Entre imagenes, los
# scripts de generacion hacen lo mismo con tools/art/gpu_turn.py (el
# 2026-11-23 una tanda de armas tiro una junta).
function Test-Meeting {
    $ids = & nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>$null
    foreach ($id in $ids) {
        $n = 0
        if ([int]::TryParse("$id".Trim(), [ref]$n)) {
            $p = Get-CimInstance Win32_Process -Filter "ProcessId=$n" -ErrorAction SilentlyContinue
            if ($p -and $p.CommandLine -match 'trabajador_gpu') { return $true }
        }
    }
    return $false
}
if ($cpuOnly -notcontains $scriptName) {
    while (Test-Meeting) {
        Write-Output 'Hay una junta en vivo usando la GPU; espero a que termine...'
        Start-Sleep -Seconds 60
    }
}

if (Test-Path $pauseMark) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Running') {
        Remove-Item $pauseMark -ErrorAction SilentlyContinue
    } elseif (Test-Meeting) {
        Write-Output 'El vigilante quedo pausado por una corrida anterior; hay junta: lo dejo para despues.'
    } elseif ($task) {
        Start-ScheduledTask -TaskName $taskName
        Remove-Item $pauseMark -ErrorAction SilentlyContinue
        Write-Output 'Vigilante de transcripciones rearrancado (lo habia dejado pausado una corrida anterior).'
    }
}

if (-not $KeepWatcher -and ($cpuOnly -notcontains $scriptName)) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Running') {
        # Si la ultima linea del log es un [start], esta transcribiendo: esperar.
        $deadline = (Get-Date).AddMinutes(15)
        while ((Get-Date) -lt $deadline) {
            $last = Get-Content $watcherLog -Tail 1 -ErrorAction SilentlyContinue
            if ($last -notmatch '\[start\]') { break }
            Write-Output 'El vigilante de transcripciones esta trabajando; espero a que termine...'
            Start-Sleep -Seconds 20
        }
        Stop-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 3
        $pausedWatcher = $true
        Set-Content -Path $pauseMark -Value (Get-Date -Format 's') -Encoding ascii
        Write-Output 'Vigilante de transcripciones en pausa mientras se usa la GPU.'
    }
}

# Sin esto Python escribe en cp1252 y los acentos rompen la salida.
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUNBUFFERED = '1'
$code = 1
try {
    & $py @Rest
    $code = $LASTEXITCODE
} finally {
    if ($pausedWatcher) {
        Start-ScheduledTask -TaskName $taskName
        Remove-Item $pauseMark -ErrorAction SilentlyContinue
        Write-Output 'Vigilante de transcripciones arrancado de nuevo.'
    }
}
exit $code
