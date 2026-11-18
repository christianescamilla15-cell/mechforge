# Catálogo de armas

**Estado (2026-11-17):** generadas las armas de brazo, hombro y robot de soporte: 32 diseños × 3 municiones = 96 armas en `data/catalog.json` (tools/catalog_gen.py). Las 15 de pecho se generaron el mismo día, cuando el usuario decidió que el arma de pecho va **aparte** de las seis: en total, las **111 armas** del catálogo. Los brazos van en los 4 huecos laterales, los hombros en los 2 superiores y el pecho en su propio hueco, que se abre en el nivel 10 del jugador.
- **Pecho:** el cañón pesado toma los números de la artillería (2 usos) con alcance 3–8; la nova, los de las armas cortas con un 30 % más de daño, empuje de 2 casillas y 3 usos.

**Cómo se generan** (tools/catalog_gen.py, armas base en tools/weapon_bases.json):
- Cada forma toma sus números de un arma ya equilibrada del catálogo anterior, una por munición (por ejemplo, Corto = trabuco, lanzallamas y descargador).
- El tipo le da su rango de clases (tabla 2) y su forma de disparar, **no su potencia**: a igual clase, las armas de una forma pegan lo mismo de media y gastan lo mismo en los cuatro tipos. El daño de las balas varía un 20 % más que el de la forma, el del cañón un 10 % más, el del bláster igual y el del láser la mitad; el cañón pesa un 5 % más y las balas y el láser un 5 % menos. Lo que hace mejor a un arma de tipo superior es que llega a clases más altas.
- Se probó primero que cada tipo cambiara el daño y los costos (las balas gastaban menos, el cañón pegaba más, el plasma térmico quemaba más). Aunque el cambio fuera igual para las tres municiones, rompía el equilibrio entre elementos: con costos más bajos el drenaje de energía valía menos y con más altos el calor dominaba (el mech de calor llegó a ganar el 96–100 % de sus combates con cañón y bláster).
- La artillería tiene alcance fijo, 8 (7 el mortero de plasma), como en el original.
- Un arma solo se transforma dentro del rango de clases de su tipo; para ir más allá hay que comprar un arma de un tipo superior. La tienda vende en cada zona las piezas cuyo rango incluye la clase de la zona.
- Torsos, piernas, módulos y especiales existen de Básica a Mítica.

**Mechs de ejemplo** (tools/builds_gen.py): cada elemento tiene un mech por tipo de arma, con las mismas formas que antes. Los de balas son los mechs con los que se empieza; las zonas 1–2 usan rivales de balas, la 3–4 de cañón, la 5–6 de bláster y la 7–10 de láser. Los jefes llevan las armas del tipo de su zona.

**Balance por tipo** (tools/sim/balance_sim.gd --band, clase Única al máximo, 1 600 combates por tipo, semilla 4242; puerta de F3: ningún elemento por encima del 55 % y el híbrido entre el 45 y el 55 %):

| Tipo | Físico | Calor | Energía | Híbrido | Duración media |
|---|---|---|---|---|---|
| Balas | 51.0 % | 49.3 % | 49.8 % | 47.8 % | 12.3 turnos |
| Cañón | 50.8 % | 49.3 % | 50.0 % | 47.5 % | 12.3 turnos |
| Bláster | 51.5 % | 49.8 % | 48.8 % | 48.0 % | 12.3 turnos |
| Láser | 49.3 % | 49.8 % | 51.0 % | 47.8 % | 12.3 turnos |

Las cuatro pasan todas las puertas, igual que el catálogo anterior (51.5 / 49.8 / 48.8 / 48.0).

**Con el robot de asistencia** (GDD §4; 2026-11-17, mismas condiciones, `--assist=full` y `--assist=charged`). Todos los mechs llevan el protocolo Blindaje y dos armas gemelas que alternan; "batería" es la mejora de la armería al máximo (+10 % al daño de sus disparos):

| Tipo | Batería | Físico | Calor | Energía | Híbrido | Duración media |
|---|---|---|---|---|---|---|
| Balas | sin mejora | 49.0 % | 54.5 % | 46.5 % | 52.3 % | 12.7 turnos |
| Cañón | sin mejora | 48.5 % | 54.5 % | 47.0 % | 52.3 % | 12.7 turnos |
| Bláster | sin mejora | 48.8 % | 54.3 % | 47.0 % | 51.5 % | 12.7 turnos |
| Láser | sin mejora | 46.3 % | 54.8 % | 49.0 % | 51.5 % | 12.7 turnos |
| Láser | al máximo | 53.8 % | 50.0 % | 46.3 % | 51.0 % | 12.3 turnos |

Pasan todas las puertas. El calor queda cerca del tope sin la mejora (Blindaje alarga los combates, y eso le favorece) y el físico cerca del tope con ella; por eso la batería no pasa de +10 %. Con +15 % los otros tres tipos seguían dentro (físico 52.8–54.5 %) y el láser no (56.8 %). Lo que se probó antes y se descartó, con sus cifras, está en el GDD §4.

Lo que fijó el usuario: armas galácticas que se despliegan desde el cuerpo del robot; cuatro categorías según dónde van montadas; dentro de cada categoría, división por tipo de arma (balas, cañón, bláster, láser); al menos 100 armas; y la materia oscura como habilidad del arma del pecho.

## 1. Categorías: dónde van las armas

| Hueco | Cuántas | Qué lleva | Se desbloquea en |
|---|---|---|---|
| Brazo derecho | 1 | Arma de brazo | Nivel 1 |
| Robot de soporte | 1 | Robot acompañante con su arma | **Nivel 3** |
| Brazo izquierdo | 1 | Arma de brazo | Nivel 5 |
| Pecho | 1 | Cañón o arma pesada | **Nivel 10** |
| Hombro derecho | 1 | Torreta | Nivel 15 |
| Hombro izquierdo | 1 | Torreta | **Nivel 20** |

- **Corrección del usuario (2026-11-16): seis armas, como en el original.** Son 4 laterales (dos por brazo) y 2 superiores (una por hombro), que es lo que el motor ya tiene. La tabla de arriba y el arma de pecho hay que rehacerlos con eso: queda por decidir si el arma de pecho es una de esas seis o va aparte.
- En negrita, los niveles que fijó el usuario; los otros se aprobaron con la propuesta.
- El nivel es el del jugador, no el de las piezas: sube con la experiencia de los combates.
- El robot de soporte es una pieza más: se consigue, sube de nivel y evoluciona igual que un arma, y lleva un arma integrada.

## 2. Tipos de arma

El tipo es la tecnología del arma. Decide en qué clases existe, cómo se ve y cómo dispara.

| Tipo | Qué dispara | Clases en las que existe | Nivel máximo | Etapas de dibujo |
|---|---|---|---|---|
| Balas | Proyectiles sólidos: ráfagas, perdigones, tiros de precisión | Básica e Intermedia | 12 | 2 |
| Cañón | Proyectil pesado y explosivo: obuses, cohetes y misiles | Intermedia y Avanzada | 18 | 3 |
| Bláster | Plasma: pernos, ráfagas y chorros de energía caliente | Intermedia a Legendaria | 24 | 4 |
| Láser | Haces: de pulso, continuo y de fase | Avanzada a Mítica | 30 | 5 |
| Única | La versión de jefe de cualquiera de los anteriores | Única | 50 | 8 |

- Las balas son las armas de las clases bajas y el láser el de las altas, como pidió el usuario. Los rangos exactos de cañón y bláster son propuesta.
- Un arma sube de clase dentro del rango de su tipo (la transformación del GDD §8). Para ir más allá hay que conseguir un arma de un tipo superior.
- Cada 6 niveles el arma pasa a una etapa nueva: cambia su dibujo y su disparo.

**Munición (elemento).** Cada arma existe en tres variantes, que son los tres elementos del combate. Comparten dibujo y se distinguen por el color de sus luces y por su efecto:

| Munición | Elemento | Efecto |
|---|---|---|
| Cinética | Físico | Más daño directo; desgasta la resistencia del rival |
| Térmica | Calor | Sobrecalienta al rival hasta apagarlo |
| Iónica | Energía | Le drena la energía y lo deja sin poder disparar |

## 3. Las armas: 37 diseños, 111 armas

Cada casilla marcada es un diseño de arma. Cada diseño existe en las tres municiones.

### Brazos: 17 diseños, 51 armas
| Forma | Papel en combate | Alcance | Balas | Cañón | Bláster | Láser |
|---|---|---|---|---|---|---|
| Hoja | Cuerpo a cuerpo; acorta la distancia antes de golpear | 1–3 | Cuchilla vibratoria | | Hoja de plasma | Hoja láser |
| Corto | Disparo corto y fuerte; algunos empujan | 1–2 | Escopeta | Obús corto | Proyector de plasma | Láser de corte |
| Medio | El disparo más regular | 2–4 | Ametralladora | Lanzagranadas | Repetidor de plasma | Láser de pulso |
| Largo | Disparo largo y preciso | 3–6 | Rifle | Cañón de brazo | Lanza de plasma | Láser de precisión |
| Saboteador | Poco daño; drena al rival o lo empuja | 1–3 | | | Sifón de plasma | Haz de drenaje |

### Hombros: 9 diseños, 27 armas
| Forma | Papel en combate | Alcance | Balas | Cañón | Bláster | Láser |
|---|---|---|---|---|---|---|
| Batería | Salva a larga distancia | 4–8 | Rotativa | Lanzamisiles | Batería de plasma | Batería láser |
| Ancla | Atrae al rival hacia ti | 3–6 | | Arpón | | Haz tractor |
| Artillería | Alcance fijo: solo acierta a esa distancia exacta; usos limitados | 7 u 8 | | Obús | Mortero de plasma | Lanza orbital |

### Pecho: 5 diseños, 15 armas
El arma pesada. El pecho se abre y el arma sale del interior del torso. Mucho daño, mucho costo de energía y calor, y retroceso.

| Forma | Papel en combate | Alcance | Balas | Cañón | Bláster | Láser |
|---|---|---|---|---|---|---|
| Cañón pesado | Un disparo devastador en línea; pocos usos | 3–8 | | Cañón de asedio | Cañón de plasma | Cañón láser |
| Nova | Onda a corta distancia que daña y empuja | 1–2 | | | Nova de plasma | Nova láser |

### Robot de soporte: 6 diseños, 18 robots
Dispara solo al terminar tu turno, sin gastar acción. Son las armas del **robot de asistencia** (GDD §4): lleva una arriba y otra abajo, dispara una por turno y las alterna.

| Forma | Papel en combate | Alcance | Balas | Cañón | Bláster | Láser |
|---|---|---|---|---|---|---|
| Artillero | Daño constante a cualquier distancia | Sin límite | Dron artillero | Dron bombardero | Dron de plasma | Dron láser |
| Zapador | Poco daño; drena de cerca | 1–4 | | | Dron sifón | Dron de drenaje |

**Total: 37 diseños × 3 municiones = 111 armas**, más las únicas de jefe (3 por mundo). Los nombres de la tabla describen el arma; los nombres finales se escriben al generar el catálogo y pasan por el validador (no puede repetirse ninguno del juego original).

## 4. Materia oscura

Definida por el usuario: es el disparo más poderoso del juego y prácticamente aniquila al enemigo.

- No es un arma: es una **habilidad** que el robot desarrolla en su árbol de habilidades.
- Solo se aplica al arma central, la del pecho: convierte su disparo en materia oscura.
- Reglas decididas por el usuario (2026-11-17): un solo uso por combate, exige el arma del pecho ya desplegada, gasta toda la energía, ignora resistencias y escudos y quita el 60 % de la vida máxima del rival. Se alcanza en el nivel 25, al final de la rama Asalto.

**Árbol de habilidades.** Hecho el 2026-11-17: tres ramas libres (Asalto, Blindaje y Sistemas), 1 punto por nivel del jugador. Detalle en el GDD §8.

## 5. Cómo se despliegan

Las armas van guardadas dentro del cuerpo. La primera vez que se usa cada una en un combate se despliega (GDD §12.2); luego queda fuera.

| Categoría | Despliegue |
|---|---|
| Brazos | El antebrazo se abre y el arma se extiende; los cañones largos se alargan en tramos como un telescopio |
| Hombros | La torreta sale de la espalda, sube y se asienta sobre el hombro; los lanzadores abren sus compuertas |
| Pecho | Las placas del pecho se separan y el arma avanza desde el interior |
| Soporte | El robot de soporte se desacopla de la espalda y queda flotando detrás |

## 6. Cómo se hace abarcable

- **Números:** las 111 armas no se equilibran una a una. Salen de una tabla: forma (alcance, daño y efecto base, que ya están equilibrados en el catálogo actual) × tipo (rango de clases y matices) × munición (efecto del elemento). El simulador comprueba el resultado.
- **Arte:** las tres municiones comparten dibujo y se distinguen con el color por zonas (`tools/art/recolor.py`). Se dibuja en blanco y se colorea después. Contando las etapas de cada tipo son unos 140 dibujos: 12 de balas, 24 de cañón, 44 de bláster y 60 de láser.
- **Orden:** primero un arma piloto completa (el cañón de plasma de pecho, base elegida por el usuario: versión 102), con sus etapas, su despliegue y su disparo. Después, las formas de brazo de clase básica, que son las que el jugador ve primero.

## 7. Qué cambia en el juego

- El robot pasa de 4 huecos laterales y 2 superiores a 2 brazos, 2 hombros y 1 pecho.
- Aparecen el nivel del jugador (experiencia y desbloqueos de la tabla 1) y el árbol de habilidades.
- Las 33 armas actuales se sustituyen por las generadas con la tabla; sus números sirven de base para las formas.
- Hay que rehacer los mechs de ejemplo y repetir las pruebas de balance, con Mítica como techo de las piezas normales.

## 8. Por decidir

1. Los rangos de clase de cañón y bláster (tabla 2).
2. Las reglas exactas de la materia oscura y el diseño de los árboles de habilidades.
3. Si faltan tipos de arma (por ejemplo eléctricas, de gravedad o escudos como arma) o formas.
4. Los huecos de escudo y de perk, que el original tiene y aquí faltan (docs/reference/original-mechanics.md, "Contraste con lo construido").
5. La proporción de alcances de las armas de brazo debe seguir la del original: la mayoría de alcance medio.
