# Referencia: mecánicas del Super Mechs original

Solo para consulta. Donde `docs/GDD.md` diga otra cosa, manda el GDD.
Investigado el 2026-11-16. Super Mechs es de Tacticsoft / Gato Games (Android `air.com.supermechs.superapp`, versión 7.628.4).

## Fuentes y confianza
| Fuente | Qué aporta | Confianza |
|---|---|---|
| [ctrlraul/supermechs-workshop](https://github.com/ctrlraul/supermechs-workshop) — `src/battle/Battle.ts`, `BattleActionsHandler.ts`, `BattleEffectsHandler.ts` | Motor de combate completo hecho por fans (TypeScript) | Alta: coincide con la otra fuente |
| [Tankaregmi/workshop-unlimited](https://github.com/Tankaregmi/workshop-unlimited) — `src/battle/BattleUtils.ts`, `src/managers/BattleManager.ts` | Segundo motor de fans, independiente | Alta: coincide con la anterior |
| [Enegg/supermechs](https://github.com/Enegg/supermechs) — `gamerules.py`, `enums/`, `tools/stats.py` | Reglas de armado, stats, tiers y tienda de arena | Alta |
| [Enegg/Item-packs](https://github.com/Enegg/Item-packs) — `items.json` | 214 objetos con stats en todos los tiers | Alta (datos recopilados por la comunidad) |
| Wiki de Fandom y foro de la comunidad (fragmentos de búsqueda) | Consejos de juego y quejas de balance | Media: opinión de jugadores |
| App Store (notas de versión) | Modos: campaña 3v3, sobrecarga y Titanes | Alta para lo que dice |

No hay versión HTML5 del juego: la web es Flash y escritorio y móvil son Adobe AIR. Por eso no se puede inspeccionar con CDP; tampoco hizo falta.

## Reglas confirmadas por los dos motores
- **Arena:** posiciones 0–9. Pares de salida: (4,5), (3,6) y (2,8).
- **Turno:** 2 acciones. Si al empezar el turno `calor > cap_calor`: si `calor − enfriamiento > cap_calor`, enfriado doble y se pierde el turno; si no, enfriado simple y queda 1 acción.
- **No hay enfriamiento pasivo:** el calor solo baja con la acción de enfriar o con el enfriado forzado.
- **Fin de turno:** `energía = min(cap, energía + regen)`.
- **Dron:** tras la última acción, si está activo y puede disparar. Encenderlo recarga sus usos.
- **Cada arma una vez por turno.**
- **Daño:** `min + round(azar × (max − min))`; si el defensor tiene resistencia de ese elemento, `max(1, daño − res)`; luego `daño −= min(0, energía_def − daño_energía)` (rotura de energía).
- **Efectos:**
  - Atacante: `vida −= backfire`, `calor += costo_calor`, `energía −= costo_energía`.
  - Defensor: `vida −= daño`, `calor += daño_calor`, `res −= daño_res` (sin mínimo en el original), y las capacidades, el enfriamiento y la regeneración bajan con mínimo 1.
- **Movimiento:** `max(andar, salto)`; sin salto no se pasa por encima del rival.
- **Posición:** retroceso y retirada (atacante hacia atrás), avance (hasta quedar pegado), empuje (defensor hacia atrás) y jalón (hasta quedar pegado). Las espadas saltan junto al rival antes de golpear.
- **Especiales:** la carga lleva al atacante junto al rival y hace daño; el teletransporte va a cualquier casilla libre y solo daña si aterriza junto al rival; el gancho trae al rival junto al atacante y hace daño.
- **No se puede disparar si:** falta energía; `backfire ≥ vida`; no quedan usos; ya se usó en el turno; está fuera de alcance; requiere salto y las piernas no saltan; la retirada saca de la arena.

## Reglas de armado (Enegg/supermechs)
- Huecos: torso, piernas, dron, 4 laterales, 2 superiores, 8 módulos, teletransporte, carga, gancho, escudo y perk.
- Peso máximo 1000 kg; sobrecarga hasta +10 kg con −15 de vida por kg.
- Las resistencias son exclusivas: como máximo un módulo de cada tipo.
- Tiers: Común, Raro, Épico, Legendario, Mítico, Divino (y Perk). Cada objeto tiene un rango de transformación (por ejemplo Legendario → Divino). El nivel sube con "poder" y, al maximizarlo, el objeto se transforma.
- Tienda de arena: la mayoría de mejoras van de +0 a +20 % en 10 niveles (0, 1, 3, 5, 7, 9, 11, 13, 15, 17, 20); resistencias hasta +40 %; vida +0 a +350 plana; backfire −0 a −20 %. Otras categorías: oro de arena y campaña, daño a Titanes, crafteo y cajas de fortuna.

## Catálogo original (214 objetos, stats en Divino al máximo)
| Tipo | Cantidad | Rangos (mediana) |
|---|---|---|
| Arma lateral | 79 | peso 8–86 (47) · alcances [2,4]×32, [1,2]×23, [3,6]×16, [1,1]×6, [4,8]×2 · usos 1–3 · backfire 72–180 |
| Arma superior | 35 | peso 19–75 (50) · alcances [4,8]×15, [3,6]×9, [8,8]×6, [7,7]×3 · backfire 180–490 |
| Dron | 29 | peso 20–51 (43) · costos ~31 |
| Torso | 24 | peso 309–370 (346) · vida 884–1786 (1214) · cap. energía (242) · regen (64) · cap. calor (282) · enfriamiento (80) · resistencias (~20) |
| Módulo | 24 | peso 15–60 (28) · resistencia 16–69 · vida 145–332 |
| Piernas | 15 | peso 114–150 (123) · vida 295–909 (428) · andar 1 (ruedas 3) · salto 2 · alcance [1,1] |
| Gancho / teletransporte / carga | 3 / 3 / 2 | 1–2 usos |

- **Elementos:** explosivo 72, eléctrico 70, físico 65 y combinado 7 (solo módulos).
- **Daño medio de laterales en Divino:** físico ~[213, 368], explosivo ~[175, 313], eléctrico ~[175, 289]. La variación llega al ±40 %.
- **Tier inicial:** Legendario 118, Épico 72, Raro 12, Común 8, Mítico 4.
- La lista completa de nombres, prohibida en nuestro catálogo, está en `original-item-names.txt`.

## Modos del original
Campaña 1v1, 2v2 y 3v3; PvP por emparejamiento con rangos; torneo semanal; clanes y alianzas con guerras semanales; Titanes (jefes de clan); base con crafteo; cajas de fortuna; chat. Es online (MMO).

## Quejas recurrentes de la comunidad (oportunidades)
- Calor y energía desbalanceados; las bombas de calor encadenan apagados.
- La rotura de energía pierde valor contra armas sin costo de energía.
- Mezclar armas de calor y de energía en un mismo build se desaconseja: pocas builds viables.
- El progreso por tiers es largo y pesa más que la táctica.
