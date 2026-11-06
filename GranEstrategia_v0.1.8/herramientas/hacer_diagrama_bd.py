#!/usr/bin/env python3
"""Diagramas de la base de datos de 0.1.8.2 (con la capa histórica: entidades, nombres, banderas, personas, cargos).

Genera en docs/:
  diagrama_bd_general.(mmd|svg|png)     modelo entidad-relación: TERRITORIO, VARIABLE, VALOR_ACTUAL, HISTORIAL, DIVISA
  diagrama_bd_historia.(mmd|svg|png)    capa histórica: ENTIDAD, NOMBRE, BANDERA, PERSONA, CARGO (todo con fechas)
  diagrama_bd_variables.(svg|png)       el ID de cada territorio conectado a TODAS las variables del catálogo y a su historial (1:0..1 y 1:N)
  diagrama_bd_jerarquia.(mmd|svg|png)   cadena de IDs mundo > continente > país > estado > provincia > ciudad, con rangos y ejemplo
Requiere: mmdc (Mermaid CLI) y playwright (Chromium) para pasar el SVG propio a PNG. Se lee datos/ids.json y datos/variables.json.
"""
import json
import os
import subprocess
import sys
from xml.sax.saxutils import escape

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(RAIZ, 'docs')
os.makedirs(DOCS, exist_ok=True)

ids = json.load(open(os.path.join(RAIZ, 'datos', 'ids.json'), encoding='utf-8'))
cat = json.load(open(os.path.join(RAIZ, 'datos', 'variables.json'), encoding='utf-8'))
VERSION = cat.get('version', ids.get('version', '0.1.8.2'))
VARS = cat['variables']

# ───────────────────────── conteos reales ─────────────────────────
tipos = ids['tipos']
cuenta = {t: 0 for t in tipos}
for fila in ids['territorios']:
    cuenta[tipos[fila[1]]] += 1
rangos = ids['rangos']
HIST = os.path.join(RAIZ, 'datos', 'historico')


def n_filas(nombre):
    try:
        return len(json.load(open(os.path.join(HIST, nombre + '.json'), encoding='utf-8'))['filas'])
    except (OSError, ValueError, KeyError):
        return 0


n_ent, n_nom, n_ban, n_per, n_car = (n_filas(x) for x in ('entidades', 'nombres', 'banderas', 'personas', 'cargos'))
por_id = {f[0]: f for f in ids['territorios']}


def buscar(tipo, nombre):
    for f in ids['territorios']:
        if tipos[f[1]] == tipo and f[2] == nombre:
            return f
    return None


def render_mmd(nombre):
    src = os.path.join(DOCS, nombre + '.mmd')
    cfg = os.path.join(DOCS, '_puppeteer.json')
    json.dump({'args': ['--no-sandbox', '--disable-setuid-sandbox']}, open(cfg, 'w'))
    for ext, extra in (('svg', []), ('png', ['-s', '2'])):
        cmd = ['mmdc', '-p', cfg, '-i', src, '-o', os.path.join(DOCS, nombre + '.' + ext), '-b', 'white'] + extra
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print('mmdc falló:', r.stderr[-600:])
            sys.exit(1)
    os.remove(cfg)


# ───────────────────────── 1) modelo general (Mermaid) ─────────────────────────
GENERAL = '''---
title: Base de datos 0.1.8.2 — modelo general (cada ID, cada variable, cada historial)
---
erDiagram
    TERRITORIO {
        int id PK "ID único; nunca se reutiliza"
        string tipo "mundo, continente, pais, estado, provincia, ciudad, entidad, ejercito, peloton, regimiento, guerra, batalla"
        string nombre
        int padre_id FK "ID del territorio que lo contiene"
        string clave "nombre de origen para enlazar con los datos"
        bool activo "0 = dado de baja (el ID se conserva)"
    }
    VARIABLE {
        int id_var PK
        string nombre "poblacion, tesoreria, tasa_fiscal..."
        string categoria "demografia, economia, desarrollo..."
        string tipo "numero, texto o id"
        string unidad
        string historial "cambio, mensual, anual o ninguno"
        string agregacion "suma, media_ponderada o ninguna"
        bool afecta_economia
    }
    VARIABLE_APLICA_A {
        int id_var FK
        string tipo_territorio "a qué tipos de territorio se aplica"
    }
    VALOR_ACTUAL {
        int id_territorio PK, FK
        int id_var PK, FK
        any valor "UN solo dato por ID y variable"
        int desde "fecha en que empezó este valor"
    }
    HISTORIAL {
        int fila PK
        int id_territorio FK
        int id_var FK
        any valor_anterior
        int desde
        int hasta
        string motivo "Conquista, Debug, cierre mensual..."
    }
    DIVISA {
        string codigo PK "COP, USD, EUR..."
        string nombre
        string simbolo
        float por_usd "unidades por 1 US$"
    }
    TERRITORIO ||--o{ TERRITORIO : "contiene (padre_id)"
    TERRITORIO ||--o{ VALOR_ACTUAL : "tiene (1 a 1 por variable)"
    VARIABLE ||--o{ VALOR_ACTUAL : "define"
    TERRITORIO ||--o{ HISTORIAL : "acumula"
    VARIABLE ||--o{ HISTORIAL : "registra"
    VARIABLE ||--|{ VARIABLE_APLICA_A : "aplica a"
    TERRITORIO ||..o{ TERRITORIO : "propietario (provincia > pais o entidad)"
    DIVISA ||--o{ TERRITORIO : "divisa (pais)"
'''
open(os.path.join(DOCS, 'diagrama_bd_general.mmd'), 'w', encoding='utf-8').write(GENERAL)
render_mmd('diagrama_bd_general')

# ───────────────────────── 3) jerarquía de IDs (Mermaid) ─────────────────────────
ej_ciudad = buscar('ciudad', 'Medellín')
ej_prov = buscar('provincia', 'Antioquia')
ej_pais = buscar('pais', 'Colombia')
ej_cont = por_id[ej_pais[3]] if ej_pais else None


def rg(t):
    a, b = rangos[t]
    return 'ID %d' % a if a == b else 'IDs %d a %d' % (a, b)


ejemplo = ''
if ej_prov and ej_pais and ej_cont:
    ejemplo = 'Ejemplo real:  Antioquia (ID %d)  →  Colombia (ID %d)  →  %s (ID %d)  →  Mundo (ID 0)' % (ej_prov[0], ej_pais[0], ej_cont[2], ej_cont[0])
    if ej_ciudad:
        ejemplo = ejemplo.replace('Ejemplo real:  ', 'Ejemplo real:  Medellín (ID %d)  →  ' % ej_ciudad[0])

JERARQUIA = '''---
title: Cadena de IDs 0.1.8.2 — cada nivel apunta a su padre (padre_id)
---
flowchart TB
    M["<b>MUNDO</b><br/>%s<br/>%d registro"]:::mundo
    C["<b>CONTINENTE</b><br/>%s<br/>%d registros"]:::cont
    P["<b>PAÍS / TERRITORIO</b><br/>%s<br/>%d registros"]:::pais
    E["<b>ESTADO</b><br/>%s<br/>%d registros<br/><i>solo países con estados (EE. UU.)</i>"]:::estado
    PR["<b>PROVINCIA</b><br/>%s<br/>%d registros<br/><i>departamentos, regiones, condados...</i>"]:::prov
    CI["<b>CIUDAD</b><br/>%s<br/>%d registros"]:::ciudad
    M -->|"1 : N"| C
    C -->|"1 : N"| P
    P -->|"1 : N"| E
    E -->|"1 : N"| PR
    P -->|"1 : N<br/>(países sin estados)"| PR
    PR -->|"1 : N"| CI
    PR -. "propietario (N : 1)<br/>quien la controla en una fecha" .-> P
    P -. "anexado_a (N : 1)" .-> P
    EN["<b>ENTIDAD HISTÓRICA</b><br/>%s<br/>%d registros<br/><i>imperios, repúblicas, virreinatos...<br/>sin padre geográfico</i>"]:::entidad
    PE["<b>PERSONA</b><br/>%s<br/>%d registros<br/><i>no es un territorio: tabla aparte</i>"]:::persona
    PR -. "propietario (N : 1)<br/>también puede ser una entidad" .-> EN
    EN -. "cargos: persona + cargo + fechas" .-> PE
    EJ["<b>EJÉRCITO</b><br/>%s<br/>%d (uno por país)<br/><i>se crea al empezar la partida</i>"]:::ejercito
    PL["<b>PELOTÓN</b><br/>%s<br/>≈ %s al empezar 2026<br/><i>hasta 1.000 soldados cada uno</i>"]:::ejercito
    RG["<b>REGIMIENTO</b><br/>IDs 12.000.000 en adelante<br/><i>grupo de pelotones: se mueve, pelea y se dibuja como UN cuadro;<br/>las tropas no se funden solas (unir = orden deliberada)</i>"]:::ejercito
    GU["<b>GUERRA</b><br/>IDs 13.000.000 en adelante<br/><i>agresor, defensor, fechas, causa<br/>(atacar una provincia ajena la declara)</i>"]:::guerra
    BA["<b>BATALLA</b><br/>IDs 14.000.000 en adelante<br/><i>bajas día por día = historial de estadísticas de batalla</i>"]:::guerra
    P -->|"1 : 1"| EJ
    EJ -->|"1 : N"| RG
    RG -->|"1 : N"| PL
    PL -. "ubicacion (N : 1)<br/>provincia donde está" .-> PR
    P -. "agresor / defensor (N : 1)" .-> GU
    GU -->|"1 : N"| BA
    BA -. "bat_provincia (N : 1)" .-> PR
    NOTA["%s"]:::nota
    classDef ejercito fill:#d1fae5,stroke:#059669,color:#111
    classDef guerra fill:#fee2e2,stroke:#b91c1c,color:#111
    classDef mundo fill:#e5e7eb,stroke:#6b7280,color:#111
    classDef cont fill:#dbeafe,stroke:#3b82f6,color:#111
    classDef pais fill:#ccfbf1,stroke:#14b8a6,color:#111
    classDef estado fill:#fef9c3,stroke:#ca8a04,color:#111
    classDef prov fill:#ffedd5,stroke:#f97316,color:#111
    classDef ciudad fill:#fce7f3,stroke:#ec4899,color:#111
    classDef entidad fill:#ede9fe,stroke:#7c3aed,color:#111
    classDef persona fill:#fae8ff,stroke:#c026d3,color:#111
    classDef nota fill:#ffffff,stroke:#9ca3af,color:#111,stroke-dasharray: 4 3
''' % (rg('mundo'), cuenta['mundo'], rg('continente'), cuenta['continente'], rg('pais'), cuenta['pais'],
       rg('estado'), cuenta['estado'], rg('provincia'), cuenta['provincia'], rg('ciudad'), cuenta['ciudad'], rg('entidad'), n_ent, rg('persona'), n_per,
       rg('ejercito'), cuenta['pais'], 'IDs 11.000.000 a 11.999.999', '21.600', ejemplo)
open(os.path.join(DOCS, 'diagrama_bd_jerarquia.mmd'), 'w', encoding='utf-8').write(JERARQUIA)
render_mmd('diagrama_bd_jerarquia')

# ───────────────────────── 4) capa histórica (Mermaid) ─────────────────────────
HISTORIA = '''---
title: Capa histórica 0.1.8.2 — entidades, nombres, banderas, personas y cargos (todo con fechas)
---
erDiagram
    TERRITORIO {
        int id PK "entidades: 1.000.000 a 1.999.999"
        string tipo "entidad"
        string nombre
        string clave "wd:Q... (Wikidata) o semilla:..."
        bool activo
    }
    ENTIDAD_INFO {
        int id PK, FK
        int inicio "fecha de nacimiento (0 = desconocida)"
        int fin "fecha de fin (0 = sigue)"
        string tipo_entidad "imperio, republica, virreinato..."
        string capital
        string fuente "semilla o wikidata"
    }
    SUCESION {
        int id_anterior FK
        int id_siguiente FK
    }
    NOMBRE {
        int id_territorio FK "entidad O país actual"
        string nombre
        string idioma "es, en, ru..."
        string clase "oficial, comun, nativo"
        int desde
        int hasta
    }
    BANDERA {
        int id_territorio FK
        string archivo "banderas_hist/xxxx.png"
        string clase "bandera, escudo, estandarte"
        int desde
        int hasta
        string licencia "licencia de cada imagen"
    }
    PERSONA {
        int id PK "2.000.000 a 9.999.999"
        string clave
        string nombre
        int nacimiento
        int muerte
    }
    CARGO {
        int id_persona FK
        int id_entidad FK
        string cargo "rey, presidente, emperador..."
        int desde
        int hasta
    }
    VAR_propietario {
        int id_provincia FK
        int valor "ID de un país O de una entidad"
        int desde
    }
    TERRITORIO ||--o| ENTIDAD_INFO : "describe"
    TERRITORIO ||--o{ SUCESION : "predecesores y sucesores"
    TERRITORIO ||--o{ NOMBRE : "se llamó (varios, con fechas)"
    TERRITORIO ||--o{ BANDERA : "usó (varias, con fechas)"
    PERSONA ||--o{ CARGO : "ocupó"
    TERRITORIO ||--o{ CARGO : "gobernada por"
    TERRITORIO ||--o{ VAR_propietario : "dueño en una fecha"
'''
open(os.path.join(DOCS, 'diagrama_bd_historia.mmd'), 'w', encoding='utf-8').write(HISTORIA)
render_mmd('diagrama_bd_historia')

# ───────────────────────── 2) variables conectadas al ID (SVG propio) ─────────────────────────
COL_CAT = {'demografia': '#2563eb', 'economia': '#d97706', 'desarrollo': '#059669', 'politica': '#dc2626', 'geografia': '#7c3aed', 'identidad': '#db2777',
           'guerra': '#b91c1c', 'ejercito': '#0f766e', 'batalla': '#9a3412'}
NOM_CAT = {'demografia': 'DEMOGRAFÍA', 'economia': 'ECONOMÍA', 'desarrollo': 'DESARROLLO', 'politica': 'POLÍTICA', 'geografia': 'GEOGRAFÍA', 'identidad': 'IDENTIDAD', 'guerra': 'GUERRA', 'ejercito': 'EJÉRCITO', 'batalla': 'BATALLA'}
ORDEN_CAT = ['demografia', 'economia', 'desarrollo', 'politica', 'geografia', 'identidad', 'guerra', 'batalla', 'ejercito']
TIPO_VAL = {'numero': 'número', 'texto': 'texto', 'id': 'ID de otro territorio'}
FONT = "font-family=\"'DejaVu Sans', Arial, sans-serif\""

W = 2000
X_TERR, W_TERR = 50, 330
X_VAR, W_VAR = 560, 400
X_HIS, W_HIS = 1290, 420
H_HDR, H_ROW = 26, 18
H_BOX = H_HDR + 3 * H_ROW + 8
GAP = 14
Y0 = 150

# posiciones de las cajas de variables, agrupadas por categoría
pos = {}
y = Y0
grupos = []
for c in ORDEN_CAT:
    vs = [v for v in VARS if v['categoria'] == c]
    if not vs:
        continue
    grupos.append((c, y))
    y += 30
    for v in vs:
        pos[v['id_var']] = y
        y += H_BOX + GAP
    y += 10
H = y + 330
out = []


def t(x, y_, txt, size=13, weight='normal', fill='#111827', anchor='start', extra=''):
    out.append('<text x="%s" y="%s" font-size="%s" font-weight="%s" fill="%s" text-anchor="%s" %s %s>%s</text>' % (x, y_, size, weight, fill, anchor, FONT, extra, escape(txt)))


def rect(x, y_, w, h, fill, stroke, sw=1.5, rx=8):
    out.append('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" stroke="%s" stroke-width="%s"/>' % (x, y_, w, h, rx, fill, stroke, sw))


# símbolos de cardinalidad (pata de gallo) — dirección: el trazo sale hacia la derecha (+1) o izquierda (-1)
def sim_uno(x, y_, d):          # ||  exactamente uno
    for k in (8, 14):
        out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#374151" stroke-width="2"/>' % (x + d * k, y_ - 8, x + d * k, y_ + 8))


def sim_cero_uno(x, y_, d):     # o|  cero o uno
    out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#374151" stroke-width="2"/>' % (x + d * 8, y_ - 8, x + d * 8, y_ + 8))
    out.append('<circle cx="%s" cy="%s" r="5" fill="#fff" stroke="#374151" stroke-width="2"/>' % (x + d * 17, y_))


def sim_muchos(x, y_, d):       # o{  cero o muchos
    for dy in (-8, 0, 8):
        out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#374151" stroke-width="2"/>' % (x + d * 14, y_, x, y_ + dy))
    out.append('<circle cx="%s" cy="%s" r="5" fill="#fff" stroke="#374151" stroke-width="2"/>' % (x + d * 22, y_))


# encabezado
t(40, 42, 'Base de datos %s — cada ID de territorio conectado a TODAS las variables' % VERSION, 24, 'bold')
t(40, 70, 'Una variable = una tabla propia con UN solo valor por ID (relación 1 a 0..1: sin sobrescribir nada). Los valores anteriores van a la tabla HIST de esa variable (relación 1 a N).', 13, 'normal', '#374151')
t(40, 90, 'Todas las variables comparten el mismo ID (id_territorio): por eso los mismos IDs de provincia, estado, país y continente sirven para consultar cualquier dato.', 13, 'normal', '#374151')
# leyenda
ly = 112
out.append('<g>')
sim_uno(46, ly, 1)
t(70, ly + 4, '= exactamente uno', 12)
sim_cero_uno(210, ly, 1)
t(240, ly + 4, '= cero o uno (a veces no hay dato)', 12)
sim_muchos(470, ly, 1)
t(505, ly + 4, '= cero o muchos', 12)
out.append('</g>')

# TERRITORIO (caja grande a la izquierda, centrada)
cy_t = (Y0 + (y - 20)) / 2
h_terr = 330
y_terr = cy_t - h_terr / 2
rect(X_TERR, y_terr, W_TERR, h_terr, '#f3f4f6', '#111827', 2.5, 10)
out.append('<rect x="%s" y="%s" width="%s" height="34" rx="8" fill="#111827"/>' % (X_TERR, y_terr, W_TERR))
t(X_TERR + W_TERR / 2, y_terr + 23, 'TERRITORIO', 17, 'bold', '#ffffff', 'middle')
campos = [('id', 'PK', 'ID único, nunca se reutiliza'), ('tipo', '', 'país · provincia · ejército · regimiento · guerra · batalla…'),
          ('nombre', '', ''), ('padre_id', 'FK', 'ID del territorio que lo contiene'), ('clave', '', 'nombre de origen (para enlazar datos)'), ('activo', '', '0 = dado de baja')]
yy = y_terr + 58
for nom, k, com in campos:
    t(X_TERR + 14, yy, nom, 14, 'bold')
    if k:
        t(X_TERR + 120, yy, k, 12, 'bold', '#b91c1c' if k == 'PK' else '#1d4ed8')
    if com:
        t(X_TERR + 14, yy + 15, com, 10.5, 'normal', '#6b7280')
    yy += 36
for i, (rt, n) in enumerate([('mundo', 1)] + [(k, cuenta[k]) for k in tipos[1:]]):
    pass
t(X_TERR + 14, y_terr + h_terr + 22, 'padre_id: TERRITORIO 1 — N TERRITORIO', 12, 'bold', '#374151')
t(X_TERR + 14, y_terr + h_terr + 40, '(provincia → estado → país → continente → mundo)', 12, 'normal', '#374151')
t(X_TERR + 14, y_terr + h_terr + 62, '%d IDs en total (%d provincias, %d ciudades,' % (sum(cuenta.values()), cuenta['provincia'], cuenta['ciudad']), 12, 'normal', '#6b7280')
t(X_TERR + 14, y_terr + h_terr + 78, '%d países, %d estados, %d continentes)' % (cuenta['pais'], cuenta['estado'], cuenta['continente']), 12, 'normal', '#6b7280')

# cajas de variables + historial + líneas
px = X_TERR + W_TERR
py = cy_t
for c, yc in grupos:
    col = COL_CAT[c]
    out.append('<rect x="%s" y="%s" width="%s" height="22" rx="5" fill="%s" opacity="0.14"/>' % (X_VAR - 10, yc - 4, X_HIS + W_HIS - X_VAR + 20, col))
    t(X_VAR, yc + 12, NOM_CAT[c], 13, 'bold', col)
for v in sorted(VARS, key=lambda v: pos[v['id_var']]):
    y_ = pos[v['id_var']]
    col = COL_CAT.get(v['categoria'], '#374151')
    mid = y_ + H_BOX / 2
    # línea TERRITORIO -> variable (1 : 0..1)
    out.append('<path d="M %s %s C %s %s, %s %s, %s %s" fill="none" stroke="%s" stroke-width="1.6" opacity="0.75"/>' % (px, py, px + 120, py, X_VAR - 120, mid, X_VAR, mid, col))
    sim_cero_uno(X_VAR, mid, -1)
    # caja de la variable
    rect(X_VAR, y_, W_VAR, H_BOX, '#ffffff', col, 2)
    out.append('<rect x="%s" y="%s" width="%s" height="%s" rx="7" fill="%s"/>' % (X_VAR, y_, W_VAR, H_HDR, col))
    t(X_VAR + 10, y_ + 18, 'VAR_%s' % v['nombre'], 13.5, 'bold', '#ffffff')
    t(X_VAR + W_VAR - 10, y_ + 18, 'variable %d' % v['id_var'], 11, 'normal', '#ffffff', 'end')
    yy = y_ + H_HDR + 15
    t(X_VAR + 10, yy, 'id_territorio', 12, 'bold')
    t(X_VAR + 100, yy, 'PK, FK → TERRITORIO.id', 11, 'normal', '#1d4ed8')
    yy += H_ROW
    unidad = (' · ' + v['unidad']) if v.get('unidad') and v['tipo'] == 'numero' else ''
    t(X_VAR + 10, yy, 'valor', 12, 'bold')
    t(X_VAR + 100, yy, '%s%s' % (TIPO_VAL.get(v['tipo'], v['tipo']), unidad), 11, 'normal', '#374151')
    yy += H_ROW
    t(X_VAR + 10, yy, 'desde', 12, 'bold')
    aplica = ', '.join(v['aplica_a'])
    t(X_VAR + 100, yy, 'fecha · aplica a: %s' % aplica, 11, 'normal', '#374151')
    # historial
    pol = v.get('historial', 'cambio')
    if pol == 'ninguno':
        rect(X_HIS, y_ + 8, W_HIS, H_BOX - 16, '#f9fafb', '#d1d5db', 1.2, 7)
        t(X_HIS + W_HIS / 2, y_ + H_BOX / 2 + 4, 'sin historial (dato fijo)', 12, 'normal', '#9ca3af', 'middle')
        continue
    out.append('<path d="M %s %s L %s %s" stroke="%s" stroke-width="1.6" opacity="0.75"/>' % (X_VAR + W_VAR, mid, X_HIS, mid, col))
    sim_uno(X_VAR + W_VAR, mid, 1)
    sim_muchos(X_HIS, mid, -1)
    rect(X_HIS, y_, W_HIS, H_BOX, '#fffbeb', col, 1.6)
    out.append('<rect x="%s" y="%s" width="%s" height="%s" rx="7" fill="%s" opacity="0.85"/>' % (X_HIS, y_, W_HIS, H_HDR, col))
    t(X_HIS + 10, y_ + 18, 'HIST_%s' % v['nombre'], 13, 'bold', '#ffffff')
    pol_txt = {'cambio': 'guarda el valor viejo en cada cambio', 'mensual': 'foto al cerrar cada mes', 'anual': 'foto al cerrar cada año'}.get(pol, pol)
    t(X_HIS + W_HIS - 10, y_ + 18, pol, 11, 'bold', '#ffffff', 'end')
    yy = y_ + H_HDR + 15
    t(X_HIS + 10, yy, 'id_territorio', 12, 'bold')
    t(X_HIS + 100, yy, 'FK → TERRITORIO.id', 11, 'normal', '#1d4ed8')
    yy += H_ROW
    t(X_HIS + 10, yy, 'valor_anterior', 12, 'bold')
    t(X_HIS + 120, yy, 'desde → hasta (fechas)', 11, 'normal', '#374151')
    yy += H_ROW
    t(X_HIS + 10, yy, 'motivo', 12, 'bold')
    t(X_HIS + 100, yy, pol_txt, 11, 'normal', '#374151')

# pie con ejemplos
yb = y + 10
rect(X_TERR, yb, X_HIS + W_HIS - X_TERR, 250, '#fefce8', '#ca8a04', 1.5, 8)
t(X_TERR + 12, yb + 22, 'Cómo se lee (ejemplo con Antioquia, ID %d):' % (ej_prov[0] if ej_prov else 0), 12.5, 'bold')
lineas = ['1) TERRITORIO.id = %d  →  Antioquia (provincia).' % (ej_prov[0] if ej_prov else 0),
          '2) VAR_poblacion guarda UNA sola fila con id_territorio',
          '    = %d → su población de hoy (nunca dos).' % (ej_prov[0] if ej_prov else 0),
          '3) Si la población cambia, el dato viejo pasa a',
          '    HIST_poblacion con sus fechas (relación 1 a N).',
          '4) VAR_propietario guarda el ID del país dueño',
          '    (ej. Colombia = %d). Si es conquistada, el nuevo' % (ej_pais[0] if ej_pais else 0),
          '    dueño queda en VAR y el anterior en HIST_propietario.',
          '5) Un país suma sus provincias: población = suma de',
          '    las filas de VAR_poblacion de sus provincias.']
for i, l in enumerate(lineas):
    t(X_TERR + 12, yb + 44 + i * 19, l, 11.5, 'normal', '#374151')

svg = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n<rect width="100%%" height="100%%" fill="#ffffff"/>\n%s\n</svg>\n' % (W, H, W, H, '\n'.join(out))
ruta_svg = os.path.join(DOCS, 'diagrama_bd_variables.svg')
open(ruta_svg, 'w', encoding='utf-8').write(svg)

# SVG -> PNG con Chromium (playwright). Se incrusta en una página HTML para que la captura sea rápida.
from playwright.sync_api import sync_playwright
html = '<html><body style="margin:0;background:#fff">%s</body></html>' % svg
ruta_html = os.path.join(DOCS, '_tmp.html')
open(ruta_html, 'w', encoding='utf-8').write(html)
with sync_playwright() as p:
    b = p.chromium.launch(args=['--disable-gpu'])
    pg = b.new_page(viewport={'width': W, 'height': 900}, device_scale_factor=1.25)
    pg.goto('file://' + ruta_html)
    pg.screenshot(path=os.path.join(DOCS, 'diagrama_bd_variables.png'), full_page=True, timeout=120000)
    b.close()
os.remove(ruta_html)
print('diagramas listos en', DOCS, '· alto del diagrama de variables:', H)
