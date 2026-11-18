extends RefCounted
## NOMBRES GENERADOS (0.1.8.52): personas, ciudades y epítetos inventados con el sonido de cada región y época.
## Todo sale de sílabas propias del juego: no copia nombres de gente real. Determinista: la misma semilla da el mismo nombre.
## Lo usan los gobernantes (scripts/gobierno.gd), y servirá a los sabios, las ciudades nuevas y las casas reales.

const ESTILOS := {
	"latino": {"pre": ["Al", "Ber", "Cris", "Dom", "Fer", "Gon", "Lu", "Mar", "Ped", "Raim", "Sanc", "Teo", "Vi", "Ala", "Ia", "Leo", "Ro"],
		"sm": ["fonso", "nardo", "tóbal", "ingo", "nando", "zalo", "is", "cos", "ro", "undo", "cho", "ncio", "cente", "rico", "mundo"], "sf": ["ra", "na", "bela", "isa", "inda", "ia", "ca", "nza"],
		"cp": ["Villa", "San", "Monte", "Puerto", "Val", "Cas", "Torre", "Roca", "Santa"], "cs": ["nueva", "real", "alta", "mar", "blanca", "dor", "grande", "fuerte", "verde"]},
	"germanico": {"pre": ["Ald", "Bern", "Eg", "Fried", "Gund", "Hein", "Ott", "Rud", "Sig", "Wolf", "Ulr", "Ead", "Thor", "Leif", "Ing"],
		"sm": ["rich", "helm", "bert", "mar", "olf", "win", "ard", "mund", "ric", "ulf"], "sf": ["hild", "trud", "burg", "gard", "wyn", "lind", "rid"],
		"cp": ["Wald", "Stein", "Burg", "Hohen", "Nord", "Eich", "Dun", "Holm"], "cs": ["burg", "heim", "stadt", "furt", "by", "ford", "wick", "dorf"]},
	"eslavo": {"pre": ["Bog", "Dra", "Mir", "Rost", "Sveto", "Vla", "Yaro", "Zbi", "Rat", "Ost", "Vse"],
		"sm": ["slav", "mir", "dan", "rad", "gor", "vit", "bor", "mil"], "sf": ["slava", "mila", "dara", "na", "ka", "vna"],
		"cp": ["Nov", "Star", "Bel", "Kras", "Zlat", "Vel", "Chern"], "cs": ["grad", "gorod", "pol", "ov", "sk", "ice", "lav"]},
	"griego": {"pre": ["Alex", "Dem", "Eur", "Kall", "Leon", "Nik", "Philo", "Theo", "Xen", "Ari", "Pyth"],
		"sm": ["andros", "ides", "ippos", "stratos", "menes", "kles", "os", "ion", "krates"], "sf": ["ippe", "ene", "ia", "ope", "ina", "ika"],
		"cp": ["Neo", "Hiera", "Kala", "Pan", "Eu", "Alko", "Thermo"], "cs": ["polis", "ia", "ae", "mos", "thos", "kleia", "ona"]},
	"arabe": {"pre": ["Abd", "Ahm", "Bad", "Far", "Hish", "Ibr", "Kha", "Mans", "Nas", "Sal", "Tar", "Yaz", "Zayn", "Rash"],
		"sm": ["ad", "ir", "ib", "ur", "an", "id", "aq", "ik"], "sf": ["a", "ia", "ira", "ina", "ima", "ila"],
		"cp": ["Al-", "Dar ", "Bab ", "Madi", "Qasr ", "Ras "], "cs": ["bar", "qand", "hira", "mar", "sala", "khan", "ziz"]},
	"turco": {"pre": ["Alp", "Bay", "Kil", "Mel", "Osm", "Tur", "Tog", "Ulu", "Yil", "Kar", "Ar"],
		"sm": ["han", "bey", "tegin", "arslan", "can", "mur", "tay"], "sf": ["ay", "gul", "sen", "han", "ge"],
		"cp": ["Kara", "Ak", "Yeni", "Bal", "Kon", "Sivri"], "cs": ["kent", "hisar", "ova", "pazar", "kale", "dag"]},
	"persa": {"pre": ["Dar", "Kav", "Khos", "Bah", "Far", "Mih", "Ard", "Sha", "Ras", "Ner"],
		"sm": ["ius", "rau", "ram", "dad", "shir", "ak", "van"], "sf": ["dokht", "zad", "in", "eh", "ush"],
		"cp": ["Shah", "Gul", "Dasht", "Bagh", "Nev"], "cs": ["abad", "shahr", "kand", "stan", "var", "dasht"]},
	"indio": {"pre": ["Aja", "Chan", "Dev", "Har", "Indra", "Jay", "Kum", "Mah", "Raj", "Sur", "Vik", "Ash", "Bhim"],
		"sm": ["deva", "pala", "gupta", "varma", "raja", "simha", "ditya", "nanda", "datta"], "sf": ["devi", "mati", "kumari", "ni", "ka", "bai"],
		"cp": ["Ratna", "Suvarna", "Giri", "Maha", "Nava", "Sri"], "cs": ["pur", "nagar", "pura", "abad", "garh", "palli"]},
	"chino": {"pre": ["Wen", "Guang", "Ming", "Yong", "Jian", "Hong", "Tai", "De", "Zhi", "Xiao", "Yuan"], "fam": ["Zhao", "Li", "Liu", "Wang", "Chen", "Yang", "Han", "Gao", "Zhou", "Xu"],
		"sm": ["wu", "di", "zong", "zu", "an", "ping", "jie", "hua"], "sf": ["mei", "lan", "yue", "ying", "xia", "zhen"],
		"cp": ["Chang", "Lin", "Jiang", "Bei", "Nan", "Tai", "Xin"], "cs": ["an", "zhou", "jing", "yang", "cheng", "du", "chuan"]},
	"japones": {"pre": ["Taka", "Yori", "Masa", "Fuji", "Mina", "Tada", "Kane", "Nori", "Hide", "Sada", "Kiyo"],
		"sm": ["hira", "mori", "toshi", "hito", "moto", "yoshi", "nobu", "kazu"], "sf": ["ko", "e", "hime", "no", "ka", "yo"],
		"cp": ["Kita", "Higashi", "Naga", "Shimo", "Aki", "Yama"], "cs": ["saki", "hama", "kawa", "yama", "no", "oka", "ura"]},
	"coreano": {"pre": ["Min", "Seo", "Ji", "Dong", "Hyun", "Tae", "Gyeong"], "fam": ["Kim", "Park", "Lee", "Choi", "Jeong", "Wang", "Gang"],
		"sm": ["jun", "won", "hoon", "soo", "jin", "hyeon", "gil"], "sf": ["yeon", "hee", "ra", "mi", "eun"],
		"cp": ["Han", "Dae", "Sin", "Pyeong", "Gwang", "Nam"], "cs": ["ju", "ju", "sung", "yang", "po", "ju"]},
	"sudeste": {"pre": ["Jaya", "Sri", "Ba", "Rama", "Ang", "Kert", "Suri", "Cha", "Indra", "Nara"],
		"sm": ["varman", "nagara", "wijaya", "kesa", "patih", "kung", "pha", "jaya"], "sf": ["wati", "dewi", "mala", "kan", "devi"],
		"cp": ["Angkor", "Maha", "Sri", "Nakhon", "Wat", "Bukit"], "cs": ["pura", "nagara", "buri", "sari", "wat", "kota"]},
	"africano_oeste": {"pre": ["Ama", "Ous", "Sun", "Kofi", "Mansa", "Aba", "Obe", "Tun", "Sekou", "Adi", "Idr"],
		"sm": ["dou", "mane", "diata", "ngo", "kou", "wa", "ko", "jide"], "sf": ["ata", "fa", "nke", "lewa", "bi"],
		"cp": ["Kum", "Tim", "Gao", "Dja", "Wa", "Kano"], "cs": ["bi", "ssa", "nne", "koro", "ngo", "tala", "bu"]},
	"africano_este": {"pre": ["Ame", "Hail", "Men", "Tek", "Yohan", "Zer", "Kass", "Isa", "Sel"],
		"sm": ["lak", "bar", "elik", "la", "bede", "fa", "ssa"], "sf": ["ye", "ret", "tu", "ba", "net"],
		"cp": ["Ad", "Ax", "Gon", "Har", "Lal", "Mog"], "cs": ["dar", "um", "ibela", "adishu", "ar", "ssa"]},
	"bantu": {"pre": ["Cha", "Lub", "Mwe", "Ndu", "Kag", "Tsh", "Zum", "Mos", "Mbe"],
		"sm": ["ka", "ngo", "mbi", "ndwe", "nsa", "lo", "ndu"], "sf": ["ni", "la", "ne", "ya", "ssa"],
		"cp": ["Mu", "Ka", "Ngo", "Lu", "Ma", "Zim"], "cs": ["bwe", "nde", "mbo", "sa", "mba", "gwe"]},
	"nativo_na": {"pre": ["Ata", "Ko", "Mah", "Nan", "Tecum", "Wapa", "Yan", "Ona", "Cha"],
		"sm": ["kwa", "ntsi", "nee", "tu", "ha", "wana", "lee"], "sf": ["na", "wa", "ki", "ta"],
		"cp": ["Mini", "Ota", "Sho", "Kana", "Oha"], "cs": ["wak", "ta", "toga", "kee", "nee", "hiyo"]},
	"maya_nahua": {"pre": ["Ahau", "Chak", "Itz", "Kuk", "Moc", "Tlac", "Xoch", "Yax", "Nez", "Cuit"],
		"sm": ["tl", "auh", "lan", "pech", "kan", "chi", "coatl", "ma"], "sf": ["xochitl", "itzel", "ka", "tla"],
		"cp": ["Tla", "Chi", "Xi", "Ix", "Tul", "Co"], "cs": ["pan", "tlan", "ha", "kal", "can", "maya"]},
	"andino": {"pre": ["Atau", "Hua", "Mayta", "Pacha", "Tupa", "Yupan", "Sinchi", "Quis", "Cusi"],
		"sm": ["pa", "c", "yupanqui", "ti", "qui", "mayta", "huallpa"], "sf": ["coya", "mama", "chuya", "ni"],
		"cp": ["Hua", "Cusi", "Pacha", "Tiwa", "Chan"], "cs": ["marca", "pampa", "huasi", "naku", "chaca", "cay"]},
	"polinesio": {"pre": ["Aro", "Kamea", "Tui", "Mana", "Hina", "Lono", "Kai", "Moa"],
		"sm": ["hau", "lani", "ana", "tama", "loa", "keao"], "sf": ["lani", "nui", "ia", "kea"],
		"cp": ["Hawa", "Ta", "Sa", "Ra", "Tonga"], "cs": ["iki", "moa", "pu", "tapu", "nui", "rea"]},
	"aborigen": {"pre": ["Bun", "Wur", "Gul", "Mar", "Dja", "Yir", "Nga"],
		"sm": ["jil", "anga", "nga", "ba", "gu", "ri"], "sf": ["la", "bi", "ra"],
		"cp": ["Bur", "Mun", "Wal", "Yar"], "cs": ["ra", "gal", "bin", "mulla", "dilla"]},
	"anglo": {"pre": ["Ed", "Wil", "Har", "Ric", "Ger", "Arth", "Osw", "Hen", "Ar", "Cle", "Gil"],
		"sm": ["ward", "liam", "old", "hard", "ald", "ur", "ry", "ment", "ric"], "sf": ["a", "ith", "ine", "elle", "ia", "wen"],
		"cp": ["New", "Fair", "Green", "North", "West", "Stone", "Mill"], "cs": ["ton", "ford", "field", "bridge", "haven", "wood", "port"]},
}

const EPITETOS := {"prudente": ["el Prudente", "la Prudente"], "belicoso": ["el Belicoso", "la Belicosa"], "avaro": ["el Avaro", "la Avara"], "piadoso": ["el Piadoso", "la Piadosa"],
	"culto": ["el Sabio", "la Sabia"], "cruel": ["el Cruel", "la Cruel"], "carismatico": ["el Magnífico", "la Magnífica"], "enfermizo": ["el Enfermizo", "la Enfermiza"],
	"justo": ["el Justo", "la Justa"], "ambicioso": ["el Ambicioso", "la Ambiciosa"]}


## El estilo de nombres de un lugar: `continente` y el centro (lon/lat) del país, según la época (los pueblos de América y Oceanía que ya son países modernos llevan nombres de sus lenguas coloniales).
static func estilo_de(continente: String, lon: float, lat: float, anio: int) -> String:
	match continente:
		"Europa":
			if lon >= 17.0 and lat >= 44.0 and lat < 60.0 and lon < 45.0:
				return "eslavo"
			if lon >= 19.0 and lon < 30.0 and lat < 42.5:
				return "griego"
			if lat >= 55.5 or (lat >= 47.5 and lon >= -5.0 and lon < 17.0) or (lat >= 50.0 and lon < -5.0):
				return "anglo" if (lon < 2.0 and lat >= 50.0 and lat < 60.0) else "germanico"
			return "latino"
		"Asia":
			if lon >= 124.0 and lon < 131.0 and lat >= 33.0 and lat < 43.5:
				return "coreano"
			if lon >= 129.0 and lat >= 30.0 and lat < 46.0:
				return "japones"
			if lon >= 100.0 and lat < 22.5:
				return "sudeste"
			if lon >= 92.0 and lat >= 22.5 and lat < 53.0 and lon < 124.0:
				return "chino"
			if lon >= 60.0 and lat < 36.0:
				return "indio"
			if lon >= 44.0 and lon < 63.0 and lat < 40.0:
				return "persa"
			if lon >= 26.0 and lat >= 36.0 and lon < 45.0 and lat < 43.0:
				return "turco"
			if lon >= 50.0 and lat >= 36.0:
				return "turco"
			if lon < 62.0:
				return "arabe"
			if lon >= 19.0 and lat >= 44.0:
				return "eslavo"
			return "chino"
		"África":
			if lat >= 15.5:
				return "arabe"
			if lon < 8.0:
				return "africano_oeste"
			if lon >= 28.0 and lat > -4.0:
				return "africano_este"
			return "bantu"
		"América del Norte":
			if anio >= 1750:
				return "anglo" if lat >= 25.5 else "latino"
			return "maya_nahua" if lat < 25.5 else "nativo_na"
		"América del Sur":
			if anio >= 1700:
				return "latino"
			return "andino" if lon <= -64.5 else "nativo_na"
		"Oceanía":
			if anio >= 1800:
				return "anglo"
			return "polinesio" if lon > 140.0 else "aborigen"
	return "latino"


static func _nuevo(rng: RandomNumberGenerator, lista: Array) -> String:
	return String(lista[rng.randi() % lista.size()])


## Un nombre de pila inventado.
static func persona(estilo: String, mujer: bool, rng: RandomNumberGenerator) -> String:
	var e: Dictionary = ESTILOS.get(estilo, ESTILOS["latino"])
	var n := _nuevo(rng, e["pre"]) + _nuevo(rng, e["sf"] if mujer else e["sm"])
	n = n.capitalize() if not n.contains(" ") else n
	if e.has("fam") and rng.randf() < 0.9:
		return "%s %s" % [_nuevo(rng, e["fam"]), n.to_lower().capitalize()]
	return n.substr(0, 1).to_upper() + n.substr(1)


## Una ciudad inventada.
static func ciudad(estilo: String, rng: RandomNumberGenerator) -> String:
	var e: Dictionary = ESTILOS.get(estilo, ESTILOS["latino"])
	var n := _nuevo(rng, e["cp"]) + _nuevo(rng, e["cs"])
	return n.substr(0, 1).to_upper() + n.substr(1)


static func romano(n: int) -> String:
	var tabla := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var r := ""
	for par in tabla:
		while n >= int(par[0]):
			r += String(par[1])
			n -= int(par[0])
	return r


static func epiteto(rasgo: String, mujer: bool) -> String:
	var e: Array = EPITETOS.get(rasgo, [])
	if e.is_empty():
		return ""
	return String(e[1] if mujer else e[0])
