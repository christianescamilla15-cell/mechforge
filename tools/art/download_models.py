"""Descarga a la cache de Hugging Face los modelos del pipeline de arte.

Se baja por etapas para no ocupar disco antes de tiempo:
  1  modelo base de ilustracion y su VAE (prueba de estilo)        ~6.8 GB
  2  ControlNet para forzar la silueta y recortador de fondo        ~2.8 GB
  3  estimador de mapas normales                                    ~2.4 GB

Uso: tools/art/run.ps1 tools/art/download_models.py --stage 1
Detalles y licencias en docs/reference/art-pipeline.md.
"""

import argparse

from huggingface_hub import snapshot_download

# Por cada repositorio, solo los archivos que hacen falta (los repos traen
# varias copias del mismo peso en otros formatos).
STAGES = {
    1: [
        ("OnomaAIResearch/Illustrious-XL-v1.0", ["Illustrious-XL-v1.0.safetensors"]),
        ("madebyollin/sdxl-vae-fp16-fix", ["config.json", "diffusion_pytorch_model.safetensors"]),
    ],
    2: [
        (
            "xinsir/controlnet-union-sdxl-1.0",
            ["config.json", "diffusion_pytorch_model.safetensors"],
        ),
        ("ZhengPeng7/BiRefNet", ["*.json", "*.py", "model.safetensors"]),
    ],
    3: [
        (
            "prs-eth/marigold-normals-v1-1",
            [
                "model_index.json",
                "scheduler/*",
                "tokenizer/*",
                "text_encoder/config.json",
                "text_encoder/model.fp16.safetensors",
                "unet/config.json",
                "unet/diffusion_pytorch_model.fp16.safetensors",
                "vae/config.json",
                "vae/diffusion_pytorch_model.fp16.safetensors",
            ],
        ),
    ],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", type=int, choices=sorted(STAGES), required=True)
    args = parser.parse_args()
    for repo, patterns in STAGES[args.stage]:
        path = snapshot_download(repo, allow_patterns=patterns)
        print("ok  %s\n    %s" % (repo, path), flush=True)
    print("ETAPA %d DESCARGADA" % args.stage)


if __name__ == "__main__":
    main()
