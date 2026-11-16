"""Prueba de estilo (fase F4): genera mechs completos de referencia, uno por
elemento, para decidir el estilo antes de producir las piezas.

Solo texto a imagen con el modelo base; todavia sin control de silueta.
Las imagenes van a art_raw/style/ (carpeta ignorada por git).

Uso:
  tools\\art\\run.ps1 tools/art/style_test.py                 # los tres elementos
  tools\\art\\run.ps1 tools/art/style_test.py --only heat --seeds 11 12 13
"""

import argparse
import time
from pathlib import Path

import torch
from diffusers import AutoencoderKL, EulerAncestralDiscreteScheduler, StableDiffusionXLPipeline
from huggingface_hub import hf_hub_download

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "style"

BASE = (
    "masterpiece, best quality, absurdres, no humans, mecha, robot, mecha focus, "
    "science fiction, full body, standing, from side, profile, solo, armor, thrusters, "
    "{colors}, anime coloring, flat color, simple background, grey background"
)
NEGATIVE = (
    "worst quality, bad quality, low quality, lowres, displeasing, scan artifacts, "
    "jpeg artifacts, monochrome, signature, text, logo, watermark, 1girl, 1boy, pilot, "
    "multiple views, scenery, mobile suit, v-fin"
)
# Paleta por elemento (GDD 5).
ELEMENTS = {
    "physical": "steel grey armor, white armor, heavy armor, shoulder cannon",
    "heat": "orange armor, red armor, glowing vents, heat exhaust",
    "energy": "blue armor, cyan armor, glowing energy lines, antenna",
}


def load_pipeline(offload):
    checkpoint = hf_hub_download(
        "OnomaAIResearch/Illustrious-XL-v1.0", "Illustrious-XL-v1.0.safetensors"
    )
    vae = AutoencoderKL.from_pretrained("madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16)
    pipe = StableDiffusionXLPipeline.from_single_file(
        checkpoint, vae=vae, torch_dtype=torch.float16, use_safetensors=True
    )
    pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)
    # Con 6 GB de VRAM el modelo no puede quedarse entero en la GPU.
    if offload == "sequential":
        pipe.enable_sequential_cpu_offload()
    else:
        pipe.enable_model_cpu_offload()
    pipe.vae.enable_tiling()
    pipe.vae.enable_slicing()
    return pipe


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=sorted(ELEMENTS), help="un solo elemento")
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102])
    parser.add_argument("--steps", type=int, default=26)
    parser.add_argument("--cfg", type=float, default=5.5)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--offload", choices=["model", "sequential"], default="model")
    parser.add_argument("--extra", default="", help="etiquetas extra para el prompt")
    parser.add_argument("--tag", default="", help="sufijo para el nombre de los archivos")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    started = time.time()
    pipe = load_pipeline(args.offload)
    print("modelo cargado en %.0f s" % (time.time() - started), flush=True)

    elements = [args.only] if args.only else list(ELEMENTS)
    for element in elements:
        prompt = BASE.format(colors=ELEMENTS[element])
        if args.extra:
            prompt += ", " + args.extra
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=NEGATIVE,
                num_inference_steps=args.steps,
                guidance_scale=args.cfg,
                width=args.width,
                height=args.height,
                generator=torch.Generator("cpu").manual_seed(seed),
            ).images[0]
            name = "%s_%d%s.png" % (element, seed, ("_" + args.tag) if args.tag else "")
            image.save(OUT / name)
            peak = torch.cuda.max_memory_allocated() / 2**30
            print(
                "ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, peak),
                flush=True,
            )
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
