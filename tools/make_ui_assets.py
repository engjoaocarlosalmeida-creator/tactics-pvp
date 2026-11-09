#!/usr/bin/env python3
"""Gera as texturas 9-slice dos menus no estilo clássico de RPG de 16 bits (janela azul com borda creme)."""
import os
from PIL import Image, ImageDraw

OUT = "assets/ui"
CREAM = (238, 230, 196)
GOLD = (255, 214, 90)
NAVY_DARK = (6, 10, 52)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def box(size, top, bottom, outer, inner_shadow=NAVY_DARK, highlight=None, border=2, cut=2, fill_alpha=255):
    w = h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / (h - 1)) + (fill_alpha,))
    # bordas: externa (cor), sombra interna escura, brilho interno opcional
    for i in range(border):
        d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=outer + (255,))
    d.rectangle([border, border, w - 1 - border, h - 1 - border], outline=inner_shadow + (255,))
    if highlight:
        d.rectangle([border + 1, border + 1, w - 2 - border, h - 2 - border], outline=highlight + (255,))
    # cantos "cortados" (cara de pixel art)
    for cx, cy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        sx = 1 if cx == 0 else -1
        sy = 1 if cy == 0 else -1
        for k in range(cut):
            for j in range(cut - k):
                img.putpixel((cx + sx * k, cy + sy * j), (0, 0, 0, 0))
    return img


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(f"{OUT}/{name}.png")


if __name__ == "__main__":
    save(box(48, (30, 46, 150), (8, 12, 70), CREAM, highlight=(84, 104, 210), border=2, cut=3, fill_alpha=205), "window")
    save(box(32, (36, 54, 140), (14, 22, 84), (176, 188, 232), highlight=(70, 90, 190), border=2, cut=2, fill_alpha=225), "button_normal")
    save(box(32, (66, 92, 200), (28, 44, 130), GOLD, highlight=(150, 170, 240), border=2, cut=2, fill_alpha=235), "button_hover")
    save(box(32, (10, 16, 56), (24, 36, 110), GOLD, highlight=(40, 56, 140), border=2, cut=2, fill_alpha=235), "button_pressed")
    save(box(32, (22, 26, 52), (14, 16, 36), (84, 90, 120), highlight=None, border=2, cut=2, fill_alpha=200), "button_disabled")
    save(box(32, (4, 6, 30), (10, 14, 56), (176, 188, 232), highlight=None, border=2, cut=2, fill_alpha=225), "field")
    save(box(24, (96, 82, 62), (60, 48, 36), GOLD, highlight=None, border=2, cut=1), "portrait_frame")
    print("ok")
