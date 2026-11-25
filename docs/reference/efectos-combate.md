# Efectos de combate: lo que hacían los clásicos y lo que nos falta

Investigación del 2026-11-24 para OBS-052 ("juegos de hace 30 años tenían efectos increíbles visuales y no pesaban más de un mega, ahí está KOF, REVIL, KRATOS"). Solo se toman **técnicas**: nada del arte, los sprites, los sonidos ni los nombres de esos juegos. Presupuesto que dio el usuario: "hasta 1 GB o más, depende de la calidad".

## Lo que hacían

**KOF / Neo Geo.** 380 sprites, 256 paletas de 15 colores; la paleta se reescribe en cualquier momento, así que un destello blanco o un cambio de color cuestan uno o dos cuadros sin memoria extra (neogeodev, fiabilidad alta). Sin transparencia: lo translúcido parpadeaba cuadro sí, cuadro no. El "super flash" (pantalla congelada y oscurecida al lanzar un súper) marca el momento (glosario de Infil). Pausa al golpear (hitstop): del orden de 8 a 16 cuadros según la fuerza en los juegos de lucha clásicos (varias fuentes, fiabilidad media); Smash Ultimate usa ⌊daño × 0.65 + 6⌋ cuadros, tope 30, × 1.5 en eléctricos (datos extraídos del juego). Sakurai: la víctima tiembla más que el atacante, el temblor se apaga poco a poco y el atacante sigue moviéndose un poco.

**Resident Evil (PS1).** 1 MB de VRAM, texturas de 256 × 256 con paleta y cuatro mezclas fijas (B/2+F/2, B+F, B−F, B+F/4; psx-spx, alta): la suma (B+F) da el resplandor de fogonazos y fuego con texturas mínimas.

**God of War (PS2).** Cada golpe lleva pausa de atacante y víctima mientras el mundo sigue (Jason de Heras, diseñador de combate de GoW3); en GoW 2018 el objetivo salta a su pose de golpe, se congelan los dos, y bajaron la sacudida de cámara para que se lea mejor, compensándolo con sonido (PlayStation Blog).

**"Game feel".** Vlambeer, "Art of Screenshake": pausa al golpear, fogonazo, explosiones más grandes, restos que se quedan, cámara que retrocede, cámara lenta. "Juice it or lose it" (GDC 2012): destellos, sacudida, curvas de animación, partículas. Eiserloh (GDC 2016): sacudida por "trauma" 0–1 que decae, con ruido y algo de rotación.

## Lo que tenemos (2026-11-24)

Fogonazo en círculo, 12 caminos y 17 cuerpos de proyectil con estela (`ShotFx`), golpe con `modulate` y temblor (`MechView.hit`), cinco impactos dibujados con círculos y líneas en mezcla normal, sacudida de cámara de seno y coseno con caída lineal (`ArenaView.shake`), crítico con sonido, sacudida y texto, muerte con cuatro estrellas, materia oscura con carga, núcleo negro y explosión.

## Lo que falta

- La pausa al golpear (la pide el GDD §11, punto 4, y §12.2).
- Un destello blanco de verdad: `modulate` multiplica y una pieza oscura nunca llega a blanco.
- Destello del color del elemento.
- Oscurecer la pantalla en el crítico y en la materia oscura.
- Estelas de imágenes fantasma, vapor al enfriar (GDD §12.2).
- Piezas que saltan y cámara lenta en el KO.
- Impactos distintos por elemento: hoy solo cambia el color.
- Chispas con gravedad.
- Mezcla aditiva y distorsión de pantalla. Choca con el GDD §12.0 ("color plano, no partículas brillantes genéricas"): lo decide el usuario.

## Propuesta priorizada

| # | Técnica | Cómo en Godot | Dónde | Esfuerzo |
|---|---|---|---|---|
| 1 | Pausa al golpear: ligero 3 cuadros, medio 6, grave 9, crítico +4, KO 20; dividida por la velocidad (mínimo 2) | `process_mode` desactivado en los dos `MechView` y en los disparos mientras la arena sigue sacudiendo. No `Engine.time_scale`: ya lo usa la pausa del juego | `BattleScreen._play_event`, `ArenaView` | Pequeño |
| 2 | Destello con shader: 2 cuadros en blanco, luego 4–6 del color del elemento | `ShaderMaterial` con `mix(COLOR.rgb, flash_color, flash)` | `MechView.hit` | Pequeño |
| 3 | Crítico tipo "super flash" | Capa negra al 50 % durante 4–6 cuadros, estrella, zoom que decae, pausa más larga | ramas `crit` de `_play_event` | Pequeño |
| 4 | Sacudida por trauma | `FastNoiseLite`, trauma², hasta 1.5° de giro y empujón en la dirección del disparo | `ArenaView.shake` | Pequeño |
| 5 | Chispas a cuadros (12 fps) con gravedad y rebote | En `ShotFx`, con el trazo de tinta | `ShotFx._sparks` | Pequeño |
| 6 | Impactos por elemento: físico con esquirlas y abolladura, calor con brasas y calima, energía con rayos dentados y parpadeo | `ShotFx._impact` con el elemento; calima con `hint_screen_texture` | `ShotFx`, `MechWear` | Medio |
| 7 | Materia oscura con super flash: mundo oscurecido, el tirador encima, onda de distorsión | `ArenaView.dark_matter` | | Medio |
| 8 | Mezcla aditiva para láser, plasma y fuego (el humo y el negro, en mezcla normal) | Dos capas en `ShotFx` | | Medio, **decisión del usuario** |
| 9 | KO completo: pausa de 20 cuadros, cámara lenta del caído, 5–7 explosiones, piezas sueltas con gravedad y giro | `MechView.destroy` | | Medio-grande |
| 10 | Estelas fantasma en embestida, teletransporte y salto | Copias de `MechView` que se desvanecen en 0.15 s | `dash_to`, `blink_to`, `jump_to` | Medio |
| 11 | Vapor al enfriar | Bocanadas que suben | rama `"cool"` | Pequeño |

Todo se escala con la velocidad del combate (1, 1.5, 2, 3). Las pausas suman menos de 0.3 s por turno a 1×. Conviene un ajuste "impactos completos / reducidos" y no pasar de 3 destellos de pantalla completa por segundo (WCAG 2.3.1).

## Con presupuesto de 1 GB

- **Cómo producirlos.** SDXL no sirve para secuencias (cada cuadro sale distinto y parpadea): sirve para fotogramas clave sueltos (estallido, arco de tajo, estrella, rayo) animados con escala, giro y un "dissolve". Blender (instalado) puede simular humo y fuego con sombreado a bandas y contorno de tinta (Line Art), en el estilo del juego, 32–48 cuadros; comparte la GPU, así que pasa por `tools/art/run.ps1`. Godot mismo puede renderizar los efectos de código a alta resolución, como `tools/*_frames.gd`.
- **Una hoja para los tres elementos:** en grises, coloreada por un shader de rampa por elemento (el cambio de paleta de KOF): tres o cuatro veces menos memoria y paleta coherente.
- **Reproducir:** `AnimatedSprite2D` con `speed_scale` = velocidad del combate, o `Sprite2D` con `hframes`/`vframes`.
- **Memoria:** un efecto de 32 cuadros a 512 px ocupa 32 MiB en RGBA8; a 1024 px, 128 MiB. En pantalla miden 150–400 px, así que 512 basta. Cargar por combate solo los de las armas montadas (`ResourceLoader.load_threaded_request` durante el cartel de inicio); meta de 300–500 MB.
- **Mezcla:** hojas para los momentos estrella (explosión, tajo, ráfaga de energía, KO) y código para el ritmo (pausa, destello, sacudida, haces, estelas).

## Fuentes

- https://wiki.neogeodev.org/index.php/General_specifications · https://wiki.neogeodev.org/index.php/Palettes · https://wiki.neogeodev.org/index.php/Sprite_shrinking
- https://glossary.infil.net (Screen Freeze / Super Flash)
- https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/
- https://www.ssbwiki.com/Hitlag
- https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/
- https://psx-spx.consoledev.net/graphicsprocessingunitgpu/ · https://www.copetti.org/writings/consoles/playstation/ · https://www.copetti.org/writings/consoles/playstation-2/
- https://threadreaderapp.com/scrolly/1385104062157254660 (Jason de Heras) · https://blog.playstation.com/?p=370399
- https://www.youtube.com/watch?v=AJdEqssNZ-U (Art of Screenshake) · https://gdcvault.com/play/1016487/ · https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing
- https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html · https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html · https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html
