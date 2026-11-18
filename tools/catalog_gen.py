"""Genera las armas del catalogo (docs/CATALOGO_ARMAS.md) desde una tabla:
forma x tipo x municion. Los numeros de cada forma salen de las armas que ya
estaban equilibradas en data/catalog.json (una por elemento); el tipo le da
su rango de clases y un matiz; la municion es el elemento. Las armas base
estan en tools/weapon_bases.json, asi que se puede volver a generar.

    python tools/catalog_gen.py            escribe data/catalog.json
    python tools/catalog_gen.py --dry      solo muestra el resumen

Sustituye las armas laterales, superiores, de pecho y drones.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from catalog_tool import load, save  # noqa: E402

ELEMENTS = ["PHYSICAL", "HEAT", "ENERGY"]
BASES = Path(__file__).resolve().parent / "weapon_bases.json"
# Pesos permitidos por hueco: los del validador del catalogo.
WEIGHT_RANGE = json.loads(
    (Path(__file__).resolve().parent.parent / "data" / "validation.json").read_text(encoding="utf-8")
)["weight"]
AMMO = {"PHYSICAL": "cinética", "HEAT": "térmica", "ENERGY": "iónica"}
AMMO_MASC = {"PHYSICAL": "cinético", "HEAT": "térmico", "ENERGY": "iónico"}
AMMO_ID = {"PHYSICAL": "cin", "HEAT": "ter", "ENERGY": "ion"}

# Tipo de arma: clases en las que existe y como dispara. El tipo no cambia la
# potencia: a igual clase, todas las armas de una forma pegan lo mismo de
# media y gastan lo mismo. Cambiar costos o dano por tipo, aunque sea igual
# para las tres municiones, rompe el equilibrio entre elementos (medido: con
# costos mas bajos el drenaje vale menos; con mas altos, el calor domina).
#   spread: cuanto varia el dano alrededor de la misma media (1 = como la
#   forma; las balas varian mas y el laser casi nada); weight: peso.
TYPES = {
    "balas": {"tiers": ("COMMON", "RARE"), "spread": 1.2, "weight": 0.95},
    "canon": {"tiers": ("RARE", "EPIC"), "spread": 1.1, "weight": 1.05},
    "blaster": {"tiers": ("RARE", "LEGENDARY"), "spread": 1.0, "weight": 1.0},
    "laser": {"tiers": ("EPIC", "MYTHIC"), "spread": 0.5, "weight": 0.95},
}

# Formas: hueco, arma base por elemento, alcance (None = el de la base) y
# nombre por tipo ("" = esa combinacion no existe). Los nombres femeninos
# llevan la municion en femenino.
FORMS = [
    ("hoja", "SIDE", ["lat_mandoble", "lat_hoja_ignea", "lat_sable_arco"], None,
     {"balas": ("Cuchilla vibratoria", "f"), "blaster": ("Hoja de plasma", "f"), "laser": ("Hoja láser", "f")}),
    ("corto", "SIDE", ["lat_trabuco", "lat_lanzallamas", "lat_descargador"], None,
     {"balas": ("Escopeta", "f"), "canon": ("Obús corto", "m"), "blaster": ("Proyector de plasma", "m"), "laser": ("Láser de corte", "m")}),
    ("medio", "SIDE", ["lat_remachadora", "lat_mortero", "lat_bobina"], None,
     {"balas": ("Ametralladora", "f"), "canon": ("Lanzagranadas", "m"), "blaster": ("Repetidor de plasma", "m"), "laser": ("Láser de pulso", "m")}),
    ("largo", "SIDE", ["lat_rifle_riel", "lat_lanza_termica", "lat_canon_iones"], None,
     {"balas": ("Rifle", "m"), "canon": ("Cañón de brazo", "m"), "blaster": ("Lanza de plasma", "f"), "laser": ("Láser de precisión", "m")}),
    ("saboteador", "SIDE", ["lat_ariete", "lat_fundidor", "lat_sifon"], None,
     {"blaster": ("Sifón de plasma", "m"), "laser": ("Haz de drenaje", "m")}),
    ("bateria", "TOP", ["sup_canon_yunque", "sup_cohetes", "sup_proyector"], None,
     {"balas": ("Rotativa", "f"), "canon": ("Lanzamisiles", "m"), "blaster": ("Batería de plasma", "f"), "laser": ("Batería láser", "f")}),
    ("ancla", "TOP", ["sup_lanzarpones", "sup_lluvia_ceniza", "sup_arco_galvanico"], None,
     {"canon": ("Arpón", "m"), "laser": ("Haz tractor", "m")}),
    # Artilleria: alcance fijo, como en el original (docs/reference/original-mechanics.md).
    ("artilleria", "TOP", ["sup_obus", "sup_meteoro", "sup_tormenta"], (8, 8),
     {"canon": ("Obús", "m"), "blaster": ("Mortero de plasma", "m"), "laser": ("Lanza orbital", "f")}),
    # Pecho (decision del usuario, 2026-11-17: va aparte de las seis armas).
    # Canon pesado: un disparo devastador en linea, pocos usos (base: la
    # artilleria, con alcance 3-8). Nova: onda corta que dana y empuja.
    ("canon_pesado", "CHEST", ["sup_obus", "sup_meteoro", "sup_tormenta"], (3, 8),
     {"canon": ("Cañón de asedio", "m"), "blaster": ("Cañón de plasma", "m"), "laser": ("Cañón láser", "m")}),
    ("nova", "CHEST", ["lat_trabuco", "lat_lanzallamas", "lat_descargador"], (1, 2),
     {"blaster": ("Nova de plasma", "f"), "laser": ("Nova láser", "f")}),
    ("artillero", "DRONE", ["dron_avispa", "dron_ascua", "dron_chispa"], None,
     {"balas": ("Dron artillero", "m"), "canon": ("Dron bombardero", "m"), "blaster": ("Dron de plasma", "m"), "laser": ("Dron láser", "m")}),
    ("zapador", "DRONE", ["dron_buitre", "dron_fuelle", "dron_sanguijuela"], (1, 4),
     {"blaster": ("Dron sifón", "m"), "laser": ("Dron de drenaje", "m")}),
]
# La lanza orbital y el mortero de plasma alcanzan a 7: dos distancias fijas,
# como el original ([8,8] y [7,7]).
FIXED_RANGE = {("artilleria", "blaster"): (7, 7)}
# Disparo de cada arma: como se ve y como llega su dano (docs/CATALOGO_ARMAS.md,
# seccion 9). Cada id esta en data/shots.json, que lo dibuja.
SHOT_FX = {
    ("hoja", "balas"): "tajo_vibrante", ("hoja", "blaster"): "tajo_plasma", ("hoja", "laser"): "tajo_luz",
    ("corto", "balas"): "perdigones", ("corto", "canon"): "obus_corto",
    ("corto", "blaster"): "chorro_plasma", ("corto", "laser"): "soplete",
    ("medio", "balas"): "rafaga", ("medio", "canon"): "granada",
    ("medio", "blaster"): "pernos", ("medio", "laser"): "pulsos",
    ("largo", "balas"): "bala_rifle", ("largo", "canon"): "proyectil",
    ("largo", "blaster"): "lanza_plasma", ("largo", "laser"): "haz_fino",
    ("bateria", "balas"): "rotativa", ("bateria", "canon"): "misiles",
    ("bateria", "blaster"): "bolas_plasma", ("bateria", "laser"): "haces_dobles",
    ("ancla", "canon"): "arpon", ("ancla", "laser"): "tractor",
    ("artilleria", "canon"): "obus", ("artilleria", "blaster"): "mortero_plasma", ("artilleria", "laser"): "orbital",
    ("canon_pesado", "canon"): "asedio", ("canon_pesado", "blaster"): "esfera_plasma",
    ("canon_pesado", "laser"): "haz_grueso",
    ("nova", "blaster"): "nova_plasma", ("nova", "laser"): "nova_luz",
    ("artillero", "balas"): "rafaga_corta", ("artillero", "canon"): "bomba",
    ("artillero", "blaster"): "perno", ("artillero", "laser"): "haz_dron",
    ("zapador", "blaster"): "sifon", ("zapador", "laser"): "sifon",
}
# El saboteador hace algo distinto con cada municion: la cinetica empuja 4
# casillas (un repulsor), la termica funde y la ionica drena.
SABOTEUR_FX = {
    "blaster": {"PHYSICAL": "repulsor", "HEAT": "chorro_plasma", "ENERGY": "sifon"},
    "laser": {"PHYSICAL": "repulsor", "HEAT": "soplete", "ENERGY": "sifon"},
}
SABOTEUR_PUSH_NAMES = {"blaster": ("Repulsor de plasma", "m"), "laser": ("Haz repulsor", "m")}

# Ajustes propios de una forma sobre su arma base.
FORM_EXTRA = {
    # La nova pega mas que un arma corta, empuja dos casillas y tiene 3 usos.
    "nova": {"dmg": 1.3, "push": 2, "uses": 3},
}

# Robot de asistencia (usuario, 2026-11-17): un cuerpo por protocolo. Todos
# Cada uno da al mech una bonificacion que vale lo que 10 kg de modulos (el
# peso de los modulos es la vara: 300 de vida = 40 kg, 28 de las tres
# resistencias = 48 kg, 140 de capacidad = 22 kg, 60 de regeneracion o
# enfriamiento = 18 kg). Medido: con el doble, el mismo protocolo en todos
# ya movia el balance (laser, calor 57.8 %). Van de Basica a Unica: cinco
# transformaciones. No pesan.
ASSIST_BODIES = [
    ("asistente_escolta", "Asistente: protocolo Escolta",
     {"res_physical": 6, "res_heat": 6, "res_energy": 6}),
    ("asistente_blindaje", "Asistente: protocolo Blindaje", {"health": 75}),
    ("asistente_reactor", "Asistente: protocolo Reactor", {"energy_cap": 35, "energy_regen": 15}),
    ("asistente_criogenia", "Asistente: protocolo Criogenia", {"heat_cap": 35, "cooling": 15}),
]


def assist_bodies():
    out = []
    for aid, name, bonus in ASSIST_BODIES:
        top = {"weight": 0}
        top.update(bonus)
        out.append({"id": aid, "name": name, "type": "ASSIST", "element": "PHYSICAL",
                    "tier_min": "COMMON", "tier_max": "DIVINE", "top": top})
    return out


def make(form, slot, base, fixed, type_id, name, gender, element):
    t = TYPES[type_id]
    top = dict(base["top"])
    low, high = WEIGHT_RANGE[slot]
    top["weight"] = min(high, max(low, round(top["weight"] * t["weight"])))
    mean = (top["dmg_min"] + top["dmg_max"]) / 2.0
    half = (top["dmg_max"] - top["dmg_min"]) / 2.0 * t["spread"]
    top["dmg_min"] = max(1, round(mean - half))
    top["dmg_max"] = max(top["dmg_min"], round(mean + half))
    extra = FORM_EXTRA.get(form, {})
    if extra.get("dmg"):
        for key in ("dmg_min", "dmg_max", "heat_dmg", "energy_dmg"):
            if top.get(key):
                top[key] = max(1, round(top[key] * extra["dmg"]))
    for key in ("push", "uses"):
        if key in extra:
            top[key] = extra[key]
    rng = FIXED_RANGE.get((form, type_id), fixed)
    if rng is not None:
        top["range_min"], top["range_max"] = rng
    if form == "saboteador":
        fx = SABOTEUR_FX[type_id][element]
        if element == "PHYSICAL":
            name, gender = SABOTEUR_PUSH_NAMES[type_id]
    else:
        fx = SHOT_FX[(form, type_id)]
    ammo = AMMO[element] if gender == "f" else AMMO_MASC[element]
    item = {
        "id": "%s_%s_%s" % (form, type_id, AMMO_ID[element]),
        "name": "%s %s" % (name, ammo),
        "type": slot,
        "element": element,
        "tier_min": t["tiers"][0],
        "tier_max": t["tiers"][1],
        "weapon_type": type_id,
        "form": form,
        "fx": fx,
    }
    if base.get("tags"):
        item["tags"] = base["tags"]
    item["top"] = top
    return item


def main():
    dry = "--dry" in sys.argv
    items = load()
    base_items = {
        item["id"]: item
        for item in json.loads(BASES.read_text(encoding="utf-8"))["items"]
    }
    generated = []
    for form, slot, bases, fixed, names in FORMS:
        for type_id, (name, gender) in names.items():
            for element, base_id in zip(ELEMENTS, bases):
                generated.append(make(form, slot, base_items[base_id], fixed, type_id, name, gender, element))
    kept = {k: v for k, v in items.items() if v["type"] not in ("SIDE", "TOP", "DRONE", "CHEST", "ASSIST")}
    # Las piezas que no son armas existen en todas las clases normales.
    for item in kept.values():
        item["tier_min"] = "COMMON"
        item["tier_max"] = "MYTHIC"
    counts = {}
    for item in generated:
        counts[item["type"]] = counts.get(item["type"], 0) + 1
    print("armas generadas:", len(generated), counts)
    if dry:
        for item in generated[:6]:
            print(json.dumps(item, ensure_ascii=False))
        return
    out = dict(kept)
    for item in generated + assist_bodies():
        out[item["id"]] = item
    save(out)


if __name__ == "__main__":
    main()
