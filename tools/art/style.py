"""Estilo de arte aprobado por el usuario el 2026-11-16.

La referencia es docs/reference/art/estilo_aprobado.png: mecha japones de
perfil, linea de tinta con trazo de boceto, color plano y fondo gris. Todo
script que genere arte toma de aqui el prompt y los ajustes, para que ninguna
pieza se salga del estilo. No cambiar sin que el usuario lo apruebe.

Parametros con los que se genero la referencia:
  modelo   OnomaAIResearch/Illustrious-XL-v1.0 (UNet guardado en 8 bits)
  VAE      madebyollin/sdxl-vae-fp16-fix
  muestreo Euler a, 26 pasos, CFG 5.5, 1024x1024, semilla 101
  prompt   STYLE_PREFIX + SUBJECT_WHOLE_MECH + colores de "physical" + STYLE_SUFFIX
"""

MODEL_REPO = "OnomaAIResearch/Illustrious-XL-v1.0"
MODEL_FILE = "Illustrious-XL-v1.0.safetensors"
VAE_REPO = "madebyollin/sdxl-vae-fp16-fix"

STEPS = 26
CFG = 5.5
SIZE = 1024

# Lo que define el estilo. Va igual en todas las imagenes.
STYLE_PREFIX = "masterpiece, best quality, absurdres, no humans, mecha, robot, mecha focus, science fiction"
STYLE_SUFFIX = "anime coloring, flat color, simple background, grey background"
NEGATIVE = (
    "worst quality, bad quality, low quality, lowres, displeasing, scan artifacts, "
    "jpeg artifacts, monochrome, signature, text, logo, watermark, 1girl, 1boy, pilot, "
    "multiple views, scenery, mobile suit, v-fin"
)

# Lo que cambia segun lo que se dibuja.
SUBJECT_WHOLE_MECH = "full body, standing, from side, profile, solo, armor, thrusters"

# Paleta por elemento (GDD 5).
ELEMENT_COLORS = {
    "physical": "steel grey armor, white armor, heavy armor, shoulder cannon",
    "heat": "orange armor, red armor, glowing vents, heat exhaust",
    "energy": "blue armor, cyan armor, glowing energy lines, antenna",
}

# Piezas sueltas (paso 3 de F4): que se dibuja y de que color, sin las
# etiquetas de mech entero. "mech" usa lo mismo que la referencia.
SUBJECT_PARTS = {
    "torso": "upper body, from side, profile, solo, armor, shoulder armor, thrusters",
    "legs": "mechanical legs, lower body, from side, profile, solo, armor",
    "cannon": "cannon, weapon focus, from side, profile, solo, gun barrel, still life",
}
PART_COLORS = {
    "physical": "steel grey armor, white armor",
    "heat": "orange armor, red armor, glowing vents",
    "energy": "blue armor, cyan armor, glowing energy lines",
}

# Variante descartada: pedia linea limpia y sombreado cel. Se conserva solo
# para poder comparar; el usuario eligio el trazo de la referencia.
CLEAN_PREFIX = (
    "masterpiece, best quality, amazing quality, very aesthetic, absurdres, newest, "
    "no humans, mecha, robot, mecha focus, science fiction"
)
CLEAN_SUFFIX = "anime coloring, clean lineart, cel shading, simple background, grey background"


def subject_for(part):
    """Etiquetas del sujeto: el mech entero o una pieza suelta."""
    return SUBJECT_PARTS.get(part, SUBJECT_WHOLE_MECH)


def colors_for(part, element):
    return ELEMENT_COLORS[element] if part == "mech" else PART_COLORS[element]


def prompt(subject, colors, variant="approved"):
    """Arma el prompt completo: estilo + sujeto + colores."""
    if variant == "clean":
        return ", ".join([CLEAN_PREFIX, subject, colors, CLEAN_SUFFIX])
    return ", ".join([STYLE_PREFIX, subject, colors, STYLE_SUFFIX])
