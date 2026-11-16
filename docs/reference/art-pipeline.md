# Referencia: cómo generar los sprites (fase F4)

Investigado el 2026-11-16 para el objetivo del GDD §11: piezas de mech en estilo mecha japonés, vistas de lado, cada una en su sprite con fondo transparente, generadas en local con una RTX 4050 de 6 GB.

**Estado:** es un plan sin probar. No se ha generado ninguna imagen todavía; la calidad, la velocidad y los valores de los ajustes están por verificar en el spike. Los identificadores de repositorio sí se comprobaron contra la API de Hugging Face y la de Civitai.

## Pipeline recomendado
1. **Modelo base:** `OnomaAIResearch/Illustrious-XL-v1.0` (un archivo de 6.94 GB, se carga con `from_single_file`). Es un SDXL afinado para ilustración japonesa que entiende etiquetas de Danbooru. Licencia tipo SDXL OpenRAIL++-M. Con el VAE `madebyollin/sdxl-vae-fp16-fix` (MIT).
2. **Control de la forma:** `xinsir/controlnet-union-sdxl-1.0` (2.51 GB, Apache-2.0) con `StableDiffusionXLControlNetUnionImg2ImgPipeline`.
   - Imagen de control: nuestra silueta con las líneas interiores principales, en modo garabato (scribble).
   - Imagen inicial: nuestro bloque de color plano, que fija la paleta y la dirección de la luz.
   - Alternativa si no se lleva bien con el modelo de anime: `Eugeoter/noob-sdxl-controlnet-scribble_pidinet` y sus variantes (2.5 GB cada una).
3. **Piezas, no mechs enteros:** se generan tres mechs completos solo como referencia de estilo, y luego cada pieza desde su propia silueta en un lienzo de 1024 px. Recortar un mech entero deja las juntas ocultas sin dibujar y las piezas no serían intercambiables.
4. **Transparencia:** pedir fondo gris liso y recortar con `ZhengPeng7/BiRefNet` (MIT, 0.44 GB) o `joelseytre/toonout` (MIT, afinado para anime). Quitar el halo del borde y reducir de 1024 a 512 px con alfa premultiplicado. Descartar los resultados cuyo contorno se aparte de la silueta dibujada.
5. **Mapas normales:** `prs-eth/marigold-normals-v1-1` (OpenRAIL++, 1.73 GB) con `MarigoldNormalsPipeline`, enmascarado con el alfa del sprite. Laigter (GPL-3.0, tiene modo sin interfaz) puede añadir el detalle de las líneas de panel.
6. **Consistencia entre piezas**, de lo más barato a lo más caro: plantilla de prompt y semillas fijas, colores del bloque inicial, remapeo de paleta al final y, si hiciera falta, un LoRA de estilo entrenado con las piezas ya aprobadas (no viable en local, ver límites).

**LoRAs de mecha opcionales** (necesitan `peft`):
- NijiMecha, versión "Noob/Illustrious", 112 MB: https://civitai.com/models/65423 (permite uso comercial de las imágenes).
- Mechanism concept, 218 MB, palabra clave `mcnm`: https://civitai.com/models/539249 (permite uso comercial de las imágenes).
- Super robot diffusion XL, 928 MB: https://civitai.com/models/124747. Es el más cercano al estilo, pero su licencia no concede uso comercial y tira hacia franquicias concretas. No usar.

## Ajustes de partida
- Muestreador Euler a, 25–28 pasos, CFG 5.5.
- Resolución 1024×1024; 832×1216 para piernas y 1216×832 para armas largas.
- Escala del ControlNet 0.6–0.8 con `control_guidance_end` 0.7; fuerza de img2img alrededor de 0.85; de 4 a 8 semillas por pieza.
- `diffusers` ignora los pesos tipo `(etiqueta:1.2)` y corta el prompt a 77 tokens: prompts cortos.

Prompt positivo:
```
masterpiece, best quality, absurdres, no humans, mecha, robot, mecha focus, science fiction, {PIEZA}, from side, solo, armor, thrusters, anime coloring, flat color, simple background, grey background
```
Ejemplos de `{PIEZA}`: `mechanical legs, lower body` · `cannon, weapon focus` · `drone, non-humanoid robot`.

Prompt negativo:
```
worst quality, bad quality, low quality, lowres, displeasing, scan artifacts, jpeg artifacts, monochrome, signature, text, logo, watermark, 1girl, 1boy, pilot, multiple views, scenery, mobile suit, v-fin
```

Etiquetas comprobadas en Danbooru: `mecha`, `no_humans`, `mecha_focus`, `non-humanoid_robot`, `from_side`, `thrusters`, `mechanical_legs`, `weapon_focus`. No existen como etiquetas: `panel_lines`, `side_view`, `cel_shading`, `mechanical_parts`.

## Límites de los 6 GB de VRAM
- El UNet (5.14 GB) más el ControlNet (2.5 GB) no caben a la vez. `enable_model_cpu_offload()` no basta porque deja ambos en la GPU; hay que usar `enable_group_offload` o `enable_sequential_cpu_offload`, más VAE por teselas. Será lento.
- Entrenar un LoRA de SDXL pide 8 GB como mínimo: no es viable en esta laptop.
- IP-Adapter añade un codificador de 2.5 GB: último recurso.

## Alternativas descartadas o de reserva
| Opción | Por qué no (o cuándo sí) |
|---|---|
| SDXL base 1.0 | Funciona, pero no entiende etiquetas de anime y es flojo en mecha |
| `Laxhar/noobai-XL-1.1` | Muy bueno, pero su licencia prohíbe el uso comercial de lo generado |
| `cagliostrolab/animagine-xl-4.0` | Licencia limpia; capacidad en mecha sin verificar. Buen candidato para comparar |
| Illustrious XL v1.1 y v2.0 | Incluir en la comparación del spike |
| Pony V6 / V7 | Prompts por puntuación; V7 pesa 13.7 GB |
| SD 1.5 de anime (`Lykon/AnyLoRA` + `lllyasviel/control_v11p_sd15_scribble`) | Cabe entero en 6 GB, a menor resolución. **Plan B** si SDXL resulta demasiado lento |
| `circlestone-labs/Anima` | El modelo de anime nuevo que mejor cabe, pero en `diffusers` no tiene ControlNet; exigiría instalar ComfyUI |
| FLUX (schnell Q4, FLUX.2 klein) y Z-Image | No caben en esta memoria o no están afinados para anime |
| LayerDiffuse (transparencia nativa) | Falla con Illustrious, NoobAI y Animagine 4 según sus propios reportes |
| `briaai/RMBG-2.0` | Licencia no comercial |

## Cosas por comprobar en el spike
- Si Illustrious rinde mejor que Animagine 4 para mecha, con la misma semilla.
- Cómo se comporta el ControlNet de xinsir con Illustrious, y los valores de fuerza.
- La velocidad real con la descarga de memoria por grupos.
- Cómo trata Marigold el arte de color plano.
- **Orientación de los mapas normales:** Godot espera X+, Y+, Z+. Marigold da X a la derecha, Y arriba y Z hacia el espectador; Laigter necesita "Invert Y" para Godot. Probar primero con una esfera.

## Fuentes
- https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.0
- https://huggingface.co/cagliostrolab/animagine-xl-4.0
- https://huggingface.co/Laxhar/noobai-XL-1.1
- https://huggingface.co/xinsir/controlnet-union-sdxl-1.0
- https://huggingface.co/docs/diffusers/main/en/api/pipelines/controlnet_union
- https://huggingface.co/docs/diffusers/main/en/optimization/memory
- https://huggingface.co/ZhengPeng7/BiRefNet
- https://huggingface.co/joelseytre/toonout
- https://huggingface.co/prs-eth/marigold-normals-v1-1
- https://huggingface.co/docs/diffusers/main/en/using-diffusers/marigold_usage
- https://docs.godotengine.org/en/stable/classes/class_canvastexture.html
- https://github.com/azagaya/laigter
- https://github.com/lllyasviel/sd-forge-layerdiffuse/issues/145
- https://github.com/kohya-ss/sd-scripts/blob/main/docs/train_SDXL-en.md
- https://civitai.com/models/65423
- https://civitai.com/models/539249
- https://danbooru.donmai.us/tags.json
