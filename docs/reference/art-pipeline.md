# Referencia: cómo generar los sprites (fase F4)

Investigado el 2026-11-16 para el objetivo del GDD §11: piezas de mech en estilo mecha japonés, vistas de lado, cada una en su sprite con fondo transparente, generadas en local con una RTX 4050 de 6 GB.

**Estado (2026-11-16):** el modelo base ya genera en esta laptop y el usuario aprobó el estilo con la imagen `art/estilo_aprobado.png`. Siguen sin probar el control de silueta, el recorte del fondo y los mapas normales. Los identificadores de repositorio se comprobaron contra la API de Hugging Face y la de Civitai.

## Pipeline recomendado
1. **Modelo base:** `OnomaAIResearch/Illustrious-XL-v1.0` (un archivo de 6.94 GB, se carga con `from_single_file`). Es un SDXL afinado para ilustración japonesa que entiende etiquetas de Danbooru. Licencia tipo SDXL OpenRAIL++-M. Con el VAE `madebyollin/sdxl-vae-fp16-fix` (MIT).
2. **Control de la forma:** `xinsir/controlnet-union-sdxl-1.0` (2.51 GB, Apache-2.0) con `StableDiffusionXLControlNetUnionImg2ImgPipeline`.
   - Imagen de control: nuestra silueta con las líneas interiores principales, en modo garabato (scribble).
   - Imagen inicial: nuestro bloque de color plano, que fija la paleta y la dirección de la luz.
   - Alternativa si no se lleva bien con el modelo de anime: `Eugeoter/noob-sdxl-controlnet-scribble_pidinet` y sus variantes (2.5 GB cada una).
3. **Del mech entero a las piezas** (cambiado el 2026-11-16 tras medirlo, ver "Control de silueta: lo medido"): el modelo dibuja bien mechs enteros y mal piezas sueltas. Se genera el cuerpo completo (torso y piernas) desde nuestro bloque y se corta por la cadera; las armas se añaden después sobre ese cuerpo y se extraen por diferencia.
4. **Transparencia:** pedir fondo gris liso y recortar con `ZhengPeng7/BiRefNet` (MIT, 0.44 GB) o `joelseytre/toonout` (MIT, afinado para anime). Quitar el halo del borde y reducir de 1024 a 512 px con alfa premultiplicado. Descartar los resultados cuyo contorno se aparte de la silueta dibujada.
5. **Mapas normales:** `prs-eth/marigold-normals-v1-1` (OpenRAIL++, 1.73 GB) con `MarigoldNormalsPipeline`, enmascarado con el alfa del sprite. Laigter (GPL-3.0, tiene modo sin interfaz) puede añadir el detalle de las líneas de panel.
6. **Consistencia entre piezas**, de lo más barato a lo más caro: plantilla de prompt y semillas fijas, colores del bloque inicial, remapeo de paleta al final y, si hiciera falta, un LoRA de estilo entrenado con las piezas ya aprobadas (no viable en local, ver límites).

**LoRAs de mecha opcionales** (necesitan `peft`):
- NijiMecha, versión "Noob/Illustrious", 112 MB: https://civitai.com/models/65423 (permite uso comercial de las imágenes).
- Mechanism concept, 218 MB, palabra clave `mcnm`: https://civitai.com/models/539249 (permite uso comercial de las imágenes).
- Super robot diffusion XL, 928 MB: https://civitai.com/models/124747. Es el más cercano al estilo, pero su licencia no concede uso comercial y tira hacia franquicias concretas. No usar.

## Estilo aprobado
- Referencia: `art/estilo_aprobado.png` (mech físico, semilla 101).
- Prompt y ajustes exactos: `tools/art/style.py` (Euler a, 26 pasos, CFG 5.5, 1024×1024, UNet en 8 bits).
- Lo que define el estilo en el prompt es `anime coloring, flat color` con las etiquetas de calidad básicas. Añadir `very aesthetic`, `clean lineart` o `cel shading` lo cambia a un acabado limpio y colorido que el usuario descartó.
- La variación de diseño entre semillas es grande (de humanoide a bestia): para que las piezas formen una familia hará falta el control de silueta, no solo el prompt.

## Ajustes de partida
- Muestreador Euler a, 25–28 pasos, CFG 5.5.
- Resolución 1024×1024; 832×1216 para piernas y 1216×832 para armas largas.
- ControlNet en modo garabato con el bloque de color como imagen inicial. Medido: escala 0.55, `control_guidance_end` 0.4 y fuerza de img2img 1.0 para mechs enteros. Con escala 0.7, final 0.7 y fuerza 0.85 el modelo calca el bloque. De 4 a 8 semillas por diseño, descartando las de coincidencia baja.
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

## Medido en esta laptop (2026-11-16)
- De los 6 GB de VRAM, unos 2 GB ya los ocupan el escritorio y otros programas: quedan unos 4 GB.
- **Con el UNet en 16 bits no cabe.** `enable_model_cpu_offload()` llenó la VRAM (5.9 de 6.1 GB), el controlador pasó a memoria compartida y la primera imagen no había terminado tras más de 10 minutos.
- **Con los pesos del UNet guardados en 8 bits** (`enable_layerwise_casting` con `float8_e4m3fn`, calculando en 16 bits) más `enable_model_cpu_offload()`: **36 segundos por imagen** de 1024×1024 a 26 pasos, con un pico de 2.8 GB. Es el modo por defecto de `tools/art/style_test.py`.
- Cargar el modelo tarda 13 segundos.
- **Los 2 GB que faltaban los ocupaba el vigilante de transcripciones de NexusForge** (tarea programada `NexusForge-TranscriptionWatcher`), que mantiene Whisper cargado en la GPU aunque esté en reposo. `tools/art/run.ps1` lo pausa mientras un script usa la GPU y lo vuelve a arrancar al terminar.

## Control de silueta: lo medido (2026-11-16)
Herramientas: `tools/art/blockout.py` dibuja los bloques (polígonos por pieza) y `tools/art/part_test.py` genera y mide la coincidencia con la silueta (IoU entre la figura generada y el bloque). 24 imágenes, mech físico.

| Prueba | Ajustes | Coincidencia (IoU) | Resultado |
|---|---|---|---|
| Mech entero y piezas, control firme | escala 0.7, final 0.7, fuerza 0.85 | 0.88–0.96 | **Calca el bloque**: formas planas, sin detalle mecánico ni el trazo aprobado. No sirve |
| Mech entero, control suelto (8 variantes) | escala 0.35–0.55, final 0.25–0.4, fuerza 1.0 | 0.62–0.68 | **Bien**: detalle, trazo de tinta y color plano; las 8 forman una familia. Respeta la distribución, no el contorno exacto |
| Piezas sueltas, control suelto | escala 0.55, final 0.4 | 0.28–0.72 | **Mal**: el torso sale como una nave, las piernas como piernas humanas cortadas y el cañón como un rifle de mano |
| Cuerpo sin armas, 3 semillas | escala 0.55, final 0.4 | 0.62 / 0.35 / 0.83 | Dos de tres en familia; la de 0.35 se va a un diseño con alas y espadas. La de 0.83 sale robusta y con el trazo más parecido a la referencia |
| Cañón suelto, control firme, 3 semillas | escala 0.9, final 0.6 | 0.71–0.79 | Otra vez calca el bloque y le añade una empuñadura. Flojo |

Conclusiones:
- Con control firme el resultado vale lo que valga nuestro bloque, y unos polígonos toscos dan un dibujo tosco.
- Con control suelto el modelo pone el diseño y nosotros la distribución. Solo funciona con mechs enteros.
- La coincidencia sirve de filtro automático: por debajo de 0.6 el diseño se salió de la familia.
- El fondo sale con un tinte verdoso o cálido en vez del gris de la referencia. No importa: se recorta.
- `from_pipe` convierte el pipeline a 32 bits si no se le pasa `torch_dtype`; el fallo aparece como "mat1 and mat2 must have the same dtype".

Segunda tanda (2026-11-16, 16 imágenes más), ya con la línea de diseño elegida por el usuario (`art/cuerpo_elegido.png`: esbelta, blanca, con luces cian):

| Prueba | Resultado |
|---|---|
| Cuerpo en calor y energía, bloque inicial con la paleta del elemento | **Mal**: sale plano y caricaturesco. El relleno de color saturado aplana el dibujo |
| Cuerpo en calor y energía, bloque inicial blanco y gris, color pedido solo en el prompt (`--init-palette physical`) | **Bien**: vuelven el detalle y el trazo. La semilla 101 conserva la familia en los tres elementos; la 102 se va siempre al diseño con alas (coincidencia 0.30–0.40) |
| Silueta de la imagen elegida como molde, solo contorno y relleno gris (`--shape-from`) | **Muy mal**: manchas brillantes sin estructura. Un contorno vacío no le basta al modelo |
| Armas sueltas con control suelto y negativos de arma de mano | Ya no salen rifles con empuñadura. Calidad desigual: un cañón bueno, otro simple; los lanzamisiles son cajas; las espadas salen medievales, no de mecha |

Receta que funciona hoy para cuerpos: bloque inicial con paleta `physical`, todas las líneas del bloque como control, escala 0.55, final 0.4, fuerza 1.0, color por prompt. Hay que generar varias semillas y curar.

Tercera tanda (2026-11-16): lote de 24 cuerpos, 8 cuerpos de energía repetidos, arma piloto y prueba de color.
- **Lote de cuerpos:** 15 de 24 pasan el filtro de coincidencia, pero a ojo solo sirven unos 4 de la línea esbelta (físico 101 y 105, calor 101 y 109) y 2 de la robusta (físico 103, calor 103). El filtro quita lo que se sale de la silueta, no lo que queda plano.
- **Energía:** con negativos contra rayos, alas y disparos desaparecen casi todos los efectos pintados, pero los cuerpos azules salen más simples y caricaturescos que los blancos. El estilo aprobado sale mejor con blindaje blanco.
- **Color por zonas (tools/art/recolor.py):** repintar el cuerpo elegido por zonas (blindaje claro, estructura oscura y luces) conserva la línea y el detalle en cualquier color. Sirve para el color personalizable (GDD §8) y permite **dibujar todas las piezas en blanco y dar el color del elemento después**, que es la vía recomendada.
- **Arma piloto (tools/art/evolve_test.py):** cañón de plasma en 5 etapas, cada una generada desde la anterior con fuerza 0.6. Mantiene la identidad del arma, pero la evolución casi no se nota y los efectos (rayos, chorro de energía) salen pintados dentro del dibujo. Corrección prevista: un bloque por etapa, cada uno más grande y con más módulos; negativos contra rayos y chispas; base blanca y color por zonas.

Elecciones del usuario (2026-11-16), guardadas en art/elegidos/: cuerpos del jugador físico 101 y 105 y calor 101 y 109; jefes físico 103 y calor 103; cañón de plasma base, la versión 102. Aprobó también dibujar en blanco y colorear por zonas.

**Prueba de mezcla de los 4 cuerpos del jugador (tools/art/cut_body.py --mix):** el recorte y el montaje funcionan, pero las piezas todavía no son intercambiables. Cada cuerpo se corta por su punto más estrecho, que en unos es el cuello y en otros la cintura, así que al mezclar aparecen dos pechos apilados o proporciones que no casan, y la unión se ve como una línea recta. Corrección prevista: que el bloque marque una cintura estrecha con una junta redonda siempre a la misma altura, cortar por esa altura fija y no por la fila más estrecha, y tapar la unión con una pieza de acople común.

**Cambio de método (2026-11-16):** la mezcla de piezas cortadas de cuerpos distintos no funciona, y el usuario pidió reformular el diseño. El método nuevo está en docs/CHASIS.md: un maniquí por chasis y cada pieza dibujada ya montada (inpainting con el aro de cintura fijo, tools/art/halves_test.py). Probado con 3 torsos y 3 pares de piernas: las 9 combinaciones encajan y conservan el detalle. Con control firme (escala 0.75, final 0.6) el chasis se respeta pero el dibujo sale plano, igual que en la primera prueba. Lo que sigue en esta lista queda sustituido por las correcciones de CHASIS.md, sección 6.

Siguiente paso (sin hacer): generar varias semillas del cuerpo con el bloque neutro, descartar las de coincidencia menor de 0.5, elegir a ojo, y cortar torso y piernas por la cadera con el recorte de fondo. Las armas y los drones se generan sueltos y se curan igual. El inpainting queda de reserva.

## Límites de los 6 GB de VRAM
- El UNet (5.14 GB) más el ControlNet (2.5 GB) no caben a la vez en 16 bits. Guardando los dos en 8 bits (`tools/art/sd.py`) sí caben con `enable_model_cpu_offload()`: pico de 4.3 GB y 42 segundos por imagen. Exige tener el vigilante de transcripciones en pausa.
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
