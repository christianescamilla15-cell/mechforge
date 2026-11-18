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

## 9. Ficha de cada arma: qué es, qué daño hace y cómo dispara

**Propuesta del 2026-11-18, pendiente del visto bueno del usuario.** La pidió el usuario al ver las armas nuevas: no es realista que todas disparen igual; primero hay que definir qué tipo de arma es cada una y qué daño puede hacer, y después su disparo. Hoy todas disparan el mismo proyectil luminoso, del color de su elemento (`ArenaView.shoot`).

### 9.1 Qué decide cada capa
- **La forma** decide el papel: alcance, usos y si empuja o jala.
- **El tipo** es la tecnología. Decide en qué clases existe el arma, y por eso hasta dónde llega su daño: el láser pega más que las balas porque llega a clases más altas. También decide cómo llega ese daño: cuántos impactos, por qué camino y cuánto varía de un disparo a otro.
- **La munición** es el elemento. La cinética pega alrededor de un 10 % más y desgasta la resistencia del rival; la térmica lo calienta; la iónica le drena energía. La cinética es también la que más empuja y jala (en el corto, el ancla y el saboteador).

En el original cada arma es una sola tirada de daño (`mín + azar × (máx − mín)`) y no hay reglas por familia: lo que distingue un arma de otra son sus números y su animación (docs/reference/original-mechanics.md).

### 9.2 Los cuatro tipos
| Tipo | Qué es | Clases | Cómo llega el daño | Cuánto varía de un disparo a otro | Ejemplo: forma media al máximo |
|---|---|---|---|---|---|
| Balas | Armas de fuego: proyectiles sólidos | Básica e Intermedia | Varios impactos pequeños que suman el daño (ráfaga o perdigones); el rifle, uno solo. Trazadoras rápidas en línea recta | La que más: ±15 % | Ametralladora, 56–75 |
| Cañón | Proyectil pesado: obús, granada, misil o arpón | Intermedia y Avanzada | Un impacto grande que estalla. La granada y el obús van en arco; los misiles, en curva con humo | ±13 % | Lanzagranadas, 75–98 |
| Bláster | Plasma: energía caliente confinada | Intermedia a Legendaria | De 1 a 4 pernos o bolas luminosas que salpican al llegar | ±12 % | Repetidor de plasma, 102–130 |
| Láser | Haz de luz | Avanzada a Mítica | Instantáneo: no viaja, llega y quema una línea | La que menos: ±6 % | Láser de pulso, 145–164 |

Las etapas de cada tipo (2 de balas, 3 de cañón, 4 de bláster y 5 de láser, sección 2) hacen crecer el disparo que se describe aquí: más proyectiles, más grandes y con más brillo.

### 9.3 Las armas, una por una
Daño por disparo con munición cinética, antes de resistencias: en su primera clase a nivel 0 → **en su última clase al nivel máximo**. Con munición térmica o iónica el daño es alrededor de un 10 % menor y se suma el calor o el drenaje de sus columnas, con la misma escala. Los números salen de `data/catalog.json`.

#### Brazos

**Hoja.** Cuerpo a cuerpo, alcance 1–3: salta junto al rival antes de golpear.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Cuchilla vibratoria | Hoja de motor que vibra. Salta junto al rival y da un tajo con chispas de metal. | 40–51 → **69–90** | 7 → 13 | 13 → 22 |
| Hoja de plasma | Filo de plasma. Salta y da un tajo con estela caliente que salpica. | 55–68 → **126–157** | 10 → 22 | 17 → 40 |
| Hoja láser | Filo de luz. Salta y corta; deja una línea quemada en el blindaje. | 77–86 → **178–200** | 13 → 30 | 23 → 53 |

**Corto.** Alcance 1–2. La munición cinética empuja 1 casilla.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Escopeta | Abanico de 6 perdigones a quemarropa. | 36–46 → **63–81** | 9 → 15 | 15 → 26 |
| Obús corto | Un obús corto y gordo que estalla al tocar. | 49–62 → **85–107** | 12 → 21 | 20 → 34 |
| Proyector de plasma | Chorro de plasma en cono, como un lanzallamas. | 49–61 → **114–142** | 12 → 27 | 20 → 46 |
| Láser de corte | Haz ancho y corto que corta como un soplete. | 70–78 → **162–180** | 16 → 37 | 26 → 61 |

**Medio.** Alcance 2–4, el más común (en el original, 32 de 79 armas laterales).

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Ametralladora | Ráfaga de 5 balas trazadoras. | 32–42 → **56–75** | 8 → 14 | 14 → 24 |
| Lanzagranadas | Una granada en parábola que estalla al caer. | 44–57 → **75–98** | 11 → 19 | 19 → 32 |
| Repetidor de plasma | Tres pernos de plasma seguidos. | 44–56 → **102–130** | 11 → 25 | 19 → 43 |
| Láser de pulso | Tres pulsos de luz que llegan al instante. | 63–71 → **145–164** | 15 → 34 | 25 → 57 |

**Largo.** Alcance 3–6.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Rifle | Una bala de alta velocidad, recta, con estela fina. | 31–40 → **54–71** | 7 → 13 | 13 → 22 |
| Cañón de brazo | Un proyectil pesado en línea recta que estalla. | 42–54 → **73–93** | 10 → 17 | 17 → 30 |
| Lanza de plasma | Un perno de plasma largo que salpica al llegar. | 43–53 → **99–123** | 10 → 22 | 17 → 40 |
| Láser de precisión | Un haz fino que llega al instante y se sostiene un momento. | 61–68 → **140–156** | 13 → 30 | 23 → 53 |

**Saboteador.** Alcance 1–3 (1–2 la térmica), pocos usos, poco daño: su papel es el efecto. Cada munición hace algo distinto.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Sifón de plasma | Plasma a presión. Cinética: golpe que empuja 4 casillas. Térmica: chorro que funde. Iónica: arco que absorbe energía. | 29–37 → **68–86** | 7 → 17 | 12 → 29 |
| Haz de drenaje | Haz. Cinética: empuja 4 casillas. Térmica: funde. Iónica: absorbe energía. | 42–47 → **97–109** | 10 → 23 | 16 → 38 |

#### Hombros

**Batería.** Alcance 4–8.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Rotativa | Ráfaga larga de 8 balas desde la torreta. | 40–51 → **69–90** | 10 → 17 | 16 → 27 |
| Lanzamisiles | Salva de 4 misiles que suben y caen sobre el rival, con estela de humo. | 54–69 → **93–119** | 13 → 22 | 21 → 36 |
| Batería de plasma | Cuatro bolas de plasma escalonadas. | 55–68 → **126–157** | 13 → 30 | 21 → 49 |
| Batería láser | Dos haces paralelos que llegan al instante. | 77–86 → **178–200** | 17 → 40 | 28 → 65 |

**Ancla.** Alcance 3–6. Jala al rival: 2 casillas con munición cinética, 1 con las otras.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Arpón | Arpón con cable: se clava y arrastra al rival. | 45–58 → **78–100** | 12 → 21 | 20 → 34 |
| Haz tractor | Haz tractor que atrae al rival. | 65–73 → **149–168** | 16 → 37 | 26 → 61 |

**Artillería.** Alcance fijo: 8 (7 el mortero de plasma), como en el original. 2 usos.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Obús | Obús en arco alto; explosión grande. | 71–92 → **123–159** | 21 → 36 | 32 → 56 |
| Mortero de plasma | Bola de plasma en arco alto; salpicadura grande. | 72–91 → **167–210** | 21 → 47 | 32 → 74 |
| Lanza orbital | Un rayo que cae del cielo sobre el rival. | 103–115 → **237–265** | 27 → 63 | 43 → 99 |

#### Pecho

**Cañón pesado.** Alcance 3–8, 2 usos.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Cañón de asedio | Obús enorme en línea recta, con culatazo y humo. | 71–92 → **123–159** | 21 → 36 | 32 → 56 |
| Cañón de plasma | Esfera de plasma grande y lenta. | 72–91 → **167–210** | 21 → 47 | 32 → 74 |
| Cañón láser | Haz grueso y sostenido. | 103–115 → **237–265** | 27 → 63 | 43 → 99 |

**Nova.** Alcance 1–2, empuja 2 casillas, 3 usos.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Nova de plasma | Onda de plasma en anillo alrededor del mech. | 64–80 → **149–184** | 15 → 35 | 26 → 59 |
| Nova láser | Destello que sale en todas direcciones. | 91–101 → **210–234** | 20 → 47 | 34 → 79 |

#### Robot de asistencia

**Artillero.** Alcance: toda la arena.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Dron artillero | Ráfaga corta desde el robot de asistencia. | 18–24 → **32–43** | 4 → 7 | 7 → 13 |
| Dron bombardero | Bomba que suelta desde arriba. | 25–32 → **44–56** | 5 → 9 | 10 → 17 |
| Dron de plasma | Perno de plasma. | 25–32 → **59–74** | 5 → 13 | 10 → 23 |
| Dron láser | Haz fino. | 36–41 → **84–94** | 7 → 17 | 13 → 30 |

**Zapador.** Alcance 1–4. Poco daño.

| Arma | Qué dispara | Daño cinético por disparo | Térmica: calor que causa | Iónica: energía que drena |
|---|---|---|---|---|
| Dron sifón | Chorro corto que absorbe de cerca. | 20–25 → **46–59** | 7 → 17 | 14 → 31 |
| Dron de drenaje | Haz corto que absorbe de cerca. | 28–32 → **66–75** | 10 → 23 | 18 → 42 |

### 9.4 Lo que no cuadra hoy
1. **Todas disparan igual.** La columna "Qué dispara" es lo que se programa después.
2. **El saboteador de munición cinética no drena.** Se llama "Sifón de plasma" y "Haz de drenaje", pero es un golpe que empuja 4 casillas, con 2 usos. Propuesta: llamarlos "Repulsor de plasma" y "Haz repulsor".
3. **Las armas de pecho tienen los números de la artillería** (decisión del 2026-11-17), pero con alcance 3–8 en vez de una sola distancia: son una artillería sin su pega. No se propone cambiarlo ahora; queda anotado.

### 9.5 Por decidir (usuario)
- **A (recomendada): el tipo cambia cómo llega el daño, no cuánto.** Como en el original. A igual clase, la ametralladora y el lanzagranadas pegan lo mismo de media; el lanzagranadas llega a más porque sube a clases más altas. No toca el balance medido ni la campaña. Se programa el disparo de cada arma; los impactos de una ráfaga se ven por separado y el daño sale en un solo número.
- **B: además, un rasgo de combate por tipo** (propuesta nuestra; el original no tiene nada así). Balas: un escudo solo para el primer impacto de la ráfaga. Cañón: la onda expansiva empuja 1 casilla. Bláster: una parte del daño quema en el turno siguiente. Láser: ignora la mitad de la resistencia. Cada rasgo se paga con menos daño base, y hay que volver a medir los cuatro tipos y la campaña. Un cambio por tipo ya rompió una vez el equilibrio entre elementos (el calor llegó a ganar el 96–100 % de sus combates).
