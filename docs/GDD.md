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
- **Huecos:** torso, piernas, 4 armas laterales, 2 superiores, 1 arma de pecho, 1 dron (robot de soporte), 8 módulos y un hueco por especial (carga, teletransporte y gancho). El arma de pecho va **aparte** de las seis armas del original (decisión del usuario, 2026-11-17) y **no cuenta para el límite de peso**: va en un hueco reforzado que se abre en el nivel 10. Medido: si contara, había que quitar uno o dos módulos para montarla y el mech salía peor que sin ella (zonas 3 a 8, del 72–81 % al 7–38 % contra el jefe con 50 victorias).
- **Robot de asistencia** (pedido del usuario, 2026-11-17; sustituye al dron de soporte y se abre igual, en el nivel 3 del jugador). Diseño:
  - **Un solo asistente por partida, con clase y nivel en el Taller.** Se transforma **5 veces** siguiendo la escalera de clases de las piezas, con el mismo tope de zona: Sonda (Básica), Vigía (Intermedia), Centinela (Avanzada), Custodio (Legendaria), Guardián (Mítica) y Arconte (Única, con un núcleo único). Cada forma tiene su dibujo, más grande y con más piezas.
  - **Dos armas, superior e inferior** (huecos `drone` y `drone_low`, con las armas de dron del catálogo). **Dispara una sola por turno y las alterna**; si a la que le toca no puede (alcance, usos o energía), dispara la otra. La segunda arma da versatilidad (otro alcance, otro efecto), no más disparos. La inferior pelea desde la primera transformación (`RulesConfig.assist_second_weapon_tier`); antes se puede montar, pero no pelea, como los huecos que abre el nivel del jugador.
  - **Ataque:** sus armas suben con él, a su clase y su nivel, sin salirse del rango de clases de su tipo. Por eso cada transformación sube el ataque, y un arma de tipo viejo se queda en su clase máxima y conviene cambiarla en la tienda.
  - **Energía propia: la batería**, que alimenta sus armas. La mejora **Batería del asistente** de la armería (se abre con la primera transformación) sube el daño de sus disparos hasta +10 %; solo el daño, no el drenaje ni el calor que causan. Es poco a propósito: con +15 % el físico ya pasaba del 55 % en láser.
  - **Sus armas siguen pagando energía y calor al mech**, como el dron de siempre. Así, quedarse sin energía o apagado por calor también calla al asistente.
  - **Defensa y bonificación al mech:** el protocolo, que se cambia gratis entre cuatro cuerpos: **Escolta** (resistencias), **Blindaje** (vida), **Reactor** (energía) y **Criogenia** (calor). Cada uno vale lo que 10 kg de módulos (un cuarto de módulo) y crece con la clase y el nivel del asistente, así que cada transformación sube también la defensa. No valen lo mismo contra todos, y esa es su gracia: Reactor contra rivales de energía y Criogenia contra los de calor rinden mucho más que los otros dos, que sirven siempre.
  - **Peso:** el arma superior pesa como siempre pesó el dron; el cuerpo y el arma inferior no cuentan para el límite (es un hueco nuevo, como el del arma de pecho: si contara habría que quitar piezas para montarla).
  - **Estable en combate, medido** (2026-11-17, tools/sim/balance_sim.gd `--assist`, tipo láser; antes del asistente: físico 49 %, calor 50 %, energía 51 %, híbrido 48 %). El balance entre elementos es muy sensible, y se descartaron tres versiones:
    1. *La batería paga los disparos y hay dos por turno:* físico 93 %, energía 14 %. El drenaje y el calor dejaban de afectar al asistente.
    2. *Dos disparos, limitados por la batería:* energía 62–68 %. Cada disparo de más acumula drenaje.
    3. *Un disparo, y la batería paga uno de cada cuatro:* energía 34 %, y 21 % con más batería.
    Regla que queda: el asistente no puede cambiar **cuántas veces** dispara ni **quién paga**. Tampoco puede haber un protocolo distinto por elemento en los mechs del Orden (físico 76 %, energía 28 %): todos llevan Blindaje, y de arma inferior una gemela de la superior, así que el asistente suma lo mismo a los dos lados. Blindaje se eligió midiendo: con Reactor o Criogenia en todos el balance se rompe (energía 25 %; físico e híbrido 63 %), Escolta es el más neutro sin batería, y Blindaje favorece un poco al calor justo en sentido contrario a la batería, que favorece al físico, así que aguanta todo el recorrido de la mejora. Las armas solo se recortan al rango de clases de su tipo en el asistente del jugador; los rivales llevan todo a la clase de su zona. Resultados en docs/CATALOGO_ARMAS.md.
  - En el código: piezas `ASSIST` de data/catalog.json (tools/catalog_gen.py), progreso común en `PlayerProfile.parts["asistente"]`, `BattleEngine._fire_assist`, `BattleMech.assist_power` y tests/unit/test_assist.gd.
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
**Actualizado el 2026-11-17:** las armas laterales, superiores y los drones se sustituyeron por las 96 armas generadas del catálogo de armas (docs/CATALOGO_ARMAS.md): 17 diseños de brazo, 9 de hombro y 6 robots de soporte, cada uno en tres municiones, con su tipo (balas, cañón, bláster o láser) y su rango de clases. Las tablas de abajo describen el catálogo anterior, del que salen los números de cada forma (tools/weapon_bases.json). Torsos, piernas, módulos y especiales siguen igual y existen de Básica a Mítica.

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
- **Árbol de habilidades** (decisiones del usuario, 2026-11-17; data/skills.json, core/skill_tree.gd). Cada nivel del jugador da 1 punto (29 en el nivel 30), como los puntos por nivel de Swords and Sandals. Hay **tres ramas libres**, de 12 habilidades cada una, que se aprenden en orden; no se llega a todo, así que el jugador elige su estilo:
  - **Asalto:** +3 % de daño (seis veces), daño del arma de pecho (+15, +15 y +20 %), +1 uso del pecho (dos veces) y, al final, la **materia oscura**.
  - **Blindaje:** +3 % de vida (cinco veces), +5 % de resistencias (cinco veces) y el **escudo de energía** (1 por combate en la sexta, 2 en la décima): absorbe el siguiente golpe, sea del turno que sea. Cubre el hueco de escudo del original.
  - **Sistemas:** +4 % de energía y de calor (seis veces cada una) y el **kit de reparación** (de la versión de 2013): devuelve el 20 % de la vida máxima, 30 % con Nanorreparación, y llega a 2 por combate.
  - El escudo y la reparación gastan una acción. La IA sabe usarlos: valora un escudo activo por lo que absorberá y guarda el kit hasta que haga falta.
  - **Los jefes del Orden también entrenan** (2026-11-17): medido con la campaña entera, el árbol solo volvía fácil a todos los jefes (zona 1 al 81 % con 50 victorias; zonas 7 a 10 cerca del 100 % con 10). Cada jefe lleva los puntos que tendría el jugador al llegar a él con unas 50 victorias por zona, repartidos por igual entre las tres ramas (data/campaign.json, `boss.skills`; el menú lo enseña). Nunca llegan a la materia oscura: es del jugador. Así el ritmo de la campaña no cambia, y especializarse en una rama, farmear más o llegar a la materia oscura es lo que da ventaja.
- **Materia oscura:** el disparo más poderoso del juego; prácticamente aniquila al enemigo. Es la última habilidad de la rama Asalto y se abre en el **nivel 25**. Reglas decididas por el usuario: una vez por combate, con el arma de pecho ya desplegada (que haya disparado en ese combate) y el rival a su alcance; quita el **60 % de la vida máxima del rival**, ignora resistencias y escudos y gasta toda la energía.
- **Huecos y nivel del jugador:** seis armas como en el original (4 laterales y 2 superiores), más el arma de pecho y el robot de soporte. El nivel del jugador sube con la experiencia de los combates (data/progression.json: 100 por victoria, 25 por derrota, 500 por jefe; nivel 3 tras unas 3 victorias, nivel 10 tras unas 75, máximo 30). El robot de soporte se abre en el nivel 3 y el arma de pecho en el 10, como fijó el usuario; las seis armas están abiertas desde el principio. Las piezas de un hueco cerrado se pueden tener y montar, pero no pelean hasta que se abre.
- **Por confirmar con el usuario:** si una pieza puede subir de clase (hoy sí, con la transformación de más abajo, hasta Mítica) o si su clase es fija, y si las clases y las etapas valen igual para torsos, piernas y drones (hoy sí) o solo para armas.
- **Poder y fusión:** el nivel sube con "poder", que se gana fusionando piezas sobrantes (su poder depende de su tier) o núcleos.
- **Transformación:** al llegar al nivel máximo de su clase, la pieza puede transformarse a la siguiente pagando celdas, si la zona ya llega a esa clase. Vuelve al nivel 0 de la nueva clase. A Única solo con un núcleo único (§9.3).
- **Monedas:** **celdas de plasma** (salen de los combates) y **núcleos únicos** (los sueltan los jefes 8, 9 y 10, §9). Los núcleos del botín y de desarmar piezas repetidas siguen por diseñar. No hay moneda de pago. El usuario pidió el 2026-11-17 que la moneda no fuera "oro" ni "monedas", que no pegan con un juego de robots; "celdas de plasma" es la propuesta: los robots funcionan con energía y se la quitan al rival vencido. En el código y en el guardado se sigue llamando `gold`; el nombre visible vive en la tabla de textos, así que cambiarlo es una línea. Donde este documento diga oro, léase celdas.
- **Botín:** cada victoria da oro y una tirada de botín, con mejores tablas en los capítulos avanzados. Hay cajas que se ganan jugando, nunca con dinero.
- **Tienda del taller** (recuerdo del usuario, 2026-11-16: en el juego antiguo había un taller donde comprabas piezas e ibas armando tu robot o tus robots). Vende por oro las piezas básicas de cada capítulo, con un surtido que cambia al avanzar; lo raro sigue saliendo del botín.
- **Garaje:** se pueden guardar varios mechs armados y elegir con cuál pelear.
- **Armería** (el equivalente de la tienda de arena del original): puntos de mejora permanentes comprados con celdas. Daño, energía y calor hasta +20 %; resistencias hasta +40 %; vida hasta +15 %; backfire hasta −20 % (§9.2).
- **Objetivo de ritmo:** llevar un build completo a Divino debe costar unas 8–12 horas de juego. Se mide con el simulador en la fase F7.

## 9. Campaña
**Visión (del usuario, 2026-11-16):** recuperar la versión antigua de Super Mechs para un jugador. Empiezas con un robot sencillo y avanzas combate a combate hasta un jefe superior al que solo se vence con táctica. Aquella versión era una demo que no pasaba de los primeros 10 combates; aquí va completa. La meta es unir la originalidad y el detalle del juego antiguo con las mecánicas de combate modernas. No hay multijugador.

- **Estructura de la partida** (usuario, 2026-11-17; modelo: Swords and Sandals, docs/reference/original-mechanics.md). El jugador tiene una base con tres sitios:
  - **Campaña:** los combates de la zona, en orden, y su jefe. Cada victoria avanza al siguiente.
  - **Arena:** combates sueltos, repetibles, para juntar celdas. No avanzan la campaña. El rival es un mech al azar con el poder más parecido al de las piezas del jugador, sin pasar de la clase de la zona: la arena siempre va a su medida.
  - **Armería:** donde las celdas se cambian por mejoras, en dos pestañas: **Mejoras** (las seis permanentes, §9.2) y **Piezas** (cada arma y cada pieza de blindaje del mech sube de nivel por separado y se transforma de clase, §9.3).
- **Cada zona son 10 combates y un jefe.** Se puede ir directo, los 10 combates seguidos y el jefe, o pasar antes por la arena.
- **Perder contra un jefe termina la partida** y se empieza de cero: se pierden las celdas, las mejoras y el avance; solo queda el historial (partidas perdidas y mejor marca). El juego avisa antes de entrar al combate. Perder un combate normal o uno de arena no cuesta nada: se puede repetir. **Rendirse** (desde la pausa, con Esc) cuenta como perder: contra un jefe también termina la partida, y la pausa lo avisa antes de confirmar (2026-11-18). La regla está en data/campaign.json (`on_boss_loss`: `new_game` o `retry`).
- **Ritmo que pidió el usuario:** unos 50 combates ganados para tener opciones reales contra el primer jefe, y unos 100 para ganarle con facilidad. Ir directo debe ser una apuesta difícil, de táctica.
- El jugador empieza con todas las piezas de su mech en clase Básica nivel 0 y las va mejorando con lo que gana.
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

### 9.1 Los jefes
**Reglas que fijó el usuario:**
- Vencer a un jefe debe ser extremadamente difícil, **no por la cantidad de vida**; usando las bonificaciones y los ataques con táctica, en teoría se puede ganar. La otra vía es reunir celdas en la arena para comprar mejoras (2026-11-16).
- **Cada jefe tiene su diseño propio y una habilidad especial:** una ventaja que el jugador no puede conseguir en la zona en la que está. Sus ejemplos: superblindaje, energía infinita, velocidad y poder de daño (2026-11-17).

**Cómo se hace:** la habilidad es el chasis del jefe (data/chassis.json: `ability`, `ability_text` y los números que cambia). Todos los jefes tienen la vida de un mech normal de su clase. El menú enseña la habilidad antes del combate. Cada habilidad deja un punto débil, que es la vía táctica.

**Los 10 jefes** (lista aprobada por el usuario el 2026-11-17, "de momento"). Los tres últimos sueltan las piezas Únicas.

| Zona | Jefe | Habilidad | Qué hace | Punto débil |
|---|---|---|---|---|
| 1 | Capataz del Orden | Superblindaje | Sus resistencias valen el doble | Se enfría un 30 % peor |
| 2 | Verdugo del Orden | Poder de daño | Sus armas pegan un 30 % más | Resistencias al 60 % |
| 3 | Reactor del Orden | Energía infinita | Sus armas no gastan energía y no se le puede drenar (ni romper su energía) | Se enfría un 15 % peor |
| 4 | Hidra del Orden | Regeneración | Repara el 5 % de su vida al empezar cada turno | Daño concentrado en pocos turnos |
| 5 | Centella del Orden | Velocidad | 3 acciones por turno en vez de 2 | Se enfría un 30 % peor |
| 6 | Égida del Orden | Escudo | Anula el primer golpe de cada turno del jugador | Armas de varios disparos y dron; resistencias al 60 %; se enfría peor |
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
- **Recompensas** (celdas de plasma): 250 por ganar en la arena o en la campaña, 60 por perder, 2500 por vencer a un jefe. Perder contra el jefe no paga: termina la partida (§9).
- **Precios por nivel** (cada mejora por separado): 150, 200, 300, 400, 450, 550, 600, 700, 800 y 950. Están puestos para el ritmo que pidió el usuario: unos 50 combates ganados llevan todo al nivel 6 y unos 100, al nivel 9. Una prueba (tests/unit/test_arena_shop.gd) vigila que se mantenga.

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

**El arma de pecho entra en la medición:** con unas 50 victorias por zona el jugador llega al nivel 10 durante la zona 2, compra un cañón pesado en la 3 (la primera que vende armas de pecho, pagándolo con las celdas de la zona) y lo lleva después. No cuenta para el límite de peso (§4).

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
- **Origen:** bibliotecas de dominio público (CC0) para empezar, con cada archivo anotado en `assets/audio/CREDITS.md` junto a su licencia. No se usa ningún sonido ni música del juego original.
- **Técnica:** buses separados para música, efectos e interfaz con su volumen en ajustes, y una pequeña variación de tono en los efectos repetidos para que no cansen.

### 12.4 Cómo se comprueba
- **Cobertura:** un test recorre los tipos de evento del motor y los tipos de `fx` del catálogo y falla si alguno no tiene animación o sonido asignado.
- **Vista:** la prueba en vivo guarda capturas de cada tipo de acción en cada escenario, y se revisan.
- **Oído:** no se puede verificar de forma automática que un sonido suena bien. El test comprueba que el archivo existe y se lanza; el usuario valida el resultado escuchándolo.
