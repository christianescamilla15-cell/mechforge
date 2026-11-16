# Prepara el entorno local de generacion de arte (fase F4).
# - Crea un entorno virtual fuera del repo que reutiliza el torch con CUDA ya
#   instalado en el Python del sistema.
# - Instala diffusers y las herramientas de recorte y relieve.
# - Con -DownloadSdxlBase descarga ademas Stable Diffusion XL base 1.0 en fp16
#   (unos 7 GB) a la cache de Hugging Face. El modelo definitivo para el
#   estilo mecha japones se elige en la fase F4.
# Uso: tools\art\setup.ps1 [-DownloadSdxlBase]
param([switch]$DownloadSdxlBase)
# Continue y no Stop: PowerShell 5.1 convierte cualquier linea de stderr de un
# programa nativo (por ejemplo, un aviso de pip) en un error fatal.
$ErrorActionPreference = 'Continue'
$venv = 'C:\Users\DANNY\dev\tools\mechforge-art\venv'
$py = Join-Path $venv 'Scripts\python.exe'

if (-not (Test-Path $py)) {
    Write-Output "Creando entorno virtual en $venv"
    python -m venv --system-site-packages $venv
}

Write-Output 'Instalando paquetes'
& $py -m pip install --quiet --disable-pip-version-check diffusers accelerate safetensors huggingface_hub rembg onnxruntime opencv-python-headless pillow
if ($LASTEXITCODE -ne 0) { throw 'pip fallo' }

$download = @'
from huggingface_hub import snapshot_download
path = snapshot_download(
    "stabilityai/stable-diffusion-xl-base-1.0",
    allow_patterns=[
        "model_index.json",
        "scheduler/*",
        "tokenizer/*",
        "tokenizer_2/*",
        "text_encoder/config.json",
        "text_encoder/model.fp16.safetensors",
        "text_encoder_2/config.json",
        "text_encoder_2/model.fp16.safetensors",
        "unet/config.json",
        "unet/diffusion_pytorch_model.fp16.safetensors",
        "vae/config.json",
        "vae/diffusion_pytorch_model.fp16.safetensors",
    ],
)
print("modelo en", path)
'@
if ($DownloadSdxlBase) {
    $download | & $py -
    if ($LASTEXITCODE -ne 0) { throw 'la descarga fallo' }
} else {
    Write-Output 'Descarga del modelo omitida (usa -DownloadSdxlBase para incluirla)'
}

Write-Output 'Comprobando versiones'
& $py -c "import torch, diffusers; print('torch', torch.__version__, 'cuda', torch.cuda.is_available(), '| diffusers', diffusers.__version__)"
Write-Output 'LISTO'
