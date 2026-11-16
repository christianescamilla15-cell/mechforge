# MechForge — Documento de diseño (paso 1)

Versión 0.1 · 2026-11-16 · Estado: propuesta inicial. Los números son puntos de partida y se ajustan con el simulador (fase F3).

## 1. Visión
Duelos tácticos 1 contra 1 por turnos entre mechs armados pieza por pieza. Se juega en local (Windows), contra la IA, con una campaña y progresión completa.

Conservamos el núcleo de Super Mechs: arena lineal, 2 acciones por turno, tres elementos (físico, calor y energía), armado con límite de peso y tiers de objetos. Corregimos sus problemas conocidos: demasiado azar, bloqueo por calor, fórmulas ocultas, poca variedad de builds y un arte genérico y estático.

**Pilares**
1. Armar es la mitad del juego: cada pieza cambia cómo peleas.
2. Cada turno es una decisión legible: el jugador ve el resultado esperado antes de actuar.
3. Los tres elementos tienen identidad propia y se contrarrestan entre sí.
4. La progresión premia la táctica, no solo el grindeo.
5. Los mechs se ven propios y vivos: luz, efectos y animación por piezas (§11).

## 2. Combate

### 2.1 Arena
- Línea de 10 casillas (0–9). Solo puede haber un mech por casilla.
- Posiciones iniciales: un par al azar (por semilla) entre (4,5), (3,6) y (2,8).
- Sin terreno en el paso 1 (el terreno va al paso 2).

### 2.2 Ciclo de turno
1. **Inicio de turno — calor.** Si `calor > capacidad_calor`:
   - Si `calor − enfriamiento > capacidad_calor`: **apagado**. Enfría `2 × enfriamiento` y pierde el turno completo.
   - Si no: **enfriado forzado**. Enfría `1 × enfriamiento` y ese turno solo tiene 1 acción.
   - El calor no baja solo: únicamente con la acción de enfriar o con el enfriado forzado.
2. **Acciones:** 2 por turno (1 si hubo enfriado forzado). Cada arma se puede usar **una sola vez por turno**.
3. **Dron:** tras la última acción dispara automáticamente si puede pagar sus costos y tiene al rival en alcance. No gasta acción. Si el dron tiene usos, son por pelea. En un turno perdido por apagado el dron no dispara, pero la energía sí se regenera.
4. **Fin de turno:** regenera `energía += regeneración` (sin pasar de la capacidad) y se vacía la lista de armas usadas.
5. **Victoria:** gana quien deje al rival en 0 de vida. Si ambos caen en la misma acción (por backfire), gana quien conserve más vida; si empatan, gana el defensor.

### 2.3 Acciones disponibles
| Acción | Efecto |
|---|---|
| Caminar | Moverse hasta `max(andar, salto)` casillas. Sin salto no se puede pasar por encima del rival. |
| Pisotón | Las piernas son un arma de alcance [1,1] con su propio daño. |
| Usar arma | Arma lateral o superior: aplica costos y efectos (§2.5). |
| Enfriar | Reduce el calor en `1 × enfriamiento`. |
| Carga (especial) | Avanza hasta quedar pegado al rival y le hace daño físico. Usos limitados. |
| Teletransporte (especial) | Va a cualquier casilla libre; solo hace daño si aterriza junto al rival, pero su costo se paga siempre. Usos limitados. |
| Gancho (especial) | Jala al rival hasta quedar pegado y le hace daño. Usos limitados. |

### 2.4 Fórmula de daño
```
base   = min + round(azar[0,1) × (max − min))
daño   = max(1, base − resistencia_del_elemento_del_defensor)
daño  += max(0, daño_de_energía_del_arma − energía_actual_del_defensor)   # rotura de energía
```
- El azar sale del RNG con semilla del combate.
- La resistencia nunca baja de 0 (en el original podía quedar negativa; aquí no).

### 2.5 Efectos de usar un arma, en este orden
1. **Sobre el atacante:** `vida −= backfire`, `calor += costo_calor`, `energía −= costo_energía`.
2. **Sobre el defensor:** `vida −= daño`, `calor += daño_de_calor`, `energía = max(0, energía − daño_de_energía)`. Además, los daños que duran toda la pelea: a la resistencia del elemento (mínimo 0), a la capacidad de calor, al enfriamiento, a la capacidad de energía y a la regeneración (estas cuatro con mínimo 1).
3. **Posición:** retroceso y retirada mueven al atacante hacia atrás; el avance lo lleva hacia delante hasta quedar pegado al rival; el empuje aleja al defensor; el jalón lo acerca hasta quedar pegado. Todo queda limitado a la arena 0–9.
4. **Espadas** (`tag: espada`): antes de golpear, el atacante salta junto al rival.

### 2.6 Cuándo no se puede usar un arma
- Le falta energía para el costo.
- El backfire es mayor o igual que la vida que le queda.
- No le quedan usos en la pelea.
- Ya se usó en este turno.
- El rival está fuera de alcance. El alcance `[min,max]` se cuenta en casillas desde el atacante hacia el rival; un arma sin alcance llega a toda la arena.
- Requiere salto y las piernas no saltan (armas con avance o retirada que no son cuerpo a cuerpo).
- La retirada lo sacaría de la arena.

### 2.7 Mejoras sobre el original
Cada una es un interruptor en `RulesConfig`, encendido por defecto, para poder medir su efecto con el simulador.

| ID | Mejora | Motivo |
|---|---|---|
| M1 | Rangos de daño estrechos: cada arma con `max − min` de como mucho el 30 % de su media (±15 %). Lo exige el validador del catálogo. | En el original un arma pegaba de 234 a 419: demasiada suerte. |
| M2 | Sin apagados seguidos: si el turno anterior de un mech fue un apagado, su siguiente calor forzado es como mucho un enfriado simple. | Encadenar apagados dejaba al rival sin jugar. |
| M3 | Previsualización: antes de confirmar, la UI muestra el daño final mín–máx tras resistencias, el calor y la energía resultantes de ambos mechs, y avisa si la acción provoca enfriado forzado o apagado. | Las fórmulas del original eran opacas. |
| M4 | El dron está siempre activo: no existe la acción de encenderlo o apagarlo. | Era una acción torpe que casi nadie usaba bien. |
| M5 | Iniciativa: quien empieza tiene 1 sola acción en su primer turno. | Compensa la ventaja de abrir. |

## 3. Estadísticas
| Clave | Significado | Viene de |
|---|---|---|
| `peso` | kg | todas las piezas |
| `vida` | HP | torso, piernas, módulos |
| `cap_energia`, `regen_energia` | reserva y recuperación por turno | torso, módulos |
| `cap_calor`, `enfriamiento` | límite y enfriamiento por acción | torso, módulos |
| `res_fisica`, `res_calor`, `res_energia` | reducción plana del daño de ese elemento | torso, módulos |
| `andar`, `salto` | casillas de movimiento | piernas |
| `daño [min,max]` | daño del elemento del arma | armas, piernas, dron, especiales |
| `daño_calor`, `daño_energia` | calor que suma o energía que quita al rival | armas de calor y de energía |
| `daño_res`, `daño_cap_calor`, `daño_enfriamiento`, `daño_cap_energia`, `daño_regen` | daños que duran toda la pelea | algunas armas |
| `alcance [min,max]` | casillas | armas, dron |
| `empuje`, `jalon`, `retroceso`, `avance`, `retirada` | movimiento | algunas armas |
| `usos` | usos por pelea | algunas armas y especiales |
| `backfire` | daño a uno mismo | algunas armas |
| `costo_calor`, `costo_energia` | costos por uso | armas, dron, especiales |

## 4. Armado
- **Huecos:** torso, piernas, 4 armas laterales, 2 superiores, 1 dron, 8 módulos y un hueco por especial (carga, teletransporte y gancho).
- **Peso:** límite de 1000 kg. Se permite sobrecarga hasta +10 kg, con −15 de vida por cada kg de más. Por encima de 1010 kg el mech no puede pelear.
- **Obligatorio:** torso y piernas.
- **Resistencias:** como máximo 1 módulo por tipo de resistencia.
- Las estadísticas del mech son la suma de las de sus piezas.

## 5. Elementos y arquetipos
| Elemento | Identidad | Fuerte contra | Débil contra |
|---|---|---|---|
| Físico | Daño puro alto; rompe resistencias; empuja | Mechs con mucha resistencia | Mechs de mucha vida que lo esperan a distancia |
| Calor (explosivo) | Sobrecalienta al rival: le quita acciones y turnos | Mechs con poco enfriamiento | Mechs con mucha capacidad de calor |
| Energía (eléctrico) | Vacía la energía: niega disparos y suma daño por rotura | Mechs que dependen de armas con costo de energía | Builds de armas sin costo de energía |

- Se permiten builds híbridos. El simulador debe mostrar al menos un híbrido competitivo; si no lo hay, se ajusta el catálogo.
- Paleta por elemento para la UI y el arte: **físico** acero y gris, **calor** naranja y rojo, **energía** cian y azul.

## 6. Catálogo del paso 1
Unas 58 piezas con nombres propios (nunca los del original).

| Tipo | Por elemento | Total |
|---|---|---|
| Torso | 2 | 6 |
| Piernas | 2 (una que salta y una con ruedas: andar 3, sin salto) | 6 |
| Arma lateral | 6 (cuerpo a cuerpo, corta, media, larga y 2 de utilidad con empuje, jalón o retroceso) | 18 |
| Arma superior | 3 | 9 |
| Dron | 2 | 6 |
| Módulo | — | 10 (vida, cada resistencia, calor, energía y combinados) |
| Especiales | — | 3 (carga, teletransporte, gancho) |

**Anclas de balance:** valores de cada tipo en el tier máximo (Divino, nivel máximo), tomados de las medianas del catálogo original. La fase F2 deriva de ellos la base por tier y nivel con los multiplicadores de §8.

| Tipo | Anclas |
|---|---|
| Torso | 310–370 kg · vida ~1200 · cap. energía ~240 · regen ~64 · cap. calor ~280 · enfriamiento ~80 · resistencias ~20 |
| Piernas | 115–150 kg · vida ~430 · andar 1 y salto 2 (ruedas: andar 3) · pisotón ~[180, 220] |
| Lateral | 8–86 kg (mediana ~47) · alcances típicos [1,1], [1,2], [2,4], [3,6] · daño medio ~290 en armas de 2 o más usos |
| Superior | 19–75 kg (mediana ~50) · alcances típicos [3,6], [4,8], [8,8] · daño medio ~330 |
| Dron | 20–51 kg (mediana ~43) · daño medio ~200 |
| Módulo | 15–60 kg (mediana ~28) · resistencia ~40 · vida ~170 · capacidad ~120 · regen o enfriamiento ~55 |

- Las armas de calor y energía hacen menos daño directo, pero suman calor o quitan energía: en los laterales, alrededor de 90 de calor o 120 de energía.
- Las armas con usos limitados (1–3) pegan más fuerte que las de usos ilimitados.
- El backfire va en armas muy fuertes, como precio.

## 7. IA del rival
- **Por utilidad:** enumera todas las secuencias legales de 2 acciones (unas 600 como mucho) y puntúa cada una con el valor esperado. Suma el daño esperado, el calor y la energía que le niega al rival, y el valor de la posición resultante (tener al rival a tiro de las armas propias y quedar fuera del alcance de las suyas). Resta el riesgo propio de enfriado forzado o apagado y la vida perdida por backfire.
- **Dificultad:** fácil (mucho ruido en la puntuación; a veces elige la segunda mejor opción), normal, y difícil (además mira la mejor respuesta del rival a 1 turno).
- La misma IA sirve para los enemigos de la campaña y para el simulador de balance.

## 8. Progresión (completa)
- **Tiers:** Común → Raro → Épico → Legendario → Mítico → Divino. Cada pieza tiene un tier inicial y un tier máximo.
- **Niveles por tier:** 10 / 15 / 20 / 25 / 30 / 40.
- **Crecimiento:** `stat(tier, nivel) = base × mult_tier[tier] × (1 + 0.3 × nivel / nivel_máx)`, con `mult_tier` = 1.0 / 1.35 / 1.8 / 2.4 / 3.2 / 4.2. El peso no escala. Los costos crecen con la mitad de la pendiente que el daño, para que subir de nivel siempre se note.
- **Poder y fusión:** el nivel sube con "poder", que se gana fusionando piezas sobrantes (su poder depende de su tier) o núcleos.
- **Transformación:** al llegar al nivel máximo de su tier, la pieza puede transformarse al siguiente pagando oro y núcleos. Vuelve al nivel 0 del nuevo tier.
- **Monedas:** **oro** (sale de los combates) y **núcleos** (salen del botín y de desarmar piezas repetidas). No hay moneda de pago.
- **Botín:** cada victoria da oro y una tirada de botín, con mejores tablas en los capítulos avanzados. Hay cajas que se ganan jugando, nunca con dinero.
- **Taller de mejoras permanentes** (el equivalente de la tienda de arena): niveles comprados con oro. Daño, energía y calor hasta +20 %; resistencias hasta +40 %; vida hasta +350 plana; backfire hasta −20 %.
- **Objetivo de ritmo:** llevar un build completo a Divino debe costar unas 8–12 horas de juego. Se mide con el simulador en la fase F7.

## 9. Campaña
- Mapa de nodos con **3 capítulos**, cada uno con unos 10 combates y un jefe.
- Los enemigos tienen builds predefinidos (en datos) que suben de tier por capítulo. Los jefes tienen piezas únicas y reglas especiales (por ejemplo, más capacidad de calor).
- Los combates se pueden repetir para farmear. Cada capítulo desbloquea piezas y niveles del taller de mejoras.
- La curva de dificultad se valida con el simulador: el build "esperado" del jugador en cada capítulo debe ganar entre el 55 % y el 70 % de las veces contra los enemigos normales.

## 10. Pantallas
Menú · Taller (armado con resumen de stats, barra de peso y avisos) · Inventario y fusión · Taller de mejoras · Mapa de campaña · Combate (arena, mechs, botones de acción, previsualización y registro) · Resultados y botín · Ajustes.

## 11. Arte: sprites 2D generados con IA, con aspecto propio
**Objetivo:** que los mechs no se vean genéricos como en el original y que el juego corra holgado en la laptop del usuario (RTX 4050 6 GB, 16 GB de RAM).

**Por qué 2D y no 3D:** el combate 2D con luces y partículas usa una fracción mínima de la GPU (cabría incluso en la gráfica integrada). Lo genérico del original viene del estilo, no de ser 2D: piezas tipo caricatura, sin luz, sin efectos y casi sin animación. El 3D completo multiplicaría el trabajo (modelar, riggear y animar cada pieza) sin ser necesario.

**Lo que lo hace propio:**
1. **Generación guiada por silueta.** Para cada pieza definimos una silueta o blockout simple (forma, perspectiva lateral y escala). La IA la "pinta" con un estilo fijo (img2img o ControlNet). Así todas las piezas comparten perspectiva, escala y luz, que es el punto débil de generar a ciegas.
2. **Iluminación 2D con mapas de relieve.** Cada sprite lleva su normal map (derivado de un mapa de profundidad generado, o con una herramienta como Laigter) para que las luces 2D de Godot le den volumen.
3. **Shaders por estado:** brillo al rojo según el calor, arcos y chispas al quedarse sin energía, grietas y humo según la vida perdida, destello del elemento al recibir daño.
4. **Animación por piezas (cutout):** respiración en reposo, balanceo y pisada al caminar, retroceso de cada arma al disparar, sacudida al recibir golpe, con partículas, sacudida de cámara y pausa breve en los golpes fuertes.
5. **Dirección de arte coherente:** paleta por elemento (§5), siluetas reconocibles por arquetipo y variantes de tier que cambian color, emisivo o detalle, nunca la forma (así el montaje no se rehace).

**Montaje:** una imagen por pieza con fondo transparente. El torso define los puntos de montaje (2 piernas, 4 laterales y 2 superiores) y cada arma su punto de agarre, en un JSON de anclas por pieza. Es el mismo sistema del original.

**Pipeline (se decide en el spike F4):** silueta → generación con estilo fijo → quitar fondo (rembg o similar) → recortar y normalizar escala → normal map → anclas → revisión en un visor de montaje dentro de Godot. La herramienta se elige en el spike: local en la RTX 4050 (SDXL con descarga de memoria, o FLUX cuantizado; `diffusers` no está instalado) o un Space de Hugging Face. El estilo se aprueba con 3 mechs completos, uno por elemento, antes de producir el catálogo entero.

**Presupuesto de rendimiento:** 60 FPS fijos en combate y modo de bajo consumo del procesador en los menús. Las texturas de cada pieza no pasan de 512 px de lado y se agrupan en atlas. Se mide en la laptop en la fase F5.
