// 0.1.8.44 · FONDO ESPACIAL de la pantalla de Descubrimientos: ESPACIO NEGRO con el color de la rama fundido en la nebulosa (Camilo, 2026-11-14: «el fondo muy como el espacio,
// NEGRO, pero con la fusión del color de la rama»). Lleva nebulosa, tres capas de estrellas con parpadeo y deriva (paralaje), estrellas fugaces, el resplandor del sol del sistema
// (la raíz del árbol, `u_sol`) y, en la rama Militar, brasas que suben. NO lleva planetas: los únicos planetas de la pantalla son los descubrimientos.
// TODO lo anima el motor con TIME: el script no redibuja nada. u_anim = 0 (calidad Baja): cielo quieto y barato (negro, una capa de estrellas, viñeta).
shader_type canvas_item;

uniform vec4 c_top : source_color = vec4(0.012, 0.030, 0.045, 1.0);     // casi negro, con un soplo del color de la rama
uniform vec4 c_bot : source_color = vec4(0.003, 0.006, 0.012, 1.0);
uniform vec4 c_acc : source_color = vec4(0.35, 0.88, 0.98, 1.0);        // el color de la rama: tiñe la nebulosa y las estrellas
uniform vec2 u_size = vec2(1280.0, 720.0);
uniform vec2 u_sol = vec2(640.0, 760.0);                                 // dónde está el sol (px, en este control): lo mueve el árbol al desplazarse o hacer zoom
uniform float u_seed = 1.0;
uniform float u_rama = 1.0;                                              // 0 Militar (brasas) · 1 Científica · 2 Sociedad
uniform float u_anim = 1.0;
uniform float u_t0 = 37.0;
uniform sampler2D tex_neb : filter_linear, repeat_enable;                // ruido fractal que se puede repetir, hecho UNA vez al abrir el juego (`fondo_descubrimientos.gd`): la nebulosa cuesta una lectura de textura y no 16 senos por píxel

float h1(float n) {
	return fract(sin(n * 91.3458 + 17.17) * 43758.5453);
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Una capa de estrellas: una por celda con probabilidad `dens`, que deriva hacia la izquierda y parpadea.
vec3 estrellas(vec2 px, float celda, float vel, float dens, float brillo, float T, float sd) {
	vec2 q = px / celda + vec2(T * vel, 0.0);
	vec2 id = floor(q);
	vec2 f = fract(q);
	if (h2(id + sd) > dens) {
		return vec3(0.0);
	}
	vec2 pos = vec2(0.25 + 0.5 * h2(id * 1.7 + sd + 3.1), 0.25 + 0.5 * h2(id * 2.3 + sd + 7.7));
	float d = length(f - pos) * celda;
	if (d > 1.9) {
		return vec3(0.0);                                   // la estrella más grande mide 1,9 px: casi todos los píxeles salen aquí, sin gastar más
	}
	float tam = mix(0.8, 1.9, h2(id + sd + 5.3));
	float tw = 0.55 + 0.45 * sin(T * (1.1 + 3.0 * h2(id + 9.1)) + 6.2832 * h2(id + 2.2));
	float a = (1.0 - smoothstep(0.0, tam, d)) * brillo * tw;
	vec3 tinte = mix(vec3(0.86, 0.93, 1.0), mix(c_acc.rgb, vec3(1.0, 0.92, 0.80), h2(id + 4.4)), 0.45 * h2(id + 6.6));
	return tinte * a;
}

// Brasas que suben (rama Militar): más grandes, cálidas, con un vaivén.
vec3 brasas(vec2 px, float celda, float vel, float T, float sd) {
	vec2 q = px / celda + vec2(0.0, T * vel);
	vec2 id = floor(q);
	vec2 f = fract(q);
	if (h2(id + sd + 31.0) > 0.38) {
		return vec3(0.0);
	}
	float vaiven = 0.12 * sin(T * 0.9 + h2(id) * 6.2832);
	vec2 pos = vec2(0.3 + 0.4 * h2(id * 1.3 + sd) + vaiven, 0.25 + 0.5 * h2(id * 2.9 + sd));
	float d = length(f - pos) * celda;
	if (d > 2.6) {
		return vec3(0.0);
	}
	float tam = mix(0.9, 2.6, h2(id + sd + 2.0));
	float a = (1.0 - smoothstep(0.0, tam, d)) * (0.35 + 0.45 * h2(id + 8.0));
	return vec3(c_acc.r, c_acc.g * 0.85, c_acc.b * 0.55) * a;
}

void fragment() {
	float T = mix(u_t0, TIME, u_anim);
	vec2 px = UV * u_size;
	vec3 col = mix(c_top.rgb, c_bot.rgb, UV.y);
	float borde = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	// resplandor del sol: una luz cálida y ancha alrededor de la raíz del árbol
	float ds = length(px - u_sol) / u_size.y;
	col += vec3(1.0, 0.80, 0.45) * exp(-ds * 3.2) * 0.07;
	if (u_anim < 0.5) {
		col += estrellas(px, 78.0, 0.020, 0.50, 1.45, T, u_seed + 11.0);
		COLOR = vec4(col * mix(0.42, 1.0, smoothstep(0.0, 0.22, borde)), 1.0);
	} else {
		// nebulosa: nubes del color de la rama sobre el negro (poca, para que el espacio siga siendo negro)
		vec2 nq = UV * vec2(u_size.x / u_size.y, 1.0) * 1.7 + vec2(T * 0.004, -T * 0.002) + u_seed * 3.7;
		float neb = smoothstep(0.42, 0.90, texture(tex_neb, nq * 0.25).r);
		col += c_acc.rgb * neb * 0.10;
		// estrellas: lejanas (finas y muchas), medias y cercanas (pocas y brillantes)
		col += estrellas(px, 34.0, 0.004, 0.62, 1.00, T, u_seed);
		col += estrellas(px, 78.0, 0.020, 0.50, 1.45, T, u_seed + 11.0);
		col += estrellas(px, 150.0, 0.052, 0.34, 2.00, T, u_seed + 23.0);
		// brasas (solo Militar)
		if (u_rama < 0.5) {
			col += brasas(px, 52.0, 0.060, T, u_seed) + brasas(px + 17.0, 91.0, 0.034, T, u_seed + 5.0) * 0.8;
		}
		// estrella fugaz: una cada ~11 s, en diagonal
		float ciclo = T * 0.09 + u_seed * 0.37;
		float fase = fract(ciclo);
		if (fase < 0.16) {
			float u = fase / 0.16;
			float idc = floor(ciclo);
			vec2 a0 = vec2(h1(idc + u_seed) * 0.8 + 0.1, h1(idc * 1.7 + u_seed) * 0.4) * u_size;
			vec2 dir = normalize(vec2(0.8, 0.45));
			vec2 cab = a0 + dir * u * u_size.x * 0.35;
			vec2 v = px - cab;
			float along = dot(v, -dir);
			float perp = abs(dot(v, vec2(-dir.y, dir.x)));
			float cola = step(0.0, along) * (1.0 - smoothstep(0.0, 130.0, along)) * (1.0 - smoothstep(0.0, 1.8, perp));
			col += vec3(1.0, 0.97, 0.9) * cola * (1.0 - abs(u * 2.0 - 1.0)) * 0.8;
		}
		// viñeta
		col *= mix(0.42, 1.0, smoothstep(0.0, 0.22, borde));
		COLOR = vec4(col, 1.0);
	}
}
