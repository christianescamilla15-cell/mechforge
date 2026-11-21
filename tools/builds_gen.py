"""Genera los mechs de ejemplo y los jefes (data/builds.json) con las armas del
catalogo generado (tools/catalog_gen.py).

Cada elemento tiene un mech por tipo de arma ("band"): balas, canon, blaster y
laser. Los de balas llevan la marca "starter": con ellos se empezaba la partida
(ahora se empieza con un tipo de robot, data/styles.json) y los usan las
pruebas y los simuladores. Los jefes llevan las
armas del tipo de su zona y su elemento. Si una forma no existe en un tipo, se
usa la del tipo mas cercano que si cubra esa clase.

    python tools/builds_gen.py         escribe data/builds.json
    python tools/builds_gen.py --dry   solo muestra el resumen
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from catalog_tool import load  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BUILDS = ROOT / "data" / "builds.json"
MAX_WEIGHT = 1000
MIN_WEIGHT = 900
AMMO_ID = {"PHYSICAL": "cin", "HEAT": "ter", "ENERGY": "ion"}
BANDS = ["balas", "canon", "blaster", "laser"]
# Tipos de respaldo por banda, en orden, cuando una forma no existe en ella.
FALLBACK = {
    "balas": ["balas", "blaster", "canon", "laser"],
    "canon": ["canon", "blaster", "balas", "laser"],
    "blaster": ["blaster", "canon", "laser", "balas"],
    "laser": ["laser", "blaster", "canon", "balas"],
}
BAND_NAME = {"balas": "", "canon": " de Asalto", "blaster": " de Plasma", "laser": " Láser"}

# Robot de asistencia de los mechs de ejemplo y del Orden: todos el mismo
# protocolo y, de arma inferior, una gemela de la superior (alternan, asi
# que disparan lo mismo que el dron de siempre). Medido el 2026-11-17: con
# un protocolo distinto por elemento el balance se rompia (laser: fisico
# 76 %, energia 28 %), y con un zapador distinto por elemento, mas (fisico
# 90 %, calor 20 %). Igual para todos, el asistente suma lo mismo a los dos
# lados.
ASSIST_PROTOCOL = "asistente_blindaje"

# Mechs de ejemplo: id base, nombre, elemento, torso, piernas, armas por
# (forma, elemento), modulos y especiales. Mismas piezas que los anteriores.
MECHS = [
    ("fisico_vanguardia", "Vanguardia", "PHYSICAL", "torso_baluarte", "piernas_zancos",
     [("hoja", "PHYSICAL"), ("corto", "PHYSICAL"), ("medio", "PHYSICAL"), ("largo", "PHYSICAL")],
     [("bateria", "PHYSICAL")], ("artillero", "PHYSICAL"),
     ["mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador"],
     {"charge": "esp_embestida", "hook": "esp_garfio"}),
    ("calor_horno", "Horno", "HEAT", "torso_fragua", "piernas_pisabrasas",
     [("hoja", "HEAT"), ("corto", "HEAT"), ("medio", "HEAT"), ("largo", "HEAT")],
     [("bateria", "HEAT")], ("artillero", "HEAT"),
     ["mod_blindaje", "mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador"],
     {"charge": "esp_embestida", "hook": "esp_garfio"}),
    ("energia_tempestad", "Tempestad", "ENERGY", "torso_dinamo", "piernas_zancas_arco",
     [("hoja", "ENERGY"), ("corto", "ENERGY"), ("medio", "ENERGY"), ("largo", "ENERGY")],
     [("bateria", "ENERGY")], ("artillero", "ENERGY"),
     ["mod_blindaje", "mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador"],
     {"charge": "esp_embestida", "teleport": "esp_baliza", "hook": "esp_garfio"}),
    ("hibrido_quimera", "Quimera", "HYBRID", "torso_centinela", "piernas_zancos",
     [("corto", "PHYSICAL"), ("corto", "HEAT"), ("medio", "ENERGY"), ("largo", "PHYSICAL")],
     [("ancla", "HEAT"), ("ancla", "ENERGY")], ("artillero", "PHYSICAL"),
     ["mod_blindaje", "mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador"],
     {"charge": "esp_embestida"}),
]
NAMES = {
    "fisico_vanguardia": "Vanguardia de Acero",
    "calor_horno": "Horno Andante",
    "energia_tempestad": "Tempestad",
    "hibrido_quimera": "Quimera",
}

# Jefes: id, nombre, mech del que toman las piezas, chasis y banda (la de su zona).
BOSSES = [
    ("jefe_zona_1", "Capataz del Orden", "fisico_vanguardia", "jefe_blindado", "balas"),
    ("jefe_zona_2", "Verdugo del Orden", "fisico_vanguardia", "jefe_potencia", "balas"),
    ("jefe_zona_3", "Reactor del Orden", "energia_tempestad", "jefe_reactor", "canon"),
    ("jefe_zona_4", "Hidra del Orden", "calor_horno", "jefe_hidra", "canon"),
    ("jefe_zona_5", "Centella del Orden", "hibrido_quimera", "jefe_veloz", "blaster"),
    ("jefe_zona_6", "Égida del Orden", "calor_horno", "jefe_egida", "blaster"),
    ("jefe_zona_7", "Espectro del Orden", "energia_tempestad", "jefe_espectro", "laser"),
    ("jefe_zona_8", "Caldera del Orden", "calor_horno", "jefe_caldera", "laser"),
    ("jefe_zona_9", "Colmena del Orden", "fisico_vanguardia", "jefe_colmena", "laser"),
    ("jefe_final", "Coloso del Orden", "hibrido_quimera", "jefe_coloso", "laser"),
]


def weapon(catalog, form, element, band):
    for type_id in FALLBACK[band]:
        wid = "%s_%s_%s" % (form, type_id, AMMO_ID[element])
        if wid in catalog:
            return wid
    raise KeyError("no hay arma %s %s" % (form, element))


def weight(catalog, items):
    total = 0
    for key in ("torso", "legs", "drone", "charge", "teleport", "hook"):
        if items.get(key):
            total += catalog[items[key]]["top"]["weight"]
    for key in ("sides", "tops", "modules"):
        for wid in items.get(key, []):
            total += catalog[wid]["top"]["weight"]
    return total


def build_items(catalog, mech, band):
    base_id, _, _, torso, legs, sides, tops, drone, modules, special = mech
    protocol, low = ASSIST_PROTOCOL, drone
    items = {
        "torso": torso,
        "legs": legs,
        "sides": [weapon(catalog, f, e, band) for f, e in sides],
        "tops": [weapon(catalog, f, e, band) for f, e in tops],
        "assist": protocol,
        "drone": weapon(catalog, drone[0], drone[1], band),
        "drone_low": weapon(catalog, low[0], low[1], band),
        "modules": list(modules),
    }
    items.update(special)
    # Que quepa en el peso sin sobrecarga: se quitan modulos repetidos y luego
    # cualquiera, empezando por el final.
    while weight(catalog, items) > MAX_WEIGHT and items["modules"]:
        repeated = [m for m in items["modules"] if items["modules"].count(m) > 1]
        items["modules"].remove(repeated[-1] if repeated else items["modules"][-1])
    # Y que aproveche el peso: si sobra, se anaden blindajes (dan vida).
    armor = catalog["mod_blindaje"]["top"]["weight"]
    while (
        weight(catalog, items) < MIN_WEIGHT
        and weight(catalog, items) + armor <= MAX_WEIGHT
        and len(items["modules"]) < 8
    ):
        items["modules"].append("mod_blindaje")
    return items


def main():
    dry = "--dry" in sys.argv
    catalog = load()
    out = []
    for mech in MECHS:
        base_id = mech[0]
        for band in BANDS:
            bid = base_id if band == "balas" else "%s_%s" % (base_id, band)
            name = NAMES[base_id] if band == "balas" else mech[1] + BAND_NAME[band]
            items = build_items(catalog, mech, band)
            entry = {"id": bid, "name": name, "element": mech[2], "band": band}
            if band == "balas":
                entry["starter"] = True
            entry["items"] = items
            out.append(entry)
            print("%-28s %-22s %4d kg" % (bid, name, weight(catalog, items)))
    by_id = {mech[0]: mech for mech in MECHS}
    for boss_id, name, source, chassis, band in BOSSES:
        mech = by_id[source]
        items = build_items(catalog, mech, band)
        out.append(
            {
                "id": boss_id,
                "name": name,
                "element": mech[2],
                "band": band,
                "boss": True,
                "chassis": chassis,
                "items": items,
            }
        )
        print("%-28s %-22s %4d kg" % (boss_id, name, weight(catalog, items)))
    if not dry:
        BUILDS.write_text(
            json.dumps({"schema_version": 1, "builds": out}, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )


if __name__ == "__main__":
    main()
