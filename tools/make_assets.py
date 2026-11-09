#!/usr/bin/env python3
"""Gera as imagens simplificadas das classes (sprites e retratos) a partir das folhas de personagem
em art_source/. Roda uma vez quando a arte muda; o resultado fica em assets/classes/."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = sys.argv[1] if len(sys.argv) > 1 else "art_source"
OUT = "assets/classes"
BODY_H = 96     # altura do sprite de corpo inteiro (px)
FACE = 48       # retrato quadrado (px)
COLORS = 24
OUTLINE = (28, 20, 18)

BOX = {
    "aprendiz":  {"m": (285, 0, 705, 1010), "f": (798, 10, 1190, 1005), "mf": (5, 15, 268, 215), "ff": (1205, 0, 1536, 218)},
    "arqueiro":  {"m": (255, 0, 668, 1010), "f": (830, 55, 1270, 985), "mf": (25, 225, 258, 470), "ff": (1277, 135, 1530, 375)},
    "escudeiro": {"m": (290, 0, 775, 1005), "f": (800, 0, 1190, 1005), "mf": (20, 15, 262, 212), "ff": (1275, 10, 1510, 215)},
    "lutador":   {"m": (335, 0, 748, 1005), "f": (820, 0, 1198, 995), "mf": (10, 10, 340, 295), "ff": (1170, 10, 1525, 295)},
}


# retangulos (relativos ao recorte) pintados com a cor do papel antes de processar: apagam
# detalhes da folha que encostam no personagem
ERASE = {("arqueiro", "f"): [(305, 535, 440, 930)]}


def paper_like(a):
    """Pixels com cor/brilho de papel bege (inclui as sombras suaves do chao)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bright = a.max(axis=2)
    return (bright > 150) & (r - b >= 8) & (r - b <= 50) & (r - g >= 0) & (r - g <= 22) & (g - b >= 0) & (g - b <= 35)


def remove_background(img, tol=34):
    """Apaga o fundo bege (e as sombras do chao) e fica so com a maior figura."""
    a = np.asarray(img.convert("RGB")).astype(int)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    close = np.sqrt(((a - bg) ** 2).sum(axis=2)) < tol
    lab, n = ndimage.label(close)
    edge_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = np.isin(lab, list(edge_labels))
    fg = ~bgmask
    paper = paper_like(a)
    # vaos entre as pernas e sombras do chao: so componentes grandes de "papel" na parte de baixo
    lower = paper & (np.arange(a.shape[0])[:, None] > 0.55 * a.shape[0])
    plab, pn = ndimage.label(lower)
    if pn:
        psizes = ndimage.sum(lower, plab, range(1, pn + 1))
        big = [i + 1 for i, sz in enumerate(psizes) if sz > 1800]
        fg &= ~np.isin(plab, big)
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    if n > 1:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = lab == (1 + int(np.argmax(sizes)))
    # corta as sombras abaixo da sola das botas (ultima linha com pixels escuros)
    dark = (a.max(axis=2) < 120) & fg
    rows = np.where(dark.sum(axis=1) >= 3)[0]
    if len(rows):
        fg[rows.max() + 3:, :] = False
    rgba = np.dstack([a.astype(np.uint8), (fg * 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def trim(img, pad=2):
    bbox = img.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    img = img.crop(bbox)
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    out.paste(img, (pad, pad))
    return out


def quantize_keep_alpha(img, colors=COLORS):
    alpha = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    rgb = img.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def add_outline(img):
    a = np.asarray(img.getchannel("A")) > 0
    grown = ndimage.binary_dilation(a, structure=np.ones((3, 3)))
    ring = grown & ~a
    arr = np.asarray(img).copy()
    arr[ring] = (*OUTLINE, 255)
    return Image.fromarray(arr, "RGBA")


def punch(img):
    from PIL import ImageEnhance
    img = ImageEnhance.Color(img).enhance(1.35)
    return ImageEnhance.Contrast(img).enhance(1.12)


def make_body(img):
    sprite = trim(remove_background(img))
    sprite = Image.merge("RGBA", (*punch(sprite.convert("RGB")).split(), sprite.getchannel("A")))
    w = max(8, round(sprite.width * (BODY_H - 4) / sprite.height))
    sprite = sprite.resize((w, BODY_H - 4), Image.Resampling.BOX)
    sprite = quantize_keep_alpha(sprite)
    sprite = add_outline(trim(sprite, pad=1))
    return sprite


def make_face(img):
    s = min(img.size)
    left, top = (img.width - s) // 2, (img.height - s) // 2
    img = punch(img.crop((left, top, left + s, top + s)).resize((FACE, FACE), Image.Resampling.BOX).convert("RGB"))
    return img.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for job, boxes in BOX.items():
        sheet = Image.open(os.path.join(SRC, job.capitalize() + ".png")).convert("RGB")
        for look in ("m", "f"):
            body = sheet.crop(boxes[look])
            for rect in ERASE.get((job, look), []):
                body.paste(tuple(int(v) for v in np.median(np.asarray(body)[:8, :8].reshape(-1, 3), axis=0)), rect)
            make_body(body).save(f"{OUT}/{job}_{look}_body.png")
            make_face(sheet.crop(boxes[look + "f"] if False else boxes["mf" if look == "m" else "ff"])).save(f"{OUT}/{job}_{look}_face.png")
    print("ok")
