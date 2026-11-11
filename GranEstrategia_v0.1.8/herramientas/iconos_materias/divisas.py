"""Monedas del juego: una por divisa (datos/divisas.json), con el símbolo de la moneda grabado y su propio metal y borde.
Cada país usa la moneda de su divisa; los países que comparten divisa (euro, dólar estadounidense, franco CFA...) comparten icono.
Texto con DejaVu Sans Bold (licencia libre). Si la fuente no tiene el símbolo, se graba el código de tres letras."""
import hashlib
import json
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFont

from lienzo import *

FUENTE = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
_fuente_cache = {}

# (borde, cara, aro interior, grabado)
METALES = {
    'oro': (hexa('d99a1f'), hexa('f2c94c'), hexa('e8b232'), hexa('9a6410')),
    'plata': (hexa('8e9ab4'), hexa('d4dcec'), hexa('b4bed4'), hexa('5a6482')),
    'bronce': (hexa('a85a28'), hexa('d9843e'), hexa('c06e30'), hexa('6e3414')),
    'verde': (hexa('2f7d46'), hexa('6fcf7f'), hexa('4aa862'), hexa('1d5230')),
    'azul': (hexa('3a62b8'), hexa('7aa8f0'), hexa('5688d8'), hexa('1d3a78')),
    'turquesa': (hexa('1f8a94'), hexa('5cc9d8'), hexa('3ea8b6'), hexa('0f5058')),
    'morado': (hexa('6a48a8'), hexa('a68ae0'), hexa('8868c4'), hexa('3a2468')),
    'rojo': (hexa('a83a3a'), hexa('e0766e'), hexa('c85a52'), hexa('6a1c1c')),
}
ORDEN = ['oro', 'plata', 'bronce', 'oro', 'verde', 'azul', 'plata', 'turquesa', 'bronce', 'morado', 'oro', 'rojo']
FIJOS = {'USD': 'verde', 'EUR': 'azul', 'GBP': 'morado', 'JPY': 'rojo', 'CNY': 'rojo', 'CHF': 'plata', 'INR': 'oro', 'CAD': 'rojo', 'AUD': 'oro',
         'MXN': 'verde', 'BRL': 'verde', 'COP': 'oro', 'ARS': 'turquesa', 'RUB': 'azul', 'KRW': 'azul', 'TRY': 'rojo'}


def _hash(codigo):
    return int(hashlib.md5(codigo.encode('utf-8')).hexdigest(), 16)


def metal_de(codigo):
    return FIJOS.get(codigo) or ORDEN[_hash(codigo) % len(ORDEN)]


def _fuente(px):
    if px not in _fuente_cache:
        _fuente_cache[px] = ImageFont.truetype(FUENTE, px, layout_engine=ImageFont.Layout.RAQM)
    return _fuente_cache[px]


def _tiene_glifos(texto):
    from fontTools.ttLib import TTFont
    if '_cm' not in _fuente_cache:
        _fuente_cache['_cm'] = TTFont(FUENTE).getBestCmap()
    return all(ord(ch) in _fuente_cache['_cm'] for ch in texto)


def _texto_ajustado(texto, ancho_max, alto_max):
    """Mayor tamaño de fuente con el que el texto cabe en (ancho_max, alto_max) px del lienzo grande."""
    for px in range(int(alto_max * 1.4), 8, -2):
        f = _fuente(px)
        l, t, r, b = f.getbbox(texto)
        if r - l <= ancho_max and b - t <= alto_max:
            return f
    return _fuente(10)


def texto_de_moneda(codigo, simbolo):
    s = simbolo.strip()
    arabe = any('\u0600' <= ch <= '\u06ff' or ch == '\ufdfc' for ch in s)         # el árabe necesita escritura de derecha a izquierda: se graba el código
    if s in ('', '—') or arabe or not _tiene_glifos(s) or len(s) > 5:
        return codigo
    return s


def moneda(c, codigo, simbolo, metal=None):
    borde, cara, aro, grab = METALES[metal or metal_de(codigo)]
    h = _hash(codigo)
    # sombra suave en el suelo
    c.elip(64, 118, 40, 5, (0, 0, 0, 55))
    c.cuerpo_elip(64, 62, 58, 58, col=borde, sombra=0.3, luz=0.0, d=3.0)
    # borde con muescas o puntos (distinto según el código)
    estilo = h % 3
    if estilo == 0:
        for i in range(36):
            a = math.radians(i * 10)
            c.linea([(64 + 55 * math.cos(a), 62 + 55 * math.sin(a)), (64 + 51 * math.cos(a), 62 + 51 * math.sin(a))], 1.8, claro(borde, 0.25))
    elif estilo == 1:
        for i in range(24):
            a = math.radians(i * 15)
            c.punto(64 + 53 * math.cos(a), 62 + 53 * math.sin(a), 1.7, claro(borde, 0.4))
    c.elip(64, 62, 48, 48, cara)
    c.elip(64, 62, 43.5, 43.5, aro)
    c.elip(64, 62, 41, 41, cara)
    # media luna de luz arriba a la izquierda
    c.recortada(c._mascara(elipse(64, 62, 41, 41)), lambda t: t.elip(44, 38, 40, 22, (255, 255, 255, 70), -38))
    # símbolo grabado
    txt = texto_de_moneda(codigo, simbolo)
    K_ = K
    caja = 62 * K_
    alto = (28 if len(txt) <= 2 else 22) * K_
    f = _texto_ajustado(txt, caja, alto)
    m = Image.new('L', (c.t, c.t), 0)
    d = ImageDraw.Draw(m)
    cx, cy = 64 * K_, 63 * K_
    d.text((cx, cy), txt, font=f, fill=255, anchor='mm')
    luz = ImageChops.offset(m, int(1.6 * K_), int(1.6 * K_))
    c._poner(luz, claro(cara, 0.55))
    c._poner(m, grab)


def todas():
    ruta = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'datos', 'divisas.json')
    return json.load(open(ruta, encoding='utf-8'))['divisas']


def _fabrica(cod, s):
    def f(c):
        moneda(c, cod, s)
    return f


def iconos():
    return {'d_' + cod: _fabrica(cod, v['s']) for cod, v in todas().items()}


ICONOS = iconos()
