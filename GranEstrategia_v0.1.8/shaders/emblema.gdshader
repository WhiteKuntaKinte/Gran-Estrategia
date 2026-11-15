// 0.1.8.44 · EMBLEMA de cada subsección del árbol de Descubrimientos: una insignia dibujada por código que CAMBIA según lo que el país ya conoce de esa subsección.
//   · COLOR = acento de la rama (rgb) y fracción conocida de la subsección (a: 0 = nada, 1 = todo)
//   · UV.x  = x local (−1,35…1,35) + 4·(número de subsección + 1) → semilla de su forma (cuántos pétalos, cuán afilados, hacia dónde gira)
//   · UV.y  = y local
// Qué se ve: el aro de afuera se llena en sentido horario con el avance; los pétalos del centro se van encendiendo uno a uno (los que faltan son solo contorno);
// el núcleo se enciende con el primer descubrimiento y, con la subsección completa, se vuelve una estrella dorada con halo. u_anim = 0 (calidad Baja) la deja quieta.
shader_type canvas_item;

uniform float u_anim = 1.0;
uniform float u_t0 = 5.0;

float h1(float n) {
	return fract(sin(n * 91.3458 + 17.17) * 43758.5453);
}

void fragment() {
	float k = floor((UV.x + 2.0) / 4.0);
	vec2 p = vec2(UV.x - 4.0 * k, UV.y);
	float prog = clamp(COLOR.a, 0.0, 1.0);
	vec3 acc = COLOR.rgb;
	float T = mix(u_t0, TIME, u_anim);
	float r = length(p);
	float lleno = step(0.999, prog);
	vec3 oro = vec3(1.0, 0.86, 0.45);
	vec3 col = vec3(0.0);
	float alfa = 0.0;
	if (r >= 1.0) {
		// halo de afuera: crece con el avance
		float g = exp(-(r - 1.0) * 4.2) * (0.08 + 0.50 * prog) * (1.0 - smoothstep(1.15, 1.34, r));
		col = mix(acc, oro, lleno);
		alfa = g;
	} else {
		float th = atan(p.x, -p.y);                                   // 0 arriba, crece en sentido horario
		float frac = fract(th / 6.2831853 + 1.0);
		col = mix(vec3(0.020, 0.024, 0.040), acc * 0.10, 0.5 + 0.5 * r);
		alfa = 0.93;
		col += vec3(1.0) * 0.05 * smoothstep(0.55, 1.0, r);           // un poco de luz hacia el borde
		// aro de avance
		float en_aro = smoothstep(0.83, 0.86, r) * (1.0 - smoothstep(0.95, 0.98, r));
		float encendido = step(frac, prog);
		float destello = 0.78 + 0.22 * sin(T * 2.4 - frac * 24.0);
		vec3 c_aro = mix(vec3(0.20, 0.22, 0.30), mix(acc, oro, lleno) * destello, encendido);
		col = mix(col, c_aro, en_aro);
		// guía finita a media altura
		col += vec3(1.0) * 0.07 * (1.0 - smoothstep(0.0, 0.015, abs(r - 0.70)));
		// pétalos del centro: N depende de la subsección; giran muy despacio
		float N = 5.0 + floor(h1(k) * 5.0);
		float sentido = h1(k + 3.0) < 0.5 ? -1.0 : 1.0;
		float a = atan(p.y, p.x) + T * 0.10 * sentido + h1(k + 9.0) * 6.2831853;
		float filo = 1.5 + 2.0 * h1(k + 5.0);
		float pet = pow(abs(cos(a * N * 0.5)), filo);
		float r_pet = 0.16 + 0.50 * pet;
		float idx = floor(fract(a / 6.2831853 + 0.5 / N) * N);
		float prendido = step((idx + 1.0) / N, prog + 0.0001);
		float dentro = (1.0 - smoothstep(r_pet - 0.02, r_pet, r)) * smoothstep(0.08, 0.11, r);
		float borde = (1.0 - smoothstep(0.0, 0.03, abs(r - r_pet))) * smoothstep(0.08, 0.11, r);
		vec3 c_pet = mix(acc, oro, lleno);
		col = mix(col, c_pet * (0.55 + 0.25 * sin(T * 1.7 + idx)), dentro * prendido * 0.85);
		col = mix(col, c_pet, borde * mix(0.22, 1.0, prendido));
		// núcleo
		float latido = 0.7 + 0.3 * sin(T * 3.0);
		float nuc = 1.0 - smoothstep(0.05, 0.10, r);
		vec3 c_nuc = mix(acc * (0.3 + 0.7 * prog) * latido, oro, lleno);
		col = mix(col, c_nuc, nuc * (prog > 0.0 ? 1.0 : 0.25));
		// borde del disco
		col += mix(vec3(0.5), acc, 0.5) * (1.0 - smoothstep(0.0, 0.025, abs(r - 0.99))) * 0.55;
		alfa *= 1.0 - smoothstep(0.985, 1.0, r) * 0.0;
	}
	COLOR = vec4(col, alfa);
}
