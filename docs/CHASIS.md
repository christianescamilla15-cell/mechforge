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

## 5. Chasis previstos (propuesta)

| Chasis | Línea de diseño | Para quién |
|---|---|---|
| Ligero | Esbelta: la que eligió el usuario (`docs/reference/art/elegidos/jugador/`) | El primer robot del jugador |
| Medio | Intermedia, por definir | Segundo robot del jugador |
| Pesado | Robusta, tipo tanque andante (`docs/reference/art/elegidos/jefes/`) | Los jefes; si el jugador puede conseguirlo queda por decidir |

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

## 7. Qué cambia respecto a lo anterior

- Los cuerpos elegidos por el usuario pasan a ser la referencia de estilo del chasis ligero, no piezas para cortar.
- El catálogo de armas (`docs/CATALOGO_ARMAS.md`) gana una columna: para qué chasis es cada arma.
- Las animaciones se hacen por chasis: como las uniones están siempre en el mismo sitio, el movimiento de andar, desplegar un arma o recibir un golpe se define una vez por chasis y sirve para todas sus piezas.
- En el juego, un mech pasa a tener chasis, y el taller filtra las piezas por él.

## 8. Por decidir

1. Cuántos chasis hay en el primer mundo y si el jugador puede conseguir el pesado.
2. Si las armas son exclusivas de un chasis o se comparten entre chasis de tamaño parecido.
3. Cuántos torsos y piernas distintos tiene cada chasis al empezar.
