#!/usr/bin/env python3
"""Genera iconos/bioma_*.png (ilustraciones 480x120) para el HUD. Requiere pillow.
Los pictogramas i_*.png (antes aquí y en hacer_iconos_*.py) salen ahora de herramientas/iconos_materias/interfaz.py, en HD (0.1.8.41)."""
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
