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

## La versión antigua (2012–2013)
El usuario recuerda una versión para un jugador: empezabas con un robot sencillo y avanzabas combate a combate hasta un jefe; era una demo que no pasaba de unos 10 combates. Es la que quiere recuperar (GDD §9). Buscado el 2026-11-16:

- El usuario la jugó hace más de 10 años y cree que existe desde hace unos 20 (hacia 2006). Lo más antiguo que se pudo documentar es de 2012, así que o estuvo antes en algún portal de juegos Flash, o era un juego anterior parecido. Falta que el usuario recuerde dónde la jugaba o algún detalle para localizarla.
- **No se encontró esa demo conservada** ni una descripción de ella. Queda sin confirmar en qué portal estaba.
- Wayback Machine tiene capturas de `supermechs.com` desde febrero de 2012 (una página con solo el texto "Super Mechs!"). En la de junio de 2012 el sitio ya cargaba el cliente Flash `BMMPortal.swf` con la descripción "Battle other players in your own Mech Warrior!", es decir, ya era multijugador.
- Una [reseña de enero de 2013](https://playlikecrazy.blogspot.com/2013/01/super-mechs.html) lo describe en beta, jugable en silvergames.com con registro: un tutorial, combates contra mechs de la computadora y contra otros jugadores, experiencia y créditos, "cientos" de mejoras para comprar, una ametralladora (minigun) y **kits de reparación** para recuperar vida en mitad del combate.
- Detalle de aquella época que el juego actual ya no tiene y que podemos recuperar: los consumibles de combate (kits de reparación).

## Quejas recurrentes de la comunidad (oportunidades)
- Calor y energía desbalanceados; las bombas de calor encadenan apagados.
- La rotura de energía pierde valor contra armas sin costo de energía.
- Mezclar armas de calor y de energía en un mismo build se desaconseja: pocas builds viables.
- El progreso por tiers es largo y pesa más que la táctica.

## Contraste con lo construido (2026-11-16)
Regla de trabajo que pidió el usuario: no se hace nada desde cero. Cada mecánica y cada detalle se afina partiendo de este análisis; lo que se aparte de él debe ser una decisión explícita.

**Coincide con el original**
- Arena de 10 posiciones y pares de salida: se mantienen. El "mapa más grande" que pidió el usuario es de pantalla (campo más ancho con cámara), no de reglas; así los alcances de las armas siguen valiendo.
- Turno, calor, energía, daño, rotura de energía, efectos sobre el defensor, empujes y jalones, y lo que impide disparar: en el motor, con sus tests.
- Movimiento: se anda o se salta según `max(andar, salto)`. La animación lo respeta desde hoy: salto en arco cuando el mech va más lejos de lo que anda o pasa por encima del rival; las espadas saltan junto al rival; la embestida, el teletransporte y el gancho tienen cada uno su gesto.
- Elementos físico, explosivo y eléctrico: son nuestras municiones cinética, térmica e iónica.
- Peso máximo, sobrecarga, resistencias exclusivas, tiers con rango de transformación y tienda de mejoras: en el diseño.
- De la versión de 2013: experiencia y créditos (nivel del jugador y oro), tienda con muchas mejoras (tienda del taller) y combates contra mechs de la computadora.

**Se aparta del original por decisión del usuario**
- Huecos de arma: el original lleva 4 laterales y 2 superiores (6 armas). El usuario fijó 2 brazos, 2 hombros y 1 pecho (5 armas) más el robot de soporte.
- Clases y niveles máximos (6/12/18/24/30/50), chasis con bonificaciones y tipos de arma ligados a la clase.
- Mejoras M1 a M6 del GDD, que responden a las quejas de la comunidad.
- Golpes críticos (2026-11-18, GDD §2.9): el original no los tiene (cada golpe es una sola tirada). El usuario los pidió con efectos: inutilizar un arma durante el turno, inmovilizar, etc.; casi seguros con el arma de pecho y mucho menos probables contra escudo y armadura gruesa.

**Se aparta del original por ajuste nuestro (pendiente del visto bueno del usuario)**
- Blindaje de la tienda: +15 % de vida en vez de +350 planos, porque aquí la vida escala con la clase (GDD §9.2).

**Me aparté sin base y hay que corregir**
- **Alcance de la artillería:** puse 5–9, que no existe en el original. Las armas superiores del original son [4,8], [3,6] y de alcance fijo [8,8] y [7,7]. La artillería pasa a alcance fijo.
- **Proporción de alcances en armas laterales:** en el original domina [2,4] (32 de 79), luego [1,2] (23), [3,6] (16) y [1,1] (6). Al generar las 111 armas hay que respetar esa proporción, no repartir a partes iguales.
- **Huecos que faltan en nuestro diseño:** el original tiene escudo y perk. El usuario ya mencionó el escudo; el perk encaja con el árbol de habilidades.
- **Dron:** en el original se enciende y eso recarga sus usos; nosotros lo dejamos siempre activo (mejora M4). Está decidido, pero la animación de encendido se puede conservar como despliegue del robot de soporte.

**Del original, aún sin usar**
- Kits de reparación en mitad del combate (versión de 2013): candidato a tipo de bonificación o a habilidad de combate.
- Ruedas (andar 3, sin salto) como tipo de piernas.

**No está en el análisis**
- La nave que deja bonificaciones: sale del recuerdo del usuario, no de las fuentes. Sus números (turno 3, cada 5, del 10 al 50 %, 3 turnos) son propuesta nuestra.

## Referencia de estructura: Swords and Sandals (2026-11-17)
El usuario nombró este juego como modelo de lo que pasa **fuera del combate** y lo confirmó con una captura de la búsqueda. Es una serie Flash de gladiadores (el segundo, *Emperor's Reign*, es de 2007). Sirve de referencia para el ciclo de la partida, no para el combate, que sigue siendo el de este documento.

**Lo que dicen las fuentes** (wiki de fans y fichas de tiendas; fiabilidad media):
- Combates por turnos de un gladiador contra otro en la arena.
- El gladiador sube de nivel y reparte puntos entre sus estadísticas (la wiki de fans habla de 8 estadísticas y 4 puntos por nivel).
- Fuera de la arena hay tiendas y herrero para comprar y equipar armas y armadura; el nivel desbloquea equipo mejor.
- Se asciende venciendo a los campeones de la arena, que hacen de jefes; los torneos van por tramos de nivel y pagan oro y experiencia.
- **No confirmado:** qué pasa al perder un duelo. Las fuentes no lo dicen; la regla de que perder contra el jefe termina la partida es decisión del usuario (GDD §9).

**Lo que tomamos** (GDD §9):
- Una base con tres sitios: la **campaña** (los combates de la zona y su jefe), la **arena** (combates sueltos para juntar moneda) y la **armería** (comprar puntos de mejora).
- El jugador decide cuándo desafiar al jefe: ir directo es una apuesta, y farmear en la arena la va volviendo segura.
- Perder contra el jefe termina la partida y se empieza de cero.

**Lo que no tomamos:** nombres, personajes, arte ni sonido. Tampoco su combate.

Fuentes: [wiki de fans](https://swordsandsandals.fandom.com/wiki/Swords_and_sandals_gladiator), [Wikipedia](https://en.wikipedia.com/wiki/Swords_and_Sandals), [TV Tropes](https://www.tvtropes.org/pmwiki/pmwiki.php/VideoGame/SwordsAndSandals), [ficha de Steam de la reedición](https://store.steampowered.com/app/649600/Swords_and_Sandals_2_Redux_Maximus_Edition/), [Flash Legacy](https://www.flashlegacy.com/game/swords-and-sandals-2-emperors-reign).
