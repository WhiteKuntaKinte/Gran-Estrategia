// 0.1.8.44 · NODOS-PLANETA del árbol de Descubrimientos. Cada descubrimiento es un planeta de colores REALISTAS y neutros (rocoso gris, desértico, océanos, helado, gigantes
// de gas ocres y azules…) alumbrado por el SOL del sistema, que es la raíz del árbol: cada planeta tiene su cara iluminada mirando al sol, una terminación (el borde entre día
// y noche) y su lado nocturno casi negro. Gira sobre su eje, sin anillos. Lo verde es la LÍNEA, no el planeta (Camilo, 2026-11-14). Una sola malla de cuadros para todo el árbol.
// Datos por vértice, sin pasarlos aparte:
//   · COLOR  = (rgb sin uso en planetas) y opacidad (a: se atenúa lo que no está enfocado)
//   · UV.x   = x local (−1,9…1,9; 1 = borde del planeta) + 4·(número de planeta)                 → semilla de su aspecto, su tipo y su giro
//   · UV.y   = y local + 4·(estado + 5·dirección del sol)   estado: 0 bloqueado · 1 disponible · 2 conocido · 3 aún lejano · 4 EL SOL; dirección: 0…31 (de 11,25° cada una)
// Estado en el planeta: BLOQUEADO = negro (solo se adivina su forma); AÚN LEJANO = gris; CONOCIDO = colores reales; DISPONIBLE = colores reales con un halo dorado.
// u_anim = 0 (calidad Baja) los deja quietos.
shader_type canvas_item;

uniform float u_anim = 1.0;
uniform float u_t0 = 9.0;

float h1(float n) {
	return fract(sin(n * 91.3458 + 17.17) * 43758.5453);
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Color de la superficie según el tipo de planeta (0…7) en la longitud `lon` y la latitud `lat` (−1…1).
vec3 superficie(float t, float lon, float lat, float hk) {
	float n1 = vnoise(vec2(lon * 2.0 + hk * 20.0, lat * 2.6 + hk * 7.0));
	float n2 = vnoise(vec2(lon * 5.5 + 3.0, lat * 6.5 + hk * 9.0));
	float n3 = vnoise(vec2(lon * 12.0, lat * 14.0 + hk * 3.0));
	float bandas = 0.5 + 0.5 * sin(lat * (7.0 + 9.0 * hk) + n1 * 3.2);
	vec3 c;
	if (t < 0.5) {                      // rocoso gris, con cráteres
		c = mix(vec3(0.29, 0.28, 0.28), vec3(0.55, 0.53, 0.50), smoothstep(0.25, 0.75, n1 * 0.6 + n2 * 0.4));
		c *= 0.78 + 0.40 * n3;
	} else if (t < 1.5) {               // desértico rojizo con casquetes
		c = mix(vec3(0.36, 0.19, 0.12), vec3(0.70, 0.41, 0.25), smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4));
		c *= 0.85 + 0.25 * n3;
		c = mix(c, vec3(0.90, 0.86, 0.82), smoothstep(0.80, 0.95, abs(lat)) * 0.85);
	} else if (t < 2.5) {               // océanos, tierra y nubes
		float tierra = smoothstep(0.50, 0.56, n1 * 0.65 + n2 * 0.35);
		c = mix(vec3(0.06, 0.18, 0.38), mix(vec3(0.23, 0.34, 0.17), vec3(0.50, 0.42, 0.28), n3), tierra);
		float nubes = smoothstep(0.56, 0.78, vnoise(vec2(lon * 3.1 + 5.0 + hk * 11.0, lat * 5.0 + 2.0)));
		c = mix(c, vec3(0.93, 0.94, 0.95), nubes * 0.55);
		c = mix(c, vec3(0.92, 0.95, 0.98), smoothstep(0.84, 0.95, abs(lat)));
	} else if (t < 3.5) {               // helado
		c = mix(vec3(0.58, 0.68, 0.78), vec3(0.88, 0.92, 0.96), n1 * 0.7 + n2 * 0.3);
		c *= 0.92 + 0.12 * n3;
	} else if (t < 4.5) {               // gigante de gas ocre, con bandas
		c = mix(mix(vec3(0.50, 0.34, 0.24), vec3(0.80, 0.67, 0.50), bandas), vec3(0.91, 0.85, 0.73), smoothstep(0.55, 0.80, n2) * 0.45);
	} else if (t < 5.5) {               // gigante pálido
		c = mix(vec3(0.66, 0.56, 0.40), vec3(0.87, 0.79, 0.61), bandas * 0.7 + n2 * 0.3);
	} else if (t < 6.5) {               // nubes venusinas
		c = mix(vec3(0.64, 0.50, 0.30), vec3(0.88, 0.76, 0.52), n1 * 0.5 + bandas * 0.3 + n2 * 0.2);
	} else {                            // gigante de hielo azul
		c = mix(vec3(0.19, 0.32, 0.56), vec3(0.46, 0.63, 0.78), bandas * 0.6 + n2 * 0.4);
	}
	return c;
}

void fragment() {
	float k = floor((UV.x + 2.0) / 4.0);
	float ss = floor((UV.y + 2.0) / 4.0);
	float q = floor(ss / 5.0 + 0.001);
	float s = ss - 5.0 * q;
	vec2 p = vec2(UV.x - 4.0 * k, UV.y - 4.0 * ss);
	float rr = length(p);
	float T = mix(u_t0, TIME, u_anim);
	if (s > 3.5) {
		// EL SOL: disco de fuego con granulación, oscurecido hacia el borde, y corona con destellos que respira
		if (rr < 1.0) {
			float z = sqrt(max(0.0, 1.0 - rr * rr));
			float gr = vnoise(p * 5.5 + vec2(T * 0.25, -T * 0.18)) * 0.6 + vnoise(p * 12.0 - vec2(T * 0.4, T * 0.1)) * 0.4;
			vec3 c = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.93, 0.62), pow(z, 0.7));
			c *= 0.80 + 0.40 * gr;
			float a = 1.0 - smoothstep(0.96, 1.0, rr);
			COLOR = vec4(mix(vec3(1.0, 0.60, 0.20), c, a), COLOR.a);
		} else {
			float ang = atan(p.y, p.x);
			float rayos = 0.65 + 0.35 * sin(ang * 11.0 + T * 0.35 + vnoise(vec2(ang * 3.0, T * 0.2)) * 4.0);
			float g = exp(-(rr - 1.0) * 2.6) * (1.0 - smoothstep(1.6, 1.9, rr)) * rayos;
			COLOR = vec4(1.0, 0.72, 0.30, g * 0.75 * COLOR.a);
		}
	} else {
		float brillo = 0.0;
		if (s > 0.5 && s < 1.5) {
			brillo = 0.34;                                                // disponible: halo dorado
		}
		if (rr >= 1.0) {
			float g = brillo * exp(-(rr - 1.0) * 3.4) * (1.0 - smoothstep(1.6, 1.9, rr));
			COLOR = vec4(1.0, 0.80, 0.24, g * COLOR.a);
		} else {
			float hk = h1(k);
			float hs = h1(k + 7.0);
			float tipo = floor(h1(k + 1.7) * 8.0);
			float mult = s < 0.5 ? 0.35 : (s < 1.5 ? 0.95 : (s < 2.5 ? 0.65 : 0.25));
			float giro = (0.20 + 0.45 * hk) * (hs < 0.5 ? -1.0 : 1.0) * mult;
			float z = sqrt(max(0.0, 1.0 - rr * rr));
			vec3 n = vec3(p.x, -p.y, z);
			float tilt = (h1(k + 3.0) - 0.5) * 0.7;
			float cs = cos(tilt);
			float sn = sin(tilt);
			vec2 np = vec2(n.x * cs - n.y * sn, n.x * sn + n.y * cs);
			float lon = atan(np.x, z) + T * giro + hk * 6.0;
			vec3 alb = superficie(tipo, lon, np.y, hk);
			// el sol: dirección en pantalla (y hacia abajo) → en el espacio de la esfera la y va hacia arriba
			float qa = q * 0.19634954;                                     // q · 2π / 32
			vec3 L = normalize(vec3(cos(qa), -sin(qa), 0.50));
			float dif = dot(n, L);
			float dia = smoothstep(-0.28, 0.55, dif);                       // la terminación: del lado de noche al de día
			vec3 col = alb * (0.045 + 1.05 * dia);
			float limbo = pow(1.0 - z, 3.0);
			float cara = clamp(dot(vec2(L.x, L.y), vec2(n.x, n.y)) * 0.8 + 0.35, 0.0, 1.0);
			col += mix(vec3(0.55, 0.68, 0.95), alb, 0.45) * limbo * cara * 0.45;      // aire en el borde iluminado
			if (s < 0.5) {
				// bloqueado: negro; solo un reflejo gris en el borde de día deja adivinar la esfera
				col = vec3(0.010, 0.011, 0.016) + vec3(0.42, 0.44, 0.52) * limbo * (0.25 + 0.75 * cara) * 0.95 + vec3(0.07) * dia;
			} else if (s > 2.5) {
				// aún lejano: gris
				float g = dot(col, vec3(0.299, 0.587, 0.114));
				col = vec3(g * 0.85 + 0.01);
			} else if (s < 1.5) {
				col += vec3(1.0, 0.80, 0.30) * limbo * 0.35;                      // disponible: un filo dorado
			}
			float a = 1.0 - smoothstep(0.93, 1.0, rr);
			vec3 sobre = brillo > 0.0 ? mix(vec3(1.0, 0.80, 0.24), col, a) : col;
			COLOR = vec4(sobre, COLOR.a * max(a, brillo));
		}
	}
}
