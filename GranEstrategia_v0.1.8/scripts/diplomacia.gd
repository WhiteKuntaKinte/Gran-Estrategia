extends RefCounted
## DIPLOMACIA (0.1.8.43): lo que los países se deben unos a otros además de la guerra y la tregua.
##   · OPINIÓN entre dos países (−100 a +100). Se mueve con lo que hacen (declarar la guerra, firmar la paz, cumplir o no una alianza, regalos) y vuelve
##     sola a 0 a razón de 1 punto cada OP_REPOSO_DIAS días. La que cuenta (`opinion_total`) suma además la alianza, la rivalidad, la infamia del otro y la coalición.
##   · ALIANZA (máx. MAX_ALIADOS por país): si atacan a un aliado, el otro recibe la llamada; si no acude, la opinión cae y la alianza se rompe.
##   · RIVAL (uno por país, 10 años): lo que más le pesa; no se puede ser aliado de un rival y la IA lo prefiere como blanco.
##   · INFAMIA: cada provincia que un país se queda por la fuerza suma 1 (2 si era tierra propia de un tercero); declarar la guerra a un aliado suma 5 y
##     romper una tregua 2,5. Se reduce a la mitad cada INFAMIA_VIDA_MEDIA días. Con INFAMIA_COALICION o más, los vecinos que no la toleran
##     forman una COALICIÓN contra el país: sus miembros lo atacan juntos (ver `IA._buscar_guerra`) hasta que la infamia baje de INFAMIA_FIN.
## Todo es mundo-lógico y barato: dos diccionarios dispersos y una revisión cada DIAS_REVISION días solo de los países infames.
## Los ganchos que lo alimentan: `Guerra.declarar` (`al_declarar`), `Guerra.firmar_paz` (`al_paz`) y `Mundo.transferir_provincia` (`al_cambiar_dueno`).

const OP_REPOSO_DIAS := 25.0
const OP_ALIANZA_MIN := 25.0               # opinión que tiene que haber para aliarse
const OP_ALIANZA_ROMPE := -10.0            # si baja de aquí (con el aliado), la alianza se deshace
const OP_AMIGOS := 40.0                    # entre amigos tan cercanos la IA no se ataca
const MAX_ALIADOS := 3
const RIVAL_DIAS := 3650
const INFAMIA_VIDA_MEDIA := 900.0
const INFAMIA_COALICION := 12.0
const INFAMIA_FIN := 5.0
const INFAMIA_PESO_MIN := 0.25             # una provincia por conquista suma entre esto y el máximo, según su población frente a la media del mundo
const INFAMIA_PESO_MAX := 3.0
const INFAMIA_PRUDENTE := 7.0              # desde aquí una IA deja de agredir por su cuenta (solo a rivales y a quien está en su coalición)
const COALICION_MAX_DIAS := 3650
const COALICION_MIN := 2                   # miembros mínimos para que exista
const MAX_MIEMBROS := 8
const DIAS_REVISION := 15
const LLAMADA_DIAS := 40                   # una llamada de alianza sin responder caduca a los 40 días
const REGALO_DIAS := 10.0                  # un regalo cuesta tantos días de los ingresos de quien lo hace...
const REGALO_OPINION := 12.0               # ... y mejora la opinión de quien lo recibe en tantos puntos
const MAX_RAZONES := 6

var mundo
var g
var ia
var opinion := {}                          # clave de pareja -> [valor, día]
var razones := {}                          # clave de pareja -> [[texto, delta, día], ...] (las últimas MAX_RAZONES)
var alianzas := {}                         # clave de pareja -> día en que se firmó
var _aliados := {}                         # ID país -> {ID aliado: true}
var _rival := {}                           # ID país -> {"b": ID rival, "hasta": día}
var _infamia := {}                         # ID país -> [valor, día]
var infames := {}                          # ID país -> true (llegó a INFAMIA_COALICION y no ha bajado de INFAMIA_FIN)
var coaliciones := {}                      # ID del objetivo -> {"miembros": [ID...], "desde": día}
var llamados: Array = []                   # [{"aliado", "ayuda_a", "contra", "dia"}] llamadas de alianza sin atender
var _pob_ref_n := -1
var _pob_ref_v := 1.0
var version := 0                           # sube con cualquier cambio (la interfaz redibuja)
var alianzas_formadas := 0
var alianzas_rotas := 0
var coaliciones_formadas := 0
var llamadas_atendidas := 0
var llamadas_rechazadas := 0
var _prox_revision := DIAS_REVISION


func iniciar(m) -> void:
	mundo = m
	g = m.guerra
	ia = m.ia


static func clave(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


func dia() -> int:
	return ia.dia_n if ia != null else 0


func _nombre(t: int) -> String:
	return mundo.bd.nombre_de(t)


func _existe(t: int) -> bool:
	var n := _nombre(t)
	return mundo.paises.has(n) and not (mundo.paises[n].provincias as Array).is_empty() and not mundo.es_inerte(n)


func _es_jugador(t: int) -> bool:
	return mundo.jugador != "" and mundo.paises.has(mundo.jugador) and int(mundo.paises[mundo.jugador].tid) == t


# ─────────────────────────────────────────────────────────────
# Opinión
# ─────────────────────────────────────────────────────────────
## Lo que ya se tienen entre ellos (sin alianza, rivalidad ni infamia), con el olvido aplicado: simétrico.
func opinion_de(a: int, b: int) -> float:
	var f = opinion.get(clave(a, b))
	if f == null:
		return 0.0
	var dias := dia() - int(f[1])
	return move_toward(float(f[0]), 0.0, float(dias) / OP_REPOSO_DIAS) if dias > 0 else float(f[0])


func cambiar_opinion(a: int, b: int, delta: float, razon := "") -> void:
	var k := clave(a, b)
	opinion[k] = [clampf(opinion_de(a, b) + delta, -100.0, 100.0), dia()]
	if razon != "":
		var l: Array = razones.get(k, [])
		l.append([razon, delta, dia()])
		if l.size() > MAX_RAZONES:
			l = l.slice(l.size() - MAX_RAZONES)
		razones[k] = l
	version += 1


## Opinión que `a` tiene de `b`: el trato directo más la alianza (+20), la rivalidad (−25), la infamia de `b` (hasta −40) y estar en la coalición contra `b` (−20).
func opinion_total(a: int, b: int) -> float:
	var v := opinion_de(a, b)
	if son_aliados(a, b):
		v += 20.0
	if es_rival(a, b):
		v -= 25.0
	v -= minf(40.0, 3.0 * infamia(b))
	if en_coalicion_contra(a, b):
		v -= 20.0
	return clampf(v, -100.0, 100.0)


## Las partes de `opinion_total(a, b)` para la interfaz: [[texto, valor], ...] (solo las que no son cero).
func lectura(a: int, b: int) -> Array:
	var r := []
	var d := opinion_de(a, b)
	if absf(d) >= 0.5:
		r.append(["Trato entre ambos", d])
	if son_aliados(a, b):
		r.append(["Alianza", 20.0])
	if es_rival(a, b):
		r.append(["Rivalidad", -25.0])
	var inf := minf(40.0, 3.0 * infamia(b))
	if inf >= 0.5:
		r.append(["Infamia de %s" % _nombre(b), -inf])
	if en_coalicion_contra(a, b):
		r.append(["Forma parte de la coalición contra %s" % _nombre(b), -20.0])
	return r


func razones_de(a: int, b: int) -> Array:
	return razones.get(clave(a, b), [])


static func etiqueta_opinion(v: float) -> String:
	if v >= 60.0:
		return "Entrañable"
	if v >= 25.0:
		return "Amistosa"
	if v >= 8.0:
		return "Cordial"
	if v > -8.0:
		return "Neutral"
	if v > -25.0:
		return "Fría"
	if v > -60.0:
		return "Hostil"
	return "Enemiga"


# ─────────────────────────────────────────────────────────────
# Infamia
# ─────────────────────────────────────────────────────────────
func infamia(t: int) -> float:
	var f = _infamia.get(t)
	if f == null:
		return 0.0
	return float(f[0]) * pow(0.5, float(dia() - int(f[1])) / INFAMIA_VIDA_MEDIA)


func sumar_infamia(t: int, x: float) -> void:
	var v := infamia(t) + x
	_infamia[t] = [v, dia()]
	if v >= INFAMIA_COALICION:
		infames[t] = true
	version += 1


# ─────────────────────────────────────────────────────────────
# Alianzas y rivales
# ─────────────────────────────────────────────────────────────
func son_aliados(a: int, b: int) -> bool:
	return alianzas.has(clave(a, b))


func aliados_de(t: int) -> Array:
	return (_aliados.get(t, {}) as Dictionary).keys()


func rival_de(t: int) -> int:
	var f = _rival.get(t)
	if f == null:
		return -1
	if int(f["hasta"]) < dia():
		_rival.erase(t)
		return -1
	return int(f["b"])


func es_rival(a: int, b: int) -> bool:
	return rival_de(a) == b or rival_de(b) == a


## Por qué `a` y `b` no pueden aliarse ("" = pueden).
func motivo_sin_alianza(a: int, b: int) -> String:
	if a == b or not _existe(a) or not _existe(b):
		return "Uno de los dos no existe."
	if son_aliados(a, b):
		return "Ya son aliados."
	if g.en_guerra(a, b):
		return "Están en guerra."
	if es_rival(a, b):
		return "Hay rivalidad entre ellos."
	if (_aliados.get(a, {}) as Dictionary).size() >= MAX_ALIADOS or (_aliados.get(b, {}) as Dictionary).size() >= MAX_ALIADOS:
		return "Uno ya tiene %d aliados." % MAX_ALIADOS
	return ""


## ¿`b` aceptaría una alianza propuesta por `a`? Devuelve {"acepta", "motivo"}. La IA exige opinión de al menos OP_ALIANZA_MIN y no se alía con un país tan infame que atraería una coalición.
func evaluar_alianza(a: int, b: int) -> Dictionary:
	var m := motivo_sin_alianza(a, b)
	if m != "":
		return {"acepta": false, "motivo": m}
	var o := opinion_total(b, a)
	if o < OP_ALIANZA_MIN:
		return {"acepta": false, "motivo": "%s no confía lo bastante en %s (opinión %d, hacen falta %d)." % [_nombre(b), _nombre(a), int(roundf(o)), int(OP_ALIANZA_MIN)]}
	if infamia(a) >= INFAMIA_PRUDENTE:
		return {"acepta": false, "motivo": "%s no quiere ligarse a un país tan temido." % _nombre(b)}
	return {"acepta": true, "motivo": ""}


func formar_alianza(a: int, b: int, razon := "Alianza") -> bool:
	if motivo_sin_alianza(a, b) != "":
		return false
	alianzas[clave(a, b)] = dia()
	for par in [[a, b], [b, a]]:
		if not _aliados.has(par[0]):
			_aliados[par[0]] = {}
		_aliados[par[0]][par[1]] = true
	cambiar_opinion(a, b, 10.0, razon)
	alianzas_formadas += 1
	mundo.evento(a, "%s y %s firman una alianza." % [_nombre(a), _nombre(b)], b)
	version += 1
	return true


func romper_alianza(a: int, b: int, razon := "Alianza rota") -> void:
	if not alianzas.erase(clave(a, b)):
		return
	(_aliados[a] as Dictionary).erase(b)
	(_aliados[b] as Dictionary).erase(a)
	alianzas_rotas += 1
	mundo.evento(a, "La alianza entre %s y %s se rompe (%s)." % [_nombre(a), _nombre(b), razon.to_lower()], b)
	version += 1


func declarar_rival(a: int, b: int) -> bool:
	if a == b or not _existe(a) or not _existe(b) or rival_de(a) == b:
		return false
	_rival[a] = {"b": b, "hasta": dia() + RIVAL_DIAS}
	if son_aliados(a, b):
		romper_alianza(a, b, "rivalidad declarada")
	cambiar_opinion(a, b, -15.0, "Lo declaró su rival")
	mundo.evento(a, "%s declara rival a %s." % [_nombre(a), _nombre(b)], b)
	version += 1
	return true


func quitar_rival(a: int) -> void:
	if _rival.erase(a):
		version += 1


## El jugador manda un regalo: paga REGALO_DIAS días de sus ingresos y mejora la opinión del otro país.
func regalar(a: int, b: int) -> Dictionary:
	var na := _nombre(a)
	if not mundo.paises.has(na) or not _existe(b):
		return {"ok": false, "msg": "No se puede."}
	var e = mundo.paises[na]
	var coste: float = mundo.ingreso_diario_local(na) * REGALO_DIAS
	if not e.tiene_tesoreria() or coste <= 0.0 or e.tesoreria < coste:
		return {"ok": false, "msg": "No tienes caja para un regalo (cuesta %d días de ingresos)." % int(REGALO_DIAS)}
	e.tesoreria = e.tesoreria - coste
	cambiar_opinion(a, b, REGALO_OPINION, "Regalo de %s" % na)
	return {"ok": true, "msg": "%s agradece el regalo (+%d de opinión)." % [_nombre(b), int(REGALO_OPINION)]}


# ─────────────────────────────────────────────────────────────
# Coaliciones
# ─────────────────────────────────────────────────────────────
func en_coalicion_contra(a: int, objetivo: int) -> bool:
	var c = coaliciones.get(objetivo)
	return c != null and (c["miembros"] as Array).has(a)


## Contra quién está `a` en una coalición (-1 = en ninguna). Si hay varias, la del objetivo más infame.
func objetivo_coalicion_de(a: int) -> int:
	var mejor := -1
	var mejor_inf := -1.0
	for t in coaliciones:
		if (coaliciones[t]["miembros"] as Array).has(a):
			var inf := infamia(int(t))
			if inf > mejor_inf:
				mejor_inf = inf
				mejor = int(t)
	return mejor


## Soldados de los miembros de la coalición contra `objetivo` (sin contar a `salvo`) que aún no están en guerra con él.
func fuerza_coalicion(objetivo: int, salvo: int) -> int:
	var c = coaliciones.get(objetivo)
	if c == null:
		return 0
	var s := 0
	for m in c["miembros"]:
		if int(m) != salvo and not g.en_guerra(int(m), objetivo):
			s += ia._soldados(int(m))
	return s


func _formar_coalicion(t: int) -> void:
	ia._preparar_frentes()
	var cand := {}
	for v in ia._vecinos_dueno.get(t, {}):
		cand[int(v)] = true
	for c in ia.activas:                                                # los rivales declarados del objetivo también
		var ct: int = int(ia.activas[c]["tid"])
		if rival_de(ct) == t:
			cand[ct] = true
	var lista := []
	for c2 in cand:
		var ct2: int = int(c2)
		if ct2 == t or not ia.activas.has(_nombre(ct2)) or son_aliados(ct2, t) or g.en_guerra(ct2, t):
			continue
		var s: int = ia._soldados(ct2)
		if s < 2000:
			continue
		lista.append([s, ct2])
	if lista.size() < COALICION_MIN:
		return
	lista.sort_custom(func(a, b): return a[0] > b[0])
	var miembros := []
	for i in mini(lista.size(), MAX_MIEMBROS):
		miembros.append(int(lista[i][1]))
	coaliciones[t] = {"miembros": miembros, "desde": dia()}
	coaliciones_formadas += 1
	var nombres := []
	for m in miembros:
		nombres.append(_nombre(int(m)))
		cambiar_opinion(int(m), t, -20.0, "Coalición contra %s" % _nombre(t))
	for i2 in miembros.size():                                            # los conspiradores se acercan entre sí
		for j2 in range(i2 + 1, miembros.size()):
			cambiar_opinion(int(miembros[i2]), int(miembros[j2]), 8.0, "Causa común contra %s" % _nombre(t))
	var txt := "Coalición contra %s (infamia %.0f): %s." % [_nombre(t), infamia(t), ", ".join(nombres)]
	mundo.evento(t, txt, int(miembros[0]))
	if _es_jugador(t):
		mundo.avisos.append({"tipo": "coalicion", "objetivo": t, "miembros": miembros.duplicate(), "texto": txt})
	version += 1


func disolver_coalicion(t: int, razon := "") -> void:
	if not coaliciones.erase(t):
		return
	mundo.evento(t, "La coalición contra %s se disuelve%s." % [_nombre(t), (" (%s)" % razon) if razon != "" else ""])
	version += 1


func _revisar_coaliciones() -> void:
	for tk in infames.keys():
		var t: int = int(tk)
		var inf := infamia(t)
		if not _existe(t) or inf < INFAMIA_FIN:
			infames.erase(t)
			disolver_coalicion(t, "ya no es una amenaza" if _existe(t) else "el país desapareció")
		elif coaliciones.has(t):
			if dia() - int(coaliciones[t]["desde"]) > COALICION_MAX_DIAS:
				disolver_coalicion(t, "pasaron diez años")
		elif inf >= INFAMIA_COALICION:
			_formar_coalicion(t)
	for t2 in coaliciones.keys():                                         # un objetivo que ya no existe no necesita coalición
		if not _existe(int(t2)):
			disolver_coalicion(int(t2), "el país desapareció")


# ─────────────────────────────────────────────────────────────
# Llamadas de alianza
# ─────────────────────────────────────────────────────────────
func _llamar_aliados(agresor: int, defensor: int) -> void:
	for par in [[defensor, agresor], [agresor, defensor]]:                 # [a quién se ayuda, contra quién]
		for al in aliados_de(int(par[0])):
			if int(al) == int(par[1]) or g.en_guerra(int(al), int(par[1])):
				continue
			llamados.append({"aliado": int(al), "ayuda_a": int(par[0]), "contra": int(par[1]), "dia": dia()})


## El aliado `a` acude (o no) a la guerra de `ayuda_a` contra `contra`. Lo usan las IA y el pop-up del jugador.
func responder_llamado(a: int, ayuda_a: int, contra: int, acude: bool) -> void:
	if acude and not g.en_guerra(a, contra) and _existe(contra):
		if g.declarar(a, contra, "Alianza con %s" % _nombre(ayuda_a)) >= 0:
			llamadas_atendidas += 1
			cambiar_opinion(a, ayuda_a, 10.0, "Acudió a su llamada")
			return
	llamadas_rechazadas += 1
	cambiar_opinion(a, ayuda_a, -35.0, "No acudió a su llamada")
	romper_alianza(a, ayuda_a, "no acudió a la guerra")


func _acude_ia(a: int, ayuda_a: int, contra: int) -> bool:
	var nom := _nombre(a)
	if not ia.activas.has(nom):
		return false
	return opinion_total(a, ayuda_a) >= 10.0 and ia._soldados(a) >= 2000 and g.rivales_de(a).size() < ia.MAX_GUERRAS + 1 \
		and not son_aliados(a, contra) and mundo.puede_atacar(a, contra)


func _atender_llamados() -> void:
	var pendientes: Array = llamados
	llamados = []
	for e in pendientes:
		var a: int = e["aliado"]
		if dia() - int(e["dia"]) > LLAMADA_DIAS or not son_aliados(a, int(e["ayuda_a"])) or g.en_guerra(a, int(e["contra"])) or not _existe(a):
			continue
		if _es_jugador(a):
			if g.en_guerra(int(e["ayuda_a"]), int(e["contra"])):
				mundo.avisos.append({"tipo": "llamado", "aliado": a, "ayuda_a": int(e["ayuda_a"]), "contra": int(e["contra"])})
			continue
		if g.en_guerra(int(e["ayuda_a"]), int(e["contra"])):
			responder_llamado(a, int(e["ayuda_a"]), int(e["contra"]), _acude_ia(a, int(e["ayuda_a"]), int(e["contra"])))


# ─────────────────────────────────────────────────────────────
# Ganchos (los llaman Guerra y Mundo)
# ─────────────────────────────────────────────────────────────
func al_declarar(agresor: int, defensor: int, causa: String) -> void:
	cambiar_opinion(agresor, defensor, -60.0, "Declaró la guerra")
	if causa.begins_with("Alianza con"):
		return                                                           # acudir a una alianza no es agresión
	if son_aliados(agresor, defensor):
		romper_alianza(agresor, defensor, "traición")
		sumar_infamia(agresor, 5.0)
	elif ia != null and ia._en_tregua(agresor, defensor):
		sumar_infamia(agresor, 2.5)
	elif es_rival(agresor, defensor) or en_coalicion_contra(agresor, defensor):
		sumar_infamia(agresor, 0.3)
	else:
		sumar_infamia(agresor, 1.0)
	_llamar_aliados(agresor, defensor)


func al_paz(a: int, b: int) -> void:
	cambiar_opinion(a, b, 15.0, "Firmaron la paz")


## Una provincia cambió de dueño. Si fue por la fuerza (paz con posesión, tratado, anexión) el nuevo dueño gana infamia y el antiguo le guarda rencor.
func al_cambiar_dueno(idx: int, origen: int, destino: int, motivo: String) -> void:
	if origen < 0 or destino < 0 or not _es_conquista(motivo):
		return
	var peso := clampf(mundo.provincias[idx].poblacion / _pob_ref(), INFAMIA_PESO_MIN, INFAMIA_PESO_MAX)   # quedarse una ciudad grande pesa más que un páramo
	if mundo.cores != null and mundo.cores.listo:
		var core: int = mundo.bd.ref("core_nacional", mundo.provincias[idx].tid)
		if core >= 0 and core != destino and core != origen and _existe(core):
			peso *= 2.0                                                   # era la tierra propia de un tercero
	sumar_infamia(destino, peso)
	cambiar_opinion(origen, destino, -4.0)


## Población media de una provincia habitada (sirve de unidad para medir cuánto pesa una conquista; se calcula una vez por mundo).
func _pob_ref() -> float:
	if _pob_ref_n != mundo.provincias.size():
		_pob_ref_n = mundo.provincias.size()
		var t := 0.0
		var n := 0
		for pr in mundo.provincias:
			if pr.poblacion > 0.0:
				t += pr.poblacion
				n += 1
		_pob_ref_v = maxf(t / float(maxi(n, 1)), 1.0)
	return _pob_ref_v


static func _es_conquista(motivo: String) -> bool:
	return motivo.begins_with("Paz con") or motivo.begins_with("Tratado de paz") or motivo.begins_with("Anexi") or motivo.begins_with("Conquista")


# ─────────────────────────────────────────────────────────────
# Reloj
# ─────────────────────────────────────────────────────────────
## Una vez por paso de simulación: atiende las llamadas de alianza y, cada DIAS_REVISION días, las coaliciones y las alianzas que se enfriaron.
func fase_dia(_k := 1) -> bool:
	if not llamados.is_empty():
		_atender_llamados()
	if dia() >= _prox_revision:
		_prox_revision = dia() + DIAS_REVISION
		_revisar_coaliciones()
		for k in alianzas.keys():
			var p: PackedStringArray = String(k).split("|")
			var a := int(p[0])
			var b := int(p[1])
			if not _existe(a) or not _existe(b) or opinion_total(a, b) < OP_ALIANZA_ROMPE:
				romper_alianza(a, b, "se enfriaron las relaciones" if _existe(a) and _existe(b) else "uno desapareció")
	return false


# ─────────────────────────────────────────────────────────────
# Para la interfaz
# ─────────────────────────────────────────────────────────────
## Resumen de la situación de `a` con `b` en una línea ("Amistosa (+31) · aliados").
func texto_relacion(a: int, b: int) -> String:
	var v := opinion_total(a, b)
	var t := "%s (%+d)" % [etiqueta_opinion(v), int(roundf(v))]
	if son_aliados(a, b):
		t += " · aliados"
	if rival_de(a) == b:
		t += " · tu rival"
	elif rival_de(b) == a:
		t += " · te tiene por rival"
	if g.en_guerra(a, b):
		t += " · en guerra"
	elif ia != null and ia.tregua_restante(a, b) > 0:
		t += " · tregua (%d días)" % ia.tregua_restante(a, b)
	return t
