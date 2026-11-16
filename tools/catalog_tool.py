"""Lee y escribe data/catalog.json conservando su formato (una pieza por linea,
agrupadas por tipo). Sirve para ajustar el balance por lotes desde un script:

    from catalog_tool import load, save
    items = load()
    items["lat_trabuco"]["top"]["energy_cost"] = 40
    save(items)

Tambien se puede ejecutar para reformatear el archivo: python tools/catalog_tool.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "data" / "catalog.json"
TYPE_ORDER = ["TORSO", "LEGS", "SIDE", "TOP", "DRONE", "MODULE", "CHARGE", "TELEPORT", "HOOK"]
ELEMENT_ORDER = ["PHYSICAL", "HEAT", "ENERGY", "COMBINED"]


def load():
    """Devuelve {id: item} en el orden del archivo."""
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return {item["id"]: item for item in data["items"]}


def save(items):
    """Escribe el catalogo: una pieza por linea y una linea en blanco entre grupos."""
    lines = ['{', '  "schema_version": 1,', '  "items": [']
    ordered = list(items.values())
    previous_group = None
    for index, item in enumerate(ordered):
        group = _group(item)
        if previous_group is not None and group != previous_group:
            lines.append("")
        previous_group = group
        comma = "," if index < len(ordered) - 1 else ""
        lines.append("    " + json.dumps(item, ensure_ascii=False) + comma)
    lines += ["  ]", "}", ""]
    CATALOG.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def _group(item):
    # Las armas laterales se separan por elemento; los especiales van juntos.
    kind = item["type"]
    if kind in ("CHARGE", "TELEPORT", "HOOK"):
        return "SPECIAL"
    if kind == "SIDE":
        return kind + item["element"]
    return kind


def scale(item, keys, factor):
    """Multiplica las estadisticas indicadas y redondea al entero mas cercano."""
    for key in keys:
        if key in item["top"]:
            item["top"][key] = max(1, round(item["top"][key] * factor))


if __name__ == "__main__":
    save(load())
    print("catalogo reformateado:", CATALOG)
