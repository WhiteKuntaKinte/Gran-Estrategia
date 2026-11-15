// 0.1.8.44 · ESTELAS en las líneas del árbol: la línea en sí es FINA (un hilo) y por ella corren cometas de luz: cabeza viva, cola larga que se afina y se apaga, del que se necesita
// hacia lo que abre; en cada línea van dos, desfasados, y cada línea con su propio desfase para que no marchen al compás. El color y la fuerza vienen del color de vértice
// (verde = camino ya conocido, dorado / violeta = cadenas del descubrimiento enfocado).
//   · UV.x = distancia recorrida a lo largo de la línea (px; con un desfase propio de cada línea) · UV.y = −1…1 a lo ancho
// u_anim = 0 (calidad Baja): la capa ni se arma, pero aquí también queda quieta por si acaso.
shader_type canvas_item;

uniform float u_anim = 1.0;
uniform float u_t0 = 3.0;
uniform float periodo = 230.0;
uniform float vel = 0.55;

// Forma de un cometa en la fase f (0…1; la cabeza va en 0,955, la cola queda detrás): x = cola, y = cabeza.
vec2 cometa(float f) {
	float cola = pow(f, 3.2) * (1.0 - smoothstep(0.955, 0.99, f));
	float cabeza = exp(-abs(f - 0.955) * 60.0) * (1.0 - smoothstep(0.955, 1.0, f) * 0.6);
	return vec2(cola, cabeza);
}

void fragment() {
	float T = mix(u_t0, TIME, u_anim);
	float base = UV.x / periodo - T * vel;
	float f1 = fract(base);
	float f2 = fract(base + 0.5);
	vec2 c1 = cometa(f1);
	vec2 c2 = cometa(f2);
	float y = abs(UV.y);
	float w1 = 1.0 - smoothstep(0.0, 1.0, y / mix(0.22, 1.0, f1));      // la cola se afina
	float w2 = 1.0 - smoothstep(0.0, 1.0, y / mix(0.22, 1.0, f2));
	float a1 = (c1.x * 0.70 + c1.y * 0.95) * w1;
	float a2 = (c2.x * 0.55 + c2.y * 0.75) * w2;
	float luz = max(a1, a2);
	float caliente = max(c1.y * w1, c2.y * w2);
	vec3 c = mix(COLOR.rgb, vec3(1.0), 0.80 * caliente + 0.10);
	COLOR = vec4(c, COLOR.a * clamp(luz, 0.0, 1.0));
}
