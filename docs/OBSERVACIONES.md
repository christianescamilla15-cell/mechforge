# Matriz de observaciones

Cada cosa que el usuario nota al jugar se apunta aquí, con sus palabras, lo que se comprobó en el código y en qué quedó. Pedida por el usuario el 2026-11-20: "vamos a crear una matriz de observaciones donde veamos cada incidencia que se da".

**Cómo se usa**
- Una fila por observación. No se borra ninguna: cuando se resuelve cambia su estado y se apunta el commit.
- **Tipo:** *fallo* (algo no funciona), *falta* (algo previsto que no está hecho), *diseño* (el usuario quiere que funcione de otra manera) o *trabajo* (cómo quiere que se trabaje).
- **Estado:** *abierta* · *en curso* · *hecha, falta tu veredicto* · *resuelta* · *vigente* (reglas de trabajo).
- "Comprobado" dice lo que se vio de verdad en el código o en una prueba, no una suposición. Si no se comprobó, lo dice.
- Antes de empezar a trabajar se lee esta matriz; al terminar se actualiza.

## Resumen

| Estado | Cuántas |
|---|---|
| Resueltas | 6 (OBS-002 a OBS-006 y OBS-023) |
| Hechas, falta tu veredicto | 3 (OBS-007, OBS-008 y OBS-009) |
| Abiertas | 13 (OBS-010 a OBS-022) |
| Reglas de trabajo vigentes | 1 (OBS-001) |

## Reglas de trabajo

| ID | Fecha | Lo que dijiste | Qué significa | Estado |
|---|---|---|---|---|
| OBS-001 | 2026-11-20 | "No cierres el juego, sigo haciendo pruebas, no lo cierres." | Mientras el juego esté abierto no se cierra ni se reemplaza su ejecutable. La versión nueva se deja aparte, en `build\windows\MechForgeNuevo.exe`, y la abres tú cuando termines. Las pruebas automáticas siguen sin guardar nada en tu partida. | Vigente |

## Fallos

| ID | Fecha | Dónde | Lo que viste | Comprobado | Estado |
|---|---|---|---|---|---|
| OBS-002 | 2026-11-20 | Taller, diana | Con la espada, "el efecto que hace es disparar, no el movimiento de la espada". | Cierto: la diana trataba todas las armas como un disparo. | **Resuelta** (`f4eee1b`): salta a la diana, levanta la hoja, da el tajo y vuelve; la hoja gira también en combate. |
| OBS-003 | 2026-11-20 | Taller, aviso del robot | "¿Qué significa resistencias repetidas?" | El aviso era una frase suelta y salía repetido hasta tres veces. La regla: solo cabe un módulo por tipo de resistencia (la Matriz Defensiva da las tres). | **Resuelta** (`943b4a3`): nombra los dos módulos que chocan, una sola vez. |
| OBS-004 | 2026-11-20 | Garaje, robot nuevo | "Cuando adquiero un robot no puedo seleccionar las piernas para armarlo." | Cierto: una pieza que falta se dibuja como fantasma y el fantasma no se podía pulsar; solo las armas tenían enchufe. Con un armazón vacío no había forma de llegar a las piernas. | **Resuelta** (`4b36b63`): el torso y las piernas que faltan se pulsan en su fantasma, y además salen como casillas en la cabecera del tablero. |
| OBS-005 | 2026-11-20 | Taller, armas de hombro | "En el arma que va arriba del hombro… nada más me deja seleccionar un arma, la otra no." | Cierto: la segunda arma de hombro se dibuja casi en el mismo sitio que la primera, detrás, y el clic siempre caía en la de delante. Les pasaba lo mismo a los dos brazos de detrás. | **Resuelta** (`4b36b63`): pulsar otra vez en el mismo sitio pasa al arma de detrás, y la cabecera del tablero tiene una casilla por cada hueco de ese tipo (1, 2, 3, 4) para elegirlo directamente. |
| OBS-023 | 2026-11-20 | Taller, girar el robot | "El robot no gira en la armería; ahí debería girar con el táctil, solo desplazando, ya que no puedo tocar la otra arma." | Sí giraba, pero solo arrastrando la plataforma de sus pies o con la rueda justo encima de ella: con el cursor sobre el robot no pasaba nada. Y girado no se podían tocar sus piezas, así que girarlo no servía para llegar a la otra arma. | **Resuelta** (`4b36b63`): la rueda del ratón o desplazar con dos dedos lo giran con el cursor en cualquier parte del robot; de media vuelta (su otro perfil) las armas del otro lado quedan delante y se pulsan como siempre. |
| OBS-006 | 2026-11-20 | Misiones, con la partida delante de un jefe | (Salió al probar, no lo viste tú.) | El monitor de misiones fallaba si recibía un avance más allá del jefe; en el ejecutable cerraba el juego. El juego no produce ese estado, la prueba sí. | **Resuelta** (`e95d771`). |

## Lo que falta o no se ve

| ID | Fecha | Dónde | Lo que viste | Comprobado | Estado |
|---|---|---|---|---|---|
| OBS-007 | 2026-11-20 | Taller, mejorar | "Cuando mejoro una unidad… no cambia. Tiene que mantenerse la estructura y la mejora cambiar gradualmente… simplemente los periféricos"; la estructura evoluciona "después de pasar un jefe". | Cierto: el dibujo era el mismo en todos los niveles. | **Hecha en una sola arma, falta tu veredicto** (`ffc3544`): la Cuchilla vibratoria suma un periférico por nivel y cambia de modelo al pasar de clase. El resto del catálogo espera a que la apruebes. |
| OBS-008 | 2026-11-20 | Taller, mejorar | "Cuando mejoras un arma, ¿qué es lo que te da más? No veo ninguna estadística del arma que mejore, o que se muestre." | La pieza sí mejora: cada nivel sube todo lo suyo (daño, vida, capacidades… y también lo que gasta) según la fórmula del GDD §8, un 5 % por nivel en la clase Básica. Pero no se enseñaba el antes y el después, y el salto es pequeño (un arma de 37–48 de daño pasa a 39–50). | **Hecha en lo de enseñarlo, falta tu veredicto** (`4b36b63`): bajo la tecla de subir sale lo que cambia ("daño 37–48 → 39–50"), y si no se puede subir, por qué. **Abierta** en si el salto por nivel debe ser mayor: es balance y lo decides tú. |
| OBS-009 | 2026-11-20 | Disparos | "Cuando le doy en disparar es un efecto genérico. Una metralleta debería tener un disparo de repeticiones… y más impacto. Una escopeta, un solo tiro, pero con fragmentos, más potencia. Y así con cada tipo de arma." | En los datos cada arma tiene su disparo (39 distintos: la escopeta lanza perdigones en abanico; la ametralladora, una ráfaga). Lo que era igual para todas: un solo retroceso del arma, un solo fogonazo y diferencias pequeñas (5 balas contra 6 perdigones). | **Hecha, falta tu veredicto** (`4b36b63`): el arma retrocede y da un fogonazo en cada bala de una ráfaga; la ametralladora dispara 9 balas seguidas; la escopeta, un solo golpe fuerte con 12 fragmentos muy abiertos; el rifle, un tiro seco. Faltan por repasar una a una las demás familias (cañón, bláster, láser). |
| OBS-010 | 2026-11-20 | Taller | "No hay para cambiar el color del arma. Debería estar integrado dentro del mismo seleccionar… elegir un color, ya sea blanco, rojo, azul, de acuerdo al color del robot." | No existe. El GDD §8 lo tenía previsto ("color personalizable", con un sombreador por zonas) y no se hizo. Hoy el color de una pieza lo pone su elemento. | Abierta. |
| OBS-011 | 2026-11-20 | Enemigos | "Cada enemigo de cada liga debe ser diferente al anterior. El jefe último no puede ser la misma forma todo el tiempo." | Cierto: los rivales de las 10 zonas son 4 diseños que se repiten (cambia el arma de la zona), y los 10 jefes usan el mismo dibujo de cuerpo. | Abierta. Es sobre todo arte nuevo. |

## Diseño: cómo quieres que funcione

| ID | Fecha | Dónde | Lo que pediste | Cómo está hoy | Estado |
|---|---|---|---|---|---|
| OBS-012 | 2026-11-20 | Garaje | Adquirir robot más sencillo: robots ya armados "con las mejores combinaciones" (uno de más resistencia, otro de más ataque…), con todas las mejoras para competir con el jefe, que "cuestan un poco más que armados"; o armar uno tú a partir de un robot genérico. | La bahía ofrece un armazón vacío gratis y 4 diseños al precio de las piezas que te faltan, sin mejoras. | Abierta. |
| OBS-013 | 2026-11-20 | Asistente | "Debería aparecer desde un principio, pero como bloqueado, hasta alcanzar dicho nivel, y una vez que lo alcanzas, ahora sí, lo puedes comprar; no lo obtienes así como así." | Se regala: tienes los cuatro protocolos desde el principio y su cuna se abre sola en el nivel 3. | Abierta. |
| OBS-014 | 2026-11-20 | Combate, rivales | "Es muy predecible. Los enemigos no hacen más que atacar. No usan habilidades, no usan estrategia. Solamente el primer nivel fue realmente combativo." | La IA elige la jugada que deja mejor el marcador, que casi siempre es pegar. Los rivales normales no tienen habilidades (solo los jefes) y todos piensan igual: no hay rivales defensivos, de desgaste o que guarden la distancia. | Abierta. Hay que medirlo con el simulador antes de tocar nada. |
| OBS-015 | 2026-11-20 | Combate, pantalla | El menú de armas de abajo se integra en el robot: al pasar el ratón por tu robot se despliegan sus armas con su icono; iluminada la que se puede usar, en gris la que no; al pasar por una, su daño, su crítico y demás, en pequeño. | Hay una barra de botones abajo. | Abierta. |
| OBS-016 | 2026-11-20 | Combate, pantalla | "Cero notificaciones. Las únicas son las que aparecen cuando atacas: el daño provocado, si hubo crítico…" | Hay registro de combate y avisos de texto. | Abierta. |
| OBS-017 | 2026-11-20 | Combate, pantalla | Vida, calor y energía: con el ratón fuera del robot, sobre el propio robot, "muy pequeño… como en transparente… nada más en dibujos, gráficos. Nada de números". | Barras con números arriba. | Abierta. |
| OBS-018 | 2026-11-20 | Combate, pantalla | "Toda la pantalla es el juego." El turno solo aparece al terminar, como palabras rápidas ("como en Tekken, que dice *fight*") después de cada turno. | Indicador de turno fijo. | Abierta. |
| OBS-019 | 2026-11-20 | Estructura | Como gladiadores: 10 ligas; en cada una, robots con armas de ese nivel; el jefe es el campeón de la liga. Liga 1, armas básicas; liga 2, más avanzadas; liga 3, más aún. "Cada arma es una evolución de la anterior." | 10 zonas de 10 combates y un jefe. La clase de las armas sube cada dos zonas, no cada una. La evolución de arma en arma ya existe (balas → cañón → bláster → láser). | Abierta: decidir si cada liga sube de clase. |
| OBS-020 | 2026-11-20 | Estructura | "Cuando inicias campaña, los dos modos se bloquean, tanto libre como arena. Debes acabar la campaña sí o sí… 10 peleas seguidas. Cada contrincante es más difícil que el anterior. Si pierdes una vez en la campaña, pierdes tu progreso de todo… vuelves a comenzar desde un principio como estabas." | Campaña, arena y libre están siempre abiertos. Perder un combate normal no quita nada (paga 60 celdas). Solo perder contra el jefe reinicia la partida. | Abierta. **Falta aclarar** qué se pierde: ¿solo el avance de esa liga (vuelves al primer combate con tu robot tal como estaba al empezarla) o todo, robot y celdas incluidos? |
| OBS-021 | 2026-11-20 | Economía | Empiezas con lo más básico, "literal con un palo": un solo arma. La arena paga menos que la campaña ("en la campaña consigues 500, en la arena 300"). Vencer al jefe da un premio grande ("20 000, 25 000 créditos") que alcanza para el equipo básico de la liga siguiente, "pero no lo más top": una cosa u otra. | Empiezas con un robot completo (4 armas de brazo, 1 de hombro y módulos). Arena y campaña pagan lo mismo (250). El jefe paga 2 500. | Abierta. |
| OBS-022 | 2026-11-20 | Piezas | El escudo: "te da una protección casi completa al primer ataque"; se compra. | Hay un escudo de energía, pero es una habilidad del árbol, no una pieza que se compra. | Abierta. |

## Orden propuesto

1. **Lo que estorba al jugar ahora** (hecho, `4b36b63`): OBS-004, OBS-005, OBS-023, OBS-008 y el primer paso de OBS-009.
2. **Reglas de la campaña y economía** (OBS-019 a OBS-022, OBS-012, OBS-013): son reglas del juego; conviene cerrarlas juntas porque el balance entero depende de ellas. Antes hay que aclarar OBS-020.
3. **Pantalla del combate** (OBS-015 a OBS-018): un solo bloque, con el mismo criterio que el hangar.
4. **Rivales** (OBS-014 y OBS-011): primero el comportamiento, que se mide con el simulador; después el arte de rivales y jefes.
5. **Arte**: el resto de la evolución de las piezas (OBS-007) cuando des el visto bueno a la espada, y el color de las piezas (OBS-010).
