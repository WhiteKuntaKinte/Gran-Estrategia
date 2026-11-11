"""
Lienzo de dibujo plano para los iconos de materias primas, sectores y divisas (0.1.8.41).

Todo se dibuja en coordenadas lógicas 0..128 sobre un lienzo 4 veces mayor y se reduce con LANCZOS, así los bordes quedan suaves.
Estilo: formas planas sin contorno, con una media luna oscura abajo a la derecha y otra clara arriba a la izquierda (`cuerpo`).
Dibujado desde cero para el juego: sin imágenes ni iconos de terceros. Solo pillow.
"""
import math
from PIL import Image, ImageChops, ImageDraw, ImageFilter

N = 128          # tamaño final del icono (px)
K = 4            # factor de supersampling


# ───────────── colores ─────────────
def hexa(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mezcla(c, otro, t):
    """t = 0 -> c, t = 1 -> otro."""
    return tuple(int(c[i] + (otro[i] - c[i]) * t) for i in range(3)) + (c[3] if len(c) > 3 else 255,)


def oscuro(c, t=0.25):
    return mezcla(c, (20, 24, 40, 255), t)


def claro(c, t=0.3):
    return mezcla(c, (255, 255, 255, 255), t)


ORO = hexa('f2c94c')
ORO2 = hexa('d99a1f')
VERDE = hexa('6fcf7f')
VERDE2 = hexa('3f9e57')
VERDE3 = hexa('2f7d46')
LIMA = hexa('b6d957')
ROJO = hexa('e0605a')
ROJO2 = hexa('b8403f')
AZUL = hexa('7aa8f0')
AZUL2 = hexa('4a78c8')
CAFE = hexa('9a6a43')
CAFE2 = hexa('6e4527')
CREMA = hexa('f1dfb0')
GRIS = hexa('aab3c4')
GRIS2 = hexa('7c869b')
NARANJA = hexa('f39a48')
ROSA = hexa('ee8fb0')
MORADO = hexa('9a74d6')
BLANCO = hexa('f2f5ff')
NEGRO = hexa('2a2f42')
CIAN = hexa('5cc9d8')


# ───────────── geometría ─────────────
def rot(pts, ang, cx=0.0, cy=0.0):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in pts]


def mover(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


def escalar(pts, sx, sy=None, cx=0.0, cy=0.0):
    sy = sx if sy is None else sy
    return [(cx + (x - cx) * sx, cy + (y - cy) * sy) for x, y in pts]


def elipse(cx, cy, rx, ry=None, ang=0.0, n=56):
    ry = rx if ry is None else ry
    pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
    return rot(pts, ang, cx, cy) if ang else pts


def bezier(p0, p1, p2, n=20, p3=None):
    r = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        else:
            x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0]
            y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1]
        r.append((x, y))
    return r


def spline(pts, cerrada=True, por_tramo=8):
    """Catmull-Rom por los puntos dados (suaviza formas orgánicas: papas, rocas, frutas)."""
    n = len(pts)
    r = []
    rng = range(n) if cerrada else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if (cerrada or i > 0) else pts[0]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (cerrada or i + 2 < n) else pts[-1]
        for j in range(por_tramo):
            t = j / por_tramo
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            r.append((x, y))
    if not cerrada:
        r.append(pts[-1])
    return r


def hoja(x0, y0, x1, y1, ancho, curva=0.0, n=14):
    """Forma de hoja (dos arcos) desde (x0,y0) hasta (x1,y1); `curva` la dobla de lado."""
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / L, dx / L
    cx, cy = mx + nx * curva, my + ny * curva
    a = bezier((x0, y0), (cx + nx * ancho, cy + ny * ancho), (x1, y1), n)
    b = bezier((x1, y1), (cx - nx * ancho, cy - ny * ancho), (x0, y0), n)
    return a + b[1:]


def gota(cx, cy, r, alto=None, ang=0.0):
    """Gota con la punta hacia arriba (ang = 0). `alto` = distancia del centro del círculo a la punta."""
    alto = r * 1.9 if alto is None else alto
    cuerpo = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(0, 181, 8)]
    izq = bezier((cx - r, cy), (cx - r * 0.9, cy - alto * 0.45), (cx, cy - alto), 14)
    der = bezier((cx, cy - alto), (cx + r * 0.9, cy - alto * 0.45), (cx + r, cy), 14)
    forma = cuerpo + izq[1:] + der[1:]
    return rot(forma, ang, cx, cy) if ang else forma


def regular(cx, cy, r, lados, ang=-90.0):
    return [(cx + r * math.cos(math.radians(ang + 360.0 * i / lados)), cy + r * math.sin(math.radians(ang + 360.0 * i / lados))) for i in range(lados)]


def estrella(cx, cy, r1, r2, puntas, ang=-90.0):
    pts = []
    for i in range(puntas * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(ang + 180.0 * i / puntas)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def engranaje(cx, cy, r_ext, r_int, dientes, ang=0.0):
    pts = []
    for i in range(dientes):
        a0 = 360.0 * i / dientes + ang
        w = 360.0 / dientes
        for da, rr in ((0.0, r_int), (w * 0.18, r_int), (w * 0.28, r_ext), (w * 0.60, r_ext), (w * 0.70, r_int)):
            a = math.radians(a0 + da)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


# ───────────── lienzo ─────────────
class Lienzo:
    def __init__(self):
        self.t = N * K
        self.im = Image.new('RGBA', (self.t, self.t), (0, 0, 0, 0))

    def _px(self, pts):
        return [(x * K, y * K) for x, y in pts]

    def _mascara(self, pts=None, linea=None, ancho=1.0, cerrada=False):
        m = Image.new('L', (self.t, self.t), 0)
        d = ImageDraw.Draw(m)
        if pts is not None and linea is None:
            d.polygon(self._px(pts), fill=255)
        elif linea is not None:
            px = self._px(linea)
            w = max(1, int(round(ancho * K)))
            d.line(px, fill=255, width=w, joint='curve')
            r = w / 2.0
            for (x, y) in (px[0], px[-1]):
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return m

    def _poner(self, mascara, col):
        a = col[3] if len(col) > 3 else 255
        capa = Image.new('RGBA', (self.t, self.t), (col[0], col[1], col[2], 255))
        if a < 255:
            mascara = mascara.point(lambda v: v * a // 255)
        capa.putalpha(mascara)
        self.im.alpha_composite(capa)

    # formas planas
    def poly(self, pts, col):
        self._poner(self._mascara(pts), col)

    def elip(self, cx, cy, rx, ry=None, col=ORO, ang=0.0):
        self.poly(elipse(cx, cy, rx, ry, ang), col)

    def rect(self, x0, y0, x1, y1, col, r=0.0):
        m = Image.new('L', (self.t, self.t), 0)
        d = ImageDraw.Draw(m)
        if r > 0:
            d.rounded_rectangle([x0 * K, y0 * K, x1 * K, y1 * K], radius=r * K, fill=255)
        else:
            d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=255)
        self._poner(m, col)

    def linea(self, pts, ancho, col):
        self._poner(self._mascara(linea=pts, ancho=ancho), col)

    def punto(self, x, y, r, col):
        self.elip(x, y, r, r, col)

    # formas con volumen: color base + media luna oscura (abajo-derecha) + luz (arriba-izquierda)
    def cuerpo(self, pts, col, sombra=0.22, luz=0.30, d=3.2, col_sombra=None, col_luz=None):
        m = self._mascara(pts)
        self._poner(m, col)
        dk = int(d * K)
        if sombra > 0:
            m2 = ImageChops.offset(m, -dk, -dk)
            cres = ImageChops.subtract(m, m2)
            self._poner(cres, col_sombra if col_sombra is not None else oscuro(col, sombra * 1.6))
        if luz > 0:
            m3 = ImageChops.offset(m, dk, dk)
            cres2 = ImageChops.subtract(m, m3)
            # la luz es más fina que la sombra
            cres2 = cres2.filter(ImageFilter.MinFilter(3))
            self._poner(cres2, col_luz if col_luz is not None else claro(col, luz))
        return m

    def cuerpo_elip(self, cx, cy, rx, ry=None, col=ORO, ang=0.0, **kw):
        return self.cuerpo(elipse(cx, cy, rx, ry, ang), col, **kw)

    def brillo(self, cx, cy, rx, ry, ang=-35.0, a=150):
        self.elip(cx, cy, rx, ry, (255, 255, 255, a), ang)

    def recortada(self, mascara, fn):
        """Ejecuta `fn(lienzo_temporal)` y pega el resultado solo dentro de `mascara`."""
        tmp = Lienzo()
        fn(tmp)
        a = ImageChops.multiply(tmp.im.getchannel('A'), mascara)
        tmp.im.putalpha(a)
        self.im.alpha_composite(tmp.im)

    def guardar(self, ruta):
        self.im.resize((N, N), Image.LANCZOS).save(ruta, optimize=True)
        return ruta
