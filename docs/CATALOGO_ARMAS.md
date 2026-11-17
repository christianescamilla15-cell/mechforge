# Catálogo de armas

**Estado (2026-11-16):** estructura aprobada por el usuario. Falta generar la lista de armas con sus números, cambiar los huecos del robot en el motor y repetir el balance. Hasta entonces el juego sigue con el catálogo anterior (`data/catalog.json`: 4 laterales y 2 superiores).

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

- Al nivel 20 el robot lleva **5 armas** (2 brazos, 2 hombros y 1 pecho) más el robot de soporte.
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
| Artillería | El mayor alcance; usos limitados | 5–9 | | Obús | Mortero de plasma | Lanza orbital |

### Pecho: 5 diseños, 15 armas
El arma pesada. El pecho se abre y el arma sale del interior del torso. Mucho daño, mucho costo de energía y calor, y retroceso.

| Forma | Papel en combate | Alcance | Balas | Cañón | Bláster | Láser |
|---|---|---|---|---|---|---|
| Cañón pesado | Un disparo devastador en línea; pocos usos | 3–8 | | Cañón de asedio | Cañón de plasma | Cañón láser |
| Nova | Onda a corta distancia que daña y empuja | 1–2 | | | Nova de plasma | Nova láser |

### Robot de soporte: 6 diseños, 18 robots
Dispara solo al terminar tu turno, sin gastar acción.

| Forma | Papel en combate | Alcance | Balas | Cañón | Bláster | Láser |
|---|---|---|---|---|---|---|
| Artillero | Daño constante a cualquier distancia | Sin límite | Dron artillero | Dron bombardero | Dron de plasma | Dron láser |
| Zapador | Poco daño; drena de cerca | 1–4 | | | Dron sifón | Dron de drenaje |

**Total: 37 diseños × 3 municiones = 111 armas**, más las únicas de jefe (3 por mundo). Los nombres de la tabla describen el arma; los nombres finales se escriben al generar el catálogo y pasan por el validador (no puede repetirse ninguno del juego original).

## 4. Materia oscura

Definida por el usuario: es el disparo más poderoso del juego y prácticamente aniquila al enemigo.

- No es un arma: es una **habilidad** que el robot desarrolla en su árbol de habilidades.
- Solo se aplica al arma central, la del pecho: convierte su disparo en materia oscura.
- Propuesta de reglas, por decidir: un solo uso por combate, exige el arma del pecho ya desplegada y gasta toda la energía; ignora las resistencias del rival.

**Árbol de habilidades.** Es un sistema nuevo: el jugador elige un árbol y lo desarrolla con el nivel. Está por diseñar: cuántos árboles hay, qué da cada rama y en qué nivel se alcanza la materia oscura.

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
