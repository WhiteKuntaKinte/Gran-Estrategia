extends RefCounted
## ICONOS DE MATERIAS PRIMAS, SECTORES Y MONEDAS (0.1.8.41): cada cultivo, animal, mineral, rubro y divisa tiene su propio icono HD.
##
## DÓNDE ESTÁN: `iconos/materias/<clave>.png` (cultivos, ganado, pesca, minerales, metales, piedras, gemas, energía), `iconos/sectores/<clave>.png`
## (rubros de la economía) e `iconos/divisas/d_<CÓDIGO>.png` (una moneda por divisa, con su símbolo). Se piden con `main.icono("materias/trigo")`.
## CÓMO SE ELIGE: `datos/materias_iconos.json` (lo genera `herramientas/iconos_materias/generar.py`, no se edita a mano) trae
##   · `alias`: nombre del juego sin tildes ("cana_de_azucar") -> icono ("materias/cana");
##   · `reglas`: palabras que, si aparecen en el nombre de un rubro ("manufactura_automotriz"), dan su icono ("sectores/automotriz"); la primera que coincide gana;
##   · `existentes`: lista de los iconos que hay en disco (así nunca se pide un archivo que falta).
## Para AÑADIR un material nuevo: dibujarlo en herramientas/iconos_materias/ (explicado en generar.py) y volver a generar.

const PinturasScript := preload("res://scripts/pinturas.gd")
const RUTA := "res://datos/materias_iconos.json"
const ICONO_MONEDA := "i_moneda"                        # el de siempre, para una divisa sin icono propio

var main
var alias := {}                                         # "cana_de_azucar" -> "materias/cana"
var reglas: Array = []                                  # [["automotri", "sectores/automotriz"], ...]
var existe := {}                                        # "materias/cana" -> true, "divisas/d_USD" -> true
var _memo := {}                                         # "nombre|rubro" -> icono (la búsqueda gasta; el mismo nombre sale muchas veces)
var listo := false


func iniciar(m) -> void:
	main = m
	alias = {}
	reglas = []
	existe = {}
	_memo = {}
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		listo = false
		return
	var js = JSON.parse_string(f.get_as_text())
	if not (js is Dictionary):
		listo = false
		return
	alias = js.get("alias", {})
	reglas = js.get("reglas", [])
	var ex: Dictionary = js.get("existentes", {})
	for carpeta in ex:
		for k in ex[carpeta]:
			existe["%s/%s" % [carpeta, ("d_" + String(k)) if carpeta == "divisas" else String(k)]] = true
	listo = not alias.is_empty()


## Icono de un material o rubro por su nombre («Caña de azúcar», «Pollo y arroz», «Manufactura (automotriz)»). "" si no hay ninguno.
## `rubro` (opcional) es el rubro económico del que sale el nombre: ayuda cuando el nombre solo no basta.
func de_nombre(nombre: String, rubro := "") -> String:
	if not listo or nombre == "":
		return ""
	var llave := nombre + "|" + rubro
	if _memo.has(llave):
		return String(_memo[llave])
	var r := _buscar(nombre, rubro)
	_memo[llave] = r
	return r


func _buscar(nombre: String, rubro: String) -> String:
	var k := PinturasScript.clave(nombre)
	if alias.has(k):
		return String(alias[k])
	var par := nombre.find("(")
	if par > 0:
		var k2 := PinturasScript.clave(nombre.substr(0, par))
		if alias.has(k2):
			return String(alias[k2])
	for parte in nombre.replace(",", " y ").split(" y "):                         # «Pollo y arroz» -> el de «Pollo»
		var kp := PinturasScript.clave(String(parte))
		if kp != "" and alias.has(kp):
			return String(alias[kp])
	for texto in [k, PinturasScript.clave(rubro)]:
		if texto == "":
			continue
		for r in reglas:
			if String(texto).contains(String(r[0])):
				return String(r[1])
	return ""


## Como `de_nombre`, pero devuelve `defecto` (p. ej. "i_cultivo") si no hay icono propio.
func o_defecto(nombre: String, rubro: String, defecto: String) -> String:
	var r := de_nombre(nombre, rubro)
	return r if r != "" else defecto


## Moneda de una divisa («USD» -> "divisas/d_USD"); el icono de siempre si esa divisa no tiene.
func de_divisa(codigo: String) -> String:
	var k := "divisas/d_" + codigo
	return k if existe.has(k) else ICONO_MONEDA


## Moneda de un país: la de su divisa. En el año 1 no hay monedas modernas: se queda el icono genérico.
func de_pais(pais: String) -> String:
	if main == null or main.mundo == null or main.epoca != main.EPOCA_ACTUAL:
		return ICONO_MONEDA
	var dv = main.mundo.divisa_de(pais)
	return de_divisa(String(dv.codigo)) if dv != null else ICONO_MONEDA


## Cuántos iconos hay por carpeta: {"materias": n, "sectores": n, "divisas": n}.
func contar() -> Dictionary:
	var r := {}
	for k in existe:
		var c := String(k).get_slice("/", 0)
		r[c] = int(r.get(c, 0)) + 1
	return r
