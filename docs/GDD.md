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
| M5 | Iniciativa: quien empieza tiene 1 sola acción en su primer turno. **Apagada desde el 2026-11-21** (OBS-034): el usuario lo vivía como una desventaja suya; los dos abren con todas sus acciones. | Compensaba la ventaja de abrir. |
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

### 2.9 Golpes críticos
Pedido por el usuario el 2026-11-18. **No está en el original**, donde cada golpe es una sola tirada de daño (docs/reference/original-mechanics.md). En el motor desde ese día (tests/unit/test_crits.gd, 18 tests). Como las bonificaciones, viene apagado en `RulesConfig` (`crits_enabled`) para no alterar las pruebas, y el juego lo enciende.

**Probabilidad de un golpe:**
```
p = crítico_del_arma × clamp(poder_del_arma / poder_del_blindaje, 0.5, 1.5)
      × max(0, 1 − 2 × resistencia_del_rival / daño_medio_del_arma)
      × max(0, 1 − 0.25 × nivel_de_escudo_del_rival)
      × (1 − bonificación_de_armadura_del_rival)
p = min(p, 0.9)
```
- **El arma** (`crit` en el catálogo, por su forma): pecho casi seguro (cañón pesado 80 %, nova 70 %); artillería 18 %; hoja y largo 10 %; corto 8 %; medio, batería y ancla 5 %; saboteador y robot de asistencia 3 %.
- **El nivel:** el poder del arma (su clase y su nivel) frente al del blindaje del rival (su torso). A igual clase no cambia nada; un arma de más clase encuentra más puntos débiles, hasta ×1.5.
- **Armadura gruesa:** la resistencia del rival a ese elemento, comparada con el daño del arma. Con resistencia igual a la cuarta parte del daño, la probabilidad baja a la mitad.
- **Escudo de alto nivel:** cada escudo de energía del árbol de habilidades (o el escudo de jefe) quita un 25 %. Un escudo activo para el golpe entero, y entonces no hay crítico.
- Ejemplo del usuario: el cañón pesado acierta casi siempre (80 %), pero contra un escudo doble y una armadura de 30 sobre 100 de daño baja al 16 %.

**Qué hace un crítico:** multiplica por 1.25 el daño, el calor y el drenaje del arma, y además, según el tipo de disparo (`crit_effect` en el catálogo):

| Tipo | Efecto | Qué hace |
|---|---|---|
| Balas | Blindaje perforado | Ese golpe atraviesa la resistencia del rival |
| Cañón | Inmovilizado | En su siguiente turno no puede andar, saltar, embestir, teletransportarse ni usar la espada que salta |
| Bláster | Sobrecarga | En su siguiente turno pierde una acción (le queda al menos una) |
| Láser | Arma inutilizada | En su siguiente turno no puede usar un arma, elegida al azar entre las que le quedan |

- La previsión (M3) enseña la probabilidad y el efecto. La IA cuenta el daño esperado del crítico, pero no planea con sus efectos.
- En pantalla: aviso "¡CRÍTICO!" y el efecto sobre el rival, línea en el registro y el estado en su panel.

**Ajuste medido** (tools/sim/balance_sim.gd `--crits`, clase Única, robot de asistencia con Blindaje, 1 600 combates por tipo, semilla 4242). Lo que se probó, en orden:
1. *Crítico ×1.5 solo al daño, armas normales con el doble de probabilidad, el láser inutilizando siempre el arma más fuerte y el bláster sumando calor:* el físico láser ganó el 67 %. El crítico solo multiplicaba el daño directo, que es donde el físico es más fuerte.
2. *El crítico también multiplica el calor y el drenaje:* el calor de balas subió al 58.5 % y el físico láser se quedó en el 60 %.
3. *La mitad de probabilidad en las armas normales y ×1.25:* el calor del bláster quedó en 58 % y el físico láser en 57.5 %. Quedaba un sesgo por efecto: inutilizar el arma más fuerte le quita al mech de calor o de energía la pieza de su presión, y sumar calor ayuda justo al mech de calor.
4. *El láser inutiliza un arma al azar y el bláster quita una acción:* **es lo que queda.**

| Tipo | Físico | Calor | Energía | Híbrido | Duración media |
|---|---|---|---|---|---|
| Balas | 49.3 % | 48.8 % | 52.0 % | 53.2 % | 12.3 turnos |
| Cañón | 49.5 % | 51.0 % | 49.5 % | 47.3 % | 12.6 turnos |
| Bláster | 50.5 % | 50.2 % | 49.3 % | 50.7 % | 12.6 turnos |
| Láser | 49.3 % | 49.3 % | 51.5 % | 48.3 % | 12.5 turnos |

Pasan todas las puertas, más cerca del 50 % que sin críticos (balas sin críticos: 49.0, 54.5, 46.5 y 52.3 %).

### 2.10 Impacto de los golpes
Pedido por el usuario el 2026-11-18. El golpe empuja al rival según el tamaño del arma. En el original el empuje es un número de cada arma (`push`), que se conserva; esto se suma por encima (gana el mayor de los dos). En el motor desde ese día (tests/unit/test_impact.gd, 10 tests); viene apagado en `RulesConfig` (`impact_enabled`) y el juego lo enciende.

| Tramo | Armas | Impacto | Retroceso del rival |
|---|---|---|---|
| Ligero | Brazos (y piernas y robot de asistencia) | Solo chispas | Ninguno (las que ya empujan por sí mismas, como la escopeta cinética o el repulsor, siguen igual) |
| Semi | Hombros | Ligero o medio según el daño frente a la vida del rival | 1 casilla (`impact_push_top`); el ancla no, porque jala |
| Grave | Pecho (cañón pesado y nova) | Grave: sacudida fuerte y destello | Hasta 3 casillas (`impact_push_chest`), menos si el blindaje del rival es de más clase que el arma |
| Última | Materia oscura | Secuencia propia: despliegue, carga y disparo según el tipo del arma de pecho | Hasta el borde de la arena, y le deja el crítico de su arma de pecho (§2.9) |

- Un escudo que para el golpe también para su impacto.
- La materia oscura tiene una secuencia distinta para cada tipo de arma de pecho: el cañón de asedio carga con partículas que llegan derechas y dispara un obús negro; el cañón de plasma las hace girar en espiral y dispara una esfera de plasma negro; el cañón láser concentra rayas en la lente y dispara un haz negro. Las tres terminan en una explosión que sacude la arena y mandan al rival al borde.
- **Medido** con los críticos encendidos (balance_sim `--crits --impact`, mismas condiciones que en §2.9): balas 49.7, 50.0, 50.2 y 53.5 %; cañón 50.8, 51.0, 48.3 y 47.5 %; bláster 51.5, 51.0, 47.5 y 51.0 %; láser 52.5, 48.3, 49.3 y 48.7 % (físico, calor, energía e híbrido). Pasan todas las puertas; la duración media no cambia (12.3 a 12.7 turnos).
- **Campaña** (tools/economy_sweep.ps1, 24 combates por casilla, con críticos e impacto), con 50 victorias en la zona: 58, 82, 91, 84, 84, 24, 99, 74, 69 y 57 % (solo con críticos: 58, 81, 87, 91, 70, 24, 98, 54, 63 y 41). Fuera del margen de ±10 puntos se vuelven más fáciles las zonas 5 (+14), 8 (+20) y 10 (+16). El impacto favorece al jugador porque en la campaña solo él lleva arma de pecho (la que empuja hasta 3) y materia oscura; además, los jefes de las zonas 5 y 10 llevan anclas en los hombros, que jalan y no empujan. El usuario pidió endurecerlas: se subió el entreno de esos tres jefes y la campaña volvió a la curva que aceptó con críticos (§9.3).
- Para verlo: `tools/clip.ps1 -Impact`.

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
- **Huecos:** torso, piernas, **2 armas de brazo y 1 de hombro**, 1 arma de pecho, 1 robot de asistencia, **9 módulos en tres familias** (abajo) y un hueco por especial (embestida, salto y garfio). El arma de pecho va **aparte** de las armas (decisión del usuario, 2026-11-17) y su hueco se abre en el nivel 10.
- **Tres armas, una por alcance (decisión del usuario, 2026-11-21, OBS-033):** "Pensándolo bien, no van a ser 4 armas de brazos, solamente van a ser 2. Y las armas superior… nada más va a ser de un solo lado, que es el lado que se muestra. Entonces en total van a ser 3 armas. Y van a poder dividirse en una de corto alcance, mediano alcance y largo alcance para la superior. Y el torso en ese caso, que es la especial, de un solo disparo por partida. Y el asistente… y todos los módulos que puedes ir añadiendo. La parte de salto, garfio y embestida… En lateral 1 y 2 podemos poner armas de corto y mediano alcance. Y lo que es la parte de arma superior nada más queda una, que vendría siendo esta de largo alcance. Y eventualmente el asistente en el nivel 5 y el arma de pecho en el nivel 10." Hasta entonces eran cuatro de brazo y dos de hombro, como en el original.
  - **Los dos brazos, de corto y medio alcance:** hojas, cortas, medias y saboteadores (alcance máximo de 2 a 4). Cualquiera de las dos casillas acepta las dos distancias; el tipo de robot limita además qué formas lleva (§9).
  - **El hombro, de largo alcance:** baterías, obuses, arpones y, desde este cambio, **los rifles**, que eran arma de brazo (alcance 3 a 6) y pasan al hombro en lugar de desaparecer; así el Tirador conserva su rifle. Su dibujo de hombro, de momento, es el mismo rifle subido al hombro.
  - **Todo va del lado que se ve:** sin brazos ni hombro del lado lejano, el robot se lee entero de perfil.
  - **El arma de pecho, un disparo por partida** (antes 2 o 3, según el arma).
  - **El asistente se abre en el nivel 5** (antes en el 3); el arma de pecho, en el 10, como antes.
  - **Las partidas de antes** (guardado versión 9) se quedan con sus dos primeras armas de brazo y su primera de hombro; un rifle montado en el brazo pasa al hombro si estaba libre. Nada se pierde: lo desmontado sigue siendo suyo.
- **El arma de pecho pesa y el núcleo ampliado la carga** (del usuario, 2026-11-20, OBS-027: "esta misma arma pesa. Por ende, puedes aumentar la capacidad del robot, pero eso es una mejora del mismo core, que solamente se da después del nivel 10, para aumentar la capacidad y que el peso del arma no afecte en lo que ya tienes, tus demás elementos"). Las armas de pecho pesan de 43 a 74 kg y cuentan para el límite como cualquier pieza. **Núcleo ampliado** es una mejora de la armería que se abre en el nivel 10 del jugador (data/arena_shop.json, `core`): en sus 10 niveles llega a cargar 80 kg del arma de pecho (4, 12, 20, 28, 36, 44, 52, 60, 68 y 80), al precio de las demás mejoras. Lo que carga sube el límite de peso de ese robot, pero **nunca más de lo que pesa su arma de pecho** (`MechBuild.max_weight`): el núcleo se amplía para ella, no para llevar más módulos. Sin ampliarlo, el arma se puede montar igual si se hace sitio quitando otras piezas. Hasta ese día el arma de pecho no contaba para el límite (medido el 2026-11-17: si contara sin más, había que quitar uno o dos módulos y el mech salía peor que sin ella; zonas 3 a 8, del 72–81 % al 7–38 % contra el jefe con 50 victorias); con el núcleo al nivel que pide el arma queda igual que entonces, y lo nuevo es que hay que pagarlo (unas 6 100 celdas para el cañón más pesado). El ritmo de las zonas 3 en adelante (§9.3) no se ha vuelto a medir con ese gasto.
  - **Cómo se ve (pendiente de dibujar):** dentro del robot va una persona (OBS-024), "físicamente acomodada dentro", y el arma de pecho va "físicamente más adelante": no ocupan el mismo sitio. Al ampliar el núcleo el torso "se hace más grande, más pesado". Va con el despliegue del arma de pecho (OBS-025) y con los pilotos.
- **Robot de asistencia** (pedido del usuario, 2026-11-17; sustituye al dron de soporte y se abre igual, en el nivel 5 del jugador desde el 2026-11-21; antes, en el 3). Diseño:
  - **Un solo asistente por partida, con clase y nivel en el Taller.** Se transforma **5 veces** siguiendo la escalera de clases de las piezas, con el mismo tope de zona: Sonda (Básica), Vigía (Intermedia), Centinela (Avanzada), Custodio (Legendaria), Guardián (Mítica) y Arconte (Única, con un núcleo único). Cada forma tiene su dibujo, más grande y con más piezas.
  - **Dos armas, superior e inferior** (huecos `drone` y `drone_low`, con las armas de dron del catálogo). **Dispara una sola por turno y las alterna**; si a la que le toca no puede (alcance, usos o energía), dispara la otra. La segunda arma da versatilidad (otro alcance, otro efecto), no más disparos. La inferior pelea desde la primera transformación (`RulesConfig.assist_second_weapon_tier`); antes se puede montar, pero no pelea, como los huecos que abre el nivel del jugador.
  - **Ataque:** sus armas suben con él, a su clase y su nivel, sin salirse del rango de clases de su tipo. Por eso cada transformación sube el ataque, y un arma de tipo viejo se queda en su clase máxima y conviene cambiarla en la tienda.
  - **Energía propia: la batería**, que alimenta sus armas. La mejora **Batería del asistente** de la armería (se abre con la primera transformación) sube el daño de sus disparos hasta +10 %; solo el daño, no el drenaje ni el calor que causan. Es poco a propósito: con +15 % el físico ya pasaba del 55 % en láser.
  - **Sus armas siguen pagando energía y calor al mech**, como el dron de siempre. Así, quedarse sin energía o apagado por calor también calla al asistente.
  - **Defensa y bonificación al mech:** el protocolo, que se cambia gratis entre cuatro cuerpos: **Escolta** (resistencias), **Blindaje** (vida), **Reactor** (energía) y **Criogenia** (calor). Cada uno vale lo que 10 kg de módulos (un cuarto de módulo) y crece con la clase y el nivel del asistente, así que cada transformación sube también la defensa. No valen lo mismo contra todos, y esa es su gracia: Reactor contra rivales de energía y Criogenia contra los de calor rinden mucho más que los otros dos, que sirven siempre.
  - **Peso:** el arma superior pesa como siempre pesó el dron; el cuerpo y el arma inferior no cuentan para el límite (es un hueco nuevo: si contara habría que quitar piezas para montarla).
  - **Estable en combate, medido** (2026-11-17, tools/sim/balance_sim.gd `--assist`, tipo láser; antes del asistente: físico 49 %, calor 50 %, energía 51 %, híbrido 48 %). El balance entre elementos es muy sensible, y se descartaron tres versiones:
    1. *La batería paga los disparos y hay dos por turno:* físico 93 %, energía 14 %. El drenaje y el calor dejaban de afectar al asistente.
    2. *Dos disparos, limitados por la batería:* energía 62–68 %. Cada disparo de más acumula drenaje.
    3. *Un disparo, y la batería paga uno de cada cuatro:* energía 34 %, y 21 % con más batería.
    Regla que queda: el asistente no puede cambiar **cuántas veces** dispara ni **quién paga**. Tampoco puede haber un protocolo distinto por elemento en los mechs del Orden (físico 76 %, energía 28 %): todos llevan Blindaje, y de arma inferior una gemela de la superior, así que el asistente suma lo mismo a los dos lados. Blindaje se eligió midiendo: con Reactor o Criogenia en todos el balance se rompe (energía 25 %; físico e híbrido 63 %), Escolta es el más neutro sin batería, y Blindaje favorece un poco al calor justo en sentido contrario a la batería, que favorece al físico, así que aguanta todo el recorrido de la mejora. Las armas solo se recortan al rango de clases de su tipo en el asistente del jugador; los rivales llevan todo a la clase de su zona. Resultados en docs/CATALOGO_ARMAS.md.
  - En el código: piezas `ASSIST` de data/catalog.json (tools/catalog_gen.py), progreso común en `PlayerProfile.parts["asistente"]`, `BattleEngine._fire_assist`, `BattleMech.assist_power` y tests/unit/test_assist.gd.
- **Peso:** límite de 1000 kg. Se permite sobrecarga hasta +10 kg, con −15 de vida por cada kg de más. Por encima de 1010 kg el mech no puede pelear.
- **Obligatorio:** torso y piernas.
- **Resistencias:** como máximo 1 módulo por tipo de resistencia. Desde el 2026-11-21 se avisa al elegir, no después (OBS-040): el módulo que repetiría una resistencia sale en rojo con el nombre y el hueco del que choca.
- **Módulos por familias (del usuario, 2026-11-21, OBS-040):** "En la parte de los módulos son muy limitados y además no puedes tenerlos todos, o sea, en algún momento te dice que no puedes usar ese módulo porque se está repitiendo. Entonces ahí te tendrían que indicar. O sea, para cada módulo tendría que haber una selección especial. Por ejemplo, 3 módulos dedicados a resistencia, a los que ya tienes hechos. 3 módulos dedicados a ataque y así. Para que tengas de dónde elegir entre cada uno y no tengas que limitarte a elegir los módulos totales mostrados ahí." Nueve huecos (`MechBuild.MODULE_SLOTS`), tres por familia (`Garage.MODULE_FAMILIES`), y cada módulo tiene la suya en el catálogo (`family`): **Resistencia** (vida y resistencias: blindaje, placas, aislante, Faraday, matriz), **Ataque** (Servo de Brazos, Servo de Hombro, Cebador de Especiales y Sobrealimentador) y **Sistemas** (batería, generador, sumidero, disipador, núcleo dual). Un hueco solo monta los de su familia; un módulo va en un solo hueco (pulsarlo desde otro lo pasa). Los de ataque dan **daño de más por golpe** (`dmg_bonus`, que escala con la clase y el nivel como todo) a un grupo de armas (`boost`): las de brazo, la de hombro, las especiales (pecho y las dos del asistente) o todas, menos. Se suma antes de los multiplicadores (`BattleEngine._damage`, `MechBuild.module_damage`). En Básica nivel 0 son +4, +6, +7 y +3 por golpe (un 8–10 % de un arma de esa clase), por 26, 24, 22 y 34 kg. Los rivales no llevan módulos de ataque. No hay módulo de puntería: la "criticidad" la da el percutor del especialista (§8.6). (Ojo: el juego enciende los críticos al arrancar, `MainScreen`; los simuladores los traen apagados salvo que se pidan.) Medido con la partida real del usuario (2026-11-21, Tirador en la liga 5, `tools/sim/save_fight_sim.gd`, IA difícil, 40 combates): contra el combate 10 gana el 100 % en los tres repartos; contra el campeón, 93 % con sus 8 módulos de antes, **65 % al pasar a familias sin módulos de ataque** (pierde el disipador y el núcleo dual) y 100 % con tres de ataque a la clase y nivel de su torso. Hasta comprarlos queda más flojo; con ellos, algo más fuerte que antes, y los rivales no llevan módulos de ataque.
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
**Actualizado el 2026-11-17:** las armas laterales, superiores y los drones se sustituyeron por las 96 armas generadas del catálogo de armas (docs/CATALOGO_ARMAS.md): 17 diseños de brazo, 9 de hombro y 6 robots de soporte, cada uno en tres municiones, con su tipo (balas, cañón, bláster o láser) y su rango de clases. Las tablas de abajo describen el catálogo anterior, del que salen los números de cada forma (tools/weapon_bases.json). Torsos, piernas, módulos y especiales siguen igual y existen de Básica a Mítica.

Unas 58 piezas con nombres propios (nunca los del original).

| Tipo | Por elemento | Total |
|---|---|---|
| Torso | 2 | 6 |
| Piernas | 2 (una que salta y una con ruedas: andar 3, sin salto) | 6 |
| Arma lateral | 6 (cuerpo a cuerpo, corta, media, larga y 2 de utilidad con empuje, jalón o retroceso) | 18 |
| Arma superior | 3 | 9 |
| Dron | 2 | 6 |
| Módulo | — | 14 (vida, cada resistencia, calor, energía, combinados y, desde OBS-040, 4 de ataque) |
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
- **Los rivales normales llevan habilidades** (2026-11-21, OBS-014: "es muy predecible; los enemigos no hacen más que atacar; no usan habilidades, no usan estrategia; solamente el primer nivel fue realmente combativo"). Medido antes de tocar nada (`tools/sim/behavior_sim.gd`, zona 1): un rival normal o difícil gastaba del 80 al 95 % de sus acciones en disparar un arma y ninguna en habilidades, porque no llevaba; usaba 3 o 4 acciones distintas por combate. Los tres primeros de cada zona, que juegan en fácil (con ruido en su valoración), se mueven, enfrían y usan especiales mucho más (un 44 % de armas y 6 acciones distintas): por eso el principio se sentía más combativo. Ahora cada combate de la campaña puede dar a su rival habilidades (data/campaign.json, `kits`; `Campaign.kits_of`): del cuarto en adelante llevan un **escudo** (para un golpe entero), un **kit de reparación** (repone parte de la vida) o los dos. El reparto de hoy está más abajo, con el carácter de cada rival; el primero (escudo o kit alternando del cuarto al séptimo, escudo en el octavo y el noveno, escudo y un kit del 10 % en el décimo) es el que mide la tabla siguiente. La IA ya sabía usarlos (valora el escudo por lo que absorberá y guarda el kit hasta que hace falta). El hangar lo dice bajo el rival antes de salir ("con escudo", "con reparación"). **Medido después** (12 combates por rival): del cuarto en adelante gastan entre el 3 y el 10 % de sus acciones en habilidades, disparan un 71–88 % y usan entre 4 y 5,5 acciones distintas. Es un cambio corto: siguen sobre todo disparando.
  - **Lo que cuesta:** el escudo y el kit son vida de más, así que esos rivales son más duros. La curva de la zona 1 sin mejoras (`tools/sim/campaign_sim.gd`, el jugador con un mech de ejemplo entero y la IA difícil, 24 combates por casilla), del combate 1 al jefe:

    | | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | Jefe |
    |---|---|---|---|---|---|---|---|---|---|---|---|
    | Antes | 100 % | 100 % | 100 % | 97.9 % | 99.0 % | 91.7 % | 74.0 % | 81.3 % | 56.3 % | 38.5 % | 3.1 % |
    | Con habilidades | 100 % | 100 % | 100 % | 94.8 % | 90.6 % | 88.5 % | 63.5 % | 84.4 % | 49.0 % | 27.1 % | 3.1 % |

- **Cada rival tiene su carácter** (2026-11-21, OBS-014, segunda parte: "no usan estrategia"). Se probó primero lo obvio y no sirvió: cambiar solo los pesos de la valoración (que le pese más su vida, la del rival, el desgaste o la distancia) casi no mueve lo que hacen —siguen disparando un 75–95 % de sus acciones—, y castigar que repitan la misma acción tampoco, porque ya alternaban sus armas (repetían entre un 0 y un 13 %). Lo que sí cambia lo que hacen son sus **gustos**: un pequeño extra, en barras de vida, para las jugadas que empiezan con cierto tipo de acción (`AIConfig.likes`); entre jugadas casi igual de buenas, cada uno elige la suya. Un **temperamento** (`data/tempers.json`, `core/temper_library.gd`) son esos gustos y unos pesos de la valoración (`guard`, `aggression`, `pressure`, `caution`, `evasion`; con todo en 1 es la IA de siempre, jugada a jugada). Cada diseño de rival dice el suyo en `data/builds.json` (`temper`) y lo conserva de una liga a otra, también en la arena y en el combate libre. Los jefes no llevan: piensan como siempre.

  | Rival | Carácter | Lo que hace |
  |---|---|---|
  | Vanguardia (físico) | agresivo | embiste y engancha para tenerte cerca; no le importa recalentarse |
  | Horno (calor) | de desgaste | se te echa encima y te pisa; le pesa más calentarte y dejarte sin energía |
  | Tempestad (energía) | esquivo | camina y salta para quedar donde tus armas no alcanzan |
  | Quimera (híbrido) | defensivo | cuida su vida: se cubre, se repara antes y enfría a tiempo |

  - **Medido** (`tools/sim/behavior_sim.gd`, zona 1, 12 combates por rival contra el mech de ejemplo con la IA normal; en qué gastan sus acciones, cuántas acciones distintas usan por combate y cuánto ganan; "antes" es con las mismas habilidades y sin carácter, `--no-temper`):

    | Combate | Rival | Carácter | | Arma | Pisotón | Moverse | Enfriar | Especial | Habilidad | Distintas | El rival gana |
    |---|---|---|---|---|---|---|---|---|---|---|---|
    | 4 | Quimera | defensivo | antes | 73,8 % | 0,0 % | 5,6 % | 1,6 % | 9,5 % | 9,5 % | 5,5 | 0 % |
    | | | | ahora | 66,4 % | 0,0 % | 7,0 % | 7,8 % | 9,4 % | 9,4 % | 5,7 | 0 % |
    | 5 | Vanguardia de Acero | agresivo | antes | 73,5 % | 0,0 % | 6,6 % | 2,2 % | 8,8 % | 8,8 % | 5,0 | 8 % |
    | | | | ahora | 69,1 % | 0,7 % | 4,4 % | 0,0 % | 17,6 % | 8,1 % | 5,5 | 8 % |
    | 6 | Horno Andante | de desgaste | antes | 80,7 % | 1,8 % | 2,3 % | 0,6 % | 0,6 % | 14,0 % | 5,3 | 42 % |
    | | | | ahora | 60,8 % | 35,9 % | 0,0 % | 0,0 % | 0,0 % | 3,3 % | 3,6 | 0 % |
    | 7 | Tempestad | esquivo | antes | 79,8 % | 0,8 % | 1,6 % | 0,0 % | 6,5 % | 11,3 % | 4,3 | 8 % |
    | | | | ahora | 73,0 % | 0,0 % | 9,8 % | 0,0 % | 9,8 % | 7,4 % | 4,3 | 8 % |
    | 8 | Quimera | defensivo | antes | 65,8 % | 0,6 % | 10,1 % | 1,3 % | 7,6 % | 14,6 % | 6,2 | 42 % |
    | | | | ahora | 57,6 % | 0,0 % | 3,3 % | 15,2 % | 7,9 % | 15,9 % | 6,8 | 0 % |
    | 9 | Horno Andante | de desgaste | antes | 81,6 % | 3,1 % | 5,5 % | 1,2 % | 1,2 % | 7,4 % | 4,7 | 92 % |
    | | | | ahora | 57,1 % | 25,0 % | 1,8 % | 0,0 % | 7,1 % | 8,9 % | 5,3 | 42 % |
    | 10 | Tempestad | esquivo | antes | 74,6 % | 1,4 % | 2,9 % | 2,2 % | 5,8 % | 13,0 % | 5,9 | 100 % |
    | | | | ahora | 70,1 % | 4,9 % | 6,9 % | 0,0 % | 8,3 % | 9,7 % | 5,5 | 83 % |

  - **Dónde se ve:** el hangar lo dice bajo el rival, en su propio renglón, antes de salir: "Agresivo · con reparación", "De desgaste · con escudo".
  - **Lo que cuesta, y cómo se compensó:** apartarse de la mejor jugada los hace más flojos (con las habilidades de antes, el jugador pasaba a ganar el 79 % y el 76 % de los combates 9 y 10). Para devolver la subida de la liga se les dio más habilidades del sexto combate en adelante: el cuarto lleva escudo; el quinto, un kit de reparación (20 %); del sexto al octavo, escudo y kit (20 %); el noveno, escudo y un kit corto (15 %); el décimo, escudo y un kit largo (25 %). Una prueba con dos escudos y 25 % en los dos últimos los dejaba en 31 % y 22 % (8 combates por casilla), demasiado. La curva de la zona 1 sin mejoras (mismo método que arriba), del combate 1 al jefe:

    | | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | Jefe |
    |---|---|---|---|---|---|---|---|---|---|---|---|
    | Sin habilidades ni carácter | 100 % | 100 % | 100 % | 97.9 % | 99.0 % | 91.7 % | 74.0 % | 81.3 % | 56.3 % | 38.5 % | 3.1 % |
    | Con las primeras habilidades | 100 % | 100 % | 100 % | 94.8 % | 90.6 % | 88.5 % | 63.5 % | 84.4 % | 49.0 % | 27.1 % | 3.1 % |
    | Con ellas y con carácter | 100 % | 100 % | 100 % | 99.0 % | 96.9 % | 99.0 % | 88.5 % | 94.8 % | 79.2 % | 76.0 % | 3.1 % |
    | Con carácter y las habilidades de ahora | 100 % | 100 % | 100 % | 99.0 % | 96.9 % | 95.8 % | 85.4 % | 91.7 % | 56.3 % | 42.7 % | 3.1 % |

  - **Límites, dichos claro:** los gustos son umbrales, no perillas suaves: con 0,03 el Horno casi no pisa y con 0,04 pisa un tercio de sus acciones. Están ajustados con las piezas de la liga 1; en las ligas altas hay que volver a medirlos. Y siguen siendo la misma IA por utilidad a dos jugadas: tienen manías, no planes a varios turnos.

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
- **Cómo se ve la mejora (regla del usuario, 2026-11-20):** "tiene que mantenerse la estructura y la mejora tiene que cambiar gradualmente… no la estructura, simplemente los periféricos"; la estructura evoluciona "después de pasar un jefe". Queda así, y manda sobre el "cada 6 niveles" de arriba:
  - **Subir de nivel dentro de una clase** no cambia la estructura de la pieza: le suma periféricos (un filo que se enciende, un generador, una célula de energía, aletas, un sensor). Cada clase tiene su modelo y **seis pasos de aspecto** repartidos entre sus niveles: en la Básica, de seis niveles, cada nivel añade uno; en las siguientes, cada dos, tres, cuatro o cinco niveles (`MechSprites.look_step`).
  - **Transformar la pieza a la clase siguiente** (lo que abre el jefe de la zona) cambia el modelo: otra estructura, más avanzada, que vuelve a empezar sin periféricos.
  - Es lo que hacía la versión antigua del original con sus familias Mark I, II y III sobre un mismo modelo (docs/reference/original-mechanics.md).
  - Se hace primero con un **arma piloto** (la hoja de balas) para que el usuario la evalúe antes de dibujar el resto del catálogo (`tools/art/evolve_weapons.py`). Mientras una pieza no tenga estos dibujos, se ve como siempre.
- **Color personalizable:** el jugador puede cambiar los colores de cada pieza. Se hace con un shader sobre zonas de color del sprite (principal, secundario y luces), sin generar arte nuevo.
  - **Primera versión, hecha el 2026-11-21 (OBS-010, del usuario: "no hay para cambiar el color del arma. Debería estar integrado dentro del mismo seleccionar… elegir un color, ya sea blanco, rojo, azul, de acuerdo al color del robot"):** cada pieza que se ve en el robot (torso, piernas, las seis armas, el arma de pecho y el asistente) se pinta de **blanco, rojo o azul**, que son los tres colores en los que ya existe su dibujo (el de cada elemento: `tools/art/recolor.py`). No hace falta arte nuevo ni shader: se elige con qué dibujo se pinta. Se elige en la computadora del taller, en la cabecera del catálogo de la casilla ("PINTURA" y tres muestras; la que lleva, con marco dorado), y se ve al momento en el plano, en su casilla, en el hangar y en el combate.
  - Se guarda en el equipo del robot (`"paint": {hueco: "PHYSICAL" | "HEAT" | "ENERGY"}`, `Garage.set_paint/paint_of`; el guardado no cambia de versión: es un campo opcional) y pasa al robot armado (`MechBuild.paints`, `paint_of`). **Solo cambia el dibujo:** el elemento de la pieza, su daño y su peso son los mismos. La pintura es del hueco: si cambias el arma de ese brazo, la nueva sale del mismo color. Volver al color del elemento de la pieza le quita la pintura. El asistente, sin pintar, sigue al torso.
  - **Lo que no hace todavía:** más colores que esos tres (verde, dorado, negro… piden exportar más dibujos con `recolor.py` o el shader por zonas de arriba), pintar los drones del asistente, y pintar por zonas (principal, secundario y luces por separado). Los rivales no se pintan.
- **Piezas únicas:** solo las sueltan los 3 últimos jefes de los 10 de cada mundo (§9). No se compran ni se consiguen transformando otra pieza.
- **Tipos de arma y clases** (usuario, 2026-11-16): balas en las clases Básica e Intermedia, cañón y bláster (plasma) en las medias, láser de Avanzada en adelante. El detalle está en docs/CATALOGO_ARMAS.md: 4 categorías por hueco, 37 diseños y 111 armas.
- **Árbol de habilidades** (decisiones del usuario, 2026-11-17; data/skills.json, core/skill_tree.gd). Cada nivel del jugador da 1 punto (29 en el nivel 30), como los puntos por nivel de Swords and Sandals. Hay **tres ramas libres**, de 12 habilidades cada una, que se aprenden en orden; no se llega a todo, así que el jugador elige su estilo:
  - **Asalto:** +3 % de daño (seis veces), daño del arma de pecho (+15, +15 y +20 %), +1 uso del pecho (dos veces) y, al final, la **materia oscura**.
  - **Blindaje:** +3 % de vida (cinco veces), +5 % de resistencias (cinco veces) y el **escudo de energía** (1 por combate en la sexta, 2 en la décima): absorbe el siguiente golpe, sea del turno que sea. Cubre el hueco de escudo del original.
  - **Sistemas:** +4 % de energía y de calor (seis veces cada una) y el **kit de reparación** (de la versión de 2013): devuelve el 20 % de la vida máxima, 30 % con Nanorreparación, y llega a 2 por combate.
  - El escudo y la reparación gastan una acción. La IA sabe usarlos: valora un escudo activo por lo que absorberá y guarda el kit hasta que haga falta.
  - **Los jefes del Orden también entrenan** (2026-11-17): medido con la campaña entera, el árbol solo volvía fácil a todos los jefes (zona 1 al 81 % con 50 victorias; zonas 7 a 10 cerca del 100 % con 10). Cada jefe lleva los puntos que tendría el jugador al llegar a él con unas 50 victorias por zona, repartidos por igual entre las tres ramas (data/campaign.json, `boss.skills`; el menú lo enseña). Nunca llegan a la materia oscura: es del jugador. Así el ritmo de la campaña no cambia, y especializarse en una rama, farmear más o llegar a la materia oscura es lo que da ventaja.
- **Materia oscura:** el disparo más poderoso del juego; prácticamente aniquila al enemigo. Es la última habilidad de la rama Asalto y se abre en el **nivel 25**. Reglas decididas por el usuario: una vez por combate, con el arma de pecho ya desplegada (que haya disparado en ese combate) y el rival a su alcance; quita el **60 % de la vida máxima del rival**, ignora resistencias y escudos y gasta toda la energía.
- **Huecos y nivel del jugador:** tres armas desde el 2026-11-21 (dos de brazo y una de hombro, §4; antes seis, como en el original), más el arma de pecho y el robot de asistencia. El nivel del jugador sube con la experiencia de los combates (data/progression.json: 100 por victoria, 25 por derrota, 500 por jefe; nivel 3 tras unas 3 victorias, nivel 10 tras unas 75, máximo 30). El robot de asistencia se abre en el nivel 5 (era el 3 hasta el 2026-11-21) y el arma de pecho en el 10, como fijó el usuario; las tres armas están abiertas desde el principio. **El robot de asistencia no se regala: se compra** (del usuario, 2026-11-20, OBS-013: "debería aparecer desde un principio, pero como bloqueado, hasta alcanzar dicho nivel, y una vez que lo alcanzas, ahora sí, lo puedes comprar; no lo obtienes así como así"). Su cuna y sus cuatro protocolos se ven desde el principio; en el nivel 5 se compra una vez (2 000 celdas en la liga 1, data/part_shop.json) eligiendo un protocolo, y con él vienen los cuatro, que se cambian gratis. Sin asistente, sus dos armas no se montan ni pelean. Las partidas de antes conservan el suyo. Las piezas de un hueco cerrado se pueden tener y montar, pero no pelean hasta que se abre.
- **Por confirmar con el usuario:** si una pieza puede subir de clase (hoy sí, con la transformación de más abajo, hasta Mítica) o si su clase es fija, y si las clases y las etapas valen igual para torsos, piernas y drones (hoy sí) o solo para armas.
- **Poder y fusión:** el nivel sube con "poder", que se gana fusionando piezas sobrantes (su poder depende de su tier) o núcleos.
- **Transformación:** al llegar al nivel máximo de su clase, la pieza puede transformarse a la siguiente pagando celdas, si la zona ya llega a esa clase. Vuelve al nivel 0 de la nueva clase. A Única solo con un núcleo único (§9.3).
- **Evolucionar un arma (2026-11-21, OBS-045):** cada tipo de arma llega hasta una clase (balas hasta Intermedia, cañón hasta Avanzada, bláster hasta Legendaria, láser hasta Mítica). Un arma al nivel máximo del tope de su tipo ya no se queda ahí: **evoluciona** en la del tipo siguiente que llega a la clase siguiente, con su forma y su elemento (`Catalog.successor`, `PlayerProfile.evolve`), al precio de transformar. La nueva sustituye a la vieja en el inventario y en todos los robots (mismo hueco y pintura), empieza a nivel 0 de la clase siguiente y se lleva sus prototipos. Cambia de modelo, porque cada tipo tiene su dibujo. Las armas del asistente suben con él: su casilla enseña la tecla del asistente.
- **Monedas:** **celdas de plasma** (salen de los combates) y **núcleos únicos** (los sueltan los jefes 8, 9 y 10, §9). Los núcleos del botín y de desarmar piezas repetidas siguen por diseñar. No hay moneda de pago. El usuario pidió el 2026-11-17 que la moneda no fuera "oro" ni "monedas", que no pegan con un juego de robots; "celdas de plasma" es la propuesta: los robots funcionan con energía y se la quitan al rival vencido. En el código y en el guardado se sigue llamando `gold`; el nombre visible vive en la tabla de textos, así que cambiarlo es una línea. Donde este documento diga oro, léase celdas.
- **Botín:** cada victoria da oro y una tirada de botín, con mejores tablas en los capítulos avanzados. Hay cajas que se ganan jugando, nunca con dinero.
- **Tienda del taller** (recuerdo del usuario, 2026-11-16: en el juego antiguo había un taller donde comprabas piezas e ibas armando tu robot o tus robots). Vende por oro las piezas básicas de cada capítulo, con un surtido que cambia al avanzar; lo raro sigue saliendo del botín.
- **Garaje:** se pueden guardar varios mechs armados y elegir con cuál pelear. Cada uno tiene su tipo (§9).
- **Armería** (el equivalente de la tienda de arena del original): puntos de mejora permanentes comprados con celdas. Daño, energía y calor hasta +20 %; resistencias hasta +40 %; vida hasta +15 %; backfire hasta −20 % (§9.2).
- **Objetivo de ritmo:** llevar un build completo a Divino debe costar unas 8–12 horas de juego. Se mide con el simulador en la fase F7.

### 8.6 El especialista (2026-11-21, OBS-043)

**Lo que pidió el usuario.** "En este juego de gladiadores había un mago, una tienda de magos, donde podías hechizar tu arma… y eso le daba mucho más criticidad de ataque… Lo podemos traer a este mundo de tecnología… con algo como el especialista: un robot capaz de crear, diseñar tecnología más allá de la que ya existe… a tu armamento, o a tu escudo cinético, se pueden adicionar efectos muy capaces que te den mucha más ventaja, pero que tengan un costo muy alto… Este taller va a ser igual inmersivo." Y: "podrás adquirir piezas o implementar piezas a tu armadura de pecho, pies y todo eso para evitar sobrecalentamiento, enfriamiento". Y al ver la propuesta: "Podemos hacer varias cosas, como que cada ataque te dé vida, que cada ataque te regenere energía, te quite calor, etcétera. Varias combinaciones… cada nivel, cada rango te va dando más nivel. Aquí no hay bloqueos por nivel o liga… se desbloquea en el nivel 10 nada más. La limitante es que cuesta mucho: la más especializada cuesta hasta 100 000… empieza desde los 1 000 y hasta los 100 000… varias combinaciones que te pueden dar mucho power."

**Quién es.** Un robot ingeniero que trabaja fuera del catálogo del Orden: recupera técnicas de eras más altas de la escalera (§9.4) y las adapta a tus piezas. Nombre por decidir con el usuario.

**Dónde está.** Un rincón del hangar, como todo lo demás (§10): su banco de trabajo, con una lámpara, chispas y sus brazos trabajando. Al pulsarlo se acerca el banco: la pieza que eliges queda bajo la lámpara (como la vitrina de la computadora, OBS-039), a un lado los prototipos que le caben, con su rango y su precio, y lo que cambia. Instalar o subir de rango es una secuencia corta con chispas y un sonido propio.

**Las reglas.**
- **Se abre en el nivel 10 del jugador, y nada más lo limita:** ni la liga ni la clase de la pieza. El límite es el precio.
- **Se combinan en cada pieza** (las dos armas de brazo, la de hombro, la de pecho, el torso y las piernas): una pieza lleva todos los prototipos que le quepan a la vez, cada uno con su rango; comprar uno no quita los demás. Hasta el 2026-11-21 era uno por pieza y otro lo sustituía; el usuario lo vivió como un error: "Acabo de ver un error: cuando subo al máximo nivel y mejoro la siguiente, el primero se reinicia. Arregla eso y valídalo." Van con la pieza, por su clave de progreso: dos brazos con la misma arma comparten sus prototipos, como comparten su nivel.
- **Rangos I a V.** Cada rango sube el efecto; se paga el rango siguiente sobre el que ya tiene. El prototipo va con la pieza.
- **Precio de 1 000 a 100 000 celdas.** Dos escalas (`data/prototypes.json`): los de serie, 1 000 · 3 000 · 8 000 · 20 000 · 50 000; los más especializados (vida por golpe, criticidad, válvula), 2 000 · 6 000 · 15 000 · 40 000 · 100 000.

| Pieza | Prototipo | Qué hace, de rango I a V |
|---|---|---|
| Arma | **Sifón vital** (especial) | Cada golpe de esa arma te devuelve vida: el 6 · 9 · 12 · 16 · 20 % del daño que hace |
| Arma | Captador de energía | Cada golpe te devuelve energía: el 4 · 6 · 8 · 11 · 15 % de tu energía máxima |
| Arma | Purga térmica | Cada golpe te quita calor: el 5 · 8 · 11 · 15 · 20 % de tu calor máximo |
| Arma | **Percutor de resonancia** (especial) | La "criticidad": esa arma suma un 8 · 12 · 16 · 22 · 30 % de probabilidad de golpe crítico a la suya (aunque no tuviera), con el efecto de su tipo |
| Arma | Núcleo de sobrecarga | +5 · 8 · 11 · 15 · 20 % de daño de esa arma |
| Torso | Radiador de fase | +10 · 16 · 22 · 30 · 40 % de enfriamiento |
| Torso | Reactor afinado | +10 · 16 · 22 · 30 · 40 % de regeneración de energía |
| Torso | **Válvula de alivio** (especial) | Las primeras 1 · 2 · 3 · 4 · 5 veces que se sobrecalienta en un combate, no pierde nada |
| Piernas | Coraza de marcha | +4 · 6 · 8 · 11 · 15 % de vida |

**Lo que no hace:** no da piezas nuevas ni sube clases, y los rivales no llevan prototipos (más adelante, los campeones podrían).

**Hecho (2026-11-21), falta el veredicto del usuario.** Su banco está en el suelo del hangar, abajo a la izquierda (`scenes/hangar/specialist_bench.gd`; con persiana y "NIVEL 10" antes de tiempo); al pulsarlo se acerca su pantalla (`scenes/hangar/specialist_screen.gd`): tus seis piezas con su prototipo y su rango, la elegida bajo la lámpara (chispas al instalar) y los prototipos que le caben con sus cinco rangos, lo que hace el siguiente y su precio; comprar pide dos pulsaciones y el especialista habla en la línea de abajo. La lógica es `core/prototype_library.gd` (PrototypeLibrary: precios, rangos, compra y `apply`), el estado de la pantalla `scenes/workshop/specialist_brief.gd`, y el motor aplica cada efecto (`BattleEngine._proto_on_hit`, `crit_chance`, la válvula al empezar el turno, `MechBuild.summary`). Se guarda en `PlayerProfile.prototypes`, por pieza. Pendiente: el dibujo del especialista mismo (un robot con nombre) y el sonido propio de instalar.

### 8.7 Las diez fases del dibujo (2026-11-21, OBS-047)

**Lo que pidió el usuario.** "Sí se ve bien, pero ampliamos un poco más las progresiones. Bueno, bastante más. Lo que me muestras de básica en mítica, eso perfectamente podría ir entre una fase, entre base e intermedio. Y ya de este modo, esto marca para pasar a cada fase. Por ejemplo, son 10 fases: de la fase 0 a la fase 1 pasa de básica a intermedia, pero con otro nombre. Fase 1, fase 2, 3 va junto con los 10 campeones que se van a enfrentar. Hay que ampliar esto. Y hay armas que se pueden transformar hasta la última, y ya son más potentes. Profundicemos más en eso."

**Una fase por campeón.** Cada liga abre media clase (la liga 1, Básica hasta el nivel 3; la 2, el resto de Básica; la 3, Intermedia hasta la mitad… la 10, el resto de Mítica), así que la fase de una pieza sale de su clase y su nivel (`ItemScaling.phase`): fase 0 (Básica, primera mitad) a fase 9 (Mítica, segunda mitad), y la 10 es la Única (con los núcleos de los últimos jefes). Cada campeón vencido abre la fase siguiente. Los números del juego no cambian: lo nuevo es el dibujo y el nombre.

**Cada fase, su dibujo.** El salto que antes iba de Básica a Mítica es ahora el de una sola fase: cada fase parte del dibujo de la anterior y le suma lo suyo (`tools/art/phase_chain.py`), primero la máquina (placas, reactor, blindaje), luego la energía (aletas, alas, placas que flotan) y al final lo divino (halos, núcleo de estrella, luz). El juego busca "<juego>_f<fase>" y, si falta, el de la fase más alta por debajo (`MechSprites.class_set`). Piloto: el torso del chasis ligero en tres cadenas de 10 fases, para elegir una.

**Cada fase, su nombre** (aprobados por el usuario el 2026-11-21: "sí, me parece bien los nombres"; `Txt.PHASE_NAMES`): 0 Prototipo, 1 Serie, 2 Reforzado, 3 Táctico, 4 Élite, 5 Vanguardia, 6 Campeón, 7 Legendario, 8 Estelar, 9 Soberano, 10 Divino. La ficha de cada pieza enseña el de su fase ("Táctico 12/12") en vez del de su clase; el color sigue siendo el de la clase.

**Las armas, hasta la última.** Con la evolución (§8, "Evolucionar un arma") un arma pasa de tipo al tope del suyo (balas → cañón → bláster → láser) y llega a la fase 9; con un núcleo, a la Única. Su dibujo cambia por tipo y, dentro de cada tipo, por fase (pedido del usuario: "ahora vamos a poner al mismo nivel las armas"): cada tipo vive en las fases de sus clases (balas 0-3, cañón 2-5, bláster 2-7, láser 4-10), su dibujo de siempre es la primera y las siguientes salen encadenadas (`tools/art/weapon_phases.py`), con la misma escalera que los torsos hasta el dios robot. El juego busca "<pieza>_f<fase>" (`MechSprites.weapon_look`). El rifle de hombro usa las fases del de brazo.

**Orden:** elegir la cadena del torso piloto → exportarla → nombres en el juego → el resto de torsos, piernas, especiales y armas, por lotes.

## 9. Campaña
**Visión (del usuario, 2026-11-16):** recuperar la versión antigua de Super Mechs para un jugador. Empiezas con un robot sencillo y avanzas combate a combate hasta un jefe superior al que solo se vence con táctica. Aquella versión era una demo que no pasaba de los primeros 10 combates; aquí va completa. La meta es unir la originalidad y el detalle del juego antiguo con las mecánicas de combate modernas. No hay multijugador.

- **Estructura de la partida** (usuario, 2026-11-17; modelo: Swords and Sandals, docs/reference/original-mechanics.md). El jugador tiene una base con tres sitios:
  - **Campaña:** los combates de la zona, en orden, y su jefe. Cada victoria avanza al siguiente.
  - **Arena:** combates sueltos, repetibles, para juntar celdas. No avanzan la campaña. El rival es un mech al azar con el poder más parecido al de las piezas del jugador, sin pasar de la clase de la zona, **y con el mismo equipo que él** (2026-11-20): tantas armas de brazo y de arriba, módulos y especiales como lleve el jugador, las de brazo de las mismas formas que las suyas si el rival las tiene (rifle contra rifle, hoja contra hoja), y asistente o arma de pecho solo si él los lleva (`Campaign.loadout_of`, `BuildLibrary.trim`). Quien empieza con una sola arma pelea contra rivales de una sola arma, y el arma con la que salen cambia de uno a otro. La arena siempre va a su medida.
  - **Armería:** donde las celdas se cambian por mejoras, en dos pestañas: **Mejoras** (las seis permanentes, §9.2) y **Piezas** (cada arma y cada pieza de blindaje del mech sube de nivel por separado y se transforma de clase, §9.3).
- **Cada zona es una liga: 10 combates y su campeón** (reglas del usuario, 2026-11-20, OBS-020: "cuando inicias campaña, los dos modos se bloquean, tanto libre como arena. Debes acabar la campaña sí o sí… 10 peleas seguidas"). Antes de entrar se puede pasar por la arena cuanto haga falta. Al salir al primer combate de la liga (el hangar pide pulsar dos veces y avisa de que se cierran) **la arena y el combate libre quedan cerrados** hasta vencer al campeón; el taller, la tienda, la armería y las habilidades siguen abiertos entre combate y combate. Vencido el campeón, la liga siguiente empieza con los tres modos abiertos (`Campaign.mode_locked`, `PlayerProfile.campaign_on`).
- **Perder un combate de la campaña termina la partida** ("pierdes el avance total; te reinicias hasta el principio"): contra un rival normal o contra el campeón, se pierden las celdas, las piezas, las mejoras y el avance; solo queda el historial (partidas perdidas y mejor marca). El hangar lo dice bajo el rival antes de salir. Perder en la arena o en el combate libre no cuesta nada. **Rendirse** (desde la pausa, con Esc) cuenta como perder, y la pausa lo avisa antes de confirmar. La regla está en data/campaign.json (`on_loss`: `new_game` o `retry`).
- **Protecciones** (del usuario, el mismo día: "eventualmente puedes comprar protección"). Se compran con celdas en el monitor de misiones, pulsando dos veces; se lleva una de cada tipo como mucho y se gasta al perder un combate de campaña (primero la revancha, si lleva las dos). Su precio sube con la paga de la liga (data/campaign.json, `protections`):
  - **Seguro de liga** (3 000 celdas en la liga 1): "nada más vuelvas al comienzo de la liga". Conservas robot, celdas y mejoras, vuelves al combate 1 de esa liga y la arena y el combate libre se abren otra vez.
  - **Revancha** (7 500 en la liga 1): "te devuelve al penúltimo enemigo… tienes una oportunidad de volver a retar al campeón". Vuelves un combate atrás (perdiendo contra el campeón, al último rival normal) y sigues dentro de la campaña.
- **Ritmo que pidió el usuario:** unos 50 combates ganados para tener opciones reales contra el primer jefe, y unos 100 para ganarle con facilidad. Ir directo debe ser una apuesta difícil, de táctica.
- **Cómo se empieza: tres tipos de robot, con el cuerpo y una sola arma** (del usuario, 2026-11-20, OBS-021 y OBS-026: "empiezas con lo más básico, literal con un palo"; "únicamente 3 tipos de robots, tipo Metal Slug, con 3 tipos de historia… todos empiezan sin nada, pero tienen 3 distintos estilos… equilibrados, pero con distintas mecánicas de batalla"). La partida nueva no es un menú: los tres están de pie en el hangar, cada uno bajo su foco y con su historia proyectada en el suelo, y se elige pulsando dos veces (`scenes/hangar/starter_select.gd`). Datos en data/styles.json (`core/style_library.gd`):

  | Tipo | Robot | Empieza con | En los brazos monta | Lo suyo |
  |---|---|---|---|---|
  | **Asalto** | Ariete (torso Fragua, piernas Pisabrasas) | Cuchilla vibratoria térmica | hojas y armas cortas | +6 % de daño |
  | **Guardián** | Muralla (torso Centinela, Orugas de Asedio) | Ametralladora cinética | armas cortas y medias (y saboteadores, de Intermedia en adelante) | un escudo por combate, de serie (para un golpe entero), y +12 % de vida |
  | **Tirador** | Halcón (torso Condensador, Deslizadores Voltaicos) | Rifle iónico | armas medias y largas | dispara a quemarropa (sus armas de brazo no tienen alcance mínimo) y +20 % de daño |

  - Los dos primeros son como los describió el usuario (el de ataque, "principalmente armas de cuerpo a cuerpo", con lo de largo y medio alcance arriba; y el de medio alcance, con "un escudo" y "un arma de ataque"). **El tercero, el Tirador, es propuesta nuestra** (él no lo describió) y falta su visto bueno, igual que los nombres y las historias.
  - **El tipo solo limita las armas de los brazos**, y cada tipo abarca dos alcances vecinos (cuerpo a cuerpo y corto; corto y medio; medio y largo), así que comparten una forma con el de al lado y ninguno se queda sin opciones en una clase. Arriba, el cuerpo, los módulos y los especiales son libres. El catálogo de la computadora del taller solo enseña lo que el tipo de ese robot monta, y lo dice ("Brazos: hojas y armas cortas").
  - **Lo suyo** usa los mismos efectos que el árbol de habilidades (`SkillSet`), así que el escudo del Guardián se suma a los que dé la rama Blindaje. **A quemarropa** (`SkillSet.point_blank`) es nuevo y solo lo da el Tirador: en combate, sus armas de brazo llegan también a la casilla de al lado.
  - **Por qué esos números** (medido el 2026-11-20, `tools/sim/starter_sim.gd`; `tools/sim/starter_trace.gd` imprime un combate jugada a jugada). En esta arena de 10 casillas el rival se echa encima, así que el alcance largo casi no da ventaja y las armas largas pegan menos por diseño: sin nada suyo, un Tirador armado entero ganaba el 0–2 % (ni siquiera podía disparar con el rival pegado), y un Guardián solo con su escudo, el 13 %. Con los tres en el mismo cuerpo y los mismos módulos, lo de la tabla los deja armados enteros en 65 % (Asalto), 52–87 % según la vida de más (Guardián; con +12 %, en medio) y 57 % (Tirador).
  - **Lo medido con cada uno en su cuerpo**, contra los rivales de la arena de la liga 1 con su mismo equipo, la IA normal en los dos lados y 32 combates por rival:

    | Momento | Asalto | Guardián | Tirador |
    |---|---|---|---|
    | Con su única arma | 61 % | 92 % | 73 % |
    | Dos armas | 82 % | 86 % | 98 % |
    | Dos armas y dos módulos | 89 % | 84 % | 95 % |
    | Armado entero | 95 % | 63 % | 71 % |

    Los tres pueden con la arena en todos los momentos y ninguno queda inservible, pero **no están parejos todavía**: el combate es casi determinista (§2.7, M1) y una ventaja pequeña mueve mucho la tasa, y además el cuerpo con el que se arma cada uno pesa más que el tipo (el Asalto entero lleva un módulo más por ir en un cuerpo de calor). El ajuste fino se hará con los rivales propios de cada liga (OBS-011) y con lo que diga el usuario al jugarlos. Sin medir: la campaña de la liga 1 con estos robots.
  - **Otro robot** (bahía vacía del hangar): un armazón vacío de cualquiera de los tres tipos, gratis, que se arma con tus piezas. Ya no se venden los cuatro robots de ejemplo armados: no tenían tipo.
  - Los robots de las partidas de antes no tienen tipo y montan cualquier arma. Una partida de antes recién empezada (sin nada ganado ni comprado) vuelve a elegir robot.
- **Mundo con 10 jefes** (pedido del usuario, 2026-11-16): el mundo se divide en 10 zonas, cada una con sus combates normales y un jefe al final. Los **3 últimos jefes** sueltan las piezas de clase Única. Sustituye a los 3 capítulos del plan anterior; donde este documento diga "capítulo" léase "zona". Más mundos quedan para el paso 2.
- **Las 10 zonas** (data/campaign.json). Cada clase de pieza ocupa dos zonas: en la primera los rivales van del nivel 0 a la mitad de la clase y en la segunda de la mitad al máximo. El jefe está al nivel más alto de su zona. La clase de la zona es también la más alta a la que el jugador puede transformar sus piezas mientras esté en ella. Las zonas de clase alta pagan más, porque sus mejoras cuestan más.

  | Zona | Nombre | Clase | Rivales | Jefe | Escenario | Paga |
  |---|---|---|---|---|---|---|
  | 1 | Frontera de Chatarra | Básica | nivel 0 a 3 | Capataz, nivel 3 | desierto | ×1 |
  | 2 | Dunas de Óxido | Básica | 3 a 6 | Verdugo, 6 | desierto | ×1 |
  | 3 | Refinerías de Ceniza | Intermedia | 0 a 6 | Reactor, 6 | ciudad | ×1.35 |
  | 4 | Anillo Orbital | Intermedia | 6 a 12 | Hidra, 12 | orbital | ×1.35 |
  | 5 | Metrópolis Silente | Avanzada | 0 a 9 | Centella, 9 | ciudad | ×1.8 |
  | 6 | Fosas de Plasma | Avanzada | 9 a 18 | Égida, 18 | desierto | ×1.8 |
  | 7 | Nebulosa Espectral | Legendaria | 0 a 12 | Espectro, 12 | orbital | ×2.4 |
  | 8 | Forjas del Núcleo | Legendaria | 12 a 24 | Caldera, 24 | ciudad | ×2.4 |
  | 9 | Bastión de Hierro | Mítica | 0 a 15 | Colmena, 15 | desierto | ×3.2 |
  | 10 | Trono del Orden | Mítica | 15 a 30 | Coloso, 30 | orbital | ×3.2 |

  Los rivales normales son por ahora los cuatro mechs de ejemplo, por turnos; la dificultad de su IA sube a lo largo de la zona.
- **Piezas Únicas:** los jefes 8, 9 y 10 sueltan un **núcleo único**. Con él, una pieza Mítica al nivel máximo se transforma en Única, en cualquier zona; es la única forma de conseguirlas.
- Al vencer al jefe 10 la campaña queda completa.
- Para farmear está la arena; los combates de campaña se ganan una sola vez.
- La curva de dificultad se valida con el simulador: el build "esperado" del jugador en cada capítulo debe ganar entre el 55 % y el 70 % de las veces contra los enemigos normales.

**La liga 1 empieza desde abajo (2026-11-21, OBS-031).** Del usuario, tras perder contra el primer rival de la campaña: "creo que está muy roto el primer rival de la campaña, me derrotó a pesar de llevar todas las mejoras". Era cierto: los rivales salían armados enteros desde el primer combate y el jugador empieza con una sola arma (medido con `tools/sim/league_start_sim.gd`: con una o dos armas, 0 % de victorias contra cualquier combate de la liga; el Tirador con una sola arma y todas las mejoras, 0 % contra el primero). Ahora cada combate de la liga 1 dice con qué sale su rival (`loadout` en data/campaign.json, el mismo recorte de la arena, `BuildLibrary.trim`), y crece con lo que paga la campaña (500 celdas por combate):

| Combate | Rival | Lleva | Nivel | IA | Habilidades |
|---|---|---|---|---|---|
| 1 | Vanguardia | 1 arma (la media, no su hoja) | 0 | fácil | — |
| 2 | Horno | 1 arma y 1 módulo | 0 | fácil | — |
| 3 | Tempestad | 2 armas | 0 | fácil | — |
| 4 | Quimera | 2 armas y 1 módulo | 0 | fácil | — |
| 5 | Vanguardia | 2 armas y 2 módulos | 0 | normal | escudo |
| 6 | Horno | 3 armas y 2 módulos | 1 | normal | reparación |
| 7 | Tempestad | 3 armas y 3 módulos | 1 | normal | escudo |
| 8 | Quimera | 3 armas, 1 de hombro y 3 módulos | 1 | normal | escudo y reparación |
| 9 | Horno | 4 armas, 1 de hombro y 3 módulos | 2 | difícil | escudo y reparación |
| 10 | Tempestad | 4 armas, 1 de hombro, 4 módulos y un especial | 2 | difícil | escudo y reparación |
| Campeón | Capataz del Orden | entero | 3 | difícil | su entrenamiento |

- **Medido** (16 combates por casilla, el jugador con la IA normal y llevando las mismas armas y módulos que el rival de cada combate):

  | | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | Campeón |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | Asalto, sin mejoras | 100 % | 100 % | 94 % | 100 % | 100 % | 75 % | 25 % | 6 % | 0 % | 0 % | 0 % |
  | Guardián, sin mejoras | 100 % | 100 % | 100 % | 100 % | 38 % | 6 % | 19 % | 6 % | 0 % | 6 % | 0 % |
  | Tirador, sin mejoras | 81 % | 100 % | 100 % | 100 % | 44 % | 13 % | 25 % | 19 % | 0 % | 0 % | 0 % |
  | Asalto, con todas las mejoras y piezas a nivel 3 | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 31 % |
  | Guardián, ídem | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 0 % |
  | Tirador, ídem | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 0 % |

- **Lo que significa:** los cuatro primeros combates se ganan con lo que la propia campaña deja comprar; del quinto en adelante hacen falta mejoras de la armería y subir las piezas, que es para lo que está la arena antes de entrar en la liga (dentro de la liga está cerrada). Las otras nueve ligas no cambian (a ellas se llega con el robot ya armado). **Sin resolver:** falta medir cuánta arena pide de verdad la liga 1 a un jugador y no a la IA.
- **El campeón de la liga 1, a la medida de los tres tipos (mismo día).** Con el superblindaje al doble, la resistencia se comía casi todo el daño de las armas medias y largas: armado entero, con asistente, todas las mejoras y piezas a nivel 3 (jugador con la IA difícil, 24 combates), el Asalto le ganaba el 88 %, el Tirador el 25 % y el Guardián el 4 % (sin asistente: 42, 0 y 0 %). Con el 60 % más (`resistance_mult` 1.6 en data/chassis.json): Asalto 96 %, Tirador 75 % y Guardián 58 %; con el 40 %: 100, 79 y 75 %. Queda en 1.6: sigue siendo el más duro de la liga y nadie se queda sin opción. Es un número que aprobó el usuario ("de momento"): si lo quiere al doble, hay que darles al Guardián y al Tirador un arma que perfore.

**La liga 1 con tres armas (2026-11-21, OBS-033).** Con dos armas de brazo y una de hombro, la rampa de la liga 1 se rehízo: el primer rival lleva una sola arma de brazo (la segunda de su diseño: la escopeta de la Vanguardia, no su hoja), del tercero en adelante las dos, el arma de hombro llega en el sexto, y los especiales en el octavo y el décimo. **El campeón de la liga 1 pelea sin su robot de asistencia** (`loadout` en data/campaign.json): el asistente se abre en el nivel 5 y quien llega al campeón solo por la campaña lo hace en el 4 (100 de experiencia por victoria); con él, el campeón ganaba casi siempre. Quien pase antes por la arena puede llegar con su asistente, y es una ventaja que se gana. La del campeón sigue siendo el superblindaje.

- **Medido a la par** (el jugador con las mismas armas y módulos que cada rival, IA normal, sin mejoras, 16 combates por casilla):

  | | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Asalto | 94 % | 100 % | 100 % | 100 % | 100 % | 63 % | 94 % | 6 % | 25 % | 19 % |
  | Guardián | 69 % | 100 % | 100 % | 100 % | 38 % | 50 % | 81 % | 6 % | 38 % | 19 % |
  | Tirador | 88 % | 100 % | 100 % | 100 % | 44 % | 0 % | 44 % | 0 % | 0 % | 0 % |

- **El campeón** (armado entero, IA difícil, 16 combates): con todas las mejoras y piezas a nivel 3, Asalto 100 %, Guardián 81 %, Tirador 69 %; sin mejoras, 0 % los tres. Con su asistente le ganaban, con todo comprado, el 69, 6 y 6 %.
- **Lo que queda flojo:** el Tirador a la par del sexto combate en adelante (su rifle de hombro llega solo; sus brazos, armas medias). Hace falta medir cuánto lo arreglan las mejoras antes de tocarlo.

**Delante del campeón se puede entrenar (2026-11-21, OBS-037).** "Si bien luchar con rivales… la experiencia se queda detenida. Yo soy actualmente atrapado… en el nivel 9, porque no puedo derrotar al jefe debido a estas desventajas acumuladas… cuando lucho una y otra vez… no se me acumula la experiencia… En caso de que no pueda derrotar a un jefe porque sea muy difícil, tengo la opción de farmear y subir de nivel jugando ya sea en la arena o acumulando experiencia en campaña." Con solo el campeón por delante, la arena se abre aunque la campaña de la liga esté en marcha (`Campaign.mode_locked`, `at_champion`); el combate libre sigue cerrado. Lo ganado en la arena se queda y perderla no toca la campaña. **Y los dos abren con todas sus acciones** (OBS-034): por eso la liga 1 empieza por sus rivales más flojos (Horno, Tempestad, Quimera, y la Vanguardia cuarta). Medido con una sola arma (`tools/sim/league_start_sim.gd --stage=0`, 16 combates): Asalto 100, 100 y 94 % en los tres primeros; Guardián 100, 94 y 88 %; Tirador 100, 100 y 81 %. El cuarto pide ya una segunda arma.

### 9.1 Los jefes
**Reglas que fijó el usuario:**
- Vencer a un jefe debe ser extremadamente difícil, **no por la cantidad de vida**; usando las bonificaciones y los ataques con táctica, en teoría se puede ganar. La otra vía es reunir celdas en la arena para comprar mejoras (2026-11-16).
- **Cada jefe tiene su diseño propio y una habilidad especial:** una ventaja que el jugador no puede conseguir en la zona en la que está. Sus ejemplos: superblindaje, energía infinita, velocidad y poder de daño (2026-11-17).

**Cómo se hace:** la habilidad es el chasis del jefe (data/chassis.json: `ability`, `ability_text` y los números que cambia). Todos los jefes tienen la vida de un mech normal de su clase. El menú enseña la habilidad antes del combate. Cada habilidad deja un punto débil, que es la vía táctica.

**Los 10 jefes** (lista aprobada por el usuario el 2026-11-17, "de momento"). Los tres últimos sueltan las piezas Únicas.

| Zona | Jefe | Habilidad | Qué hace | Punto débil |
|---|---|---|---|---|
| 1 | Capataz del Orden | Superblindaje | Sus resistencias valen un 60 % más (eran el doble hasta el 2026-11-21, ver abajo) | Se enfría un 30 % peor |
| 2 | Verdugo del Orden | Poder de daño | Sus armas pegan un 30 % más | Resistencias al 60 % |
| 3 | Reactor del Orden | Energía infinita | Sus armas no gastan energía y no se le puede drenar (ni romper su energía) | Se enfría un 15 % peor |
| 4 | Hidra del Orden | Regeneración | Repara el 5 % de su vida al empezar cada turno | Daño concentrado en pocos turnos |
| 5 | Centella del Orden | Velocidad | 3 acciones por turno en vez de 2 | Se enfría un 30 % peor |
| 6 | Égida del Orden | Manto de plasma (desde el 2026-11-21, OBS-041; antes, un escudo que anulaba el primer golpe de cada turno) | Una capa de vida de más, la mitad de su vida, que los golpes gastan antes que la vida y que, rota, no vuelve | Armas de varios disparos y dron; resistencias al 60 %; se enfría peor |
| 7 | Espectro del Orden | Evasión | Al recibir daño salta al extremo de la arena de su lado, una vez por turno | Armas de alcance largo |
| 8 | Caldera del Orden | Núcleo térmico | Nunca se sobrecalienta | Resiste la energía a la mitad |
| 9 | Colmena del Orden | Enjambre | Su dron dispara dos veces | Si el jugador se le pega, solo dispara una |
| 10 | Coloso del Orden | Velocidad y superblindaje | 3 acciones por turno y resistencias ×1.7 | Se enfría un 30 % peor |

Algunos jefes llevan además algo de resistencia o de potencia de más (data/chassis.json) para que todos queden en la misma franja de dificultad. Por ahora montan las piezas de los mechs de ejemplo; su diseño y sus armas propias llegan con el catálogo nuevo. Las habilidades se prueban una a una en tests/unit/test_boss_abilities.gd.

**Medido el 2026-11-17 con la misma vara para todos** (tools/sim/bosses_sim.gd: todo en clase Básica nivel 6, bonificaciones encendidas, IA difícil en los dos lados, 20 combates por casilla, así que cada cifra tiene unos ±10 puntos de margen; "50 combates" = armería al nivel 6):

| Jefe | Directo: media | Directo: mejor mech | Con 50 combates: media | Con 50 combates: mejor mech |
|---|---|---|---|---|
| 1 Superblindaje | 1 % | 5 % (físico) | 51 % | 80 % (calor) |
| 2 Poder de daño | 5 % | 15 % (energía) | 69 % | 70 % |
| 3 Energía infinita | 15 % | 30 % (calor) | 88 % | 100 % (calor) |
| 4 Regeneración | 0 % | 0 % | 75 % | 90 % (energía) |
| 5 Velocidad | 6 % | 20 % (energía) | 76 % | 90 % (híbrido) |
| 6 Escudo | 0 % | 0 % | 26 % | 70 % (calor) |
| 7 Evasión | 3 % | 5 % | 38 % | 60 % (energía) |
| 8 Núcleo térmico | 20 % | 75 % (energía) | 84 % | 100 % (energía) |
| 9 Enjambre | 5 % | 20 % (energía) | 65 % | 90 % (energía) |
| 10 Velocidad y superblindaje | 0 % | 0 % | 16 % | 25 % (calor) |

- Ningún jefe se vence de entrada salvo por su punto débil (la Caldera, con el mech de energía).
- Con unos 50 combates de armería todos se vuelven ganables, y el mech que ataca el punto débil gana mucho más que los otros.
- El jefe final: 0 % de entrada, 16 % con 50 combates y 94 % con la armería al máximo.
- Ninguna habilidad deja combates atascados: 0 empates por límite de turnos en 2 960 combates.
- **Falta:** ajustarlos de nuevo cuando exista cada zona, con la clase y el equipo que tenga el jugador al llegar.

**El jefe de velocidad, medido el 2026-11-16** (data/chassis.json, chasis "jefe"; data/builds.json, mech "jefe_final"):
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


### 9.2 La segunda vía: la arena y la armería
**Dónde está (2026-11-18, pedido del usuario):** la armería no es una pantalla aparte: es el espacio Mejoras del taller, junto a Pieza, Tienda y Habilidades (PLAN F6).

Hecho el 2026-11-16 y ajustado el 2026-11-17 (core/arena_shop.gd, core/player_profile.gd, core/campaign.gd, data/arena_shop.json). La armería sigue la tienda de arena del original: seis mejoras permanentes en 10 niveles pequeños, con su misma tabla de pasos (0, 1, 3, 5, 7, 9, 11, 13, 15, 17 y 20 sobre 20).

| Mejora | Tope |
|---|---|
| Potencia de las armas | +20 % |
| Energía y regeneración | +20 % |
| Calor y enfriamiento | +20 % |
| Resistencias | +40 % |
| Blindaje (vida) | +15 % |
| Amortiguación del retroceso propio | −20 % |

- **Blindaje en porcentaje:** el original da +350 de vida plana, pensado para mechs de su clase más alta. Aquí todo escala con la clase, y en la clase Básica esos 350 casi duplicaban la vida. +15 % es lo que valen 350 puntos en la clase Mítica, y pesa igual en cualquier clase. Ajuste nuestro, pendiente del visto bueno del usuario.
- **Recompensas** (celdas de plasma; del usuario, 2026-11-20, OBS-021: "en la campaña consigues 500, en la arena 300" y el campeón da "20 000, 25 000"): **300** por ganar en la arena y 60 por perder; **500** por cada combate de campaña ganado; **22 500** por vencer al campeón, que alcanza para el equipo básico de la liga siguiente "pero no lo más top". Perder en la campaña no paga: termina la partida o gasta una protección (§9). Todo se multiplica por la paga de la liga. Hasta el 2026-11-20 eran 250, 250 y 2 500.
- **Tope por zona (2026-11-18, pedido del usuario: que todo se abra de forma orgánica, al vencer jefes y subir de nivel):** en las zonas 1 y 2 la armería llega como mucho al nivel 9; el 10 se abre en la zona 3 (`armory_cap` en data/campaign.json). Es el tope más bajo que no cambia el ritmo aprobado: quien farmea 100 victorias en la zona 1 ya llega a unos 8.3 de media, y con tope 9 la zona 1 queda igual (84 % con 100 victorias), mientras que con tope 8 bajaba al 72 % y con 7 al 62 %. Lo demás ya venía limitado: la tienda solo vende la clase de la zona y en nivel 0, las piezas no pasan del nivel tope de la zona, transformar solo llega a la clase de la zona, el pecho se abre en el nivel 10 del jugador (y la tienda no lo vende antes de la zona 3), las habilidades piden puntos de nivel y las piezas Únicas, núcleos de jefe. tests/unit/test_progress_locks.gd lo comprueba con 100 000 celdas en la zona 1: nada pasa de su tope y ninguna compra se para por falta de celdas.
- **Precios por nivel** (cada mejora por separado): 180, 240, 360, 480, 540, 660, 720, 840, 960 y 1 140 (los de antes × 1.2, porque la arena paga ahora 300 en vez de 250; la tabla de más abajo se midió con los precios y la paga de antes, y el ritmo en combates es el mismo). Están puestos para el ritmo que pidió el usuario: unos 50 combates ganados llevan todo al nivel 6 y unos 100, al nivel 9. Una prueba (tests/unit/test_arena_shop.gd) vigila que se mantenga.

**Medido el 2026-11-17 contra el primer jefe** (tools/sim/shop_route_sim.gd: Capataz del Orden con Superblindaje, todo en clase Básica nivel 6, bonificaciones encendidas, IA difícil en los dos lados, 40 combates por casilla; todas las mejoras al mismo nivel):

| Armería | Celdas | Combates ganados | Físico | Calor | Energía | Híbrido | Media |
|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 2.5 % | 7.5 % | 12.5 % | 0 % | 5.6 % |
| 2 | 2 100 | 9 | 0 % | 12.5 % | 22.5 % | 0 % | 8.8 % |
| 4 | 6 300 | 26 | 0 % | 65 % | 47.5 % | 0 % | 28.1 % |
| 5 | 9 000 | 36 | 20 % | 90 % | 65 % | 2.5 % | 44.4 % |
| 6 | 12 300 | 50 | 22.5 % | 85 % | 65 % | 17.5 % | 47.5 % |
| 7 | 15 900 | 64 | 52.5 % | 95 % | 95 % | 40 % | 70.6 % |
| 8 | 20 100 | 81 | 72.5 % | 100 % | 87.5 % | 65 % | 81.3 % |
| 9 | 24 900 | 100 | 87.5 % | 97.5 % | 90 % | 75 % | 87.5 % |
| 10 | 30 600 | 123 | 100 % | 100 % | 97.5 % | 95 % | 98.1 % |

- **Ir directo es una apuesta:** los 10 combates de la campaña dan para el nivel 2 de la armería, con un 9 % de victorias de media.
- **Con unos 50 combates** se gana casi la mitad de las veces; con el mech adecuado, mucho más.
- **Con unos 100** se gana casi siempre.
- **El mech importa:** el superblindaje se come el daño de las armas físicas, así que el mech de calor (que lo sobrecalienta) y el de energía (cuyo drenaje la coraza no para) son los que mejor lo vencen. El físico necesita casi el doble de mejoras.
- Las mejoras se compran todas a la par en la medición; un jugador que concentre sus celdas en las que le sirven llegará antes.
- **Pendiente:** con estos precios la armería queda casi al máximo tras el primer jefe. Para las zonas siguientes la progresión tendrá que venir de las piezas (tienda de piezas, niveles y transformación, F7), o habrá que abrir niveles de armería por zona.

**La curva de la zona 1 sin mejoras** (tools/sim/campaign_sim.gd, el jugador con la IA difícil, 40 combates por casilla):

| Combate | 1–5 | 6 | 7 | 8 | 9 | 10 | Jefe |
|---|---|---|---|---|---|---|---|
| Victorias de media | 100 % | 98.8 % | 93.8 % | 88.1 % | 58.1 % | 36.3 % | 6.3 % |

- Los primeros combates son de aprendizaje; los dos últimos ya piden pasar por la arena o jugar fino.
- Ganar los 10 seguidos y al jefe sin perder ni uno: 1 % de las veces.


### 9.3 La campaña entera: la armería del Orden
Medido el 2026-11-17 (tools/economy_sweep.ps1). Al pasar de la zona 1, la armería del jugador llega al máximo hacia la zona 4 y, sin nada que la compense, los jefes de la zona 3 en adelante caían con 25 victorias. Ahora **el Orden también tiene su armería**: cada zona fija el nivel de las mejoras de todos sus rivales, jefe incluido (data/campaign.json, `enemy_armory`; el menú lo enseña). Sube zona a zona: 0, 0, 3, 5, 5, 6, 8, 8, 8 y 8. Además se retocaron cinco jefes (data/chassis.json): Égida, Espectro y Colmena algo más débiles, Caldera más resistente y Coloso con resistencias ×1.5.

**El arma de pecho entra en la medición:** con unas 50 victorias por zona el jugador llega al nivel 10 durante la zona 2, compra un cañón pesado en la 3 (la primera que vende armas de pecho, pagándolo con las celdas de la zona) y lo lleva después. Desde el 2026-11-20 pesa, y lo carga el núcleo ampliado (§4): el simulador da por hecho que el jugador lo amplía y lo paga.

Victorias contra el jefe tras gastar N victorias en la zona, empezando con lo que tendría quien pasó la anterior con unas 50 (24 combates por casilla; cada cifra tiene unos ±10 puntos de margen). Medido el 2026-11-18 con el árbol de habilidades (el jugador lleva los puntos de su nivel, repartidos por igual), los jefes entrenados (§8) y el robot de asistencia en los dos lados (§4):

| Zona | Jefe | Orden | Entreno | 25 vict. | 50 vict. | 100 vict. | Mech que mejor lo vence a las 50 |
|---|---|---|---|---|---|---|---|
| 1 | Capataz (superblindaje) | 0 | 8 | 7 % | 46 % | 84 % | calor (92 %) |
| 2 | Verdugo (poder de daño) | 0 | 11 | 59 % | 88 % | 95 % | calor (96 %) |
| 3 | Reactor (energía infinita) | 3 | 14 | 17 % | 88 % | 100 % | híbrido (92 %) |
| 4 | Hidra (regeneración) | 5 | 16 | 30 % | 79 % | 76 % | híbrido (88 %) |
| 5 | Centella (velocidad) | 5 | 18 → 19 | 21 % | 66 % | 77 % | híbrido (88 %) |
| 6 | Égida (escudo) | 6 | 19 | 23 % | 26 % | 29 % | calor (79–88 %) |
| 7 | Espectro (evasión) | 8 | 21 | 60 % | 96 % | 99 % | todos |
| 8 | Caldera (núcleo térmico) | 8 | 22 → 24 | 54 % | 57 % | 68 % | energía e híbrido (88 %) |
| 9 | Colmena (enjambre) | 8 | 24 | 8 % | 63 % | 69 % | físico (88 %) |
| 10 | Coloso (final) | 8 | 25 → 30 | 20 % | 32 % | 34 % | híbrido (50 %) |

- Sin entrenar a los jefes, el árbol solo bastaba para volver fáciles a casi todos: zona 1 al 81 % con 50 victorias, zonas 7 a 10 cerca del 100 % con 10. Con el entrenamiento el ritmo vuelve al de antes del árbol (zona 1: 44 % → 46 % con 50).
- La zona 1 sigue el ritmo del usuario: unas 50 victorias para tener opciones y unas 100 para ganar con facilidad (§9.2).
- De la 2 a la 9, con unas 50 victorias en la zona se gana a menudo, y el mech que ataca el punto débil del jefe gana casi siempre. En las zonas 6, 8 y 9 la media baja porque hay que llevar el mech adecuado: cambiar de armas en el taller es parte de la táctica. La zona 7 quedó fácil (el Espectro cae con 50 victorias con cualquier mech).
- Las zonas que abren clase nueva (3, 5, 7 y 9) piden más victorias: hay que transformar las piezas (y en la 3, comprar el arma de pecho).
- El jefe final es extremadamente difícil, como pidió el usuario: 32 % de media con 50 victorias y 34 % con 100. Repartir los puntos por igual no llega a la materia oscura (nivel 25 en la rama Asalto); quien la persiga la tiene para el Coloso.
- **Los golpes críticos (§2.9) movieron poco el ritmo.** Medido el 2026-11-18, con 50 victorias: 58, 81, 87, 91, 70, 24, 98, 54, 63 y 41 % (antes 46, 88, 88, 79, 66, 26, 96, 57, 63 y 32). Fuera del margen de ±10 puntos solo las zonas 1 y 4 (+12). Con 25 victorias, la zona 3 sube de 17 a 46 %: es donde se compra el cañón pesado, casi seguro de crítico, y en la campaña solo lo lleva el jugador. El usuario decidió dejarla así (2026-11-18).
- **El impacto de los golpes (§2.10) la facilita algo más.** Medido el 2026-11-18, con 50 victorias: 58, 82, 91, 84, 84, 24, 99, 74, 69 y 57 % (solo con críticos: 58, 81, 87, 91, 70, 24, 98, 54, 63 y 41). Suben las zonas 5 (+14), 8 (+20) y 10 (+16): en la campaña solo el jugador lleva arma de pecho y materia oscura, que son las que más empujan, y los jefes de las zonas 5 y 10 llevan anclas, que jalan. El usuario pidió endurecerlas (siguiente punto).
- **Jefes 5, 8 y 10 endurecidos (2026-11-18, pedido del usuario).** Su nivel ya es el tope que la zona permite (es el del jugador en ella), así que la palanca es su entreno: de 18, 22 y 25 puntos a 19, 24 y 30 (data/campaign.json; la tabla de arriba enseña el cambio, pero sus porcentajes son los de antes de los críticos). El entreno no baja de una zona a la siguiente (tests/unit/test_campaign.gd), por eso la zona 5 queda en 19, como la 6 (con 22 bajaba al 63 %, pero por encima de la 6), y la 8 en 24, como la 9 (con 27 bajaba al 41 %). Con 30 el Coloso vuelve a su 32 %; con 36 llega a la materia oscura y no pierde nunca. Con 50 victorias la campaña queda en 58, 82, 91, 84, 70, 24, 99, 51, 69 y 32 %; con 25 y 100 victorias: zona 5, 37 y 96 %; zona 8, 53 y 71 %; zona 10, 32 y 38 %. Todas las zonas quedan a menos de 10 puntos de la campaña con solo críticos que el usuario aceptó (58, 81, 87, 91, 70, 24, 98, 54, 63 y 41).
- **El robot de asistencia no movió el ritmo.** La misma medición sin él (2026-11-17) daba, con 50 victorias: 46, 83, 89, 70, 66, 24, 99, 52, 56 y 21 %. Con él: 46, 88, 88, 79, 66, 26, 96, 57, 63 y 32 %. Todas las diferencias caben en el margen de ±10 puntos salvo la del Coloso (+11), que con 100 victorias queda igual (37 % → 34 %). El jugador sube y transforma su asistente con las celdas de la zona y compra la batería; el Orden lleva el suyo a la clase de la zona.

### 9.4 La escalera tecnológica de las ligas (aprobada, 2026-11-21)

**Lo que pidió el usuario (OBS-011).** Primero: "cada enemigo de cada liga debe ser diferente al anterior" y "los rivales se vuelven con armas más estilizadas, más potentes; o sea, el nivel 10 es básicamente un dios robot". Y al ver el primer rival de prueba: "se ve bien. Nada más que la dirección debe de tener un sentido, no solamente añadir otro color o un arma nueva. Debe de ser una evolución tecnológica, como en ligas… son robots, al final de cuentas van evolucionando hasta llegar a un nivel 10. Puedes tomar como base algún libro, Warhammer, o algún detalle así… que tenga algún sentido".

**La idea que le da sentido.** En el orden de máquinas, **lo más antiguo es lo más avanzado**. La frontera se defiende con lo barato y recién fabricado; cuanto más cerca del Trono, más vieja, más escasa y más venerada es la tecnología, hasta la máquina que fundó el Orden, que sus robots tratan como a un dios. Subir de liga es **remontar la historia de las máquinas**. Y lo que separa una era de la siguiente es una sola cosa: **de dónde sacan la energía**. Con más energía cambian, por este orden, sus armas, su blindaje y por último su forma. Por eso un rival de una liga alta no es el de la liga 1 con otro color: está hecho de otra manera.

**De dónde sale** (ideas, no nombres ni diseños; el límite de no copiar marcas sigue en pie):
- *Warhammer 40.000*: la tecnología como reliquia de una edad dorada perdida, que se venera en vez de entenderse, y las máquinas de guerra más viejas tratadas como dioses.
- *La escala de Kardashov* (1964): medir una civilización por la energía que domina. Aquí, cada liga domina una fuente mayor.
- *Las generaciones de mechas del anime*: primero el armazón y el blindaje, luego las armas de energía, luego la movilidad, luego las unidades remotas.
- *La tercera ley de Clarke*: una tecnología lo bastante avanzada no se distingue de la magia. En las últimas ligas las máquinas dejan de parecer máquinas.

**Los diez escalones.** Encajan con lo que ya existe: los nombres de las zonas, las cuatro familias de armas (balas, cañón, bláster y láser, §6) y la habilidad de cada campeón (§9.1), que pasa a ser **el avance de su era**: el campeón lo tiene entero y sus rivales, la versión de serie.

| Liga | Zona | Era | De dónde saca la energía | Cómo se nota en el robot | Armas | El campeón encarna |
|---|---|---|---|---|---|---|
| 1 | Frontera de Chatarra | **Serie ligera** | Celdas químicas | Armazón fino, juntas y pistones a la vista, placas atornilladas | Balas | Superblindaje: la primera respuesta, poner más chapa |
| 2 | Dunas de Óxido | **Acero pesado** | Motores mayores, la misma química | Blindaje por capas, cúpulas, crestas y hombreras: cuerpo de asedio | Balas de más calibre | Poder de daño: el arma grande |
| 3 | Refinerías de Ceniza | **El horno** | Reactor de fusión | Núcleo que se ve, chimeneas y rejillas al rojo; el cuerpo se construye alrededor del reactor | Cañón | Energía infinita: el primer reactor que no se agota |
| 4 | Anillo Orbital | **El vacío** | Reactor sellado y propulsores | Casco estanco sin juntas abiertas, toberas, antenas; piezas que se reparan solas | Cañón guiado | Regeneración: la máquina que se rehace |
| 5 | Metrópolis Silente | **El sintético** | Fibra motriz en lugar de pistones | Sin tornillos ni placas: cuerpo liso, de una pieza, con músculo artificial | Bláster | Velocidad: tres acciones donde otros hacen dos |
| 6 | Fosas de Plasma | **El campo** | Plasma contenido | Ya no se defiende con chapa sino con campos: emisores, conductos que brillan a través del blindaje | Bláster de plasma | Manto de plasma: el golpe que se gasta en el campo |
| 7 | Nebulosa Espectral | **La luz** | Luz condensada | Piezas que flotan sin unión, paneles traslúcidos, cuerpo a medio hacer de luz | Láser | Evasión: estar y no estar |
| 8 | Forjas del Núcleo | **La estrella** | Un núcleo estelar | Metal vivo que fluye, grietas encendidas, un sol en el pecho | Láser de núcleo | Núcleo térmico: no se sobrecalienta nunca |
| 9 | Bastión de Hierro | **El enjambre** | Energía repartida entre muchos cuerpos | No es un robot sino muchos: módulos y drones que orbitan y se reensamblan, muchos ojos | Láser en red | Enjambre: su dron dispara dos veces |
| 10 | Trono del Orden | **La máquina primera** | Materia oscura | Todas las eras en un solo cuerpo: halo, anillos y alas que flotan, oro y blanco; ya no parece fabricado | Lo que quiera | El Coloso: velocidad y superblindaje a la vez, lo primero y lo mejor |

**Cómo se lee la escalera en tres tramos** (para que el salto se vea aunque no se lea esta tabla):
1. **Ligas 1 a 4, la máquina:** se ve cómo está hecha. Tornillos, pistones, chimeneas, toberas. Gana quien lleva más acero y más motor.
2. **Ligas 5 a 7, la energía:** deja de verse cómo está hecha. Superficies lisas, campos, luz. Gana quien controla la energía.
3. **Ligas 8 a 10, lo sagrado:** deja de parecer una máquina. Metal vivo, muchos cuerpos, y al final un dios.

**Lo que esto ordena de lo que ya hay:**
- El rival de prueba de la liga 2 (cúpula, cresta, hombreras, más chapa) cae en su escalón: acero pesado.
- Las armas ya suben así: balas en las ligas 1 y 2, cañón en la 3 y la 4, bláster en la 5 y la 6, láser de la 7 a la 10. Falta que su dibujo cambie también dentro de cada familia de liga en liga (OBS-007, la evolución del dibujo, pendiente del veredicto de la espada).
- La materia oscura, que hoy es la habilidad final del árbol del jugador, es la energía del Trono: el jugador acaba usando contra el Orden su propia fuente.
- Responde a OBS-019 ("cada arma es una evolución de la anterior"): cada liga es un escalón entero, no solo una clase de pieza.

**Bocetos de un torso por era** (2026-11-21, `docs/reference/art/escalera_ligas.png`). Cada uno se dibujó sobre el maniquí del chasis ligero, como el rival de prueba de la liga 2, para que todos casen con las mismas piernas y armas; solo cambian las etiquetas de diseño de su era (`tools/art/halves_test.py --extra`, una tanda por era). Se ven claros el horno (3: celdas del reactor al rojo), el campo (6: aletas de energía), la luz (7: cristal azul) y la máquina primera (10: halo, oro y alas). El vacío (4), el sintético (5) y el enjambre (9) salieron al principio casi iguales a la liga 1 y se repitieron con etiquetas más visuales y tres semillas: quedan el traje con tanques a la espalda (4), la carcasa blanca con fibra muscular a la vista (5) y el racimo de ojos y cápsulas (9). La estrella (8) se lee, pero sucia. Son bocetos del torso: ni piernas ni armas de su era, ni recortados para el juego.

**Decidido por el usuario (2026-11-21).** Al ver los bocetos: "se ve bien": la escalera y los nombres de las eras quedan como están. Y sobre su robot: "Mi robot conserva su estilo, salvo las armas especiales de cada jefe: esas sí las puedo comprar, pero por un alto coste." Su robot no recorre la escalera; cada campeón tiene **su arma especial**, con el aspecto de su era, que el jugador puede comprar muy cara. Lo interpretado (pendiente de que lo confirme): es el arma de pecho (la "especial", de un disparo por combate, como la llamó en OBS-033) y se compra **después de vencerlo**, por 10 veces el precio de su tipo (`data/part_shop.json`, `boss_weapon_mult`). **Que el campeón la use contra el jugador está en espera:** con ella, el Tirador del usuario pasaba del 93 al 43 % contra el campeón de la liga 5 (`tools/sim/save_fight_sim.gd`, IA difícil, 40 combates); hay que compensarlo antes de ponérsela.

**Orden de trabajo:** primero el campeón de la liga 5 (Centella del Orden, la era del sintético), que es el siguiente jefe del usuario: su cuerpo propio y su arma especial. Con su visto bueno, los rivales de esa liga y el resto de campeones, liga a liga. El arte se genera con el juego cerrado.

## 10. Pantallas
Menú · Taller (armado con resumen de stats, barra de peso y avisos) · Inventario y fusión · Taller de mejoras · Mapa de campaña · Combate (la arena a pantalla entera; ver más abajo) · Resultados y botín · Ajustes.

**Regla (2026-11-18 y 2026-11-20, del usuario):** todo eso vive dentro de un solo hangar y debe sentirse "casi como si no existiera un menú": lo que se puede hacer es un objeto de la escena (el robot, una bahía, una pantalla de la pared, una proyección) y no un botón ni una lista aparte. El mapa de campaña es el monitor de misiones del hangar y su fila de rivales proyectada delante de tu robot; se sale a combatir pulsando al rival. El inventario y la tienda son la computadora del taller (abajo; hasta el 2026-11-21 eran un tablero de piezas que colgaba junto al robot) y las piezas se ven dibujadas, no en una lista; las mejoras y las habilidades se usan en su propia pantalla de la pared, que crece al pulsarla (docs/PLAN.md, F8).

**El taller: una computadora (del usuario, 2026-11-21, OBS-030).** "Este menú de armas se hace más inmersivo": elegir la pieza en el propio robot "ya no va a estar. En vez de esto, va a haber como una especie de pantalla de computadora donde se va a mostrar un gráfico… de robot de frente. En cada espacio donde va un arma, tú vas a poder seleccionar la casilla y, de acuerdo al nivel que tengas, se te va a desplegar a un lado de esa pantalla las armas disponibles, por tipo… ya nos deshacemos de todos esos menús que nada tienen que ver en el garaje". La pantalla TALLER de la pared (`scenes/hangar/loadout_screen.gd`, LoadoutScreen) crece al pulsarla, o al pulsar tu robot, y ocupa casi toda la pantalla:
- **A la izquierda, el plano:** tu robot, como una proyección, con su dibujo de perfil, el mismo del hangar y del combate (`scenes/hangar/mech_blueprint.gd`). Hasta el 2026-11-21 salía de frente, con el giro en 3D del hangar; el usuario canceló ese giro ("aquí no funciona", OBS-036) y de frente "se veía todo mal": las armas no tienen dibujo de frente. Alrededor, una casilla por hueco, unida con una línea a su pieza: las armas, el arma de hombro y el pecho del lado al que mira el robot, el asistente detrás, el torso arriba, las piernas abajo, y al pie los especiales, los drones y los módulos.
- **A la derecha, el catálogo de la casilla elegida** (`scenes/hangar/parts_rack.gd`, ahora dentro de la pantalla): las piezas que caben ahí, **agrupadas por tipo** con su rótulo (hojas, cortas, medias, largas y saboteadores en los brazos; físico, calor y energía en el cuerpo y los módulos…). Las tuyas, sólidas, con su clase y nivel; las que vende la tienda en tu liga, como hologramas con su precio (en rojo si no te alcanza). Solo salen las que tu tipo de robot monta. Una tuya se pulsa para montarla y la que llevas se pulsa para quitarla; un holograma se compra con dos pulsaciones. Debajo, la ficha de la pieza bajo el ratón, con lo que cambiaría en el robot, la tecla de subirla de nivel o transformarla y la lectura del robot. Una casilla cerrada dice desde qué nivel se abre.
- **Como al examinar un objeto en Resident Evil (2026-11-21, OBS-039):** "esta parte del menú de la tienda me gustaría que fuera más inmersivo… como Resident Evil". Al acercarla, la sala se queda a oscuras detrás y la pantalla se enciende como un monitor viejo (`LoadoutScreen`, `POWER_SECONDS`). El catálogo es un **maletín de espuma**: un hueco recortado por pieza; las tuyas, sólidas (la que examinas se levanta un poco); las de la tienda, proyectadas en su hueco con su precio. Encima, la **vitrina** (`ui/part_showcase.gd`, PartShowcase): la pieza bajo el ratón (o la del hueco) en grande sobre un pedestal a oscuras, bajo un foco con polvo, con sombra, reflejo y un brillo que la recorre; a su lado, su **ficha**: una barra por dato (daño, alcance como regla de casillas, lo que quita al rival, usos, energía y calor que gasta, peso; en el cuerpo, vida, energía, calor y resistencias), con la escala de la mayor de la lista y comparada con la montada: verde lo que gana, rojo lo que pierde, con flechas. La tecla de subir o transformar va al pie de la ficha. Entre la vitrina y el maletín, una línea de terminal escribe letra a letra qué hace pulsar la pieza. La cabecera dice qué cabe en el hueco ("Armas de corto y medio alcance" en los brazos, "Armas de largo alcance" en el hombro, "Un disparo por combate" en el pecho; `WorkshopBrief.slot_kind`). Es un piloto: falta el veredicto del usuario antes de llevar el mismo tono al plano del robot.
- **Lo que se quitó del hangar:** el tablero que colgaba de un riel, el banco de equipo con sus cunas, los enchufes sobre el robot, elegir una pieza tocándola en el robot y arrastrar piezas. La pantalla "TIENDA" de la pared es ahora "TALLER": la tienda va dentro del catálogo. El robot del hangar ya no se gira (OBS-036) y, al pulsarlo, abre la computadora.
- **Probar un arma** sigue siendo en la diana, con la computadora recogida: prueba el arma de la última casilla tocada.
- **Cerrar:** la tecla de la esquina, Esc o pulsar fuera.
- **Qué decide lo que sale en el catálogo:** hoy, la liga (la tienda vende la clase de tu liga) y el tipo de tu robot; el nivel del jugador abre las casillas (asistente en el 5, pecho en el 10). Lo arma `WorkshopBrief.loadout` (las casillas con `slots`, el catálogo con `rack`); la pantalla no decide nada, solo avisa de lo que se pulsa.

**El combate: "toda la pantalla es el juego" (del usuario, 2026-11-20, OBS-015 a OBS-018).** La arena ocupa la pantalla entera y encima no hay barras, botones, registro ni avisos (`ui/battle/battle_hud.gd`, BattleHud):
- **Las armas van en el propio robot.** Al pasar el ratón por tu robot (o al tocarlo, que en táctil no hay ratón que pase) se despliegan en abanico sobre él, cada una con su icono: primero las armas y, tras un hueco, el pisotón, los especiales, las habilidades y enfriar. **Encendida la que se puede usar ahora y en gris la que no**; las de usos contados llevan sus puntos debajo. Al pasar por una sale su tarjeta, en pequeño: el daño que hará de verdad contra ese rival, su crítico y lo que hace, alcance y costes, si te sobrecalienta y, si está en gris, por qué. Pulsarla la usa. Cerca de un borde el abanico se corre hacia dentro para verse entero.
- **Vida, calor y energía:** tres rayitas translúcidas sobre cada robot, sin números (la vida pasa de verde a dorado y a rojo; el calor parpadea cuando pasa del tope), y dos rombos con las acciones que le quedan a quien le toca. Las del jugador se avivan al abrir el abanico.
- **Cero notificaciones:** se quitaron el registro del combate, la previsión, las pistas ("haz clic en una casilla…", "pensando…") y los paneles de arriba. Quedan solo los números que saltan del golpe: el daño, el crítico y lo que hace, el calor, lo que se repara.
- **El turno no está fijo en pantalla:** un rótulo cruza la pantalla un instante cuando cambia ("TU TURNO", "TURNO DEL RIVAL"), y otro al empezar ("¡COMBATE!", con el nombre del rival), "como en Tekken, que dice *fight*".
- Moverse sigue siendo pulsar una casilla del suelo (las alcanzables se iluminan); el ratón solo es del abanico sobre el robot y sus iconos (`BattleHud._has_point`), y lo demás es de la arena. La pausa (Esc) y el cuadro del resultado no cambian.
- **La baliza de salto ve la arena entera** (del usuario, 2026-11-21, OBS-035: "Hay una desventaja a mi lado. Por ejemplo, cuando sale una [bonificación] en combate y está el rival cerca, yo no tengo forma de transportarme hasta el lugar si está lejos, pero el rival sí puede. Hagamos iguales las cosas. En cuanto yo le dé en baliza de salto, el mapa se agranda para tener todo el alcance como el rival."): mientras se tiene en la mano, la cámara se aleja hasta que cabe todo el campo (`ArenaView.overview`) y se puede saltar a cualquier casilla, como la IA. Al saltar o soltarla, vuelve a seguir a los robots.
- **El arma de pecho se despliega cada vez que se usa** (OBS-025: "una animación especial en el despliegue, cada vez que se use"): la compuerta se abre con su sonido, un destello del color de su munición y un temblor, dispara y se vuelve a guardar (`MechView.deploy/stow`, `ArenaView.fire_between`). Su daño ya subía con su nivel, su clase y las mejoras, como cualquier arma.

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
| Estados | Brillo de calor creciente; vapor al enfriar; apagado (luces fuera, postura caída y humo); sin energía (parpadeo y arcos); daños visibles con poca vida. **Hecho el 2026-11-18** (pedido del usuario; scenes/battle/mech_wear.gd): con la vida por debajo del 75 % salen arañazos, del 50 % hollín y humo gris, y del 25 % humo negro, chispas y llamas; con la energía por debajo del 25 % saltan arcos eléctricos y las luces fallan. Los críticos también se ven: chispas en las piernas si está inmovilizado, el arma inutilizada apagada y echando humo, y arcos si está sobrecargado. Para revisarlo: `tools/clip.ps1 -Wear` |
| Final | Explosión y piezas que saltan al ser destruido; pose de victoria |
| Interfaz | Números flotantes, barras que se mueven con suavidad, cartel de turno, respuesta de los botones y transiciones entre pantallas |

**Movimiento, hecho el 2026-11-17** (pedido del usuario: andar, volar, levitar y retroceder como en el original). Las piernas, que el arte dibuja de una pieza y de lado, llevan un esqueleto 2D (scenes/battle/leg_rig.gd): muslo, espinilla y pie giran sobre cadera, rodilla y tobillo, y el dibujo se dobla como una malla sin cortes. Se dibuja una segunda pierna más oscura detrás, en fase opuesta. El pie de apoyo se queda en el suelo.
- **Andar:** zancada con las dos piernas, polvo en cada paso; hacia atrás anda de espaldas mirando al rival y se echa hacia atrás.
- **Volar:** las piernas que saltan se agachan, despegan con propulsores en los pies, recogen las piernas en el arco y aterrizan flexionando; también de espaldas.
- **Levitar** (piernas con la etiqueta `levita`): flotan con un brillo debajo y se deslizan inclinándose. **Rodar** (`orugas` o `ruedas`): se deslizan sin pasos, con una vibración leve.
- **Empujones y jalones:** el rival resbala sin girarse, con las piernas clavadas y el cuerpo echado hacia el golpe. **Retroceso al disparar** (armas que retroceden): salto corto hacia atrás con propulsores.
- **Embestida:** propulsores y cuerpo echado hacia delante.
- Para revisarlas: `tools/clip.ps1 -Showcase` (muestra en la arena) y `tools/clip.ps1 -Cycle` (ciclos de cerca); `tools/rig_frames.gd` saca una hoja de poses y `tools/weapon_frames.gd` una de armas montadas.
- Falta: arte propio para orugas, ruedas y piernas que levitan (hoy usan los dibujos de piernas que andan) y que las armas tengan dibujo propio.

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

Cada arma del catálogo lleva un campo `fx` con su disparo (hecho el 2026-11-18; la ficha de cada una está en docs/CATALOGO_ARMAS.md, sección 9). `data/shots.json` define los 35 disparos y el de la materia oscura: camino (recto, parábola, curva de misil, haz instantáneo, rayo desde el cielo, cable, onda, tajo), cuerpo, número de proyectiles, velocidad e impacto (chispas, explosión, salpicadura de plasma, quemadura o absorción). `scenes/battle/shot_fx.gd` los dibuja; las luces van del color de la munición. Falta el sonido de cada uno y que el disparo crezca con las etapas del arma.

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
- **Origen:** bibliotecas de dominio público (CC0) para empezar, con cada archivo anotado en `assets/audio/CREDITOS.md` junto a su licencia. No se usa ningún sonido ni música del juego original.
- **Técnica:** buses separados para música, efectos e interfaz con su volumen en ajustes, y una pequeña variación de tono en los efectos repetidos para que no cansen.

**Hecho el 2026-11-18 (pedido del usuario).** 75 archivos en `assets/audio/` (13 MB):
- **Fuentes**, todas CC0 y bajadas de OpenGameArt (Kenney no deja descargar de forma automática desde su web, y se usan las copias que él mismo subió): *Sci-fi Sounds*, *Interface Sounds* y *63 Digital sound effects* de Kenney; *100 CC0 SFX* de rubberduck (solo los golpes de metal); *Dark Sci-Fi Audio Pack* de SRG774 (música de la base y jingle de victoria); *Space Battle* de MintoDog (combate) y *Friendly Talk On a Robotic Battlefield* de illin (jefes). Los disparos de bala se sintetizan en `tools/audio/curate.py` (ruido filtrado, cuerpo grave y cola): ningún paquete tenía uno creíble.
- **Cómo se eligió sin oírlo:** `tools/audio/curate.py` mide cada candidato (duración, nivel, ataque, brillo) y se escogió por esos datos y por su nombre. Después recorta las colas, iguala el nivel (RMS de la parte que suena; -18 dB los efectos y -22 la interfaz) sin pasar de -1 dB de pico, y escribe `assets/audio/CREDITOS.md`.
- **Qué suena** (`data/sounds.json`, que se puede cambiar sin tocar código): cada uno de los 35 disparos y los de la materia oscura al salir, su impacto al llegar (chispas, explosión, plasma, quemadura, drenaje u onda), el impacto medio, grave y último según el arma (§2.10), pasos, propulsores, salto, garfio, embestida, pisotón, enfriar, apagado, crítico, escudo, reparación, esquiva, la nave y su bonificación, destrucción, el despliegue y la carga de la materia oscura (que sube de tono), y en la interfaz: clic en todos los botones, tic en los deslizadores, abrir y cerrar paneles, comprar, subir de nivel, transformar y aprender una habilidad. Música: base, combate y jefe, en bucle con fundido entre ellas, y jingles de victoria y derrota.
- **Técnica:** `scenes/audio/sfx.gd` con 24 voces; un mismo sonido no se repite en 30 ms (los perdigones que salen a la vez suenan una vez); la carga oscura sube de tono; un limitador a -1 dB en el canal general.
- **Comprobado:** tests/unit/test_sounds.gd (cada archivo existe, cada disparo y cada clase de impacto tienen sonido, y cada sonido que pide el código existe; lo comprueba leyendo el código). En vivo se grabó el canal general en dos combates (`--record-audio`): 88 y 45 sonidos; con la música 6 dB por debajo de la primera versión y el limitador, el pico queda en -1 dBFS sin muestras saturadas, y 76 de 88 y 35 de 45 sonidos suben el nivel al menos 1.5 dB en el instante en que el juego los pide (los demás coinciden con otro sonido más fuerte).
- **Falta:** el ambiente de cada escenario, una música propia del taller, la alarma de sobrecalentamiento y el aviso de energía agotada, y sonidos distintos para ruedas y orugas. Y que el usuario lo escuche: los datos no dicen si algo suena bien.

**Piloto de efectos diseñados por capas (2026-11-20, OBS-029).** El usuario, al jugarlo: "los efectos de sonido, la espada, los disparos, son muy sencillos". Eran recortes de un solo archivo, en mono. El piloto rehace lo que más se oye en la liga 1 (`tools/audio/design.py`, todo sintetizado ahí con semilla fija, sin archivos de fuera):
- **Cada efecto son varias capas con su papel**, como las montaría un diseñador de sonido. Un disparo de bala: el chasquido del aire, el cuerpo de la explosión, el golpe grave, el cañón que resuena, el mecanismo (cerrojo, corredera) y la cola. El tajo de la hoja vibratoria: el silbido del aire, cuyo tono sube y baja con el arco; el motor que la hace vibrar; el filo que canta y el chasquido en el punto más rápido. Un golpe contra el blindaje: el corte o el golpe seco, la chapa que suena, el desgarro, las chispas y, en una de cada tres balas, el silbido del rebote.
- **Estéreo y con sala:** las capas se saturan juntas, se abren en estéreo (el tajo cruza de un lado a otro) y pasan por la reverberación de un hangar. Se nivelan por su tramo más fuerte (RMS en 50 ms a −13 dB, pico máximo −1 dB), sin comprimir: probado, y el compresor dejaba el golpe inicial en un zumbido plano.
- **Qué cambió:** la ametralladora (cuatro variantes cortas y secas, para nueve balas seguidas), el rifle (un tiro largo con su eco y el cerrojo después), la escopeta (más grave, con la corredera al final), el tajo (tres variantes), el golpe de la hoja en el blindaje (nuevo, tres variantes: antes sonaban las chispas genéricas) y las balas contra el blindaje (tres).
- **El tajo va con la animación:** antes el silbido y el golpe sonaban a 0.08 s uno del otro, al empezar el movimiento. Ahora el silbido empieza cuando la hoja se levanta (`ArenaView.strike`, `MechStage._test_strike`) y el corte y su golpe llegan cuando cae, 0.3 s después; el daño también aparece entonces.
- **Cómo se comprobó sin oírlo:** `design.py --sheet` dibuja la envolvente en dB y el espectrograma de cada sonido (así se vieron y se corrigieron dos fallos: una nivelación que aplastaba el golpe y capas que se cortaban en seco), y se grabó un combate (`--record-audio`): 88 sonidos, pico de 0.89 sin muestras saturadas, y el silbido y el golpe de la hoja separados 0.29–0.32 s en los cinco tajos. **Lo que no dice ninguna medida es si suenan bien:** falta que el usuario los oiga antes de rehacer así los cañones, el plasma, los láseres y lo demás.

**Música (OBS-028), sin empezar:** el usuario pide que esté "al nivel de lo que estamos haciendo". Las tres pistas de ahora son de paquetes CC0. La propuesta es generarla en su GPU con ACE-Step 1.5 (licencia MIT, corre con menos de 6 GB), una por sitio (hangar, combate, campeón) y luego por liga; hace falta instalarlo, y eso está pendiente de su visto bueno.

### 12.4 Cómo se comprueba
- **Cobertura:** un test recorre los tipos de evento del motor y los tipos de `fx` del catálogo y falla si alguno no tiene animación o sonido asignado.
- **Vista:** la prueba en vivo guarda capturas de cada tipo de acción en cada escenario, y se revisan.
- **Oído:** no se puede verificar de forma automática que un sonido suena bien. El test comprueba que el archivo existe y se lanza; el usuario valida el resultado escuchándolo.
