#!/usr/bin/env python3
"""
Genera datos/divisas.json: base de DIVISAS del juego (0.1.7.9.1) y la economía base de cada país (PIB y población 2026).

  divisas : código -> {n: nombre, s: símbolo, u: unidades de esa divisa por 1 USD}
            El valor de una divisa es 1/u dólares: cuanto más pequeño es u, más valiosa es la divisa.
  paises  : país -> {d: código de divisa, pib: PIB anual en USD (estimación 2026), pob: población 2026}

Fuentes: PIB 2023 en US$ corrientes del Banco Mundial (repo datasets/gdp) x 1,12 para llevarlo a 2026; para los países sin dato
(Venezuela, Cuba, Taiwán, Catar...) una estimación escrita a mano en GDP_EXTRA. Los tipos de cambio (u) son APROXIMADOS de
2025-2026 escritos a mano: sirven para jugar, no son cotizaciones. Las divisas de otras épocas se añadirán a este mismo formato.

Uso: python3 -I herramientas/construir_divisas.py RUTA_GDP_CSV
"""
import csv, json, os, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')
CRECIMIENTO_2023_2026 = 1.12

# código: (nombre, símbolo, unidades por 1 USD)
DIVISAS = {
    'USD': ('Dólar estadounidense', '$', 1.0), 'EUR': ('Euro', '€', 0.86), 'GBP': ('Libra esterlina', '£', 0.75),
    'JPY': ('Yen japonés', '¥', 150.0), 'CNY': ('Yuan chino', '¥', 7.15), 'INR': ('Rupia india', '₹', 88.0),
    'BRL': ('Real brasileño', 'R$', 5.4), 'MXN': ('Peso mexicano', '$', 18.5), 'COP': ('Peso colombiano', '$', 3900.0),
    'ARS': ('Peso argentino', '$', 1450.0), 'CLP': ('Peso chileno', '$', 940.0), 'PEN': ('Sol peruano', 'S/', 3.5),
    'UYU': ('Peso uruguayo', '$U', 40.0), 'PYG': ('Guaraní paraguayo', '₲', 7300.0), 'BOB': ('Boliviano', 'Bs', 6.96),
    'VES': ('Bolívar venezolano', 'Bs.S', 250.0), 'CRC': ('Colón costarricense', '₡', 505.0), 'GTQ': ('Quetzal guatemalteco', 'Q', 7.7),
    'HNL': ('Lempira hondureño', 'L', 26.2), 'NIO': ('Córdoba nicaragüense', 'C$', 36.8), 'DOP': ('Peso dominicano', 'RD$', 63.0),
    'HTG': ('Gourde haitiano', 'G', 131.0), 'JMD': ('Dólar jamaicano', 'J$', 160.0), 'TTD': ('Dólar de Trinidad y Tobago', 'TT$', 6.8),
    'BBD': ('Dólar de Barbados', 'Bds$', 2.0), 'BSD': ('Dólar bahameño', 'B$', 1.0), 'BZD': ('Dólar beliceño', 'BZ$', 2.0),
    'CUP': ('Peso cubano', '$MN', 24.0), 'XCD': ('Dólar del Caribe Oriental', 'EC$', 2.7), 'ANG': ('Florín antillano', 'ƒ', 1.79),
    'AWG': ('Florín arubeño', 'ƒ', 1.79), 'KYD': ('Dólar de las Islas Caimán', 'CI$', 0.83), 'BMD': ('Dólar bermudeño', 'BD$', 1.0),
    'GYD': ('Dólar guyanés', 'G$', 209.0), 'SRD': ('Dólar surinamés', 'Sr$', 38.0),
    'CAD': ('Dólar canadiense', 'C$', 1.38), 'AUD': ('Dólar australiano', 'A$', 1.52), 'NZD': ('Dólar neozelandés', 'NZ$', 1.70),
    'CHF': ('Franco suizo', 'Fr', 0.80), 'SEK': ('Corona sueca', 'kr', 9.4), 'NOK': ('Corona noruega', 'kr', 10.2),
    'DKK': ('Corona danesa', 'kr', 6.4), 'ISK': ('Corona islandesa', 'kr', 125.0), 'PLN': ('Esloti polaco', 'zł', 3.7),
    'CZK': ('Corona checa', 'Kč', 21.0), 'HUF': ('Forinto húngaro', 'Ft', 335.0), 'RON': ('Leu rumano', 'lei', 4.3),
    'BGN': ('Lev búlgaro', 'лв', 1.68), 'RSD': ('Dinar serbio', 'din', 100.0), 'MKD': ('Denar macedonio', 'ден', 53.0),
    'ALL': ('Lek albanés', 'L', 83.0), 'BAM': ('Marco convertible bosnio', 'KM', 1.68), 'MDL': ('Leu moldavo', 'L', 17.0),
    'UAH': ('Grivna ucraniana', '₴', 41.0), 'BYN': ('Rublo bielorruso', 'Br', 3.3), 'RUB': ('Rublo ruso', '₽', 85.0),
    'GEL': ('Lari georgiano', '₾', 2.7), 'AMD': ('Dram armenio', '֏', 385.0), 'AZN': ('Manat azerbaiyano', '₼', 1.7),
    'KZT': ('Tengue kazajo', '₸', 520.0), 'UZS': ('Som uzbeko', 'soʻm', 12500.0), 'KGS': ('Som kirguís', 'с', 87.0),
    'TJS': ('Somoni tayiko', 'SM', 9.3), 'TMT': ('Manat turcomano', 'm', 3.5), 'TRY': ('Lira turca', '₺', 43.0),
    'ILS': ('Nuevo séquel israelí', '₪', 3.4), 'JOD': ('Dinar jordano', 'JD', 0.71), 'LBP': ('Libra libanesa', 'L£', 89500.0),
    'SYP': ('Libra siria', 'S£', 120.0), 'IQD': ('Dinar iraquí', 'ع.د', 1310.0), 'IRR': ('Rial iraní', '﷼', 1050000.0),
    'SAR': ('Riyal saudí', '﷼', 3.75), 'AED': ('Dírham de los EAU', 'د.إ', 3.67), 'QAR': ('Riyal catarí', 'ر.ق', 3.64),
    'KWD': ('Dinar kuwaití', 'KD', 0.307), 'BHD': ('Dinar bahreiní', 'BD', 0.376), 'OMR': ('Rial omaní', 'ر.ع.', 0.385),
    'YER': ('Rial yemení', '﷼', 1620.0), 'EGP': ('Libra egipcia', 'E£', 48.0), 'LYD': ('Dinar libio', 'LD', 5.4),
    'TND': ('Dinar tunecino', 'DT', 3.0), 'DZD': ('Dinar argelino', 'DA', 132.0), 'MAD': ('Dírham marroquí', 'DH', 9.3),
    'MRU': ('Uguiya mauritana', 'UM', 40.0), 'SDG': ('Libra sudanesa', 'SDG', 2500.0), 'SSP': ('Libra sursudanesa', 'SSP', 4500.0),
    'ETB': ('Birr etíope', 'Br', 150.0), 'ERN': ('Nakfa eritreo', 'Nfk', 15.0), 'DJF': ('Franco yibutiano', 'Fdj', 177.7),
    'SOS': ('Chelín somalí', 'Sh', 571.0), 'KES': ('Chelín keniano', 'KSh', 129.0), 'UGX': ('Chelín ugandés', 'USh', 3600.0),
    'TZS': ('Chelín tanzano', 'TSh', 2600.0), 'RWF': ('Franco ruandés', 'FRw', 1450.0), 'BIF': ('Franco burundés', 'FBu', 2950.0),
    'CDF': ('Franco congoleño', 'FC', 2800.0), 'AOA': ('Kwanza angoleño', 'Kz', 920.0), 'ZMW': ('Kwacha zambiano', 'ZK', 24.0),
    'MWK': ('Kwacha malauí', 'MK', 1750.0), 'MZN': ('Metical mozambiqueño', 'MT', 63.9), 'ZWG': ('ZiG zimbabuense', 'ZiG', 26.0),
    'BWP': ('Pula botsuano', 'P', 13.5), 'NAD': ('Dólar namibio', 'N$', 17.5), 'ZAR': ('Rand sudafricano', 'R', 17.5),
    'LSL': ('Loti lesotense', 'L', 17.5), 'SZL': ('Lilangeni suazi', 'E', 17.5), 'MGA': ('Ariary malgache', 'Ar', 4500.0),
    'MUR': ('Rupia mauriciana', '₨', 45.0), 'SCR': ('Rupia seychelense', '₨', 14.5), 'KMF': ('Franco comorense', 'CF', 425.0),
    'GHS': ('Cedi ghanés', 'GH₵', 11.0), 'NGN': ('Naira nigeriana', '₦', 1500.0), 'XOF': ('Franco CFA de África Occidental', 'CFA', 565.0),
    'XAF': ('Franco CFA de África Central', 'FCFA', 565.0), 'GMD': ('Dalasi gambiano', 'D', 72.0), 'GNF': ('Franco guineano', 'FG', 8650.0),
    'LRD': ('Dólar liberiano', 'L$', 190.0), 'SLE': ('Leone sierraleonés', 'Le', 22.5), 'CVE': ('Escudo caboverdiano', 'Esc', 95.0),
    'STN': ('Dobra santotomense', 'Db', 21.0), 'PKR': ('Rupia pakistaní', '₨', 280.0), 'BDT': ('Taka bangladesí', '৳', 122.0),
    'LKR': ('Rupia esrilanquesa', 'Rs', 300.0), 'NPR': ('Rupia nepalí', '₨', 140.0), 'BTN': ('Ngultrum butanés', 'Nu', 88.0),
    'MVR': ('Rufiyaa maldiva', 'Rf', 15.4), 'AFN': ('Afgani', '؋', 70.0), 'MMK': ('Kyat birmano', 'K', 2100.0),
    'THB': ('Baht tailandés', '฿', 33.0), 'LAK': ('Kip laosiano', '₭', 21500.0), 'KHR': ('Riel camboyano', '៛', 4050.0),
    'VND': ('Dong vietnamita', '₫', 26000.0), 'MYR': ('Ringgit malayo', 'RM', 4.2), 'SGD': ('Dólar singapurense', 'S$', 1.30),
    'BND': ('Dólar de Brunéi', 'B$', 1.30), 'IDR': ('Rupia indonesia', 'Rp', 16500.0), 'PHP': ('Peso filipino', '₱', 57.0),
    'KRW': ('Won surcoreano', '₩', 1400.0), 'KPW': ('Won norcoreano', '₩', 900.0), 'MNT': ('Tugrik mongol', '₮', 3600.0),
    'TWD': ('Nuevo dólar taiwanés', 'NT$', 31.0), 'HKD': ('Dólar de Hong Kong', 'HK$', 7.8), 'MOP': ('Pataca de Macao', 'MOP$', 8.03),
    'PGK': ('Kina papú', 'K', 4.1), 'FJD': ('Dólar fiyiano', 'FJ$', 2.25), 'SBD': ('Dólar salomonense', 'SI$', 8.4),
    'VUV': ('Vatu vanuatuense', 'VT', 120.0), 'WST': ('Tala samoano', 'WS$', 2.75), 'TOP': ('Paanga tongano', 'T$', 2.4),
    'XPF': ('Franco CFP', '₣', 103.0), 'XXX': ('Sin divisa propia', '—', 1.0),
}

# a3 -> divisa (lo que no aparece usa USD)
_EUR = 'AUT BEL HRV CYP EST FIN FRA DEU GRC IRL ITA LVA LTU LUX MLT NLD PRT SVK SVN ESP MCO SMR AND MNE KOS ALD SPM BLM MAF ATF ESB WSB CNM'
_USD = ('USA ECU SLV PAN TLS MHL FSM PLW PRI GUM MNP ASM VIR UMI USG IOT TCA VGB SXM')
_GBP = 'GBR GIB FLK SHN GGY JEY IMN SGS'
_XOF = 'BEN BFA CIV GNB MLI NER SEN TGO'
_XAF = 'CMR CAF TCD COG GNQ GAB'
_XCD = 'AIA ATG DMA GRD KNA LCA VCT MSR'
_AUD = 'AUS KIR NRU TUV NFK IOA HMD'
_NZD = 'NZL COK NIU PCN'
_DKK = 'DNK FRO GRL'
_XPF = 'NCL PYF WLF'
PAIS_DIVISA = {
    'ARG': 'ARS', 'ARM': 'AMD', 'AGO': 'AOA', 'ALB': 'ALL', 'ARE': 'AED', 'AZE': 'AZN', 'BDI': 'BIF', 'BGD': 'BDT', 'BGR': 'BGN',
    'BHR': 'BHD', 'BHS': 'BSD', 'BIH': 'BAM', 'BLR': 'BYN', 'BLZ': 'BZD', 'BMU': 'BMD', 'BOL': 'BOB', 'BRA': 'BRL', 'BRB': 'BBD',
    'BRN': 'BND', 'BTN': 'BTN', 'BWA': 'BWP', 'CAN': 'CAD', 'CHE': 'CHF', 'LIE': 'CHF', 'CHL': 'CLP', 'SPI': 'CLP', 'CHN': 'CNY',
    'COD': 'CDF', 'COL': 'COP', 'COM': 'KMF', 'CPV': 'CVE', 'CRI': 'CRC', 'CUB': 'CUP', 'CUW': 'ANG', 'CYM': 'KYD', 'CYN': 'TRY',
    'CZE': 'CZK', 'DJI': 'DJF', 'DOM': 'DOP', 'DZA': 'DZD', 'EGY': 'EGP', 'ERI': 'ERN', 'ETH': 'ETB', 'FJI': 'FJD', 'GEO': 'GEL',
    'GHA': 'GHS', 'GIN': 'GNF', 'GMB': 'GMD', 'GTM': 'GTQ', 'GUY': 'GYD', 'HKG': 'HKD', 'HND': 'HNL', 'HTI': 'HTG', 'HUN': 'HUF',
    'IDN': 'IDR', 'IND': 'INR', 'KAS': 'INR', 'IRN': 'IRR', 'IRQ': 'IQD', 'ISL': 'ISK', 'ISR': 'ILS', 'PSX': 'ILS', 'JAM': 'JMD',
    'JOR': 'JOD', 'JPN': 'JPY', 'KAZ': 'KZT', 'KEN': 'KES', 'KGZ': 'KGS', 'KHM': 'KHR', 'KOR': 'KRW', 'PRK': 'KPW', 'KWT': 'KWD',
    'LAO': 'LAK', 'LBN': 'LBP', 'LBR': 'LRD', 'LBY': 'LYD', 'LKA': 'LKR', 'LSO': 'LSL', 'MAC': 'MOP', 'MAR': 'MAD', 'SAH': 'MAD',
    'MDA': 'MDL', 'MDG': 'MGA', 'MDV': 'MVR', 'MEX': 'MXN', 'MKD': 'MKD', 'MMR': 'MMK', 'MNG': 'MNT', 'MOZ': 'MZN', 'MRT': 'MRU',
    'MUS': 'MUR', 'MWI': 'MWK', 'MYS': 'MYR', 'NAM': 'NAD', 'NGA': 'NGN', 'NIC': 'NIO', 'NOR': 'NOK', 'NPL': 'NPR', 'OMN': 'OMR',
    'PAK': 'PKR', 'PER': 'PEN', 'PHL': 'PHP', 'PNG': 'PGK', 'POL': 'PLN', 'PRY': 'PYG', 'QAT': 'QAR', 'ROU': 'RON', 'RUS': 'RUB',
    'KAB': 'RUB', 'RWA': 'RWF', 'SAU': 'SAR', 'SDN': 'SDG', 'SDS': 'SSP', 'SGP': 'SGD', 'SLB': 'SBD', 'SLE': 'SLE', 'SOM': 'SOS',
    'SOL': 'SOS', 'SRB': 'RSD', 'STP': 'STN', 'SUR': 'SRD', 'SWE': 'SEK', 'SWZ': 'SZL', 'SYC': 'SCR', 'SYR': 'SYP', 'THA': 'THB',
    'TJK': 'TJS', 'TKM': 'TMT', 'TON': 'TOP', 'TTO': 'TTD', 'TUN': 'TND', 'TUR': 'TRY', 'TWN': 'TWD', 'TZA': 'TZS', 'UGA': 'UGX',
    'UKR': 'UAH', 'URY': 'UYU', 'UZB': 'UZS', 'VEN': 'VES', 'VNM': 'VND', 'VUT': 'VUV', 'WSM': 'WST', 'YEM': 'YER', 'ZAF': 'ZAR',
    'ZMB': 'ZMW', 'ZWE': 'ZWG', 'ABW': 'AWG', 'ATA': 'XXX', 'BRT': 'XXX',
}
for lista, cod in ((_EUR, 'EUR'), (_USD, 'USD'), (_GBP, 'GBP'), (_XOF, 'XOF'), (_XAF, 'XAF'), (_XCD, 'XCD'), (_AUD, 'AUD'),
                   (_NZD, 'NZD'), (_DKK, 'DKK'), (_XPF, 'XPF')):
    for a3 in lista.split():
        PAIS_DIVISA[a3] = cod

# PIB 2026 estimado (miles de millones de USD) de países sin dato del Banco Mundial
GDP_EXTRA = {
    'QAT': 235, 'VEN': 110, 'CUB': 110, 'LBN': 25, 'SYR': 25, 'AFG': 17, 'YEM': 20, 'ERI': 3, 'SDS': 6, 'TWN': 800, 'PRK': 30,
    'BTN': 3.0, 'LIE': 7.5, 'MCO': 8.5, 'SMR': 2.1, 'KOS': 11, 'PSX': 20, 'TON': 0.5, 'GIB': 3.0, 'ABW': 3.5, 'CUW': 3.6,
    'NCL': 10, 'PYF': 6.5, 'GRL': 3.3, 'FRO': 3.8, 'BMU': 8.5, 'CYM': 7.0, 'GGY': 4.5, 'JEY': 7.5, 'IMN': 8.0, 'ALD': 1.8,
    'AIA': 0.4, 'VGB': 1.5, 'MSR': 0.07, 'VIR': 4.5, 'BLM': 0.4, 'MAF': 0.6, 'SHN': 0.03, 'COK': 0.4, 'NIU': 0.01, 'WLF': 0.2,
    'ASM': 0.7, 'GUM': 6.5, 'MNP': 1.2, 'FLK': 0.3, 'SPM': 0.3, 'SAH': 1.0, 'SOL': 3.0, 'CYN': 5.0, 'ESB': 0.2, 'WSB': 0.1,
    'USG': 0.0, 'KAS': 0.0, 'KAB': 0.0, 'ATA': 0.0, 'PCN': 0.0, 'ATF': 0.0, 'HMD': 0.0, 'IOA': 0.0, 'IOT': 0.0, 'NFK': 0.1,
    'SGS': 0.0, 'UMI': 0.0, 'CNM': 0.0, 'SPI': 0.0, 'BRT': 0.0,
}
PIB_POR_HAB_DEFECTO = 5000.0


def main():
    ruta_gdp = sys.argv[1]
    ent = json.load(open(os.path.join(DATOS, 'entidades.json'), encoding='utf-8'))['paises']
    info = json.load(open(os.path.join(DATOS, 'info.json'), encoding='utf-8'))['pais']
    gdp = {}
    for r in csv.DictReader(open(ruta_gdp, encoding='utf-8')):
        if r['Year'] == '2023' and r['Value']:
            gdp[r['Country Code']] = float(r['Value'])
    paises, usadas = {}, set()
    for nombre, e in ent.items():
        a3 = e['a3']
        cod = PAIS_DIVISA.get(a3, 'USD')
        usadas.add(cod)
        pob = int(info.get(nombre, {}).get('pob', 0))
        if a3 in gdp:
            pib = gdp[a3] * CRECIMIENTO_2023_2026
        elif a3 in GDP_EXTRA:
            pib = GDP_EXTRA[a3] * 1e9
        else:
            pib = pob * PIB_POR_HAB_DEFECTO
        paises[nombre] = {'d': cod, 'pib': int(pib), 'pob': pob}
    divisas = {c: {'n': DIVISAS[c][0], 's': DIVISAS[c][1], 'u': DIVISAS[c][2]} for c in sorted(DIVISAS)}
    json.dump({'divisas': divisas, 'paises': paises, 'tasa_fiscal': 0.25, 'version': '0.1.7.9.1'},
              open(os.path.join(DATOS, 'divisas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    tot = sum(p['pib'] for p in paises.values())
    print('divisas', len(divisas), '(usadas %d) | países %d | PIB mundial 2026 ≈ %.1f billones USD' % (len(usadas), len(paises), tot / 1e12))
    sin = [c for c in usadas if c not in DIVISAS]
    print('divisas usadas sin definir:', sin)


if __name__ == '__main__':
    main()
