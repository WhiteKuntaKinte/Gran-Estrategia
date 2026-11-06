"""Utilidades de geometría: limpieza de anillos, división de autointersecciones y triangulación."""
import numpy as np


def area_firmada(pts):
    a = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        a += x1 * y2 - x2 * y1
    return a / 2.0


def limpiar(ring):
    """Quita duplicados consecutivos y 'espigas' degeneradas (a, b, a)."""
    pts = []
    for x, y in ring:
        p = (float(x), float(y))
        if not pts or p != pts[-1]:
            pts.append(p)
    while len(pts) > 1 and pts[0] == pts[-1]:
        pts.pop()
    cambio = True
    while cambio and len(pts) >= 3:
        cambio = False
        n = len(pts)
        for i in range(n):
            a = pts[i - 1]
            c = pts[(i + 1) % n]
            if a == c:
                del pts[i]
                # elimina el duplicado resultante
                n2 = len(pts)
                j = 0
                while j < len(pts) and len(pts) > 1:
                    if pts[j] == pts[(j + 1) % len(pts)]:
                        del pts[(j + 1) % len(pts)]
                    else:
                        j += 1
                cambio = True
                break
    return pts


def _primera_interseccion(pts):
    n = len(pts)
    P = np.array(pts, dtype=float)
    A = P
    B = np.roll(P, -1, axis=0)
    for i in range(n):
        a, b = A[i], B[i]
        j0 = i + 2
        if j0 >= n:
            continue
        C = A[j0:n]
        D = B[j0:n]
        if i == 0:
            C = C[:-1]
            D = D[:-1]
        if len(C) == 0:
            continue

        def cr(o, p, q):
            return (p[..., 0] - o[..., 0]) * (q[..., 1] - o[..., 1]) - (p[..., 1] - o[..., 1]) * (q[..., 0] - o[..., 0])

        d1 = cr(a, b, C)
        d2 = cr(a, b, D)
        d3 = cr(C, D, a)
        d4 = cr(C, D, b)
        ok = (d1 * d2 < 0) & (d3 * d4 < 0)
        if ok.any():
            k = int(np.argmax(ok))
            j = j0 + k
            t = d3[k] / (d3[k] - d4[k])
            X = a + t * (b - a)
            return i, j, (float(X[0]), float(X[1]))
    return None


def dividir_autointersecciones(pts, prof=0):
    if len(pts) < 4 or prof > 20:
        return [pts]
    r = _primera_interseccion(pts)
    if r is None:
        return [pts]
    i, j, X = r
    lazo1 = [X] + pts[i + 1: j + 1]
    lazo2 = pts[j + 1:] + pts[: i + 1] + [X]
    salida = []
    for lazo in (lazo1, lazo2):
        lazo = limpiar(lazo)
        if len(lazo) >= 3 and abs(area_firmada(lazo)) > 1e-6:
            salida.extend(dividir_autointersecciones(lazo, prof + 1))
    return salida


def triangular(pts):
    """Ear clipping rápido (lista enlazada + prueba solo contra vértices cóncavos).
    Devuelve (lista de triángulos (i,j,k), área_cubierta)."""
    n = len(pts)
    P = np.array(pts, dtype=float)
    orden = list(range(n - 1, -1, -1)) if area_firmada(pts) < 0 else list(range(n))
    m0 = len(orden)
    X = P[orden, 0]
    Y = P[orden, 1]
    # trabajamos con posiciones 0..m0-1 sobre 'orden'
    prv = list(range(-1, m0 - 1))
    prv[0] = m0 - 1
    nxt = list(range(1, m0 + 1))
    nxt[-1] = 0
    vivo = np.ones(m0, dtype=bool)
    eps = 1e-12

    def cruz(i):
        a, b = prv[i], nxt[i]
        return (X[i] - X[a]) * (Y[b] - Y[i]) - (Y[i] - Y[a]) * (X[b] - X[i])

    refl = np.zeros(m0, dtype=bool)
    for i in range(m0):
        refl[i] = cruz(i) < -eps
    rid = None
    tris = []
    restantes = m0
    i = 0
    fallos = 0
    while restantes > 3:
        a, b = prv[i], nxt[i]
        cr = cruz(i)
        if abs(cr) <= eps:                      # colineal: se elimina sin triángulo
            nxt[a] = b
            prv[b] = a
            vivo[i] = False
            refl[i] = False
            restantes -= 1
            rid = None
            i = a
            fallos = 0
            continue
        es_oreja = cr > 0
        if es_oreja:
            if rid is None:
                rid = np.flatnonzero(refl & vivo)
            if len(rid):
                ax, ay, bx, by, cx, cy = X[a], Y[a], X[i], Y[i], X[b], Y[b]
                mnx, mxx = min(ax, bx, cx), max(ax, bx, cx)
                mny, mxy = min(ay, by, cy), max(ay, by, cy)
                qx, qy = X[rid], Y[rid]
                sel = (qx >= mnx) & (qx <= mxx) & (qy >= mny) & (qy <= mxy)
                if sel.any():
                    qx, qy = qx[sel], qy[sel]
                    ok = ~(((qx == ax) & (qy == ay)) | ((qx == bx) & (qy == by)) | ((qx == cx) & (qy == cy)))
                    qx, qy = qx[ok], qy[ok]
                    if len(qx):
                        d1 = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax)
                        d2 = (cx - bx) * (qy - by) - (cy - by) * (qx - bx)
                        d3 = (ax - cx) * (qy - cy) - (ay - cy) * (qx - cx)
                        if ((d1 >= -1e-9) & (d2 >= -1e-9) & (d3 >= -1e-9)).any():
                            es_oreja = False
        if es_oreja:
            tris.append((orden[a], orden[i], orden[b]))
            nxt[a] = b
            prv[b] = a
            vivo[i] = False
            refl[i] = False
            restantes -= 1
            for v in (a, b):
                antes = refl[v]
                refl[v] = cruz(v) < -eps
                if antes != refl[v]:
                    rid = None
            i = b
            fallos = 0
        else:
            i = nxt[i]
            fallos += 1
            if fallos > restantes:               # degenerado numérico: recorta el más convexo
                idx = np.flatnonzero(vivo)
                mejor, mk = -1e18, int(idx[0])
                for v in idx:
                    c = cruz(int(v))
                    if c > mejor:
                        mejor, mk = c, int(v)
                a, b = prv[mk], nxt[mk]
                tris.append((orden[a], orden[mk], orden[b]))
                nxt[a] = b
                prv[b] = a
                vivo[mk] = False
                refl[mk] = False
                restantes -= 1
                refl[a] = cruz(a) < -eps
                refl[b] = cruz(b) < -eps
                rid = None
                i = b
                fallos = 0
    if restantes == 3:
        idx = [int(v) for v in np.flatnonzero(vivo)]
        a, b, c = idx
        if abs((X[b] - X[a]) * (Y[c] - Y[a]) - (Y[b] - Y[a]) * (X[c] - X[a])) > eps:
            tris.append((orden[a], orden[b], orden[c]))
    cub = 0.0
    for i0, i1, i2 in tris:
        a, b, c = P[i0], P[i1], P[i2]
        cub += abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2.0
    return tris, cub


# ─── Niveles de detalle de líneas (0.1.7.9.9G, rendimiento al alejar el zoom) ───
def dp_indices(pts, tol):
    """Douglas-Peucker iterativo sobre un arreglo (n, 2). Devuelve los índices que se conservan (siempre incluye extremos)."""
    n = len(pts)
    if n <= 2:
        return list(range(n))
    keep = np.zeros(n, bool)
    keep[0] = keep[-1] = True
    pila = [(0, n - 1)]
    while pila:
        i, j = pila.pop()
        if j <= i + 1:
            continue
        p = pts[i + 1:j]
        a = pts[i]
        d = pts[j] - a
        l2 = float(d @ d)
        if l2 < 1e-12:
            dist = np.hypot(p[:, 0] - a[0], p[:, 1] - a[1])
        else:
            t = np.clip(((p - a) @ d) / l2, 0.0, 1.0)
            proj = a + t[:, None] * d
            dist = np.hypot(p[:, 0] - proj[:, 0], p[:, 1] - proj[:, 1])
        k = int(np.argmax(dist))
        if dist[k] > tol:
            m = i + 1 + k
            keep[m] = True
            pila.append((i, m))
            pila.append((m, j))
    return [int(x) for x in np.nonzero(keep)[0]]


def cadenas_de_segmentos(segs, decimales=3):
    """Une segmentos ((x,y),(x,y)) que comparten extremo en polilíneas (listas de puntos). Determinista."""
    def clave(p):
        return (round(float(p[0]), decimales), round(float(p[1]), decimales))
    ady = {}
    for i, (a, b) in enumerate(segs):
        ady.setdefault(clave(a), []).append(i)
        ady.setdefault(clave(b), []).append(i)
    usado = [False] * len(segs)
    cadenas = []
    for i0 in range(len(segs)):
        if usado[i0]:
            continue
        usado[i0] = True
        pts = [segs[i0][0], segs[i0][1]]
        for _sentido in (0, 1):
            while True:
                fin = pts[-1]
                nxt = None
                for j in ady.get(clave(fin), ()):
                    if not usado[j]:
                        nxt = j
                        break
                if nxt is None:
                    break
                usado[nxt] = True
                pa, pb = segs[nxt]
                if clave(pa) != clave(fin):
                    pa, pb = pb, pa
                pts.append(pb)
            pts.reverse()
        cadenas.append(pts)
    return cadenas


def simplificar_segmentos(segs, tol):
    """Devuelve segmentos ((x,y),(x,y)) equivalentes a `segs` pero con la polilínea simplificada a `tol` unidades de error máximo."""
    salida = []
    for pts in cadenas_de_segmentos(segs):
        arr = np.array(pts, dtype=float)
        tramos = [arr]
        if len(arr) >= 4 and np.allclose(arr[0], arr[-1], atol=5e-4):
            # Anillo cerrado (isla): se parte en el punto más lejano del inicio para que una isla diminuta no se reduzca a nada
            # (Douglas-Peucker sobre un anillo completo solo conserva el punto de inicio) y conserve al menos una marca.
            m = int(np.argmax(np.hypot(arr[:, 0] - arr[0, 0], arr[:, 1] - arr[0, 1])))
            if 0 < m < len(arr) - 1:
                tramos = [arr[:m + 1], arr[m:]]
        for tr in tramos:
            idx = dp_indices(tr, tol)
            for k in range(len(idx) - 1):
                a = tuple(tr[idx[k]])
                b = tuple(tr[idx[k + 1]])
                if a != b:
                    salida.append((a, b))
    return salida
