# Catálogo de armas: propuesta

**Estado:** propuesta del 2026-11-16, pendiente de que el usuario la apruebe. Hasta entonces el juego sigue con el catálogo anterior (`data/catalog.json`) y con sus huecos anteriores (4 laterales y 2 superiores).

Parte de lo que pidió el usuario: armas galácticas, que se despliegan desde el cuerpo del robot, repartidas por el sitio donde van montadas, con un arma pesada en el pecho y un robot de soporte.

## 1. Dónde van las armas

| Hueco | Cuántas | Qué lleva | Se desbloquea en |
|---|---|---|---|
| Brazo derecho | 1 | Arma de brazo | Nivel 1 |
| Robot de soporte | 1 | Robot acompañante con su arma | **Nivel 3** |
| Brazo izquierdo | 1 | Arma de brazo | Nivel 5 (propuesta) |
| Pecho | 1 | Cañón o arma pesada | **Nivel 10** |
| Hombro derecho | 1 | Torreta | Nivel 15 (propuesta) |
| Hombro izquierdo | 1 | Torreta | **Nivel 20** |

- Al nivel 20 el robot lleva **5 armas** (2 brazos, 2 hombros y 1 pecho) más el robot de soporte.
- En negrita, los niveles que fijó el usuario. Los otros tres son propuesta para repartir el resto entre el 1 y el 20.
- El nivel es el del jugador (el piloto), no el de las piezas. Es un concepto nuevo: sube con la experiencia que dan los combates.
- El robot de soporte es una pieza más: se consigue, sube de nivel y pasa por etapas tecnológicas igual que un arma, y lleva una sola arma integrada.

## 2. Las tres líneas tecnológicas

Cada elemento del juego es una línea de tecnología. El disparo de un arma avanza por su línea conforme la pieza sube de etapa (cada 6 niveles, GDD §8).

| Etapa | Niveles | Cinética (físico) | Plasma (calor) | Iones (energía) |
|---|---|---|---|---|
| 1 | 1–6 | Proyectil sólido | Chorro térmico | Arco eléctrico |
| 2 | 7–12 | Riel magnético | Perno de plasma | Perno de iones |
| 3 | 13–18 | Gauss de ráfaga | Plasma confinado | Haz de partículas |
| 4 | 19–24 | Masa acelerada | Fusión | Haz coherente |
| 5 | 25–30 | Lanza gravitatoria | Llamarada solar | Haz de fase |
| 6 a 8 | 31–50 (solo piezas únicas) | Singularidad | Antimateria | Disrupción cuántica |

Los nombres de las etapas son de trabajo. Lo que importa es que cada etapa cambia el dibujo del arma, su fogonazo, su proyectil, su impacto y su sonido (GDD §12.2).

## 3. Familias de arma

13 familias. Cada una existe en las tres líneas, así que son **39 armas**.

### Brazos: 6 familias, 18 armas
Las armas de uso constante. Salen del antebrazo o lo sustituyen.

| Familia | Papel en combate | Alcance | Cómo se despliega |
|---|---|---|---|
| Hoja | Cuerpo a cuerpo; acorta la distancia antes de golpear | 1–3 | La hoja se enciende o se extiende desde el antebrazo |
| Bláster | Disparo corto y fuerte; algunos empujan | 1–2 | El antebrazo se abre y asoma el emisor |
| Repetidor | Disparo medio, el más regular | 2–4 | Cañones gemelos que salen de los costados del brazo |
| Lanza | Disparo largo y preciso | 3–6 | Cañón telescópico que se alarga en tres tramos |
| Saboteador | Poco daño; drena calor, energía o capacidad del rival, o lo empuja | 1–3 | Garra o sonda que se proyecta |
| Carga | Golpe de efecto fuerte con usos limitados por combate | 2–4 | Compuerta del brazo que expulsa la carga |

### Hombros: 3 familias, 9 armas
Torretas que salen de la espalda y se asientan sobre el hombro. Alcance largo.

| Familia | Papel en combate | Alcance | Cómo se despliega |
|---|---|---|---|
| Batería | Salva a larga distancia | 4–8 | Lanzador que se levanta y abre sus compuertas |
| Ancla | Atrae al rival hacia ti | 3–6 | Proyector que gira hacia delante y lanza el anclaje |
| Artillería | El disparo de mayor alcance; usos limitados | 5–9 | Tubo que se eleva y se bloquea en ángulo |

### Pecho: 2 familias, 6 armas (nuevas)
El arma pesada. El pecho se abre y el arma sale del interior del torso. Mucho daño, mucho costo de energía y calor, y retroceso.

| Familia | Papel en combate | Alcance | Cómo se despliega |
|---|---|---|---|
| Cañón pesado | Un disparo devastador en línea; pocos usos por combate | 3–8 | Las placas del pecho se separan y avanza el cañón |
| Nova | Onda a corta distancia que daña y empuja | 1–2 | El pecho se abre en pétalos y queda el núcleo al descubierto |

### Robot de soporte: 2 familias, 6 robots
Dispara solo al terminar tu turno, sin gastar acción.

| Familia | Papel en combate | Alcance |
|---|---|---|
| Artillero | Daño constante a cualquier distancia | Sin límite |
| Zapador | Poco daño; drena calor o energía de cerca | 1–4 |

## 4. Qué cambia respecto al catálogo actual

- Las 18 armas laterales, las 9 superiores y los 6 drones de hoy encajan uno a uno en las familias de brazo, hombro y soporte. Conservan sus números de balance; cambian de nombre y de tema hacia lo galáctico (hoy hay nombres como Trabuco, Mandoble o Lanzallamas).
- Las 6 armas de pecho son nuevas y hay que diseñar y equilibrar sus números.
- El robot pasa de 4 huecos laterales a 2 brazos, y gana el hueco de pecho. Eso obliga a rehacer los mechs de ejemplo y a repetir las pruebas de balance.
- Hace falta el nivel del jugador, con la experiencia por combate y los desbloqueos de la tabla 1.

## 5. Cuánto arte supone

Cada arma se dibuja una vez por etapa tecnológica, en dos o tres tramos para poder animar el despliegue.

| Hasta la etapa | Dibujos de arma |
|---|---|
| Solo etapa 1 | 39 |
| Hasta la 3 | 117 |
| Hasta la 5 (clase Mítica) | 195 |

Por eso se empieza por un arma piloto completa y, con lo que se aprenda, se decide el ritmo del resto.

## 6. Por confirmar con el usuario

1. Los niveles de desbloqueo propuestos (brazo izquierdo al 5 y primer hombro al 15).
2. Si las 13 familias cubren lo que imagina o falta algún tipo de arma.
3. Si el robot de soporte lleva un arma integrada (propuesta) o un arma que se le cambia.
4. Lo que sigue pendiente del GDD §8: si una pieza puede subir de clase o su clase es fija.
