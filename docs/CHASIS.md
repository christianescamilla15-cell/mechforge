# Chasis: la base de cada robot

**Estado (2026-11-16):** reformulación del diseño por piezas, pedida por el usuario tras ver que las piezas cortadas de cuerpos distintos no casaban. La idea central está probada con imágenes (sección 6). Falta la aprobación del usuario y las decisiones de la sección 8.

## 1. Qué fallaba

La prueba de mezcla de los cuatro cuerpos elegidos dio combinaciones que no eran físicamente posibles ni se veían bien. Causas:

1. **Cada cuerpo se cortaba por una articulación distinta** (en unos el cuello, en otros la cintura): salían dos pechos apilados o piernas sin pelvis.
2. **Masas que no se sostienen:** un torso enorme sobre piernas finas, o un casco pequeño sobre piernas anchas.
3. **Posturas distintas:** piernas en columna frente a piernas en compás; torsos inclinados cada uno a su manera.
4. **Sin unión:** cada pieza acababa en un corte recto de ancho distinto.
5. **Escalas distintas:** cada cuerpo se dibujó a su propio tamaño.
6. **Lenguajes de diseño distintos:** formas orgánicas con alas junto a blindaje liso. Con las armas pasa lo mismo: un arma de un diseño muy distinto no casa con el brazo o el hombro donde se monta.

La raíz es una sola: las piezas se generaban como dibujos independientes y se intentaban unir después.

## 2. El chasis

El **chasis** es la base de un robot: su esqueleto, su tamaño y sus uniones. Todo lo demás se diseña para un chasis.

- Cada robot tiene un chasis. El jugador puede **conseguir robots con otros chasis y cambiar de uno a otro** (usuario, 2026-11-16); se guardan en el garaje.
- Los torsos, las piernas y las armas pertenecen a un chasis. Dentro de un chasis todo casa, porque comparte uniones, tamaño y lenguaje de diseño.
- Lo que no casa no se puede montar: el taller solo ofrece las piezas del chasis del robot.

## 3. Uniones estándar

Cada chasis fija dónde están sus uniones y de qué tamaño son. Toda pieza termina en la unión que le toca.

| Unión | Qué conecta | Cómo es |
|---|---|---|
| Cintura | Torso con piernas | Aro de acople visible, siempre a la misma altura y del mismo ancho. Pertenece al chasis, no a la pieza |
| Brazo (2) | Arma de brazo con el torso | Articulación redonda en el costado del torso. El torso se dibuja sin brazos: el brazo es el arma |
| Hombro (2) | Torreta con el torso | Base plana sobre la espalda alta |
| Pecho | Arma pesada | Compuerta en el frente del torso, de tamaño fijo |
| Espalda | Robot de soporte | Punto de acople del que se suelta al empezar el combate |

En vista lateral, el brazo y el hombro del lado lejano se dibujan detrás del torso, algo desplazados y más oscuros.

## 4. Reglas de compatibilidad

**Físicas**
- Una sola talla por chasis: todos los torsos caben en la misma envolvente y todas las piernas cargan ese peso.
- El torso queda centrado sobre el aro, y los pies apoyan debajo del aro. Ninguna pieza cruza la línea de la cintura.
- Cada arma cabe en la envolvente de su unión: largo y alto máximos para brazo, hombro y pecho.

**Estéticas**
- Cada chasis tiene su lenguaje de formas (la línea esbelta, la robusta).
- Todas las piezas se dibujan en blanco y al mismo aumento, para que el grosor de línea sea igual.
- El robot entero lleva un solo esquema de color por zonas (`tools/art/recolor.py`), que es lo que más unifica.

## 5. Los tres chasis

Aprobados por el usuario el 2026-11-16. Cada chasis tiene su carácter en combate y se mejora por niveles, como cualquier pieza.

| Chasis | Línea de diseño | Carácter en combate | Se consigue |
|---|---|---|---|
| Ligero | Esbelta: la que eligió el usuario (docs/reference/art/elegidos/jugador/) | Sus armas consumen mucha menos energía, así que dispara más y con más potencia. Menos vida | Es el primer robot |
| Medio | Intermedia, por definir | Equilibrado (propuesta: mejor manejo del calor) | Por definir (propuesta: nivel 5) |
| Pesado | Robusta, tipo tanque andante (docs/reference/art/elegidos/jefes/). Es también la de los jefes | Un salto enorme de vida y de resistencias. Más lento y con mayor consumo (propuesta) | Después del nivel 10 |

- El jugador elige: seguir mejorando su chasis ligero al siguiente nivel, o pasar al pesado para ganar aguante.
- **En el motor desde el 2026-11-16** (core/chassis_def.gd, data/chassis.json, 10 tests): el chasis multiplica la vida, las resistencias, la capacidad de calor, el enfriamiento, el gasto de energía de las armas y la potencia de disparo.

**Números actuales, medidos con tools/sim/chassis_sim.gd** (el mismo mech con un chasis contra el mismo mech con otro, 600 combates, clase Mítica):

| Chasis | Vida | Resistencias | Potencia de disparo | Gasto de energía | Calor |
|---|---|---|---|---|---|
| Ligero | −10 % | igual | +20 % | −40 % | igual |
| Medio | +3 % | igual | +10 % | igual | +15 % de capacidad y enfriamiento |
| Pesado | +25 % | +25 % | −10 % | +15 % | igual |

| Cruce | Gana el primero | Gana el segundo |
|---|---|---|
| Ligero contra medio | 40.5 % | 59.5 % |
| Ligero contra pesado | 45.0 % | 55.0 % |
| Medio contra pesado | 50.0 % | 50.0 % |

- Ningún chasis gana siempre: todos los cruces quedan entre el 40 % y el 60 %. El ligero es de momento el más flojo.
- Lo que no funcionó: ahorrar energía, por sí solo, no le daba nada al ligero (perdía el 100 % contra el pesado), porque a estos mechs no les falta energía. Por eso su ventaja real es la potencia de disparo. Y un pesado con +40 % de vida y resistencias ganaba el 100 %.
- Depende mucho del mech: con el de calor el medio le gana al pesado el 94 % de las veces, y con el híbrido solo el 4 %. Elegir chasis según lo que llevas montado es parte del juego, pero esos extremos hay que suavizarlos.
- Estos números son provisionales: hay que repetir el ajuste cuando cambien los huecos y el catálogo de armas.

**La bonificación crece con el nivel del chasis** (usuario, 2026-11-16): los números de la tabla son los del nivel máximo. Al principio las diferencias entre chasis son pequeñas y se potencian al mejorarlo. En el motor: en el nivel 0 el chasis da el 20 % de su bonificación y crece de forma lineal hasta el nivel 30 (RulesConfig.chassis_start_share y chassis_max_level; ChassisDef.at_level). Medido con 360 combates por nivel:

| Nivel del chasis | Ligero contra medio | Ligero contra pesado | Medio contra pesado |
|---|---|---|---|
| 0 | 50.0 / 50.0 | 48.3 / 51.7 | 54.2 / 45.8 |
| 15 | 41.7 / 58.3 | 42.5 / 57.5 | 52.5 / 47.5 |
| 30 | 39.2 / 60.8 | 50.8 / 49.2 | 49.2 / 50.8 |

**Habilidades de combate** (usuario, 2026-11-16; por diseñar): el chasis permite una serie de habilidades que se usan durante la batalla. Va junto con el árbol de habilidades (docs/CATALOGO_ARMAS.md, sección 4).


## 6. Cómo se dibujan las piezas

Método nuevo: **cada pieza se dibuja ya montada**.

1. Por cada chasis se hace un **maniquí**: un robot completo en blanco, con el aro de cintura y las uniones en su sitio.
2. Para un torso nuevo se dejan fijos las piernas y el aro del maniquí, y el modelo vuelve a dibujar solo lo que hay por encima. Para unas piernas nuevas, al revés.
3. Las armas se dibujan igual, sobre el maniquí y en su unión.
4. Se recorta cada pieza por la unión, que está en el mismo punto en todas.

Como todas las piezas se dibujaron contra el mismo aro, cualquier torso casa con cualquier par de piernas de ese chasis. Además el modelo acierta más, porque siempre ve un robot entero y no una pieza suelta.

**Prueba hecha (2026-11-16, `tools/art/halves_test.py`):** 3 torsos y 3 pares de piernas sobre un mismo maniquí, y las 9 combinaciones montadas (`tools/art/cut_body.py --hip`).
- Las 9 combinaciones encajan en el aro, sin costura, y se sostienen: es lo que no se conseguía antes.
- El dibujo conserva el detalle y la línea de tinta, a diferencia de cuando se le obligaba a seguir un bloque (ahí sale plano).
- Fallos por corregir: al repintar medio lienzo el modelo inventa suelo y horizonte, y el recorte de fondo falla (hay que repintar solo la envolvente de la pieza); los torsos salen con brazos y armas aunque se pidan sin ellos; unas piernas salieron demasiado inclinadas; algún tinte de color donde debía ser blanco.

**Segunda prueba, ya sobre el chasis ligero (2026-11-16):**
- **Maniquí:** el cuerpo elegido por el usuario (físico 101) con un aro de acople añadido en la cintura, repintando solo esa franja. Guardado en docs/reference/art/elegidos/maniqui_ligero.png. El aro está en la fila 530, columna 493 del lienzo de 1024.
- **Piezas:** 3 torsos y 3 pares de piernas, repintando solo la envolvente de cada pieza y sin bloque de control (manda el maniquí).
- **Resultado:** las 9 combinaciones encajan en el aro, con el detalle y la línea del estilo aprobado, todas en blanco, y el recorte de fondo sale limpio: desaparecieron el suelo inventado y los rectángulos.
- **Sigue fallando:** un torso salió con brazos y manos; los torsos son grandes para las piernas más finas; cada torso tiene un lenguaje de formas algo distinto.
- **Costo medido:** 50 segundos por pieza, pico de 4.3 GB de VRAM.

**Lote del chasis ligero (2026-11-16):** 8 torsos y 8 pares de piernas, con tres ajustes: envolvente del torso más ajustada, negativos contra brazos y armas en el torso, y fuerza 0.9 para que cada pieza herede las formas del maniquí.
- Torsos: los 8 salen sin brazos, de tamaño acotado y de la misma serie (casco en pico sobre un cuello).
- Piernas: más desiguales; a ojo sirven 5 de 8.
- Defecto: el fondo de la zona repintada queda de un tono algo distinto y se nota un rectángulo tenue. Hay que igualarlo antes del recorte definitivo.

**Primer arma montada (zona chest):** cañón de plasma en el pecho, 4 intentos sin bloque de control. Solo 1 dibujó un cañón (pequeño); 2 dejaron la zona vacía y 1 dibujó una placa. Sin silueta el modelo tiende a no dibujar nada. Siguiente intento: darle la silueta del arma como control, dentro de la zona, y un tamaño mayor.

**Armas de brazo y de hombro, y piernas especiales (2026-11-17, `tools/art/mounts_test.py`):** la receta del cañón de pecho (silueta como control dentro de la zona, escala 0.65, final 0.5, fuerza 0.9) sobre el robot 18, 4 semillas por diseño, unos 50 s por imagen.
- **Brazo** (unión redonda en el costado del cuello y el arma hacia delante): ametralladora, hoja, corta, rifle largo y sifón. Sale el arma en 2 de cada 4 semillas; en las demás la zona queda vacía. Elegidas: medio 2, hoja 1, corto 2, largo 2 y saboteador 2.
- **Hombro:** sobre el casco no hay sitio, y con la base tal cual salen piezas diminutas. Con la base bajada 170 píxeles y una silueta más grande salen bien: artillería 3, arpón 3 y lanzamisiles 3.
- **Piernas especiales** (repintando toda la zona de piernas, fuerza 1.0): orugas 1 (blanca, con luces cian, la mejor), ruedas 4 y levitación 4. Las otras semillas salen con color propio (verde, marrón) o con formas que no son de mecha.
- **Recorte:** `tools/art/extract_overlay.py` las saca por diferencia con la base y las colorea por elemento; las piernas, con `export_parts.py`. Las ocho armas salen limpias en los tres elementos.
- **En el juego** (`scenes/battle/mech_sprites.gd` y `mech_view.gd`): cada arma se dibuja en su hueco con la pieza de su forma (desde el 2026-11-18, de su forma y su tipo: ver más abajo). Las laterales 1 y 2 van delante del torso; la 3 y la 4, y la segunda superior, detrás y más oscuras, como el brazo del lado lejano. Cada una dispara desde su boca y retrocede al disparar; el cañón de pecho solo sale cuando dispara él. Las orugas, ruedas y levitación se dibujan de una pieza, sin esqueleto.
- **Drones:** con la receta de las armas la zona queda vacía (6 de 6): en fondo liso el modelo no dibuja nada. Pintando antes un bloque blanco del dron y con más fuerza de silueta (0.8 y 0.6, fuerza 0.85) los 8 de 8 dibujan un dron, más sencillo que las armas pero con el mismo trazo. Se llegaron a montar dos (artillero 1 y zapador 1), pero se retiraron el mismo día: eran demasiado simples para el estilo y los sustituye el robot de asistencia, que lleva sus armas dibujadas en su forma.
- **Robot de asistencia, seis formas (2026-11-17).** Primer intento, con la receta de los drones (bloque pintado en una zona pequeña y control firme): discos planos, sin detalle. El usuario los rechazó: no tenían nada del estilo mecha japonés. Segundo intento, con la receta de los cuerpos aprobados (`tools/art/assist_test.py`): cada forma a lienzo completo y grande, bloque blanco y gris con sus piezas (casco, sensor, torreta, cápsula inferior y, según la forma, aleta, góndola, alas, placas y anillo), todas sus líneas como control suelto (escala 0.5, final 0.4) y fuerza 1.0. Salen con blindaje por paneles, trazo de tinta, sensores y armas; 24 imágenes, de las que se eligió una familia que crece: Sonda 101, Vigía 101, Centinela 103, Custodio 102, Guardián 102 y Arconte 102. `tools/art/export_assist.py` las recorta (quitando también el fondo encerrado en el anillo), las colorea por elemento y guarda el centro y las bocas de sus dos armas.
- **Regla que sale de aquí:** una pieza que tenga que verse detallada se dibuja grande y a lienzo completo, con control suelto, y se reduce después; dibujarla pequeña dentro de una zona, o con el control firme, da formas planas.
- **Un dibujo por forma y tipo de arma (2026-11-18, `tools/art/weapons_test.py` y `export_weapons.py`).** Las ocho armas montadas eran tubos de color, planas al lado de los cuerpos y del asistente, y había una por forma. Se rehicieron todas: 26 dibujos, uno por cada forma y tipo del catálogo (17 de brazo y 9 de hombro), en los tres elementos. Lo que se probó, en orden:
  1. *Arma suelta con la receta del asistente* (control suelto, 0.5 y 0.4): sale detallada pero fuera de estilo, como un objeto de fantasía (hojas ornamentadas, cables, óxido). El modelo dibuja bien un robot o un dron; un arma sola la trata como un objeto. Además el prompt pasaba de los 77 tokens de CLIP y se perdía el final, que es el fondo gris: ahora el script se niega a generar si no cabe.
  2. *Control firme* (0.8 y 0.6): calca el bloque y sale plana, justo lo que se quería evitar.
  3. *Lienzo apaisado para dibujarla al doble de tamaño* (1536×640, los mismos píxeles): con un bloque de pocas formas grandes sale aún más plana. El tamaño no da detalle por sí solo.
  4. *Bloque con su propio detalle y control medio* (0.65 y 0.5, fuerza 1.0): **es la que queda.** Cada pieza del bloque lleva líneas dentro (filete y tornillos en las placas, costillas en cañones y raíles, lamas en los paneles, refuerzos en la estructura; función `details`). El modelo pone el detalle donde el control tiene líneas, y con el control a media fuerza las entinta en el estilo y añade lo suyo (cintas de munición, escudos, brillos). 78 imágenes (3 semillas por diseño, 42 s cada una); las elegidas están en `export_weapons.CHOSEN`. La semilla 103 tiende a dibujar un robot entero detrás del arma; la 101, la del estilo aprobado, es la que más acierta.
  - **Diseños:** cada tipo se reconoce por su cañón. Balas: tres cañones finos, abrazadera y tambor. Cañón: uno grueso con manguito y freno de boca. Bláster: núcleo luminoso entre dos carcasas con bobinas. Láser: dos raíles finos con canal de haz, lente y aletas. Las formas cambian el largo y lo que acompaña (mira en la larga, boca ancha en la corta, hoja, garra o antena en el saboteador; lanzador, pieza inclinada o arpón en las de hombro).
  - **Exportación:** recorte del fondo, color por elemento y anclas (la cintura del robot, calculada desde la unión del bloque, y la boca del arma, de donde sale el disparo). Las de brazo se reducen a 0.36 píxeles por unidad del bloque y las de hombro a 0.30: a la misma escala tapaban medio robot. A las de hombro se les corta lo que el modelo añade por debajo del pedestal y se hunden un poco en la espalda para que no floten.
  - **En el juego:** `MechSprites.weapon_kind` busca `arm_<forma>_<tipo>` o `shoulder_<forma>_<tipo>`. Para revisarlas montadas: `tools/weapon_frames.gd` (una hoja con un mech por juego de armas) y `tools/clip.ps1 -Showcase`, que ahora las va cambiando y disparando.
- **Regla corregida:** el detalle no sale del tamaño ni del control suelto, sino de dos cosas juntas: que el modelo sepa dibujar eso en el estilo (un robot o un dron sí, un arma sola no) y que el control tenga líneas donde debe haber detalle. Para lo que el modelo no domina, el diseño lo pone el bloque, con su detalle dentro, y el control va a media fuerza.
- Pendiente: las armas de pecho siguen con un solo dibujo (el cañón que se despliega) y los jefes siguen sin armas visibles.

## 7. Qué cambia respecto a lo anterior

- Los cuerpos elegidos por el usuario pasan a ser la referencia de estilo del chasis ligero, no piezas para cortar.
- El catálogo de armas (`docs/CATALOGO_ARMAS.md`) gana una columna: para qué chasis es cada arma.
- Las animaciones se hacen por chasis: como las uniones están siempre en el mismo sitio, el movimiento de andar, desplegar un arma o recibir un golpe se define una vez por chasis y sirve para todas sus piezas.
- En el juego, un mech pasa a tener chasis, y el taller filtra las piezas por él.

## 8. Por decidir

1. Los números de las bonificaciones de cada chasis y cuándo se consigue el medio.
2. Si las armas son exclusivas de un chasis o se comparten entre chasis de tamaño parecido. Mientras no se decida se comparten, con la regla de que quepan en la unión.
3. Cuántos torsos y piernas distintos tiene cada chasis al empezar.
