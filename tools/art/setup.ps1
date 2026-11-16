# Prepara el entorno local de generacion de arte (fase F4).
# Crea un entorno virtual AISLADO fuera del repo (sin paquetes del sistema: la
# primera version los heredaba y chocaban entre si) con torch para CUDA 12.6 y
# diffusers. No descarga modelos: eso lo hace tools\art\download_models.ps1.
# Uso: tools\art\setup.ps1 [-Recreate]
param([switch]$Recreate)
# Continue y no Stop: PowerShell 5.1 convierte cualquier linea de stderr de un
# programa nativo (por ejemplo, un aviso de pip) en un error fatal.
$ErrorActionPreference = 'Continue'
$envDir = 'C:\Users\DANNY\dev\tools\mechforge-art\env'
$py = Join-Path $envDir 'Scripts\python.exe'
$torchIndex = 'https://download.pytorch.org/whl/cu126'

if ($Recreate -and (Test-Path $envDir)) {
    Write-Output "Borrando $envDir"
    Remove-Item -Recurse -Force $envDir -Confirm:$false
}
if (-not (Test-Path $py)) {
    Write-Output "Creando entorno virtual aislado en $envDir"
    python -m venv $envDir
    if ($LASTEXITCODE -ne 0) { Write-Output 'ERROR: no se pudo crear el entorno'; exit 1 }
}

Write-Output 'Instalando torch con CUDA 12.6'
& $py -m pip install --quiet --disable-pip-version-check torch==2.14.1 torchvision --index-url $torchIndex
if ($LASTEXITCODE -ne 0) { Write-Output 'ERROR: fallo la instalacion de torch'; exit 1 }

Write-Output 'Instalando diffusers y herramientas'
# torch se repite con su indice para que pip no lo cambie por la version de CPU.
& $py -m pip install --quiet --disable-pip-version-check torch==2.14.1 diffusers==0.43.0 transformers accelerate peft safetensors huggingface_hub sentencepiece protobuf opencv-python-headless pillow numpy --extra-index-url $torchIndex
if ($LASTEXITCODE -ne 0) { Write-Output 'ERROR: fallo la instalacion de paquetes'; exit 1 }

Write-Output 'Comprobando el entorno'
$check = @'
import torch, diffusers, transformers, accelerate, peft, cv2
from diffusers import (
    StableDiffusionXLPipeline,
    StableDiffusionXLControlNetUnionImg2ImgPipeline,
    MarigoldNormalsPipeline,
)
gpu = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "SIN GPU"
print("torch", torch.__version__, "| cuda", torch.cuda.is_available(), "|", gpu)
print("diffusers", diffusers.__version__, "| transformers", transformers.__version__,
      "| accelerate", accelerate.__version__, "| peft", peft.__version__)
assert torch.cuda.is_available(), "torch no ve la GPU"
print("ENTORNO OK")
'@
$check | & $py -
if ($LASTEXITCODE -ne 0) { Write-Output 'ERROR: el entorno no pasa la comprobacion'; exit 1 }
& $py -m pip check
Write-Output 'LISTO'
