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
