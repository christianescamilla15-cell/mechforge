"""Carga de los modelos de arte con los ajustes de memoria para 6 GB de VRAM.

Lo usan todos los scripts que generan imagenes, para que carguen el modelo
exactamente igual que cuando se aprobo el estilo (tools/art/style.py).
"""

import torch
from diffusers import AutoencoderKL, EulerAncestralDiscreteScheduler, StableDiffusionXLPipeline
from huggingface_hub import hf_hub_download

import style

CONTROLNET_REPO = "xinsir/controlnet-union-sdxl-1.0"
# Tipos de control del ControlNet union, segun la tarjeta del modelo.
MODE_SCRIBBLE = 2  # garabato, hed, pidi
MODE_LINEART = 3  # canny, lineart, lineart de anime

OFFLOAD_CHOICES = ["fp8", "group", "sequential", "model"]


def _store_in_8_bits(model):
    """Pesos guardados en 8 bits y calculo en 16: ocupa la mitad de VRAM."""
    model.enable_layerwise_casting(storage_dtype=torch.float8_e4m3fn, compute_dtype=torch.float16)


def load_pipeline(offload="fp8", controlled=""):
    """Devuelve el pipeline listo para generar.

    controlled: "" para texto a imagen sin control (prueba de estilo),
    "txt2img" o "img2img" para anadir el ControlNet de silueta.
    """
    checkpoint = hf_hub_download(style.MODEL_REPO, style.MODEL_FILE)
    vae = AutoencoderKL.from_pretrained(style.VAE_REPO, torch_dtype=torch.float16)
    pipe = StableDiffusionXLPipeline.from_single_file(
        checkpoint, vae=vae, torch_dtype=torch.float16, use_safetensors=True
    )
    pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)

    if controlled:
        from diffusers import (
            ControlNetUnionModel,
            StableDiffusionXLControlNetUnionImg2ImgPipeline,
            StableDiffusionXLControlNetUnionPipeline,
        )

        controlnet = ControlNetUnionModel.from_pretrained(CONTROLNET_REPO, torch_dtype=torch.float16)
        if offload == "fp8":
            _store_in_8_bits(controlnet)
        kind = (
            StableDiffusionXLControlNetUnionImg2ImgPipeline
            if controlled == "img2img"
            else StableDiffusionXLControlNetUnionPipeline
        )
        # from_pipe convierte todo a 32 bits si no se le dice el tipo.
        pipe = kind.from_pipe(pipe, controlnet=controlnet, torch_dtype=torch.float16)

    # El UNet ocupa unos 5 GB en 16 bits y no cabe en 6 GB junto a lo demas: el
    # controlador lo pasa a memoria compartida y cada imagen tarda mas de 10
    # minutos (medido el 2026-11-16).
    if offload == "fp8":
        _store_in_8_bits(pipe.unet)
        pipe.enable_model_cpu_offload()
    elif offload == "group":
        # Solo unos pocos bloques del UNet en la GPU a la vez.
        pipe.unet.enable_group_offload(
            onload_device=torch.device("cuda"),
            offload_device=torch.device("cpu"),
            offload_type="block_level",
            num_blocks_per_group=2,
        )
        for part in (pipe.text_encoder, pipe.text_encoder_2, pipe.vae):
            part.to("cuda")
    elif offload == "sequential":
        pipe.enable_sequential_cpu_offload()
    else:
        pipe.enable_model_cpu_offload()
    pipe.vae.enable_tiling()
    pipe.vae.enable_slicing()
    return pipe


def progress_printer(total_steps):
    """Avisa cada 5 pasos con los segundos transcurridos, para ver si va lento."""
    import time

    state = {"last": time.time()}

    def on_step(pipe, step, timestep, kwargs):
        if (step + 1) % 5 == 0 or step == 0:
            now = time.time()
            print(
                "    paso %d/%d  (+%.0f s)" % (step + 1, total_steps, now - state["last"]),
                flush=True,
            )
            state["last"] = now
        return kwargs

    return on_step


def peak_vram_gb():
    return torch.cuda.max_memory_allocated() / 2**30
