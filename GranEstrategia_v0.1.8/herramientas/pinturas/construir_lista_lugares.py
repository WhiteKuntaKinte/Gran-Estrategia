#!/usr/bin/env python3
"""
Arma la lista de búsqueda de las pinturas POR LUGAR (0.1.8.43): una obra de dominio público ligada a una provincia (o a un estado de EE. UU.)
concreta, para que su panel no repita la pintura de todo el país.

  python3 construir_lista_lugares.py            -> escribe lista_busqueda_4.json (la lee el flujo «Traer pinturas», modo buscar)

CLAVES (las mismas que usa scripts/pinturas.gd, con el nombre sin tildes, en minúsculas y con «_»):
  2026/lugar_<pais>__<provincia>          p. ej. 2026/lugar_espana__toledo
  2026/estado_estados_unidos__<estado>    p. ej. 2026/estado_estados_unidos__california
Los nombres son los de la base de datos de 2026 (los de `Provincia.nombre` y `Provincia.estado`). Se agrega un lugar escribiendo una línea en LUGARES.
"""
import json, os, re, unicodedata


def clave(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


# (país, provincia, [consultas en inglés/idioma de Commons])
LUGARES = [
    ("España", "Toledo", ["El Greco View of Toledo", "El Greco Vista de Toledo", "El Greco Toledo landscape"]),
    ("España", "Sevilla", ["Murillo Sevilla painting", "Sorolla Sevilla Jardines del Alcazar", "View of Seville 17th century painting"]),
    ("España", "Valencia", ["Sorolla Paseo a orillas del mar", "Sorolla Valencia playa", "Sorolla Valencian fisherwomen"]),
    ("España", "Barcelona", ["Ramon Casas painting Barcelona", "Santiago Rusinol painting", "Ramon Casas Plaza de toros"]),
    ("España", "Madrid", ["Velazquez Las Meninas", "Goya Madrid painting San Isidro", "Goya La pradera de San Isidro"]),
    ("España", "Granada", ["Alhambra painting David Roberts", "Alhambra Court of the Lions painting", "Granada Alhambra 19th century painting"]),
    ("España", "Asturias", ["Madrazo Batalla de Covadonga", "Covadonga painting Pelayo", "Asturias painting 19th century landscape"]),
    ("España", "Segovia", ["Zuloaga Segovia", "Ignacio Zuloaga Segovia painting", "Segovia aqueduct painting"]),
    ("Francia", "París", ["Caillebotte Paris Street Rainy Day", "Caillebotte Pont de l'Europe", "Pissarro Boulevard Montmartre"]),
    ("Francia", "Sena Marítimo", ["Monet Rouen Cathedral", "Monet Impression Sunrise Le Havre", "Monet Cathedrale de Rouen facade"]),
    ("Francia", "Bocas del Ródano", ["Van Gogh Starry Night Over the Rhone", "Van Gogh Cafe Terrace at Night", "Van Gogh Arles painting"]),
    ("Francia", "Yvelines", ["Versailles painting Pierre-Denis Martin", "Château de Versailles 17th century painting", "Monet Argenteuil"]),
    ("Francia", "Sena y Marne", ["Millet Angelus", "Millet The Gleaners", "Barbizon school painting"]),
    ("Francia", "Vaucluse", ["Avignon painting Pont d'Avignon", "Palais des Papes Avignon painting", "Hubert Robert Avignon"]),
    ("Italia", "Venecia", ["Canaletto Grand Canal Venice", "Canaletto Il Canal Grande", "Guardi Venice painting"]),
    ("Italia", "Roma", ["Giovanni Paolo Panini Rome", "Panini Ancient Rome", "Piranesi Rome painting"]),
    ("Italia", "Florencia", ["Botticelli Birth of Venus", "Botticelli Primavera", "Florence Duomo painting"]),
    ("Italia", "Nápoles", ["Joseph Wright of Derby Vesuvius", "Pompeii fresco", "Naples bay painting Gaspar van Wittel"]),
    ("Italia", "Milán", ["Leonardo Last Supper", "Leonardo da Vinci Ultima Cena", "Milan Duomo painting"]),
    ("Italia", "Siena", ["Lorenzetti Allegory of Good Government", "Ambrogio Lorenzetti Siena fresco", "Duccio Maesta"]),
    ("Italia", "Padua", ["Giotto Scrovegni Chapel", "Giotto Lamentation Padua", "Mantegna Padua Eremitani"]),
    ("Italia", "Perugia", ["Giotto Assisi Saint Francis fresco", "Giotto Legend of Saint Francis Assisi", "Perugino Perugia"]),
    ("Italia", "Palermo", ["Cappella Palatina Palermo mosaic", "Triumph of Death Palermo fresco", "Palermo painting 19th century"]),
    ("Países Bajos", "Holanda Meridional", ["Vermeer View of Delft", "Vermeer Het Straatje", "Vermeer Delft painting"]),
    ("Países Bajos", "Holanda Septentrional", ["Berckheyde Amsterdam Dam Square", "Jan van der Heyden Amsterdam", "Amsterdam canal painting 17th century"]),
    ("Países Bajos", "Frisia", ["Hendrick Avercamp winter landscape skaters", "Avercamp Winter Landscape with Skaters", "Avercamp Ice Scene"]),
    ("Países Bajos", "Brabante Septentrional", ["Van Gogh The Potato Eaters", "Van Gogh Nuenen", "Van Gogh Weaver Nuenen"]),
    ("Países Bajos", "Zelanda", ["Mondrian Domburg church tower", "Mondrian Dune landscape Domburg", "Mondrian Westkapelle"]),
    ("Reino Unido", "Londres", ["Monet Houses of Parliament", "Monet Waterloo Bridge", "Canaletto London Thames"]),
    ("Reino Unido", "Edimburgo", ["Nasmyth Edinburgh from Calton Hill", "Edinburgh painting Alexander Nasmyth", "Edinburgh castle painting 19th century"]),
    ("Reino Unido", "Argyll and Bute", ["Turner Fingal's Cave Staffa", "Turner Staffa Fingal's Cave", "Mendelssohn Fingal's Cave painting"]),
    ("Reino Unido", "Cornualles", ["Stanhope Forbes A Fish Sale on a Cornish Beach", "Newlyn school painting", "Cornwall painting Stanhope Forbes"]),
    ("Reino Unido", "Cumbria", ["Turner Buttermere", "Lake District painting 19th century", "Thomas Gainsborough Lake District painting"]),
    ("Reino Unido", "Suffolk", ["Constable The Hay Wain", "Constable Flatford Mill", "Constable Dedham Vale"]),
    ("Reino Unido", "Wiltshire", ["Constable Salisbury Cathedral from the Meadows", "Constable Salisbury Cathedral", "Turner Stonehenge"]),
    ("Reino Unido", "Dorset", ["Constable Weymouth Bay", "Weymouth Bay painting", "Dorset coast painting 19th century"]),
    ("Reino Unido", "Birmingham", ["Burne-Jones Star of Bethlehem", "Burne-Jones Adoration of the Magi", "Pre-Raphaelite Birmingham"]),
    ("Alemania", "Sajonia", ["Bellotto Dresden from the right bank of the Elbe", "Canaletto Dresden Zwinger", "Caspar David Friedrich Dresden"]),
    ("Alemania", "Berlín", ["Adolph Menzel Berlin-Potsdam railway", "Menzel Flötenkonzert", "Berlin painting 19th century Menzel"]),
    ("Alemania", "Baviera", ["Spitzweg Der arme Poet", "Spitzweg The Poor Poet", "Munich painting Spitzweg"]),
    ("Alemania", "Mecklemburgo-Pomerania Occidental", ["Caspar David Friedrich Chalk Cliffs on Rügen", "Friedrich Kreidefelsen auf Rügen", "Friedrich Greifswald"]),
    ("Alemania", "Renania del Norte-Westfalia", ["Stefan Lochner Adoration of the Magi Cologne", "Lochner Cologne Cathedral altarpiece", "Cologne cathedral painting"]),
    ("Alemania", "Baden-Wurtemberg", ["Hans Thoma Black Forest painting", "Hans Thoma Schwarzwald", "Black Forest painting 19th century"]),
    ("Alemania", "Sajonia-Anhalt", ["Cranach Martin Luther Wittenberg", "Cranach Lutherbildnis", "Wittenberg painting"]),
    ("Austria", "Viena", ["Klimt The Kiss", "Klimt Der Kuss", "Klimt Vienna Burgtheater"]),
    ("Austria", "Salzburgo", ["Salzburg painting 19th century", "Salzburg Friedrich Loos", "Hohensalzburg painting"]),
    ("Austria", "Tirol", ["Egger-Lienz Totentanz", "Albin Egger-Lienz painting", "Tyrol painting Egger-Lienz Das Kreuz"]),
    ("Suiza", "Berna", ["Hodler Lake Thun", "Hodler Thunersee und Stockhornkette", "Hodler Eiger Monch Jungfrau"]),
    ("Suiza", "Ginebra", ["Hodler Lake Geneva Mont Blanc", "Hodler Le Léman", "Liotard Geneva"]),
    ("Suiza", "Lucerna", ["Turner Lake Lucerne", "Turner Lucerne painting", "Lake Lucerne painting"]),
    ("Suiza", "Los Grisones", ["Segantini Alpine Pastures", "Segantini Alpine landscape", "Giovanni Segantini painting Engadin"]),
    ("Polonia", "Voivodato de Pequeña Polonia", ["Matejko Stanczyk", "Wyspianski Krakow painting", "Krakow Wawel painting 19th century"]),
    ("Polonia", "Voivodato de Mazovia", ["Bellotto Warsaw view", "Canaletto Warsaw Krakowskie Przedmiescie", "Bellotto Warszawa painting"]),
    ("Chequia", "Praga", ["Mucha Slav Epic", "Mucha The Slav Epic Slavs in their original homeland", "Prague painting 19th century"]),
    ("Hungría", "Budapest", ["Munkacsy Honfoglalas", "Budapest Danube painting 19th century", "Feszty Arpad Magyar landing painting"]),
    ("Noruega", "Oslo", ["Munch The Scream", "Edvard Munch Skrik", "Munch Oslo fjord painting"]),
    ("Noruega", "Hordaland", ["Dahl View from Stalheim", "Johan Christian Dahl Bergen painting", "Tidemand Gude Bridal Procession Hardangerfjord"]),
    ("Suecia", "Estocolmo", ["Carl Larsson painting", "Stockholm painting 19th century", "Richard Bergh Stockholm"]),
    ("Suecia", "Dalarna", ["Anders Zorn Midsummer Dance", "Zorn Midsommardans", "Anders Zorn Mora painting"]),
    ("Finlandia", "Uusimaa", ["Edelfelt Helsinki painting", "Albert Edelfelt Kaivopuisto", "Helsinki painting 19th century"]),
    ("Finlandia", "Carelia del Norte", ["Gallen-Kallela Aino Myth", "Gallen-Kallela Kullervo Cursing", "Gallen-Kallela Lemminkainen's Mother"]),
    ("Dinamarca", "Capital", ["Hammershoi Copenhagen painting", "Eckersberg Marble Quay Copenhagen", "Copenhagen Eckersberg painting"]),
    ("Dinamarca", "Jutlandia Septentrional", ["Krøyer Summer Evening on Skagen Beach", "Krøyer Skagen painting", "Skagen painters Hip Hip Hurra"]),
    ("Islandia", "Suðurland", ["Thorlaksson Thingvellir painting", "Þórarinn B. Þorláksson Þingvellir", "Iceland landscape painting 19th century"]),
    ("Rusia", "Moscú", ["Polenov Moscow Courtyard", "Apollinary Vasnetsov Moscow Kremlin", "Vasnetsov Moscow painting"]),
    ("Rusia", "San Petersburgo", ["Bronze Horseman painting Saint Petersburg", "Kustodiev Saint Petersburg painting", "Saint Petersburg Neva painting 19th century"]),
    ("Rusia", "República autónoma de Crimea", ["Aivazovsky Crimea painting", "Aivazovsky Feodosia", "Aivazovsky Black Sea Crimea"]),
    ("Rusia", "Briansk", ["Shishkin Morning in a Pine Forest", "Shishkin Pine forest", "Shishkin Rye"]),
    ("Rusia", "Ivánovo", ["Levitan After the rain Plyos", "Levitan Volga painting", "Levitan Plyos"]),
    ("Rusia", "Pskov", ["Roerich Pskov", "Roerich Pskovo-Pechersky Monastery", "Pskov Kremlin painting"]),
    ("Ucrania", "Kiev", ["Kuindzhi Moonlit Night on the Dnieper", "Kuindzhi Dnieper in the morning", "Kyiv painting 19th century"]),
    ("Ucrania", "Odesa", ["Aivazovsky Odessa Moonlit Night", "Aivazovsky Odessa", "Odessa painting 19th century"]),
    ("Turquía", "Estambul", ["Aivazovsky Constantinople Golden Horn", "Gerome Istanbul painting", "Istanbul Bosphorus painting 19th century"]),
    ("Grecia", "Ática", ["Klenze Acropolis Athens ideal view", "Acropolis painting 19th century", "Athens Acropolis painting Edward Dodwell"]),
    ("Grecia", "Creta", ["El Greco View of Mount Sinai", "Cretan icon painting", "Crete painting Candia"]),
    ("Grecia", "Monte Athos", ["Mount Athos monastery painting", "Athos fresco", "Mount Athos icon"]),
    ("Egipto", "Guiza", ["David Roberts Pyramids of Giza", "David Roberts Great Sphinx", "Giza pyramids painting 19th century"]),
    ("Egipto", "Lúxor", ["David Roberts Karnak", "David Roberts Temple of Luxor", "Luxor painting Karnak 19th century"]),
    ("Egipto", "Asuán", ["David Roberts Philae", "Philae temple painting", "Aswan painting 19th century"]),
    ("Egipto", "Fayún", ["Fayum mummy portrait", "Fayum portrait of a young man", "Fayum portrait of a woman"]),
    ("Egipto", "El Cairo", ["David Roberts Cairo gate", "Gerome Cairo painting", "Cairo painting 19th century"]),
    ("Irán", "Isfahán", ["Chehel Sotoun mural Isfahan", "Isfahan painting Safavid", "Chehel Sotoun painting"]),
    ("Irán", "Teherán", ["Kamal-ol-Molk Hall of Mirrors", "Kamal-ol-Molk painting Golestan", "Golestan Palace painting"]),
    ("Irán", "Fars", ["Persepolis painting Flandin", "Flandin Coste Persepolis", "Persepolis 19th century painting"]),
    ("India", "Kerala", ["Raja Ravi Varma painting", "Raja Ravi Varma Shakuntala", "Ravi Varma Kerala"]),
    ("India", "Uttar Pradesh", ["Taj Mahal painting 19th century", "Mughal painting Agra Taj Mahal", "Akbar Fatehpur Sikri painting"]),
    ("India", "Rajastán", ["Bani Thani Kishangarh", "Rajput painting Rajasthan", "Kishangarh painting Nihal Chand"]),
    ("India", "Maharashtra", ["Ajanta cave painting", "Ajanta fresco Bodhisattva Padmapani", "Ajanta caves mural"]),
    ("India", "Delhi", ["Delhi Durbar 1903 painting", "Delhi Red Fort painting 19th century", "Mughal Delhi painting Shah Jahan"]),
    ("India", "Panyab", ["Golden Temple Amritsar painting", "Amritsar painting 19th century", "Maharaja Ranjit Singh painting"]),
    ("China", "Henan", ["Zhang Zeduan Along the River During Qingming Festival", "Qingming Shanghe Tu", "Guo Xi Early Spring"]),
    ("China", "Zhejiang", ["Huang Gongwang Dwelling in the Fuchun Mountains", "Fuchun Mountains scroll", "Hangzhou West Lake painting"]),
    ("China", "Pekín", ["Castiglione Qianlong painting", "Forbidden City painting Qing", "Beijing painting Qing dynasty"]),
    ("China", "Shaanxi", ["Tang dynasty tomb mural Xi'an", "Xi'an Tang tomb mural", "Shaanxi tomb mural"]),
    ("China", "Jiangsu", ["Wen Zhengming Suzhou garden", "Wen Zhengming painting Humble Administrator's Garden", "Suzhou painting"]),
    ("China", "Guangdong", ["Canton factories painting Chinese export", "Guangzhou Canton painting 19th century", "Pearl River Canton painting"]),
    ("China", "Tíbet", ["Tibetan thangka", "Potala Palace painting", "Thangka Buddha Tibet"]),
    ("Japón", "Kanagawa", ["Hokusai Great Wave off Kanagawa", "Hokusai Kanagawa-oki nami ura", "Hokusai Under the Wave off Kanagawa"]),
    ("Japón", "Tokio", ["Hiroshige Sudden Shower over Shin-Ohashi Bridge", "Hiroshige One Hundred Famous Views of Edo", "Hiroshige Plum Garden Kameido"]),
    ("Japón", "Kioto", ["Rakuchu rakugai zu Kyoto screen", "Maruyama Okyo Kyoto", "Kyoto folding screen Edo period"]),
    ("Japón", "Yamanashi", ["Hokusai Fuji Kai Province Kajikazawa", "Hokusai Fine Wind Clear Morning", "Hokusai Thirty-six Views of Mount Fuji"]),
    ("Japón", "Nagasaki", ["Kawahara Keiga Dejima painting", "Dejima Nagasaki painting", "Nagasaki Dejima Dutch trading post painting"]),
    ("Japón", "Shizuoka", ["Hiroshige Tokaido Fifty-three Stations Yui", "Hiroshige Tokaido Hara Fuji", "Hiroshige Tokaido Shizuoka"]),
    ("Corea del Sur", "Seúl", ["Jeong Seon Inwangjesaek", "Jeong Seon Seoul painting", "Joseon painting Hanyang"]),
    ("Colombia", "Bogotá", ["Edward Mark Plaza de Bolivar Bogota", "Bogotá painting 19th century", "Ramón Torres Méndez Bogotá"]),
    ("Colombia", "Antioquia", ["Francisco Antonio Cano Horizontes", "Francisco Antonio Cano painting", "Medellín painting 19th century"]),
    ("Colombia", "Cundinamarca", ["Salto del Tequendama painting", "Tequendama 19th century painting", "Tequendama waterfall painting Colombia"]),
    ("Colombia", "Bolívar", ["Cartagena de Indias painting", "Cartagena de Indias 18th century painting", "Cartagena bay painting"]),
    ("Colombia", "Boyacá", ["Batalla de Boyacá painting", "Puente de Boyacá painting Martín Tovar", "Boyacá Colombia painting 19th century"]),
    ("Perú", "Lima", ["Pancho Fierro Lima painting", "Pancho Fierro acuarelas", "Lima painting 19th century Plaza de Armas"]),
    ("Perú", "Cusco", ["Escuela Cusqueña painting", "Cusco School Corpus Christi procession", "Cuzco school Virgin painting"]),
    ("Argentina", "Buenos Aires", ["Pueyrredón Un alto en el campo", "Prilidiano Pueyrredón painting", "Buenos Aires painting 19th century Cándido López"]),
    ("Chile", "Valparaíso", ["Somerscales Valparaiso", "Thomas Somerscales painting", "Valparaíso bay painting 19th century"]),
    ("Chile", "Santiago", ["Rugendas Santiago de Chile", "Santiago de Chile painting 19th century", "Pedro Subercaseaux painting"]),
    ("Venezuela", "Carabobo", ["Tovar y Tovar Batalla de Carabobo", "Martín Tovar y Tovar Carabobo", "Battle of Carabobo painting"]),
    ("Venezuela", "Capital", ["Arturo Michelena Miranda en La Carraca", "Michelena painting Caracas", "Caracas painting 19th century"]),
    ("Brasil", "Estado de Río de Janeiro", ["Rugendas Rio de Janeiro painting", "Debret Rio de Janeiro", "Guanabara Bay painting 19th century"]),
    ("Brasil", "Bahía", ["Salvador Bahia painting 19th century", "Rugendas Bahia", "Salvador da Bahia 19th century painting"]),
    ("Brasil", "Pernambuco", ["Frans Post Brazilian landscape", "Frans Post Olinda", "Frans Post Dutch Brazil"]),
    ("Brasil", "Estado de São Paulo", ["Pedro Américo Independência ou Morte", "Independence or Death painting", "Almeida Júnior Caipira"]),
    ("Brasil", "Minas Gerais", ["Ataíde painting Ouro Preto", "Ouro Preto painting", "Manuel da Costa Ataíde ceiling"]),
    ("México", "Mexico", ["José María Velasco Valle de México", "Velasco Valley of Mexico", "Velasco Mexico City painting"]),
    ("México", "Oaxaca", ["Velasco Valle de Oaxaca", "Monte Alban painting", "Oaxaca painting 19th century"]),
    ("México", "Yucatán", ["Catherwood Uxmal", "Catherwood Chichen Itza", "Catherwood Yucatan lithograph"]),
    ("México", "Chiapas", ["Catherwood Palenque", "Palenque painting 19th century", "Palenque Waldeck"]),
    ("México", "Guanajuato", ["Hermenegildo Bustos painting", "Guanajuato painting 19th century", "Guanajuato city painting"]),
    ("Canadá", "Quebec", ["Krieghoff Quebec painting", "Cornelius Krieghoff Habitants", "Quebec City painting 19th century"]),
    ("Canadá", "Ontario", ["Tom Thomson The Jack Pine", "Tom Thomson Northern River", "Tom Thomson West Wind"]),
    ("Canadá", "Columbia Británica", ["Emily Carr painting", "Emily Carr Big Raven", "Paul Kane British Columbia painting"]),
    ("Canadá", "Alberta", ["Paul Kane Rocky Mountains painting", "Paul Kane Alberta", "Canadian Rockies painting 19th century"]),
    ("Australia", "Victoria", ["Tom Roberts Shearing the Rams", "Frederick McCubbin Lost", "Arthur Streeton Golden Summer Eaglemont"]),
    ("Australia", "Nueva Gales del Sur", ["Arthur Streeton The Fire's On", "Tom Roberts Bailed Up", "Sydney Harbour painting 19th century"]),
    ("Australia", "Tasmania", ["John Glover My Harvest Home", "John Glover Tasmania painting", "Tasmania landscape painting 19th century"]),
    ("Australia", "Australia Occidental", ["Swan River colony painting", "Perth painting 19th century", "Western Australia painting 19th century"]),
    ("Nueva Zelanda", "Auckland", ["Goldie Maori portrait", "Charles Goldie painting", "Auckland painting 19th century"]),
    ("Nueva Zelanda", "West Coast", ["Petrus van der Velden Otira Gorge", "Van der Velden Otira", "West Coast New Zealand painting"]),
    ("Uzbekistán", "Samarcanda", ["Vereshchagin Doors of Tamerlane", "Vereshchagin Samarkand", "Registan painting Vereshchagin"]),
    ("Israel", "Jerusalén", ["David Roberts Jerusalem from the Mount of Olives", "David Roberts Jerusalem", "Jerusalem painting 19th century"]),
    ("Argelia", "Argel", ["Delacroix Women of Algiers", "Delacroix Femmes d'Alger dans leur appartement", "Algiers painting 19th century"]),
    ("Sudáfrica", "Occidental del Cabo", ["Thomas Baines Cape Town painting", "Cape Town painting 19th century", "Table Mountain painting 19th century"]),
    ("Indonesia", "Java Central", ["Raden Saleh Arrest of Diponegoro", "Raden Saleh painting", "Borobudur painting 19th century"]),
    ("Filipinas", "Quezon", ["Juan Luna Spoliarium", "Juan Luna painting", "Hidalgo painting Philippines"]),
    ("Rumanía", "Bucarest", ["Grigorescu painting", "Nicolae Grigorescu Bucharest", "Bucharest painting 19th century"]),
]

ESTADOS_EEUU = [
    ("California", ["Bierstadt Yosemite Valley", "Bierstadt Valley of the Yosemite", "Bierstadt California painting"]),
    ("Nueva York", ["Frederic Church Niagara", "Thomas Cole Hudson River School", "Hudson River painting Kensett"]),
    ("Arizona", ["Thomas Moran Grand Canyon", "Moran Chasm of the Colorado", "Grand Canyon painting 19th century"]),
    ("Wyoming", ["Bierstadt Lander's Peak", "Thomas Moran Yellowstone", "Bierstadt Grand Tetons"]),
    ("Massachusetts", ["Thomas Cole The Oxbow", "Cole View from Mount Holyoke", "Massachusetts painting 19th century"]),
    ("Pensilvania", ["Washington Crossing the Delaware Leutze", "Edward Hicks Peaceable Kingdom", "Philadelphia painting 19th century"]),
    ("Luisiana", ["Degas A Cotton Office in New Orleans", "Degas New Orleans", "New Orleans painting 19th century"]),
    ("Texas", ["Frederic Remington Texas painting", "Remington A Dash for the Timber", "Texas painting 19th century"]),
    ("Oregón", ["Bierstadt Mount Hood", "Mount Hood painting 19th century", "Oregon Trail painting"]),
    ("Washington", ["Mount Rainier painting 19th century", "Paul Kane Mount St Helens", "Washington state painting 19th century"]),
    ("Florida", ["Winslow Homer Florida", "Winslow Homer The Gulf Stream", "Martin Johnson Heade Florida"]),
    ("Montana", ["Charles Russell Lewis and Clark meeting Indians at Ross' Hole", "Charles M. Russell painting", "Karl Bodmer Missouri River painting"]),
    ("Alaska", ["Sydney Laurence Mount McKinley", "Sydney Laurence painting", "Alaska painting 19th century"]),
    ("Hawái", ["Jules Tavernier Kilauea", "Kilauea painting 19th century", "Hawaii painting 19th century volcano"]),
    ("Colorado", ["Bierstadt Rocky Mountains", "Albert Bierstadt Estes Park", "Colorado painting 19th century"]),
    ("Utah", ["Thomas Moran Zion", "Zion Canyon painting 19th century", "Utah painting 19th century"]),
    ("Virginia", ["Jamestown painting", "Virginia painting 19th century", "Mount Vernon painting 19th century"]),
    ("Misisipi", ["Mississippi River painting George Caleb Bingham", "Bingham Fur Traders Descending the Missouri", "Mississippi painting 19th century"]),
    ("Nueva Jersey", ["Washington Crossing the Delaware", "New Jersey painting 19th century", "Princeton painting battle"]),
    ("Illinois", ["Chicago painting 19th century", "Lincoln painting", "Illinois painting 19th century"]),
    ("Míchigan", ["Great Lakes painting 19th century", "Michigan painting 19th century", "Mackinac painting"]),
]


def main():
    ent = []
    for pais, prov, q in LUGARES:
        ent.append({"epoca": "2026", "clave": "lugar_%s__%s" % (clave(pais), clave(prov)), "q": q})
    for est, q in ESTADOS_EEUU:
        ent.append({"epoca": "2026", "clave": "estado_estados_unidos__%s" % clave(est), "q": q})
    salida = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lista_busqueda_4.json")
    json.dump({"ayuda": "0.1.8.43: pinturas por lugar (provincia o estado de EE. UU.). La genera construir_lista_lugares.py.", "entradas": ent},
              open(salida, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(ent), "entradas ->", salida)


if __name__ == "__main__":
    main()
