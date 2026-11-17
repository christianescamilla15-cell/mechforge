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

### 1.1 Historia y universo
Definido por el usuario el 2026-11-16.

- El universo está bajo un **orden de máquinas** que quiere conquistarlo todo, a cualquier costo.
- Una parte de los robots se ha **insurreccionado** contra ese orden. Los insurrectos buscan la convivencia pacífica con las demás especies del universo.
- El jugador es un robot insurrecto. Empieza con un mech sencillo y lo mejora combate a combate.
- Cada mundo tiene **10 jefes** del orden. Los jefes usan la línea de diseño robusta; el jugador y los rivales normales, la esbelta (§11).
- Los nombres de las facciones, los mundos y los jefes están por escribir.

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

### 2.8 Bonificaciones que caen en la arena
Pedido por el usuario el 2026-11-16, como en el juego antiguo. **En el motor desde ese día** (tests/unit/test_drops.gd, 11 tests).

- Durante el combate pasa una nave y deja caer una bonificación en una casilla libre de la arena.
- La toma el mech que llega a esa casilla, sea andando, saltando o empujado.
- Quien la toma tiene la ventaja durante **3 turnos propios**.
- Todo es al azar: el tipo (más **armadura**: recibe menos daño; más **potencia de disparo**: hace más daño) y la cantidad, entre el **10 % y el 50 %**. El azar sale de la semilla del combate, así que un combate se repite igual.
- El tipo se ve en cuanto cae; la cantidad solo al tomarla.
- Cae la primera en el turno 3 y otra cada 5 turnos si no queda ninguna en la arena.
- La IA la valora (lo que da por los turnos que le quedan) y va a por ella cuando le compensa.
- Todos los números están en RulesConfig (grupo Bonificaciones). En las reglas vienen apagadas, para no alterar las pruebas ni el simulador; el juego las enciende al arrancar.
- **Sin medir todavía:** cómo cambian el balance. Falta añadirlas al simulador. Más tipos (energía, enfriamiento, reparación) quedan por decidir con el usuario.

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
- **Clases de pieza** (pedido del usuario, 2026-11-16). Sustituyen a los nombres de tier anteriores; en el código y en el catálogo los identificadores siguen siendo `COMMON` … `DIVINE`:

  | Clase | Identificador | Nivel máximo | Etapas tecnológicas |
  |---|---|---|---|
  | Básica | `COMMON` | 6 | 1 |
  | Intermedia | `RARE` | 12 | 2 |
  | Avanzada | `EPIC` | 18 | 3 |
  | Legendaria | `LEGENDARY` | 24 | 4 |
  | Mítica | `MYTHIC` | 30 | 5 |
  | Única | `DIVINE` | 50 | 8, más el remate del nivel 50 |

  Donde este documento diga Común, Raro, Épico, Legendario, Mítico o Divino se refiere a estas mismas clases, en ese orden.
- **Niveles por clase:** 6 / 12 / 18 / 24 / 30 / 50 (`RulesConfig.tier_max_level`).
- **Crecimiento:** `poder(tier, nivel) = mult_tier[tier] × (1 + 0.3 × nivel / nivel_máx)`, con `mult_tier` = 1.0 / 1.35 / 1.8 / 2.4 / 3.2 / 4.2. Va de 1.0 (Común nivel 0) a 5.46 (Divino nivel 40), y transformar una pieza siempre la mejora aunque reinicie el nivel.
- **Escalado proporcional:** `stat = stat_del_catálogo × poder / 5.46`, redondeado y con mínimo 1. Escalan la vida, las capacidades, la regeneración, el enfriamiento, las resistencias, todos los daños, el backfire y los costos. No escalan el peso, el movimiento, el alcance, los empujes ni los usos. Como todo usa el mismo factor, un duelo entre mechs del mismo tier se comporta igual en cualquier tier: el balance se ajusta una sola vez.
- Los costos escalan igual que el daño. Un arma de tier alto en un torso de tier bajo gasta una parte grande de su energía y su calor: hay que subir el núcleo para alimentar las armas grandes.
- **Mejora por niveles (micromejoras):** cada nivel es una mejora pequeña de la pieza, y cada nivel se nota también en su aspecto, que gana definición.
- **Etapas tecnológicas:** cada 6 niveles la pieza pasa a una etapa más avanzada y cambia de dibujo: el arma se ve y dispara como una tecnología superior (§12.2). Dentro de una etapa, cada nivel añade detalle sobre ese dibujo (líneas de luz, brillo, piezas añadidas e intensidad de los efectos).
- **Color personalizable:** el jugador puede cambiar los colores de cada pieza. Se hace con un shader sobre zonas de color del sprite (principal, secundario y luces), sin generar arte nuevo.
- **Piezas únicas:** solo las sueltan los 3 últimos jefes de los 10 de cada mundo (§9). No se compran ni se consiguen transformando otra pieza.
- **Tipos de arma y clases** (usuario, 2026-11-16): balas en las clases Básica e Intermedia, cañón y bláster (plasma) en las medias, láser de Avanzada en adelante. El detalle está en docs/CATALOGO_ARMAS.md: 4 categorías por hueco, 37 diseños y 111 armas.
- **Materia oscura:** el disparo más poderoso del juego; prácticamente aniquila al enemigo. No es un arma sino una habilidad del **árbol de habilidades** que elija el jugador, y solo se aplica al arma del pecho. El árbol de habilidades es un sistema nuevo, por diseñar.
- **Huecos y nivel del jugador:** 2 brazos, 2 hombros, 1 pecho y robot de soporte, desbloqueados con el nivel del jugador (soporte al 3, pecho al 10, cinco armas al 20).
- **Por confirmar con el usuario:** si una pieza puede subir de clase (hoy sí, con la transformación de más abajo, hasta Mítica) o si su clase es fija, y si las clases y las etapas valen igual para torsos, piernas y drones (hoy sí) o solo para armas.
- **Poder y fusión:** el nivel sube con "poder", que se gana fusionando piezas sobrantes (su poder depende de su tier) o núcleos.
- **Transformación:** al llegar al nivel máximo de su tier, la pieza puede transformarse al siguiente pagando oro y núcleos. Vuelve al nivel 0 del nuevo tier.
- **Monedas:** **oro** (sale de los combates) y **núcleos** (salen del botín y de desarmar piezas repetidas). No hay moneda de pago.
- **Botín:** cada victoria da oro y una tirada de botín, con mejores tablas en los capítulos avanzados. Hay cajas que se ganan jugando, nunca con dinero.
- **Tienda del taller** (recuerdo del usuario, 2026-11-16: en el juego antiguo había un taller donde comprabas piezas e ibas armando tu robot o tus robots). Vende por oro las piezas básicas de cada capítulo, con un surtido que cambia al avanzar; lo raro sigue saliendo del botín.
- **Garaje:** se pueden guardar varios mechs armados y elegir con cuál pelear.
- **Taller de mejoras permanentes** (el equivalente de la tienda de arena): niveles comprados con oro. Daño, energía y calor hasta +20 %; resistencias hasta +40 %; vida hasta +350 plana; backfire hasta −20 %.
- **Objetivo de ritmo:** llevar un build completo a Divino debe costar unas 8–12 horas de juego. Se mide con el simulador en la fase F7.

## 9. Campaña
**Visión (del usuario, 2026-11-16):** recuperar la versión antigua de Super Mechs para un jugador. Empiezas con un robot sencillo y avanzas combate a combate hasta un jefe superior al que solo se vence con táctica. Aquella versión era una demo que no pasaba de los primeros 10 combates; aquí va completa. La meta es unir la originalidad y el detalle del juego antiguo con las mecánicas de combate modernas. No hay multijugador.

- El jugador empieza con un mech básico de tier Común (torso, piernas y un par de armas) y lo va completando con lo que gana.
- **Mundo con 10 jefes** (pedido del usuario, 2026-11-16): el mundo se divide en 10 zonas, cada una con sus combates normales y un jefe al final. Los **3 últimos jefes** sueltan las piezas de clase Única. Sustituye a los 3 capítulos del plan anterior; donde este documento diga "capítulo" léase "zona". Más mundos quedan para el paso 2.
- Los enemigos tienen builds predefinidos (en datos) que suben de tier por capítulo. Los jefes tienen piezas únicas y reglas especiales (por ejemplo, más capacidad de calor).
- Los combates se pueden repetir para farmear. Cada capítulo desbloquea piezas y niveles del taller de mejoras.
- La curva de dificultad se valida con el simulador: el build "esperado" del jugador en cada capítulo debe ganar entre el 55 % y el 70 % de las veces contra los enemigos normales.

### 9.1 El jefe final
Pedido por el usuario el 2026-11-16: vencerlo debe ser extremadamente difícil, **no por la cantidad de vida**; usando las bonificaciones y los ataques con táctica, en teoría se puede ganar. La otra vía es reunir monedas en la arena para comprar mejor armamento.

**Cómo está hecho** (data/chassis.json, chasis "jefe"; data/builds.json, mech "jefe_final"):
- Tiene la misma vida que un mech normal de su clase.
- Juega **3 acciones por turno** en vez de 2, con las armas de los tres elementos.
- Resiste un 20 % más.
- **Punto débil:** se enfría un 30 % peor. Si se le sobrecalienta tiene que gastar acciones en enfriar, y al enfriar a la fuerza se queda con una sola.
- Usa la línea de diseño robusta y se dibuja más grande.

**Medido con tools/sim/boss_sim.gd** (jefe en clase Mítica; el jugador con la IA difícil; dos tandas de 30 y 70 combates por casilla, de ahí los rangos):

| Mech del jugador | Equipo una clase por debajo | Misma clase, sin bonificaciones | Misma clase, con bonificaciones | Una clase por encima |
|---|---|---|---|---|
| Calor (lo sobrecalienta) | 0 % | 3–6 % | 13–23 % | 100 % |
| Energía | 0 % | 0 % | 4–10 % | 100 % |
| Físico | 0 % | 0 % | 0 % | 100 % |
| Híbrido | 0 % | 0 % | 0–3 % | 100 % |

- En pelea directa es casi imposible. La táctica que funciona es la que ataca su punto débil (calor), y las bonificaciones multiplican por tres o cuatro las opciones.
- La vía del equipo también funciona, pero el salto es demasiado brusco: con una clase menos no se gana nunca y con una más se gana siempre. Hay que suavizarlo cuando exista la tienda, para que comprar armas mejores acerque la victoria poco a poco.
- La IA que hace de jugador no busca las bonificaciones tan bien como una persona; un jugador atento debería sacar más partido.


### 9.2 La segunda vía: oro de la arena y tienda
Hecho el 2026-11-16 (core/arena_shop.gd, core/player_profile.gd, data/arena_shop.json; 13 tests). Sigue la tienda de arena del original: seis mejoras permanentes en 10 niveles pequeños, con su misma tabla de pasos (0, 1, 3, 5, 7, 9, 11, 13, 15, 17 y 20 sobre 20).

| Mejora | Tope |
|---|---|
| Potencia de las armas | +20 % |
| Energía y regeneración | +20 % |
| Calor y enfriamiento | +20 % |
| Resistencias | +40 % |
| Blindaje (vida) | +350 |
| Amortiguación del retroceso propio | −20 % |

- Cada combate da oro: 250 por ganar, 60 por perder y 2500 por vencer a un jefe. El progreso se guarda en user://save.json.
- Las mejoras solo cuentan para el mech del jugador. Se compran desde el menú.
- **Los precios y las recompensas son propuesta nuestra**: el análisis del original da la estructura y los topes, no cuánto costaba cada nivel.

**Medido con tools/sim/shop_route_sim.gd** (jefe y jugador en clase Mítica, bonificaciones encendidas, IA difícil, 40 combates por casilla; todas las mejoras al mismo nivel):

| Nivel de tienda | Oro total | Combates de arena ganados | Físico | Calor | Energía | Híbrido | Media |
|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 % | 7.5 % | 7.5 % | 0 % | 3.8 % |
| 2 | 4 800 | 20 | 10 % | 47.5 % | 10 % | 2.5 % | 17.5 % |
| 4 | 16 800 | 68 | 35 % | 72.5 % | 37.5 % | 40 % | 46.3 % |
| 6 | 40 800 | 164 | 47.5 % | 92.5 % | 72.5 % | 60 % | 68.1 % |
| 8 | 81 600 | 327 | 90 % | 100 % | 82.5 % | 87.5 % | 90 % |
| 10 | 145 800 | 584 | 100 % | 100 % | 97.5 % | 97.5 % | 98.8 % |

- La subida es gradual: cada dos niveles acercan la victoria, sin el salto brusco que había entre clases de equipo.
- Las dos vías se suman: con el mech de calor (el que ataca el punto débil del jefe) basta el nivel 2 para ganar casi la mitad de las veces; con el físico hace falta el nivel 6.
- Con estos precios, llevar todo al máximo son 584 combates ganados. Es demasiado para un solo jefe; hay que ajustar precios y recompensas cuando exista la campaña entera.


## 10. Pantallas
Menú · Taller (armado con resumen de stats, barra de peso y avisos) · Inventario y fusión · Taller de mejoras · Mapa de campaña · Combate (arena, mechs, botones de acción, previsualización y registro) · Resultados y botín · Ajustes.

## 11. Arte: sprites 2D generados con IA, con aspecto propio
**Objetivo:** que los mechs no se vean genéricos como en el original y que el juego corra holgado en la laptop del usuario (RTX 4050 6 GB, 16 GB de RAM).

**Por qué 2D y no 3D:** el combate 2D con luces y partículas usa una fracción mínima de la GPU (cabría incluso en la gráfica integrada). Lo genérico del original viene del estilo, no de ser 2D: piezas tipo caricatura, sin luz, sin efectos y casi sin animación. El 3D completo multiplicaría el trabajo (modelar, riggear y animar cada pieza) sin ser necesario.

**Dirección de arte (del usuario, 2026-11-16): mecha japonés.** Se mantiene la base del juego original (mechs modulares vistos de lado, cada pieza es un sprite) con la estética de la ilustración de robots japonesa: blindaje anguloso, líneas de panel, propulsores, sensores luminosos y sombreado tipo cel. Los diseños son propios y genéricos dentro de ese estilo: no se reproduce ninguna franquicia concreta ni sus nombres.

**Estilo aprobado (usuario, 2026-11-16):** la referencia es `docs/reference/art/estilo_aprobado.png`. El estilo final debe ser exactamente ese, no una aproximación: mecha de proporciones realistas, línea de tinta con trazo de boceto técnico, color plano con paleta contenida y fondo gris neutro. No debe perderse ni ese trazo ni ese realismo gráfico. El prompt y los ajustes con los que se generó están fijados en `tools/art/style.py`, y la misma semilla reproduce la imagen. Se probó una variante de línea limpia y sombreado cel y se descartó: sale más colorida y caricaturesca.

**Cómo se vigila:** cada lote nuevo de piezas se revisa en una hoja junto a la referencia antes de aceptarlo.

**Sensación de referencia (usuario, 2026-11-16):** del juego antiguo le atraía su aire a Metal Slug: maquinaria robusta y compacta, dibujada a mano con mucho detalle, y animación con peso. Se toma como guía de proporciones y de movimiento (§12), sin copiar su arte y sin cambiar el estilo aprobado.

**Líneas de diseño (usuario, 2026-11-16):**
- **Mechs del jugador y rivales normales:** línea esbelta, blanca con luces de color. Referencia: `docs/reference/art/cuerpo_elegido.png`.
- **Jefes:** línea robusta, tipo tanque andante, más pesada y con más blindaje.
- **Personalización de cabeza a pies:** como en el original, el jugador elige cada pieza entre distintos estilos y diseños y se pueden mezclar. Por eso torso, piernas, armas y dron son sprites separados con anclas comunes.

**Chasis (reformulación del 2026-11-16):** las piezas ya no se cortan de cuerpos independientes. Cada robot tiene un chasis con uniones estándar (aro de cintura, brazos, hombros, pecho y espalda) y cada pieza se dibuja ya montada sobre el maniquí de ese chasis. El jugador puede conseguir robots con otros chasis. El diseño completo y la prueba están en docs/CHASIS.md.

**Lo que lo hace propio:**
1. **Generación guiada por silueta.** Para cada pieza definimos una silueta o blockout simple (forma, perspectiva lateral y escala). La IA la "pinta" con un estilo fijo (img2img o ControlNet). Así todas las piezas comparten perspectiva, escala y luz, que es el punto débil de generar a ciegas.
2. **Iluminación 2D con mapas de relieve.** Cada sprite lleva su normal map (derivado de un mapa de profundidad generado, o con una herramienta como Laigter) para que las luces 2D de Godot le den volumen.
3. **Shaders por estado:** brillo al rojo según el calor, arcos y chispas al quedarse sin energía, grietas y humo según la vida perdida, destello del elemento al recibir daño.
4. **Animación por piezas (cutout):** respiración en reposo, balanceo y pisada al caminar, retroceso de cada arma al disparar, sacudida al recibir golpe, con partículas, sacudida de cámara y pausa breve en los golpes fuertes.
5. **Dirección de arte coherente:** paleta por elemento (§5), siluetas reconocibles por arquetipo y variantes de tier que cambian color, emisivo o detalle, nunca la forma (así el montaje no se rehace).

**Montaje:** una imagen por pieza con fondo transparente. El torso define los puntos de montaje (2 piernas, 4 laterales y 2 superiores) y cada arma su punto de agarre, en un JSON de anclas por pieza. Es el mismo sistema del original.

**Pipeline** (detalle, licencias y alternativas en `docs/reference/art-pipeline.md`): silueta y bloque de color nuestros → generación local con un modelo de ilustración japonesa (Illustrious-XL) guiado por un ControlNet → recorte del fondo → reducción a 512 px → mapa normal → anclas → revisión en un visor de montaje dentro de Godot. Todo corre en la RTX 4050 del usuario, sin servicios en la nube. El estilo se aprueba con mechs de referencia, uno por elemento, antes de producir el catálogo entero.

**Presupuesto de rendimiento:** 60 FPS fijos en combate y modo de bajo consumo del procesador en los menús. Las texturas de cada pieza no pasan de 512 px de lado y se agrupan en atlas. Se mide en la laptop en la fase F5.

## 12. Presentación: entorno, animaciones, efectos y sonido
**Requisito del usuario (2026-11-16):** el juego debe cubrir el entorno, las animaciones, los sonidos y el resto de la presentación al nivel del juego original. Todo el contenido es propio: no se usan sus escenarios, animaciones, sonidos ni música.

### 12.0 Coherencia con el diseño
Requisito del usuario (2026-11-16): las interacciones deben ir acordes al diseño. Todo lo que se mueve, suena o se pulsa sigue el lenguaje visual de la referencia de estilo (§11):
- **Efectos:** fogonazos, explosiones, humo y chispas dibujados con el mismo trazo de tinta y color plano, no partículas brillantes genéricas.
- **Movimiento:** peso mecánico creíble. Los mechs arrancan y frenan con inercia, las armas tienen retroceso y los golpes desplazan; nada de rebotes de caricatura.
- **Interfaz:** paneles, botones y tipografía con aire de plano técnico, en la misma paleta contenida; los colores vivos se reservan para el elemento (acero, naranja, cian) y para los avisos.
- **Escenarios:** mismo trazo y misma paleta, con menos contraste que los mechs para que no compitan con ellos.
- **Sonido:** mecánico y con cuerpo (servos, metal, impactos secos), no efectos de dibujo animado.

### 12.1 Entorno
- **Escenarios de arena:** uno por capítulo de la campaña más uno de entrenamiento (4 en total). Cada uno en capas para dar profundidad: fondo lejano, estructuras intermedias y suelo. El suelo queda alineado con las 10 casillas.
- Se generan con el mismo modelo local que los mechs, para que compartan estilo.
- **Vida ambiental:** partículas de polvo, humo o chispas, luces que parpadean y un leve desplazamiento de las capas con las sacudidas de cámara.
- **Luz:** cada escenario define su luz ambiente y la dirección de su luz principal; los mapas normales de los mechs responden a ella.

**Campo y cámara** (pedido del usuario, 2026-11-16: como en el juego antiguo y como los escenarios de KOF). El campo es más ancho que la pantalla y se recorre hacia adelante y hacia atrás: cada casilla mide 230 de ancho, así que las 10 suman 2300. Una cámara sigue el punto medio de los dos mechs y se aleja cuando se separan. El paisaje va en capas que se mueven a distinta velocidad según su lejanía, con animaciones propias: estrellas que titilan, naves que cruzan, luces que parpadean, polvo o chispas en el aire.

**Escenarios hechos (2026-11-16), como datos en data/stages.json:** Ciudad del Orden, Desierto de Óxido, Anillo Orbital y Hangar de Pruebas (el de entrenamiento). Cada uno define cielo, astro, dos capas de paisaje (torres, dunas, picos o estructura metálica), ambiente, bruma y colores del suelo. Están dibujados por código y son provisionales: falta generarlos con el modelo local en el estilo aprobado, como dice la lista de arriba, y repartirlos entre las 10 zonas del mundo.

**Sin decidir:** si el campo crece también en casillas (hoy son 10). Cambiaría los alcances de las armas y obligaría a repetir el balance.


### 12.2 Animaciones
Animación por piezas (cada pieza es un sprite que se mueve, gira o se desplaza), más partículas y shaders.

| Grupo | Animaciones |
|---|---|
| Reposo | Respiración del mech, dron flotando, parpadeo de propulsores y sensores |
| Movimiento | Paso de piernas con balanceo del cuerpo; ruedas girando; salto con agachada, arco y polvo al caer |
| Ataques cuerpo a cuerpo | Tajo de espada con estela; golpe de martillo; pisotón |
| Ataques a distancia | Retroceso del arma, fogonazo y proyectil según el tipo: bala con trazadora, obús en arco, cohete con humo, chorro de llamas, rayo y arco eléctrico, pulso de drenaje |
| Especiales | Embestida con estela e impacto; salto con destello al desaparecer y aparecer; gancho con cable que sale y recoge |
| Dron | Disparo desde su posición |
| Impactos | Destello, sacudida y chispas; en los golpes fuertes, sacudida de cámara y una pausa breve |
| Estados | Brillo de calor creciente; vapor al enfriar; apagado (luces fuera, postura caída y humo); sin energía (parpadeo y arcos); daños visibles con poca vida |
| Final | Explosión y piezas que saltan al ser destruido; pose de victoria |
| Interfaz | Números flotantes, barras que se mueven con suavidad, cartel de turno, respuesta de los botones y transiciones entre pantallas |

**Armas: cómo se empuñan y cómo disparan** (pedido del usuario, 2026-11-16). Cada familia de arma tiene su propia forma de desplegarse, apuntar, disparar e impactar, y evoluciona con las etapas tecnológicas de la pieza (§8): el mismo cañón no se ve ni dispara igual en la etapa 1 que en la 5.

| Familia | Despliegue y disparo | Proyectil e impacto |
|---|---|---|
| Balística ligera (ametralladora, rotativa) | El brazo se afianza, los cañones giran y vibra el retroceso | Ráfaga de trazadoras, casquillos, chispas en el blindaje |
| Balística pesada (cañón, obús, mortero) | Se anclan las piernas, retroceso largo y humo en la boca | Proyectil visible, en arco si es obús; onda y cráter |
| Escopeta y metralla | Golpe seco de retroceso | Abanico de perdigones a corta distancia |
| Riel y gauss | Carga con arcos entre los raíles antes del disparo | Línea instantánea que atraviesa y deja estela |
| Misiles y cohetes | Se abren las compuertas del lanzador | Estela de humo, vuelo guiado en curva, explosión |
| Granadas y minas | Lanzamiento en parábola | Rebote, mecha y explosión retardada |
| Láser | Lente que se enciende y carga | Rayo continuo que quema una línea en el blindaje |
| Bláster y plasma | Bobina que se ilumina | Bola o perno de energía con salpicadura al impactar |
| Llama y térmico | Piloto encendido y chorro | Cono de fuego, brasas y metal al rojo |
| Eléctrico | Bobinas que chisporrotean | Arco ramificado que salta al rival y le drena energía |
| Cuerpo a cuerpo (espada, hacha, martillo, taladro, sierra) | Desenvaine o arranque del motor y avance | Tajo con estela, golpe con sacudida, chispas continuas en taladro y sierra |
| Escudos y defensas | Paneles que se despliegan o campo que se enciende | Destello al absorber el golpe; se agrieta o parpadea con poca vida |

**Dirección de las armas** (pedido del usuario, 2026-11-16): el nivel de detalle que busca es el del juego original.
- **Armamento galáctico.** El catálogo se orienta a tecnología de ciencia ficción: plasma, iones, partículas, antimateria, gravedad, haces y hojas de energía. Las armas convencionales (balas, obuses, cohetes) son las etapas bajas de esa misma línea, no un estilo aparte; nada de espadas ni armas de aspecto medieval.
- **Despliegue.** Las armas van guardadas dentro del cuerpo del robot. La primera vez que se usa cada arma en un combate se despliega: se abren las compuertas, el arma sale del cuerpo y se extiende o se desdobla hasta quedar lista. Después queda desplegada el resto del combate y solo hace su gesto de disparo. Al apagarse el mech, las armas se recogen.
- **Cómo se construye:** cada arma se dibuja en dos o tres tramos (base, cuerpo y boca o emisor) que se animan por separado: salen de detrás del torso, se deslizan como un telescopio o giran sobre su base. Las compuertas son piezas pequeñas del torso.
- **Evolución del disparo.** Conforme el arma sube de nivel cambia su disparo, no solo su dibujo: dentro de una etapa crecen el tamaño, el brillo y las capas del efecto; al cambiar de etapa cambia el tipo de disparo (por ejemplo, de perno de plasma a ráfaga, y de ráfaga a haz sostenido).
- Antes de repetirlo en todo el catálogo se hace un **arma piloto** completa (dibujo por etapas, despliegue y disparo por niveles) para que el usuario la evalúe.

La etapa tecnológica cambia el dibujo del arma, el fogonazo, el proyectil, el impacto y el sonido. Para que el trabajo sea abarcable, cada familia define sus efectos una vez y cada etapa los varía (tamaño, color, número de proyectiles, capas de efecto).

**Revisión por partes:** cada familia se le enseña al usuario en movimiento, en sus etapas, antes de darla por buena (ver `docs/PLAN.md`, fase F5).

Cada pieza del catálogo llevará un campo `fx` con su tipo de presentación (por ejemplo `espada`, `bala`, `cohete`, `llama`, `rayo`), del que salen su animación de ataque, su proyectil y su sonido.

### 12.3 Sonido y música
- **Efectos**, por categoría:
  - Interfaz: pasar por un botón, pulsar, confirmar y error.
  - Movimiento: paso, salto, caída y ruedas.
  - Armas, uno por tipo de `fx`: tajo e impacto de metal, disparo, cañonazo, lanzamiento y explosión de cohete, llamas, rayo, descarga eléctrica y drenaje.
  - Especiales: embestida, salto y gancho.
  - Estados: alarma de sobrecalentamiento, vapor al enfriar, apagado, reencendido y aviso de energía agotada.
  - Impactos ligeros y pesados, explosión de destrucción, y fanfarrias de victoria y derrota.
  - Ambiente: un bucle por escenario.
- **Música:** menú, taller, combate normal, combate contra jefe, victoria y derrota.
- **Origen:** bibliotecas de dominio público (CC0) para empezar, con cada archivo anotado en `assets/audio/CREDITS.md` junto a su licencia. No se usa ningún sonido ni música del juego original.
- **Técnica:** buses separados para música, efectos e interfaz con su volumen en ajustes, y una pequeña variación de tono en los efectos repetidos para que no cansen.

### 12.4 Cómo se comprueba
- **Cobertura:** un test recorre los tipos de evento del motor y los tipos de `fx` del catálogo y falla si alguno no tiene animación o sonido asignado.
- **Vista:** la prueba en vivo guarda capturas de cada tipo de acción en cada escenario, y se revisan.
- **Oído:** no se puede verificar de forma automática que un sonido suena bien. El test comprueba que el archivo existe y se lanza; el usuario valida el resultado escuchándolo.
