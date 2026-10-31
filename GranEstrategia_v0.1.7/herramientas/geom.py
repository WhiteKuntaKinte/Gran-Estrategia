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
    """Ear clipping robusto. Devuelve (lista de triángulos (i,j,k), área_cubierta)."""
    n = len(pts)
    P = np.array(pts, dtype=float)
    if area_firmada(pts) < 0:
        orden = list(range(n - 1, -1, -1))
    else:
        orden = list(range(n))
    idx = orden[:]
    tris = []
    eps = 1e-12
    k = 0
    guardia = 0
    while len(idx) > 3 and guardia < 200000:
        guardia += 1
        m = len(idx)
        if k >= m:
            k = 0
        encontrado = False
        for paso in range(m):
            kk = (k + paso) % m
            i0, i1, i2 = idx[kk - 1], idx[kk], idx[(kk + 1) % m]
            a, b, c = P[i0], P[i1], P[i2]
            cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
            if abs(cr) <= eps:
                del idx[kk]
                encontrado = True
                k = kk
                break
            if cr < 0:
                continue
            otros = np.array([q for q in idx if q != i0 and q != i1 and q != i2], dtype=int)
            if len(otros):
                Q = P[otros]
                # excluir puntos coincidentes con los vértices del triángulo
                igual = ((Q == a).all(axis=1)) | ((Q == b).all(axis=1)) | ((Q == c).all(axis=1))
                Q = Q[~igual]
                if len(Q):
                    d1 = (b[0] - a[0]) * (Q[:, 1] - a[1]) - (b[1] - a[1]) * (Q[:, 0] - a[0])
                    d2 = (c[0] - b[0]) * (Q[:, 1] - b[1]) - (c[1] - b[1]) * (Q[:, 0] - b[0])
                    d3 = (a[0] - c[0]) * (Q[:, 1] - c[1]) - (a[1] - c[1]) * (Q[:, 0] - c[0])
                    dentro = (d1 >= -1e-9) & (d2 >= -1e-9) & (d3 >= -1e-9)
                    if dentro.any():
                        continue
            tris.append((i0, i1, i2))
            del idx[kk]
            encontrado = True
            k = kk
            break
        if not encontrado:
            # Caso numérico degenerado: recorta el vértice más convexo
            m = len(idx)
            mejor, mk = -1e18, 0
            for kk in range(m):
                i0, i1, i2 = idx[kk - 1], idx[kk], idx[(kk + 1) % m]
                a, b, c = P[i0], P[i1], P[i2]
                cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
                if cr > mejor:
                    mejor, mk = cr, kk
            i0, i1, i2 = idx[mk - 1], idx[mk], idx[(mk + 1) % m]
            tris.append((i0, i1, i2))
            del idx[mk]
            k = mk
    if len(idx) == 3:
        a, b, c = P[idx[0]], P[idx[1]], P[idx[2]]
        cr = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        if abs(cr) > eps:
            tris.append((idx[0], idx[1], idx[2]))
    cub = 0.0
    for i0, i1, i2 in tris:
        a, b, c = P[i0], P[i1], P[i2]
        cub += abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2.0
    return tris, cub
