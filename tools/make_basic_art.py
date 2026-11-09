#!/usr/bin/env python3
"""Gera a arte basica de apoio (placeholder organizado) a partir de codigo:
 - icones de acoes, itens, classes, sexo e ajuda (pixel art 16x16 ampliado para 32x32)
 - sprites PROVISORIOS das 4 classes sem arte final (Cavaleiro, Mago, Sacerdote, Ladrao),
   derivados do sprite da classe base (precisa dos sprites base gerados por tools/make_assets.py)
 - textura de detalhe do terreno e icone do jogo
Uso (na raiz do projeto): python tools/make_basic_art.py   (requer: pillow, numpy)
Saida: assets/icons, assets/classes (provisorios), assets/ui/terrain_detail.png e game_icon.png."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

PAL = {
    ".": None, "k": (28, 20, 18), "w": (240, 236, 214), "g": (255, 214, 90), "G": (200, 150, 40),
    "s": (190, 198, 214), "S": (120, 128, 150), "b": (96, 150, 255), "B": (40, 80, 190),
    "r": (225, 70, 60), "R": (140, 30, 30), "n": (150, 100, 60), "N": (96, 60, 34),
    "p": (170, 110, 230), "P": (100, 60, 160), "e": (90, 200, 110), "E": (40, 120, 60),
    "y": (255, 240, 150), "o": (240, 150, 60),
}
ICONS = {
 "move": ["................", "................", ".......k........", ".......kk.......", ".......kbk......", "kkkkkkkkbbk.....", "kbbbbbbbbbbk....", "kbbbbbbbbbbbk...", "kbbbbbbbbbbk....", "kkkkkkkkbbk.....", ".......kbk......", ".......kk.......", ".......k........", "................", "................", "................"],
 "attack": ["..............kk", "............kssk", "...........kssk.", "..........kssk..", ".........kssk...", "........kssk....", ".k.....kssk.....", "kgk...kssk......", ".kgk.kssk.......", "..kgkssk........", "...kggk.........", "..knkgk.........", ".knk.kk.........", "knk.............", "kk..............", "................"],
 "items": ["................", "......kkkk......", ".....kGggGk.....", "....kGggggGk....", "...kkkkkkkkkk...", "..knnnnnnnnnnk..", "..knNNNNNNNNnk..", "..knnnnggnnnnk..", "..knnnnggnnnnk..", "..knNNNNNNNNnk..", "..knnnnnnnnnnk..", "...kkkkkkkkkk...", "................", "................", "................", "................"],
 "switch": ["................", "................", "...kkkkkkkk.....", "..kbbbbbbbbk....", "..kbbbbbbbbbk...", "...kkkkkkkbbbk..", "..........kbk...", "...........k....", "...k............", "..kbk..........", "..kbbbkkkkkkk...", "...kbbbbbbbbbk..", "....kbbbbbbbk...", ".....kkkkkkk....", "................", "................"],
 "end": ["................", "....kkkkkkkk....", "...krrrrrrrrk...", "..krrrwwwwrrrk..", "..krrwkkkkwrrk..", "..krrwkrrkwrrk..", "..krrwkrrkwrrk..", "..krrwkkkkwrrk..", "..krrrwwwwrrrk..", "...krrrrrrrrk...", "....kkkkkkkk....", "................", "................", "................", "................", "................"],
 "sword": ["..............kk", "............kssk", "...........kssk.", "..........kssk..", ".........kssk...", "........kssk....", ".k.....kssk.....", "kgk...kssk......", ".kgk.kssk.......", "..kgkssk........", "...kggk.........", "..knkgk.........", ".knk.kk.........", "knk.............", "kk..............", "................"],
 "bow": ["....kk..........", "...knnk.........", "..kn.nk.........", "..kn..nk........", ".kn....nk.......", ".kn.....nk......", ".kn.....nk......", ".kn.....nk......", ".kn.....nk......", ".kn....nk.......", "..kn..nk........", "..kn.nk.........", "...knnk.........", "....kk..........", "................", "................"],
 "staff": ["......kkkk......", ".....kyyyyk.....", ".....kyggyk.....", ".....kyyyyk.....", "......kkkk......", ".......kn.......", ".......kn.......", ".......kn.......", ".......kN.......", ".......kn.......", ".......kn.......", ".......kN.......", ".......kn.......", ".......kn.......", ".......kk.......", "................"],
 "shield": ["................", "..kkkkkkkkkkk...", "..kBBBBkBBBBk...", "..kBBBBkBBBBk...", "..kkkkkkkkkkk...", "..kBBBBkBBBBk...", "..kBBBBkBBBBk...", "...kBBBkBBBk....", "...kBBBkBBBk....", "....kBBkBBk.....", ".....kBBBk......", "......kBk.......", ".......k........", "................", "................", "................"],
 "armor_leather": ["................", "..kkk......kkk..", ".knnnk....knnnk.", ".knnnnkkkknnnnk.", ".kNnnnnnnnnnnNk.", "..kNnnnnnnnnNk..", "...knnnnnnnnnk..", "...knnnggnnnnk..", "...knnnggnnnnk..", "...kNnnnnnnNnk..", "...kNnnnnnnNnk..", "...kkkkkkkkkkk..", "................", "................", "................", "................"],
 "armor_iron": ["................", "..kkk......kkk..", ".kssskk..kksssk.", ".ksSssskkksSssk.", ".kSsssssssssSk..", "..kSssssssssSk..", "...ksssSSsssSk..", "...ksssSSssssk..", "...ksssSSssssk..", "...kSsssssssSk..", "...kSSssssssSk..", "...kkkkkkkkkkk..", "................", "................", "................", "................"],
 "potion": ["................", "......kkkk......", ".......kk.......", "......kssk......", ".....kk..kk.....", "....krrrrrrk....", "...krrwrrrrrk...", "...krrwrrrrrk...", "...krrrrrrrrk...", "...kRrrrrrrRk...", "....kRRRRRRk....", ".....kkkkkk.....", "................", "................", "................", "................"],
 "rope": ["................", "....kkkkkkk.....", "...knnNnnnnk....", "..knnk...kNnk...", "..knk.....knk...", "..kNk.....knk...", "..knk.....kNk...", "..knnk...knnk...", "...knnnnnnnk....", "....kNnnNnk.....", ".....kkkkk......", "................", "................", "................", "................", "................"],
 "hp": ["................", "................", "..kkk....kkk....", ".krrrk..krrrk...", "krrwrrkkrrrrrk..", "krrwrrrrrrrrrk..", "krrrrrrrrrrrrk..", ".krrrrrrrrrrk...", "..krrrrrrrrk....", "...krrrrrrk.....", "....krrrrk......", ".....krrk.......", "......kk........", "................", "................", "................"],
 "lock": ["................", "......kkkk......", ".....kSssSk.....", ".....ks..sk.....", ".....ks..sk.....", "...kkkkkkkkkk...", "...kGggggggGk...", "...kgggkkgggk...", "...kgggkkgggk...", "...kGggggggGk...", "...kkkkkkkkkk...", "................", "................", "................", "................", "................"],
 "gear": ["................", "......kk........", "...kk.kk.kk.....", "..kssksskkssk...", "...kssssssssk...", ".kksskkkkksskk..", ".ksssk...kssssk.", "kssssk...kssssk.", ".ksssk...kssssk.", ".kksskkkkksskk..", "...kssssssssk...", "..kssksskkssk...", "...kk.kk.kk.....", "......kk........", "................", "................"],
}
EMBLEMS = {"escudeiro": "shield", "aprendiz": "staff", "lutador": "sword", "cavaleiro": "armor_iron",
           "arqueiro": "bow", "sacerdote": "potion", "mago": "staff", "ladrao": "rope"}


def draw_icon(rows, scale=2):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row[:16]):
            c = PAL.get(ch)
            if c:
                img.putpixel((x, y), c + (255,))
    return img.resize((16 * scale, 16 * scale), Image.Resampling.NEAREST)


def sex_icon(kind, color):
    """Simbolo de masculino (azul) ou feminino (rosa) desenhado com linhas (nao depende de fonte)."""
    S = 8
    im = Image.new("RGBA", (16 * S, 16 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = int(1.6 * S)
    if kind == "m":
        d.ellipse([2 * S, 6 * S, 10 * S, 14 * S], outline=color, width=w)
        d.line([(8.5 * S, 7.5 * S), (13.5 * S, 2.5 * S)], fill=color, width=w)
        d.line([(9 * S, 2 * S), (14 * S, 2 * S)], fill=color, width=w)
        d.line([(14 * S, 2 * S), (14 * S, 7 * S)], fill=color, width=w)
    else:
        d.ellipse([3.5 * S, 1.5 * S, 12.5 * S, 10.5 * S], outline=color, width=w)
        d.line([(8 * S, 10.5 * S), (8 * S, 15 * S)], fill=color, width=w)
        d.line([(5 * S, 12.8 * S), (11 * S, 12.8 * S)], fill=color, width=w)
    return im.resize((16, 16), Image.Resampling.LANCZOS)


def make_icons():
    os.makedirs("assets/icons", exist_ok=True)
    for name, rows in ICONS.items():
        draw_icon(rows).save(f"assets/icons/{name}.png")
    for job, icon in EMBLEMS.items():
        draw_icon(ICONS[icon]).save(f"assets/icons/class_{job}.png")
    sex_icon("m", (90, 169, 255, 255)).save("assets/icons/sex_m.png")
    sex_icon("f", (255, 122, 184, 255)).save("assets/icons/sex_f.png")
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 29, 29], fill=(20, 32, 110, 255), outline=(238, 230, 196, 255), width=2)
    f = ImageFont.truetype("assets/fonts/Marcellus-Regular.ttf", 24)
    d.text((16, 16), "?", font=f, fill=(255, 214, 90, 255), anchor="mm")
    im.save("assets/icons/help.png")


def head_info(img):
    a = np.asarray(img)[..., 3] > 0
    rows = np.where(a.any(axis=1))[0]
    top = int(rows.min())
    xs = np.where(a[top:top + 5].any(axis=0))[0]
    return int(xs.mean()), top


def paint(img, cx, y_bottom, rows, scale=1.7):
    acc = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            c = PAL.get(ch)
            if c:
                acc.putpixel((dx, dy), c + (255,))
    acc = acc.resize((round(acc.width * scale), round(acc.height * scale)), Image.Resampling.NEAREST)
    img.alpha_composite(acc, (cx - acc.width // 2, y_bottom - acc.height))


HAT = [".....kk.....", "....kPPk....", "...kPPPPk...", "...kPPpPk...", "..kPPPPPPk..", ".kPPPPPPPPk.", "kkkkkkkkkkkk"]
PLUME = ["...kk...", "..krRk..", ".krRRk..", "..kRrk..", "...kk..."]
HALO = [".kkkkkkkk.", "kggyyyyggk", ".kkkkkkkk."]
HOOD = ["..kkkkkk..", ".kNNNNNNk.", "kNNkkkkNNk"]


def tint(img, rgb, strength):
    a = np.asarray(img).astype(float)
    mask = a[..., 3] > 0
    for c in range(3):
        a[..., c] = np.where(mask, a[..., c] * (1 - strength) + rgb[c] * strength, a[..., c])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def variant(base, job):
    img = Image.open(base).convert("RGBA")
    cx, top = head_info(img)
    pad = 22
    canvas = Image.new("RGBA", (img.width + 8, img.height + pad), (0, 0, 0, 0))
    canvas.paste(img, (4, pad))
    img = canvas
    cx += 4
    top += pad
    if job == "mago":
        img = tint(img, (110, 80, 190), 0.16)
        paint(img, cx, top + 5, HAT)
    elif job == "sacerdote":
        img = tint(img, (250, 244, 220), 0.16)
        paint(img, cx, top - 1, HALO, 2.2)
    elif job == "cavaleiro":
        img = tint(img, (110, 140, 205), 0.15)
        paint(img, cx, top + 3, PLUME, 2.0)
    elif job == "ladrao":
        img = tint(img, (60, 70, 80), 0.20)
        paint(img, cx, top + 5, HOOD, 1.7)
    return img.crop(img.getchannel("A").getbbox())


def make_provisional_sprites():
    parents = {"cavaleiro": "escudeiro", "mago": "aprendiz", "sacerdote": "aprendiz", "ladrao": "lutador"}
    for job, parent in parents.items():
        for look in ("m", "f"):
            variant(f"assets/classes/{parent}_{look}_body.png", job).save(f"assets/classes/{job}_{look}_body.png")
            Image.open(f"assets/classes/{parent}_{look}_face.png").save(f"assets/classes/{job}_{look}_face.png")


def make_terrain_detail():
    rng = np.random.default_rng(7)
    base = np.full((32, 32), 236, dtype=np.int16)
    base += rng.integers(-14, 6, size=(32, 32))
    for _ in range(40):
        x, y = rng.integers(0, 32, size=2)
        base[y, x] -= 26
    Image.fromarray(np.clip(base, 150, 255).astype(np.uint8), "L").convert("RGB").save("assets/ui/terrain_detail.png")


def make_game_icon():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, 123, 123], radius=18, fill=(14, 22, 90, 255), outline=(238, 230, 196, 255), width=5)
    d.rounded_rectangle([12, 12, 115, 115], radius=12, outline=(255, 214, 90, 255), width=2)
    sword = draw_icon(ICONS["sword"], 6).resize((96, 96), Image.Resampling.NEAREST)
    shield = draw_icon(ICONS["shield"], 6).resize((96, 96), Image.Resampling.NEAREST)
    img.alpha_composite(shield, (16, 20))
    img.alpha_composite(sword, (16, 14))
    img.save("assets/ui/game_icon.png")


if __name__ == "__main__":
    make_icons()
    make_provisional_sprites()
    make_terrain_detail()
    make_game_icon()
    print("ok")
