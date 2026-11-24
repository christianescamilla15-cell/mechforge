"""Separar la figura del fondo liso de las imagenes generadas.

Solo numpy y OpenCV: no carga los modelos, asi que sirve tambien para las
herramientas que no usan la GPU.
"""

import cv2
import numpy as np
from PIL import Image


def foreground_mask(image, tolerance=14):
    """Separa la figura del fondo liso: es fondo lo que se parece al color del
    borde y ademas esta conectado con el borde."""
    pixels = np.asarray(image.convert("RGB")).astype(np.int16)
    border = np.concatenate(
        [pixels[:6].reshape(-1, 3), pixels[-6:].reshape(-1, 3), pixels[:, :6].reshape(-1, 3), pixels[:, -6:].reshape(-1, 3)]
    )
    background_color = np.median(border, axis=0)
    similar = (np.abs(pixels - background_color).max(axis=2) < tolerance).astype(np.uint8)
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
    alarga un 2-5 %). Si ninguna vale, la de siempre. Devuelve
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
            return mask, tolerance
    return base, 14


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
