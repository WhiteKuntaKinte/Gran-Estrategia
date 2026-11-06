#!/usr/bin/env python3
"""Genera iconos/*.png (pictogramas 96x96) y iconos/bioma_*.png (ilustraciones 480x120) para el HUD. Requiere pillow."""
import os, math, random
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, 'iconos')
os.makedirs(OUT, exist_ok=True)
S = 4


def lienzo(w, h, fondo=(0, 0, 0, 0)):
    return Image.new('RGBA', (w * S, h * S), fondo)


def guardar(img, nombre, w, h):
    img.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, nombre))


def c(*v):
    return tuple(int(x * S) for x in v)


def icono(nombre, f, col=(235, 240, 255, 255)):
    im = lienzo(96, 96)
    d = ImageDraw.Draw(im)
    f(d, col)
    guardar(im, nombre + '.png', 96, 96)


def veg(d, k):
    d.ellipse(c(22, 8, 74, 60), fill=(88, 190, 110, 255)); d.ellipse(c(14, 28, 52, 66), fill=(70, 165, 95, 255))
    d.ellipse(c(44, 28, 82, 66), fill=(70, 165, 95, 255)); d.rectangle(c(43, 56, 53, 88), fill=(150, 105, 65, 255))

def flora(d, k):
    for ang in range(0, 360, 72):
        x = 48 + 20 * math.cos(math.radians(ang)); y = 44 + 20 * math.sin(math.radians(ang))
        d.ellipse(c(x - 13, y - 13, x + 13, y + 13), fill=(240, 130, 170, 255))
    d.ellipse(c(38, 34, 58, 54), fill=(250, 214, 80, 255)); d.rectangle(c(46, 62, 50, 92), fill=(80, 170, 100, 255))
    d.ellipse(c(50, 70, 74, 84), fill=(80, 170, 100, 255))

def fauna(d, k):
    col = (235, 190, 120, 255)
    d.ellipse(c(28, 50, 68, 88), fill=col)
    for (x, y, r) in ((16, 38, 9), (36, 22, 10), (60, 22, 10), (80, 38, 9)):
        d.ellipse(c(x - r, y - r - 2, x + r, y + r + 2), fill=col)

def alt(d, k):
    d.polygon([c(4, 82), c(36, 24), c(58, 58), c(70, 40), c(92, 82)], fill=(150, 165, 190, 255))
    d.polygon([c(36, 24), c(28, 40), c(36, 36), c(43, 42)], fill=(250, 250, 255, 255))
    d.polygon([c(70, 40), c(63, 52), c(70, 49), c(76, 53)], fill=(250, 250, 255, 255))

def pob(d, k):
    for (x, col) in ((34, (120, 180, 250, 255)), (62, (250, 170, 110, 255))):
        d.ellipse(c(x - 11, 14, x + 11, 36), fill=col); d.rounded_rectangle(c(x - 18, 40, x + 18, 84), radius=12 * S, fill=col)

def area(d, k):
    d.rectangle(c(18, 18, 78, 78), outline=(120, 220, 170, 255), width=6 * S)
    d.polygon([c(8, 8), c(28, 8), c(8, 28)], fill=(120, 220, 170, 255)); d.polygon([c(88, 88), c(68, 88), c(88, 68)], fill=(120, 220, 170, 255))

def etn(d, k):
    for (x, y, col) in ((36, 36, (240, 110, 110, 190)), (60, 36, (110, 200, 120, 190)), (48, 58, (110, 150, 250, 190))):
        d.ellipse(c(x - 24, y - 24, x + 24, y + 24), fill=col)

def dens(d, k):
    for i in range(4):
        for j in range(4):
            d.ellipse(c(14 + i * 20, 14 + j * 20, 26 + i * 20, 26 + j * 20), fill=(250, 210, 110, 255))

def prof(d, k):
    for y, col in ((30, (120, 200, 250, 255)), (52, (70, 150, 230, 255)), (74, (40, 100, 200, 255))):
        pts = [c(6 + x * 4, y + 7 * math.sin(x / 2.6)) for x in range(0, 23)]
        d.line(pts, fill=col, width=7 * S, joint='curve')

def cont(d, k):
    d.ellipse(c(10, 10, 86, 86), outline=(150, 190, 255, 255), width=5 * S)
    d.ellipse(c(34, 10, 62, 86), outline=(150, 190, 255, 255), width=4 * S)
    d.line([c(10, 48), c(86, 48)], fill=(150, 190, 255, 255), width=4 * S)

def pais(d, k):
    d.rectangle(c(20, 12, 25, 90), fill=(235, 235, 245, 255))
    d.polygon([c(25, 14), c(80, 24), c(25, 46)], fill=(240, 100, 100, 255)); d.polygon([c(25, 46), c(80, 56), c(25, 76)], fill=(240, 200, 80, 255))

def prov(d, k):
    d.polygon([c(48, 10), c(20, 36), c(76, 36)], fill=(255, 140, 90, 255)); d.ellipse(c(26, 18, 70, 62), fill=(255, 140, 90, 255))
    d.polygon([c(30, 52), c(48, 90), c(66, 52)], fill=(255, 140, 90, 255)); d.ellipse(c(38, 30, 58, 50), fill=(60, 30, 20, 255))

def pausa_i(d, k):
    d.rounded_rectangle(c(24, 18, 40, 78), radius=4 * S, fill=k); d.rounded_rectangle(c(56, 18, 72, 78), radius=4 * S, fill=k)

def atras(d, k):
    d.polygon([c(14, 48), c(48, 18), c(48, 36), c(84, 36), c(84, 60), c(48, 60), c(48, 78)], fill=k)

for n, f in (('veg', veg), ('flora', flora), ('fauna', fauna), ('alt', alt), ('pob', pob), ('area', area), ('etn', etn),
             ('dens', dens), ('prof', prof), ('cont', cont), ('pais', pais), ('prov', prov), ('pausa', pausa_i), ('atras', atras)):
    icono('i_' + n, f)

def eco(d, k):
    d.ellipse(c(10, 22, 70, 82), fill=(240, 200, 70, 255)); d.ellipse(c(20, 32, 60, 72), outline=(200, 150, 30, 255), width=4 * S)
    d.ellipse(c(44, 12, 86, 54), fill=(250, 220, 100, 255)); d.ellipse(c(51, 19, 79, 47), outline=(210, 165, 40, 255), width=3 * S)

def gob(d, k):
    d.polygon([c(48, 8), c(88, 32), c(8, 32)], fill=(200, 210, 235, 255))
    for x in (16, 34, 52, 70):
        d.rectangle(c(x, 38, x + 10, 74), fill=(225, 232, 248, 255))
    d.rectangle(c(8, 78, 88, 88), fill=(200, 210, 235, 255))

def cultivo(d, k):
    d.line([c(48, 90), c(48, 22)], fill=(200, 170, 70, 255), width=4 * S)
    for i, y in enumerate((70, 54, 38, 24)):
        d.ellipse(c(48 - 22, y - 7, 48 - 2, y + 7), fill=(235, 200, 90, 255)); d.ellipse(c(48 + 2, y - 7, 48 + 22, y + 7), fill=(235, 200, 90, 255))

def carne(d, k):
    d.ellipse(c(10, 28, 84, 78), fill=(215, 105, 95, 255)); d.ellipse(c(28, 40, 56, 62), fill=(245, 215, 200, 255))
    d.ellipse(c(66, 36, 90, 60), fill=(235, 235, 235, 255))

def mineral(d, k):
    d.polygon([c(10, 84), c(30, 38), c(50, 84)], fill=(150, 160, 180, 255)); d.polygon([c(40, 84), c(62, 26), c(86, 84)], fill=(120, 135, 160, 255))
    d.polygon([c(62, 26), c(54, 44), c(62, 40), c(70, 46)], fill=(250, 250, 255, 255)); d.polygon([c(70, 70), c(78, 60), c(86, 70), c(78, 80)], fill=(110, 220, 240, 255))

def ciudad(d, k):
    for (x, w, h, col) in ((8, 22, 46, (150, 175, 220, 255)), (30, 26, 66, (180, 200, 240, 255)), (56, 24, 40, (140, 165, 210, 255)), (78, 12, 28, (160, 185, 225, 255))):
        d.rectangle(c(x, 88 - h, x + w, 88), fill=col)
        for yy in range(88 - h + 6, 84, 12):
            d.rectangle(c(x + 4, yy, x + 8, yy + 5), fill=(255, 235, 150, 255))

def vista(d, k):
    d.ellipse(c(10, 10, 86, 86), outline=(150, 200, 250, 255), width=5 * S)
    d.ellipse(c(32, 10, 64, 86), outline=(150, 200, 250, 255), width=4 * S); d.line([c(10, 48), c(86, 48)], fill=(150, 200, 250, 255), width=4 * S)

def info(d, k):
    d.ellipse(c(10, 10, 86, 86), outline=(150, 200, 250, 255), width=5 * S); d.ellipse(c(42, 20, 54, 32), fill=k); d.rounded_rectangle(c(42, 38, 54, 74), radius=3 * S, fill=k)

def estrella(d, k):
    pts = []
    for i in range(10):
        r = 40 if i % 2 == 0 else 17
        a = math.radians(-90 + i * 36)
        pts.append(c(48 + r * math.cos(a), 50 + r * math.sin(a)))
    d.polygon(pts, fill=(250, 210, 70, 255))

def estado(d, k):
    d.polygon([c(12, 16), c(84, 16), c(84, 60), c(60, 60), c(60, 84), c(12, 84)], fill=(120, 190, 220, 255), outline=(235, 245, 255, 255))

def desc(d, k):
    for y in (22, 40, 58, 76):
        d.rounded_rectangle(c(14, y, 82 if y != 76 else 54, y + 8), radius=3 * S, fill=k)

for n, f in (('eco', eco), ('gob', gob), ('cultivo', cultivo), ('carne', carne), ('mineral', mineral), ('ciudad', ciudad), ('vista', vista),
             ('info', info), ('estrella', estrella), ('estado', estado), ('desc', desc)):
    icono('i_' + n, f)

# ── ilustraciones de bioma ──
W, H = 480, 120
rnd = random.Random(7)


def cielo(d, top, bot):
    for y in range(H * S):
        t = y / (H * S)
        d.line([(0, y), (W * S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))


def suelo(d, col, y=88):
    d.rectangle((0, y * S, W * S, H * S), fill=col + (255,))


def colinas(d, col, base=84, amp=10, ph=0.0):
    pts = [(0, H * S)] + [(x * S, int((base + amp * math.sin(x / 55.0 + ph)) * S)) for x in range(0, W + 6, 6)] + [(W * S, H * S)]
    d.polygon(pts, fill=col + (255,))


def arbol_r(d, x, y, r, col, tr=(110, 80, 50)):
    d.rectangle(c(x - 2, y - r * 0.2, x + 2, y + r * 1.0), fill=tr + (255,)); d.ellipse(c(x - r, y - r * 1.8, x + r, y + r * 0.2), fill=col + (255,))

def abeto(d, x, y, h, col):
    for k in range(3):
        d.polygon([c(x, y - h + k * h * 0.28), c(x - h * 0.34 + k * 1.5, y - h * 0.2 * (1 - k * 0.3)), c(x + h * 0.34 - k * 1.5, y - h * 0.2 * (1 - k * 0.3))], fill=col + (255,))
    d.rectangle(c(x - 1.5, y - h * 0.2, x + 1.5, y), fill=(90, 65, 45, 255))

def palma(d, x, y, h):
    d.line([c(x, y), c(x + 4, y - h)], fill=(130, 95, 60, 255), width=4 * S)
    for ang in (-150, -110, -70, -30, 10):
        d.line([c(x + 4, y - h), c(x + 4 + 24 * math.cos(math.radians(ang)), y - h - 14 * abs(math.sin(math.radians(ang))) + 8)], fill=(60, 160, 80, 255), width=5 * S)

def cactus(d, x, y, h):
    col = (70, 140, 80, 255)
    d.rounded_rectangle(c(x - 4, y - h, x + 4, y), radius=4 * S, fill=col)
    d.rounded_rectangle(c(x - 14, y - h * 0.6, x - 8, y - h * 0.3), radius=3 * S, fill=col); d.rectangle(c(x - 14, y - h * 0.32, x - 3, y - h * 0.26), fill=col)
    d.rounded_rectangle(c(x + 8, y - h * 0.75, x + 14, y - h * 0.4), radius=3 * S, fill=col); d.rectangle(c(x + 3, y - h * 0.42, x + 14, y - h * 0.36), fill=col)

def acacia(d, x, y, h):
    d.line([c(x, y), c(x, y - h)], fill=(100, 75, 50, 255), width=3 * S); d.ellipse(c(x - 26, y - h - 8, x + 26, y - h + 8), fill=(80, 130, 60, 255))

def pasto(d, y, col, n=60):
    for _ in range(n):
        x = rnd.uniform(0, W); h = rnd.uniform(5, 12)
        d.line([c(x, y), c(x + rnd.uniform(-3, 3), y - h)], fill=col + (255,), width=2 * S)

def montana(d, x, y, w, h, col, nieve=True):
    d.polygon([c(x - w / 2, y), c(x, y - h), c(x + w / 2, y)], fill=col + (255,))
    if nieve:
        d.polygon([c(x, y - h), c(x - w * 0.12, y - h * 0.72), c(x - w * 0.02, y - h * 0.78), c(x + w * 0.05, y - h * 0.7), c(x + w * 0.13, y - h * 0.74)], fill=(250, 252, 255, 255))

def sol(d, x, y, col=(255, 235, 150)):
    d.ellipse(c(x - 14, y - 14, x + 14, y + 14), fill=col + (255,))

def biome(codigo, f):
    im = lienzo(W, H)
    d = ImageDraw.Draw(im)
    f(d)
    guardar(im, 'bioma_%s.png' % codigo, W, H)

def b_ntf(d):
    cielo(d, (150, 200, 240), (225, 238, 250)); colinas(d, (110, 160, 90), 80); suelo(d, (90, 140, 70), 96)
    for x in (40, 120, 200, 290, 370, 440): arbol_r(d, x, 94, 16, (190, 140, 50) if x % 3 == 0 else (95, 160, 70))
def b_stf(d):
    cielo(d, (170, 205, 225), (225, 235, 240)); colinas(d, (90, 135, 100), 78); suelo(d, (70, 115, 85), 98)
    for x in (30, 90, 170, 250, 330, 420): arbol_r(d, x, 96, 14, (60, 120, 90))
def b_wtf(d):
    cielo(d, (170, 215, 235), (235, 245, 245)); colinas(d, (90, 160, 100), 76); suelo(d, (70, 140, 80), 98)
    for x in (40, 110, 190, 270, 350, 430): arbol_r(d, x, 96, 15, (60, 150, 85))
def b_tdf(d):
    cielo(d, (240, 200, 140), (250, 235, 200)); colinas(d, (190, 160, 90), 80); suelo(d, (170, 140, 80), 98); sol(d, 400, 30)
    for x in (50, 140, 230, 330, 420): arbol_r(d, x, 96, 15, (170, 160, 70))
def b_tef(d):
    cielo(d, (120, 190, 200), (200, 230, 220)); colinas(d, (50, 120, 70), 70); suelo(d, (35, 100, 55), 96)
    for x in range(20, 480, 48): arbol_r(d, x, 96, 22, (40, 130, 65))
def b_cof(d):
    cielo(d, (150, 175, 195), (215, 225, 232)); colinas(d, (90, 120, 110), 82); suelo(d, (235, 240, 245), 100)
    for x in range(15, 480, 34): abeto(d, x, 100, 36 + (x % 3) * 8, (35, 90, 70))
def b_des(d):
    cielo(d, (250, 210, 150), (252, 240, 205)); sol(d, 80, 32, (255, 245, 190)); colinas(d, (225, 190, 130), 84, 8, 1.0); colinas(d, (210, 170, 110), 96, 6)
    cactus(d, 330, 100, 40); cactus(d, 410, 104, 28)
def b_sav(d):
    cielo(d, (250, 215, 150), (252, 238, 200)); sol(d, 400, 34, (255, 240, 170)); colinas(d, (205, 175, 90), 88, 5); suelo(d, (190, 160, 80), 100)
    pasto(d, 104, (150, 125, 55)); acacia(d, 120, 100, 34); acacia(d, 300, 102, 28)
def b_teg(d):
    cielo(d, (150, 200, 245), (230, 240, 252)); colinas(d, (150, 190, 100), 86, 6); suelo(d, (130, 175, 85), 100); pasto(d, 106, (95, 140, 60), 90)
def b_lak(d):
    cielo(d, (150, 200, 240), (230, 240, 250)); colinas(d, (100, 150, 100), 62, 6); d.rectangle((0, 70 * S, W * S, H * S), fill=(60, 130, 190, 255))
    for k in range(5): d.line([c(40 + k * 85, 90 + k % 2 * 8), c(80 + k * 85, 90 + k % 2 * 8)], fill=(150, 205, 235, 255), width=2 * S)
def b_man(d):
    cielo(d, (160, 215, 230), (225, 240, 240)); d.rectangle((0, 80 * S, W * S, H * S), fill=(70, 125, 140, 255))
    for x in range(30, 480, 55):
        arbol_r(d, x, 80, 14, (45, 120, 70))
        for k in (-8, 0, 8): d.line([c(x + k * 0.4, 80), c(x + k, 100)], fill=(95, 70, 50, 255), width=2 * S)
def b_med(d):
    cielo(d, (140, 195, 245), (225, 240, 252)); sol(d, 60, 30); colinas(d, (170, 160, 110), 76, 12); suelo(d, (150, 140, 95), 100)
    for x in (80, 180, 270, 360, 440): arbol_r(d, x, 98, 12, (110, 130, 70))
def b_tmg(d):
    cielo(d, (170, 195, 230), (225, 232, 245)); montana(d, 130, 100, 220, 60, (120, 135, 160)); montana(d, 340, 100, 260, 80, (105, 120, 150)); colinas(d, (130, 160, 110), 100, 3); pasto(d, 108, (90, 130, 85), 70)
def b_tun(d):
    cielo(d, (170, 195, 220), (230, 238, 248)); colinas(d, (205, 215, 225), 86, 6); suelo(d, (225, 232, 240), 100); montana(d, 380, 90, 140, 40, (150, 165, 185))
    pasto(d, 106, (130, 150, 120), 40)
def b_ice(d):
    cielo(d, (185, 210, 235), (240, 246, 252)); colinas(d, (225, 238, 250), 80, 5); suelo(d, (240, 247, 255), 96)
    montana(d, 110, 98, 160, 50, (200, 220, 240)); montana(d, 330, 98, 200, 70, (190, 212, 236))

for cod, f in (('NTF', b_ntf), ('STF', b_stf), ('WTF', b_wtf), ('TDF', b_tdf), ('TEF', b_tef), ('COF', b_cof), ('DES', b_des), ('SAV', b_sav),
               ('TEG', b_teg), ('LAK', b_lak), ('MAN', b_man), ('MED', b_med), ('TMG', b_tmg), ('TUN', b_tun), ('ICE', b_ice)):
    biome(cod, f)
print('iconos:', len(os.listdir(OUT)))
