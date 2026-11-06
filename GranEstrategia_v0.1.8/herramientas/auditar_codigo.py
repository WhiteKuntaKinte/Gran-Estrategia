#!/usr/bin/env python3
"""Uso: python3 herramientas/auditar_codigo.py <carpeta del proyecto> <salida.json>
Auditoría estática del proyecto GDScript: funciones, variables, duplicados, grafo de llamadas (recursión), escrituras directas a columnas."""
import re, sys, json, os, collections
RAIZ = sys.argv[1]
archivos = [os.path.join(RAIZ, 'MapaPrincipal.gd')] + sorted(os.path.join(RAIZ, 'scripts', f) for f in os.listdir(os.path.join(RAIZ, 'scripts')) if f.endswith('.gd'))
re_func = re.compile(r'^(\t*)(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
re_class = re.compile(r'^(\t*)class\s+([A-Za-z_][A-Za-z0-9_]*)')
re_var = re.compile(r'^(\t*)(?:static\s+)?(var|const)\s+([A-Za-z_][A-Za-z0-9_]*)')
re_call = re.compile(r'(?<![A-Za-z0-9_\.])([A-Za-z_][A-Za-z0-9_]*)\s*\(')
re_mcall = re.compile(r'\.([A-Za-z_][A-Za-z0-9_]*)\s*\(')
KW = {'if','elif','while','for','match','return','func','and','or','not','in','is','as','await','assert','print','push_error','push_warning','str','int','float','bool','range','len','min','max','abs','clamp','lerp','Vector2','Vector2i','Color','Rect2','Callable','Array','Dictionary','preload','load','super','mini','maxi','clampi','clampf','minf','maxf','absf','absi','sqrt','pow','floor','ceil','round','roundf','floorf','ceilf','sign','signf','fposmod','posmod','lerpf','smoothstep','snappedf','is_nan','is_equal_approx','randf','randi','typeof','sin','cos','atan2','deg_to_rad','rad_to_deg','sort','PackedInt32Array','PackedFloat32Array','PackedFloat64Array','PackedVector2Array','PackedByteArray','PackedColorArray','PackedStringArray','PackedInt64Array','Time','OS'}
res = {'archivos': {}, 'dup_funcs': [], 'dup_vars': [], 'recursion': [], 'directas': []}
global_funcs = collections.defaultdict(list)   # nombre -> [(archivo, clase)]
por_archivo = {}
for ruta in archivos:
    nom = os.path.relpath(ruta, RAIZ)
    lineas = open(ruta, encoding='utf-8').read().split('\n')
    clase_actual = [('', -1)]   # (nombre, indent)
    funcs = []                  # (clase, nombre, linea_ini, linea_fin, cuerpo)
    vars_ = []
    cur = None
    for i, ln in enumerate(lineas):
        m = re_class.match(ln)
        if m:
            clase_actual.append((m.group(2), len(m.group(1))))
            continue
        # cerrar clases por indentación
        if ln.strip() and not ln.strip().startswith('#'):
            ind = len(ln) - len(ln.lstrip('\t'))
            while len(clase_actual) > 1 and ind <= clase_actual[-1][1] and not ln.startswith(' '):
                clase_actual.pop()
        mf = re_func.match(ln)
        if mf:
            if cur: cur['fin'] = i - 1; funcs.append(cur)
            cur = {'clase': clase_actual[-1][0], 'nombre': mf.group(2), 'ini': i + 1, 'fin': i + 1, 'indent': len(mf.group(1)), 'cuerpo': []}
            continue
        if cur is not None:
            if ln.strip() and not ln.startswith('\t' * (cur['indent'] + 1)) and not ln.strip().startswith('#'):
                cur['fin'] = i; funcs.append(cur); cur = None
            else:
                cur['cuerpo'].append(ln)
        mv = re_var.match(ln)
        if mv and cur is None:
            vars_.append((clase_actual[-1][0], mv.group(3), i + 1, mv.group(2)))
    if cur: cur['fin'] = len(lineas); funcs.append(cur)
    por_archivo[nom] = funcs
    # duplicados
    vistos = collections.Counter((f['clase'], f['nombre']) for f in funcs)
    for (c, n), k in vistos.items():
        if k > 1: res['dup_funcs'].append({'archivo': nom, 'clase': c, 'funcion': n, 'veces': k})
    vv = collections.Counter((c, n) for c, n, _, _ in vars_)
    for (c, n), k in vv.items():
        if k > 1: res['dup_vars'].append({'archivo': nom, 'clase': c, 'variable': n, 'veces': k})
    res['archivos'][nom] = {'lineas': len(lineas), 'funciones': len(funcs), 'variables_y_constantes': len(vars_), 'clases_internas': sorted({f['clase'] for f in funcs if f['clase']})}
    for f in funcs:
        global_funcs[f['nombre']].append((nom, f['clase']))

# grafo de llamadas por archivo (nombre simple; las llamadas con punto se resuelven por nombre único en el proyecto)
nodos = {}
for nom, funcs in por_archivo.items():
    for f in funcs:
        nodos[(nom, f['clase'], f['nombre'])] = f
indice = collections.defaultdict(list)
for k in nodos:
    indice[k[2]].append(k)
aristas = collections.defaultdict(set)
for k, f in nodos.items():
    txt = '\n'.join(re.sub(r'#.*$', '', l) for l in f['cuerpo'])
    txt = re.sub(r'"[^"\n]*"', '""', txt)
    llamadas = set(re_call.findall(txt)) | set(re_mcall.findall(txt))
    for c in llamadas:
        if c in KW: continue
        objetivos = indice.get(c, [])
        if not objetivos: continue
        # preferir mismo archivo/clase
        mismo = [o for o in objetivos if o[0] == k[0] and o[1] == k[1]]
        if mismo: objetivos = mismo
        elif len(objetivos) > 1:
            continue                     # nombre ambiguo entre archivos: no se asume
        for o in objetivos:
            aristas[k].add(o)
# Tarjan
idx = {}; low = {}; pila = []; en = set(); comps = []; n = [0]
sys.setrecursionlimit(100000)
def sc(v):
    idx[v] = low[v] = n[0]; n[0] += 1; pila.append(v); en.add(v)
    for w in aristas.get(v, ()):
        if w not in idx: sc(w); low[v] = min(low[v], low[w])
        elif w in en: low[v] = min(low[v], idx[w])
    if low[v] == idx[v]:
        c = []
        while True:
            w = pila.pop(); en.discard(w); c.append(w)
            if w == v: break
        comps.append(c)
for v in nodos:
    if v not in idx: sc(v)
for c in comps:
    if len(c) > 1:
        res['recursion'].append({'tipo': 'indirecta', 'ciclo': sorted('%s::%s' % (a[0], a[2]) for a in c)})
    elif c[0] in aristas.get(c[0], ()):
        res['recursion'].append({'tipo': 'directa', 'ciclo': ['%s::%s' % (c[0][0], c[0][2])]})
# escrituras directas a columnas fuera de poner_* / base_datos
pat = re.compile(r'(col_[fis]|\b(?:pc|vp|dv|tot|bm|fa|ex|cols?|acum)\b)\[[^\]]+\]\s*(?:[-+*/]?=)(?!=)')
for ruta in archivos:
    nom = os.path.relpath(ruta, RAIZ)
    for i, ln in enumerate(open(ruta, encoding='utf-8').read().split('\n')):
        if re.search(r'col_[fis]\[[^\]]+\]\s*[-+*/]?=(?!=)', ln) or re.search(r'\b(pc|vp|dv|tot|bm|fa|ex)\[[^\]]+\]\s*[-+*/]?=(?!=)', ln):
            res['directas'].append({'archivo': nom, 'linea': i + 1, 'codigo': ln.strip()[:110]})
json.dump(res, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
print('funciones', sum(v['funciones'] for v in res['archivos'].values()), 'dup_funcs', len(res['dup_funcs']), 'dup_vars', len(res['dup_vars']), 'ciclos', len(res['recursion']), 'escrituras directas', len(res['directas']))
