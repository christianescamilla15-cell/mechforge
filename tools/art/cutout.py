"""Separar la figura del fondo liso de las imagenes generadas.

Solo numpy y OpenCV: no carga los modelos, asi que sirve tambien para las
herramientas que no usan la GPU.
"""

import cv2
import numpy as np
from PIL import Image


def background_difference(image):
    """Por pixel, cuanto se aparta del color del fondo (la mediana del borde
    de la imagen), en el canal que mas se aparta."""
    pixels = np.asarray(image.convert("RGB")).astype(np.int16)
    border = np.concatenate(
        [pixels[:6].reshape(-1, 3), pixels[-6:].reshape(-1, 3), pixels[:, :6].reshape(-1, 3), pixels[:, -6:].reshape(-1, 3)]
    )
    background_color = np.median(border, axis=0)
    return np.abs(pixels - background_color).max(axis=2)


def foreground_mask(image, tolerance=14):
    """Separa la figura del fondo liso: es fondo lo que se parece al color del
    borde y ademas esta conectado con el borde."""
    similar = (background_difference(image) < tolerance).astype(np.uint8)
    _, labels = cv2.connectedComponents(similar, connectivity=4)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    edge_labels = edge_labels[edge_labels != 0]
    return ~np.isin(labels, edge_labels)


def clean_figure(image, tolerance=14):
    """Mascara de la figura principal, sin la linea de suelo ni motas sueltas."""
    figure = foreground_mask(image, tolerance).astype(np.uint8)
    # Abrir la mascara quita lo fino: la linea de sombra bajo los pies.
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    opened = cv2.morphologyEx(figure, cv2.MORPH_OPEN, kernel)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(opened, connectivity=8)
    if count <= 1:
        return opened.astype(bool)
    areas = stats[1:, cv2.CC_STAT_AREA]
    keep = [1 + index for index, area in enumerate(areas) if area >= 0.02 * areas.max()]
    main = np.isin(labels, keep).astype(np.uint8)
    # Devolver el borde que se comio la apertura, solo pegado a la figura.
    return np.logical_and(cv2.dilate(main, kernel).astype(bool), figure.astype(bool))


def filled_outline(mask, close=25):
    """La mascara con sus huecos rellenos, tras cerrar los cortes de su
    contorno: lo que queda dentro de la silueta."""
    shape = cv2.morphologyEx(
        mask.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (close, close))
    )
    outside = np.pad(shape, 1)
    cv2.floodFill(outside, None, (0, 0), 1)
    return shape.astype(bool) | (outside[1:-1, 1:-1] == 0)


def glow_free_figure(image, tolerances=(45, 35, 25), lost_inside=0.01, keep=0.9):
    """Mascara de la figura sin el brillo ni la sombra suaves que la rodean
    (las fases altas de las armas los pintan, y con la tolerancia de siempre
    se quedaban pegados como un halo). Prueba de la tolerancia mas alta a la
    mas baja y se queda con la primera que solo quita por fuera: el brillo
    esta fuera del contorno de la pieza, y una pieza clara sobre el fondo
    claro se vacia por dentro (el cuerpo de la ancla laser en la fase 7). Lo
    que quita dentro de la silueta no pasa de `lost_inside` de la figura, y
    la pieza no pierde mas largo que el del brillo (`keep`; el brillo la
    alarga un 2-5 %). Si ninguna vale, la de siempre. A la elegida se le
    devuelven las piezas claras que dejo fuera (`lost_pieces`). Devuelve
    (mascara, tolerancia)."""
    base = clean_figure(image)
    columns = np.where(base.any(axis=0))[0]
    if columns.size == 0:
        return base, 14
    width = columns[-1] - columns[0] + 1
    for tolerance in tolerances:
        mask = clean_figure(image, tolerance)
        kept = np.where(mask.any(axis=0))[0]
        if kept.size == 0 or kept[-1] - kept[0] + 1 < keep * width:
            continue
        lost = base & ~mask
        if (lost & filled_outline(mask)).sum() <= lost_inside * base.sum():
            return mask | lost_pieces(image, mask, base), tolerance
    return base, 14


def lost_pieces(image, mask, base, min_radius=8.0, min_difference=20.0, keep=0.8):
    """De lo que una tolerancia alta deja fuera de la figura (`base` sin
    `mask`), los trozos que son pieza y no brillo. Una pieza clara sobre el
    fondo claro (la espuela del pie de ligero_14 en su fase 1, la boca del
    canon corto en la 5, los canones del laser de bateria en la 5) se iba con
    el halo porque queda por fuera del contorno de lo que si se ve. Es pieza
    el trozo que:
    - es grueso: su radio inscrito llega a `min_radius` (la sombra del suelo
      y los bordes sueltos son finos);
    - tiene color propio: cerca de la figura se aparta del fondo al menos
      `min_difference` (las estelas y neblinas palidas se quedan en 19);
    - no se apaga hacia fuera: lejos de la figura conserva al menos `keep` de
      lo que se aparta cerca. El brillo se apaga al alejarse (de 28 a 16); una
      pieza mantiene su color hasta su borde, o lo oscurece con su linea.
    Medido el 2026-11-24 sobre las fases exportadas de armas, torsos y
    piernas. No distingue un halo claro pintado pegado a la linea del
    contorno (el blaster medio en su fase 4 lo devuelve como una banda gris
    alrededor): lo exportado se revisa a ojo. Devuelve la mascara de lo que
    hay que devolver."""
    lost = (base & ~mask).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(lost, connectivity=8)
    back = np.zeros(mask.shape, bool)
    if count <= 1:
        return back
    radius = cv2.distanceTransform(lost, cv2.DIST_L2, 5)
    reach = cv2.distanceTransform((~mask).astype(np.uint8), cv2.DIST_L2, 5)
    difference = background_difference(image).astype(float)
    for index in range(1, count):
        if stats[index, cv2.CC_STAT_AREA] < np.pi * min_radius * min_radius:
            continue
        piece = labels == index
        if radius[piece].max() < min_radius:
            continue
        far_from, values = reach[piece], difference[piece]
        low, high = far_from.min(), far_from.max()
        near = values[far_from <= low + (high - low) / 3].mean()
        far = values[far_from >= low + 2 * (high - low) / 3].mean()
        if near >= min_difference and far >= keep * near:
            back |= piece
    return back


def drop_holes(image, mask, tolerance=14, min_area=1000):
    """Quita de la mascara los huecos de fondo encerrados por la figura (de
    frente, el hueco entre las piernas cuando los pies se tocan). Solo los
    grandes: las motas del color del fondo dentro de una pieza se quedan."""
    pixels = np.asarray(image.convert("RGB")).astype(np.int16)
    border = np.concatenate([pixels[:6].reshape(-1, 3), pixels[-6:].reshape(-1, 3)])
    background_color = np.median(border, axis=0)
    similar = (np.abs(pixels - background_color).max(axis=2) < tolerance) & mask
    count, labels, stats, _ = cv2.connectedComponentsWithStats(similar.astype(np.uint8), connectivity=4)
    holes = [i for i in range(1, count) if stats[i, cv2.CC_STAT_AREA] >= min_area]
    return mask & ~np.isin(labels, holes)


def to_rgba(image, mask):
    """Imagen con transparencia: opaca donde la mascara, con el borde suavizado."""
    alpha = cv2.GaussianBlur(mask.astype(np.uint8) * 255, (3, 3), 0)
    rgba = np.dstack([np.asarray(image.convert("RGB")), alpha])
    return Image.fromarray(rgba, "RGBA")
