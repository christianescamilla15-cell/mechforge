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
4. **Energía:** al **inicio** de cada turno propio se regenera `energía += regeneración`, sin pasar de la capacidad (mejora M6; el original regeneraba al final del turno).
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
| M6 | La energía se regenera al inicio del turno propio, no al final. | Con la regla original, un drenaje dejaba al rival en 0 justo antes de jugar y lo bloqueaba por completo. Así siempre le queda su regeneración para actuar. |

**Efecto medido con el simulador (F3):**
- **M1** hace los combates casi deterministas: entre mechs parejos, un 1 % de ventaja mueve la tasa de victoria unos 10 puntos. Por eso el balance se mide con el margen (vida que le sobra al ganador) además de la tasa.
- **M5:** sin ella, quien empieza gana el 71 % de los combates espejo; con ella, alrededor del 55–58 %. El valor exacto oscila entre 31 % y 69 % según la vida total, porque depende de si hacen falta un número par o impar de acciones para matar.
- **M6:** sin ella, el mech de energía gana el 82 % y quien empieza el 69 %.
- **M2:** con los mechs de ejemplo no cambia nada medible. Los apagados son el 0.5 % de los turnos y nunca se encadenan; queda como red de seguridad para builds extremos.

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

**Cómo se guardan:** `data/catalog.json` tiene las estadísticas de cada pieza en el tier máximo (Divino a nivel máximo). El resto de tiers y niveles se calcula bajándolas en proporción (§8). `data/validation.json` fija los rangos de peso y la composición mínima que exige el validador, y `data/builds.json` los mechs de ejemplo (uno por elemento y un híbrido).

**Valores tras el ajuste de F3** (Divino a nivel máximo). El daño es más bajo que en el original para que los combates duren más de tres rondas:

| Tipo | Valores |
|---|---|
| Torso | 315–365 kg · vida 1200–1600 · cap. energía 180–400 · regen 50–125 · cap. calor 250–400 · enfriamiento 85–135 · resistencias 15–30 |
| Piernas | 116–140 kg · vida 400–520 · andar 1 y salto 2, o ruedas con andar 3 · pisotón: físico ~135–150, calor y energía ~110–120 |
| Lateral | 30–60 kg · alcances [1,1], [1,2], [1,3], [2,4], [3,6] · daño medio: físico 194–248, calor y energía 172–232; las de utilidad, 76–135 |
| Superior | 48–70 kg · alcances [3,6], [4,8], [5,9] · daño medio: físico 208–248, calor y energía 194–232; las de 2 usos, 330 y 292 |
| Dron | 30–42 kg · daño medio: físico 92–116, calor y energía 68–97 |
| Módulo | 18–48 kg · resistencia 45 (o 28 a las tres) · vida 300 · capacidad 140 · regen o enfriamiento 60 |
| Especiales | 14–22 kg · 1 uso |

- **Identidad de elemento** (la exige el validador): las armas físicas no dan calor ni drenan energía; las de calor llevan `daño_calor` (laterales 39–48) y las de energía `daño_energia` (laterales 70–80), a cambio de un 7–11 % menos de daño directo.
- **Costos:** las armas físicas gastan energía (laterales 30–45) y algo de calor; las de calor gastan sobre todo calor propio; las de energía, sobre todo energía. El costo de energía de las físicas es lo que hace que el drenaje les pese.
- Las armas con usos limitados (1–3) pegan más fuerte o tienen un efecto grande (bombas de calor y de drenaje, daño a capacidades).
- **Tier inicial:** el equipo básico empieza en Común; las piezas especializadas, en Raro, Épico o Legendario. Todas llegan a Divino.

## 7. IA del rival
- **Búsqueda:** en su turno prueba cada secuencia legal de 2 acciones en una copia del combate (unas 600 como mucho), usando el daño esperado en lugar de tiradas, y valora el estado en el que queda. Ejecuta la primera acción de la mejor secuencia y vuelve a decidir antes de la segunda.
- **Valoración**, en fracciones de barra de vida:
  - Diferencia de vida entre los dos mechs.
  - Lo que vale una acción de cada mech: el daño medio de sus dos mejores armas sobre la vida del rival. Todo lo demás se mide en esa unidad.
  - Acciones que el calor ya le quitó al rival (enfriado forzado o apagado), a su valor completo.
  - Calor acumulado: cada `enfriamiento` de calor acabará costando una acción, así que vale una fracción de una acción (`heat_discount`), a favor si es del rival y en contra si es propio.
  - Energía: cuánto le falta a cada mech para disparar sus dos armas más caras.
  - Posición: qué parte del mejor daño de cada uno alcanza a la distancia actual.
- **No enfría antes de tiempo.** El enfriado forzado cuesta la misma acción que enfriar voluntariamente y además aprovecha el margen del tope de calor. Una versión anterior de la IA enfriaba por miedo al sobrecalentamiento y perdía la mitad de sus acciones.
- **Dificultad:** al azar (solo para pruebas), fácil (ruido en la valoración), normal, y difícil (revisa las mejores jugadas contra la mejor respuesta del rival). Los parámetros están en `AIConfig`.
- La misma IA sirve para los enemigos de la campaña y para el simulador de balance.

### 7.1 Cómo se mide el balance
- `tools/sim.ps1` enfrenta a todos los mechs de `data/builds.json` entre sí con la IA normal, en paralelo, y comprueba las puertas de la fase F3. Con `-Trace` imprime un combate jugada por jugada.
- **Promedia sobre varias escalas de vida** (por defecto 0.92 a 1.08). Con poco azar, quién gana un cruce parejo depende de la paridad de las acciones necesarias para matar; promediar mide el balance y no ese artefacto. Con `--levels` promedia también sobre niveles del tier.
- **Resultado en Divino máximo** (1600 combates): físico 51.5 %, calor 49.8 %, energía 48.8 %, híbrido 48.0 %. Márgenes entre elementos de ±1 %. Duración media de 12.3 turnos. Un 23 % de los turnos empieza con enfriado forzado.
- **Limitación conocida:** en tiers bajos los números son pequeños y el redondeo desplaza el balance. En Común, promediando niveles, los tres elementos quedan en 50 %, pero el híbrido de ejemplo sube al 61 %; nivel a nivel, un elemento puede irse a ±10 puntos.
- Los mechs de ejemplo llevan el mismo paquete de módulos (blindaje, matriz defensiva, generador y disipador) para que la comparación mida los elementos y no qué contra lleva cada uno. Los de calor, energía y el híbrido llevan un segundo blindaje porque sus piezas pesan menos.
- El balance está ajustado para estos cuatro mechs. Otros builds pueden romperlo; se revisará cuando existan los enemigos de la campaña (F8).

## 8. Progresión (completa)
- **Tiers:** Común → Raro → Épico → Legendario → Mítico → Divino. Cada pieza tiene un tier inicial y un tier máximo.
- **Niveles por tier:** 10 / 15 / 20 / 25 / 30 / 40.
- **Crecimiento:** `poder(tier, nivel) = mult_tier[tier] × (1 + 0.3 × nivel / nivel_máx)`, con `mult_tier` = 1.0 / 1.35 / 1.8 / 2.4 / 3.2 / 4.2. Va de 1.0 (Común nivel 0) a 5.46 (Divino nivel 40), y transformar una pieza siempre la mejora aunque reinicie el nivel.
- **Escalado proporcional:** `stat = stat_del_catálogo × poder / 5.46`, redondeado y con mínimo 1. Escalan la vida, las capacidades, la regeneración, el enfriamiento, las resistencias, todos los daños, el backfire y los costos. No escalan el peso, el movimiento, el alcance, los empujes ni los usos. Como todo usa el mismo factor, un duelo entre mechs del mismo tier se comporta igual en cualquier tier: el balance se ajusta una sola vez.
- Los costos escalan igual que el daño. Un arma de tier alto en un torso de tier bajo gasta una parte grande de su energía y su calor: hay que subir el núcleo para alimentar las armas grandes.
- **Poder y fusión:** el nivel sube con "poder", que se gana fusionando piezas sobrantes (su poder depende de su tier) o núcleos.
- **Transformación:** al llegar al nivel máximo de su tier, la pieza puede transformarse al siguiente pagando oro y núcleos. Vuelve al nivel 0 del nuevo tier.
- **Monedas:** **oro** (sale de los combates) y **núcleos** (salen del botín y de desarmar piezas repetidas). No hay moneda de pago.
- **Botín:** cada victoria da oro y una tirada de botín, con mejores tablas en los capítulos avanzados. Hay cajas que se ganan jugando, nunca con dinero.
- **Taller de mejoras permanentes** (el equivalente de la tienda de arena): niveles comprados con oro. Daño, energía y calor hasta +20 %; resistencias hasta +40 %; vida hasta +350 plana; backfire hasta −20 %.
- **Objetivo de ritmo:** llevar un build completo a Divino debe costar unas 8–12 horas de juego. Se mide con el simulador en la fase F7.

## 9. Campaña
**Visión (del usuario, 2026-11-16):** recuperar la versión antigua de Super Mechs para un jugador. Empiezas con un robot sencillo y avanzas combate a combate hasta un jefe superior al que solo se vence con táctica. Aquella versión era una demo que no pasaba de los primeros 10 combates; aquí va completa. La meta es unir la originalidad y el detalle del juego antiguo con las mecánicas de combate modernas. No hay multijugador.

- El jugador empieza con un mech básico de tier Común (torso, piernas y un par de armas) y lo va completando con lo que gana.
- Escalera de combates en **3 capítulos**, cada uno con unos 10 combates y un jefe al final.
- Los enemigos tienen builds predefinidos (en datos) que suben de tier por capítulo. Los jefes tienen piezas únicas y reglas especiales (por ejemplo, más capacidad de calor).
- Los combates se pueden repetir para farmear. Cada capítulo desbloquea piezas y niveles del taller de mejoras.
- La curva de dificultad se valida con el simulador: el build "esperado" del jugador en cada capítulo debe ganar entre el 55 % y el 70 % de las veces contra los enemigos normales.

## 10. Pantallas
Menú · Taller (armado con resumen de stats, barra de peso y avisos) · Inventario y fusión · Taller de mejoras · Mapa de campaña · Combate (arena, mechs, botones de acción, previsualización y registro) · Resultados y botín · Ajustes.

## 11. Arte: sprites 2D generados con IA, con aspecto propio
**Objetivo:** que los mechs no se vean genéricos como en el original y que el juego corra holgado en la laptop del usuario (RTX 4050 6 GB, 16 GB de RAM).

**Por qué 2D y no 3D:** el combate 2D con luces y partículas usa una fracción mínima de la GPU (cabría incluso en la gráfica integrada). Lo genérico del original viene del estilo, no de ser 2D: piezas tipo caricatura, sin luz, sin efectos y casi sin animación. El 3D completo multiplicaría el trabajo (modelar, riggear y animar cada pieza) sin ser necesario.

**Dirección de arte (del usuario, 2026-11-16): mecha japonés.** Se mantiene la base del juego original (mechs modulares vistos de lado, cada pieza es un sprite) con la estética de la ilustración de robots japonesa: blindaje anguloso, líneas de panel, propulsores, sensores luminosos y sombreado tipo cel. Los diseños son propios y genéricos dentro de ese estilo: no se reproduce ninguna franquicia concreta ni sus nombres.

**Lo que lo hace propio:**
1. **Generación guiada por silueta.** Para cada pieza definimos una silueta o blockout simple (forma, perspectiva lateral y escala). La IA la "pinta" con un estilo fijo (img2img o ControlNet). Así todas las piezas comparten perspectiva, escala y luz, que es el punto débil de generar a ciegas.
2. **Iluminación 2D con mapas de relieve.** Cada sprite lleva su normal map (derivado de un mapa de profundidad generado, o con una herramienta como Laigter) para que las luces 2D de Godot le den volumen.
3. **Shaders por estado:** brillo al rojo según el calor, arcos y chispas al quedarse sin energía, grietas y humo según la vida perdida, destello del elemento al recibir daño.
4. **Animación por piezas (cutout):** respiración en reposo, balanceo y pisada al caminar, retroceso de cada arma al disparar, sacudida al recibir golpe, con partículas, sacudida de cámara y pausa breve en los golpes fuertes.
5. **Dirección de arte coherente:** paleta por elemento (§5), siluetas reconocibles por arquetipo y variantes de tier que cambian color, emisivo o detalle, nunca la forma (así el montaje no se rehace).

**Montaje:** una imagen por pieza con fondo transparente. El torso define los puntos de montaje (2 piernas, 4 laterales y 2 superiores) y cada arma su punto de agarre, en un JSON de anclas por pieza. Es el mismo sistema del original.

**Pipeline** (detalle, licencias y alternativas en `docs/reference/art-pipeline.md`): silueta y bloque de color nuestros → generación local con un modelo de ilustración japonesa (Illustrious-XL) guiado por un ControlNet → recorte del fondo → reducción a 512 px → mapa normal → anclas → revisión en un visor de montaje dentro de Godot. Todo corre en la RTX 4050 del usuario, sin servicios en la nube. El estilo se aprueba con mechs de referencia, uno por elemento, antes de producir el catálogo entero.

**Presupuesto de rendimiento:** 60 FPS fijos en combate y modo de bajo consumo del procesador en los menús. Las texturas de cada pieza no pasan de 512 px de lado y se agrupan en atlas. Se mide en la laptop en la fase F5.
