#!/usr/bin/env python3
"""Arma lista_epoca_N.json (consultas de Commons por época y lugar) para commons_pinturas_epoca.py. Solo obras anteriores a la fecha del escenario."""
import json, sys

R = ["region_europa_occidental", "region_europa_norte", "region_europa_este", "region_mediterraneo", "region_oriente_medio", "region_asia_central",
     "region_asia_este", "region_asia_sur", "region_sudeste_asiatico", "region_maghreb", "region_nilo", "region_africa_subsahariana",
     "region_norteamerica", "region_mesoamerica_caribe", "region_sudamerica_andes", "region_sudamerica_este", "region_oceania"]
C = ["continente_europa", "continente_asia", "continente_africa", "continente_america_del_norte", "continente_america_del_sur", "continente_oceania", "mundo"]

Q = {
"1dc": {
 "region_europa_occidental": ["Gundestrup cauldron", "Celtic La Tene art", "Vix krater", "Hochdorf Celtic"],
 "region_europa_norte": ["Bronze Age rock carvings Tanum", "Nordic Bronze Age rock art", "Trundholm sun chariot", "Hjortspring boat"],
 "region_europa_este": ["Kazanlak tomb mural", "Thracian tomb fresco", "Scythian gold plaque", "Panagyurishte treasure"],
 "region_mediterraneo": ["Villa of Livia garden fresco", "Alexander Mosaic Pompeii", "Villa of the Mysteries fresco", "Etruscan tomb painting Tarquinia"],
 "region_oriente_medio": ["Ishtar Gate Babylon", "Persepolis relief", "Lachish relief Assyrian", "Nimrud relief Assyrian"],
 "region_asia_central": ["Pazyryk felt", "Scythian gold stag", "Saka gold", "Pazyryk carpet"],
 "region_asia_este": ["Mawangdui silk banner", "Han dynasty tomb mural", "Terracotta Army", "Western Han painting"],
 "region_asia_sur": ["Sanchi stupa relief", "Bharhut stupa relief", "Ajanta cave 10 painting", "Ashoka pillar Sarnath"],
 "region_sudeste_asiatico": ["Dong Son drum", "Ban Chiang pottery", "Dong Son bronze", "Oc Eo"],
 "region_maghreb": ["Tassili n'Ajjer rock art", "Carthage mosaic Punic", "Punic stele Carthage", "Numidian Massinissa"],
 "region_nilo": ["Book of the Dead Hunefer", "Tomb of Nakht painting", "Nebamun tomb painting", "Meidum geese"],
 "region_africa_subsahariana": ["Nok terracotta", "Brandberg White Lady rock painting", "San rock painting", "Drakensberg rock art"],
 "region_norteamerica": ["Hopewell mica hand", "Hopewell effigy pipe", "Serpent Mound", "Basketmaker rock art"],
 "region_mesoamerica_caribe": ["San Bartolo mural", "Monte Alban Danzante", "Olmec colossal head", "Izapa stela"],
 "region_sudamerica_andes": ["Paracas textile mantle", "Chavin de Huantar Lanzon", "Nazca lines hummingbird", "Paracas Necropolis"],
 "region_sudamerica_este": ["Serra da Capivara rock painting", "Marajoara pottery", "Lagoa Santa", "Pedra Furada"],
 "region_oceania": ["Kakadu rock art", "Lapita pottery", "Gwion Gwion rock painting", "Aboriginal rock art"],
 "continente_europa": ["Lascaux Hall of the Bulls", "Altamira bison", "Roman fresco Pompeii", "Etruscan fresco"],
 "continente_asia": ["Mawangdui", "Terracotta Army", "Persepolis", "Sanchi"],
 "continente_africa": ["Tassili n'Ajjer rock art", "Egyptian tomb painting", "Tomb of Nakht", "Nok sculpture"],
 "continente_america_del_norte": ["Hopewell", "petroglyph rock art North America", "Serpent Mound", "Pueblo rock art"],
 "continente_america_del_sur": ["Paracas textile", "Nazca lines", "Chavin", "Serra da Capivara"],
 "continente_oceania": ["Kakadu rock art", "Lapita", "Aboriginal rock painting", "Gwion Gwion"],
 "mundo": ["Lascaux", "Altamira", "Chauvet cave", "Alexander Mosaic"]},
"1096": {
 "region_europa_occidental": ["Bayeux Tapestry", "Book of Kells", "Beatus manuscript Spain", "Utrecht Psalter"],
 "region_europa_norte": ["Oseberg ship", "Urnes stave church", "Viking runestone Uppland", "Gokstad ship"],
 "region_europa_este": ["Saint Sophia Kyiv fresco Oranta", "Kievan Rus mosaic Saint Michael", "Ostromir Gospels", "Saint Sophia Novgorod fresco"],
 "region_mediterraneo": ["San Vitale mosaic Ravenna", "San Clemente fresco Rome", "Sant'Angelo in Formis fresco", "Codex Purpureus Rossanensis"],
 "region_oriente_medio": ["Dome of the Rock mosaic", "Samarra fresco", "Qusayr Amra fresco", "Seljuk tile"],
 "region_asia_central": ["Afrasiab murals Samarkand", "Bamiyan Buddha mural", "Kyzil cave painting", "Bezeklik mural"],
 "region_asia_este": ["Guo Xi Early Spring", "Fan Kuan Travelers among mountains and streams", "Night Revels of Han Xizai", "Dunhuang Mogao mural"],
 "region_asia_sur": ["Brihadisvara temple fresco", "Pala Ashtasahasrika Prajnaparamita manuscript", "Khajuraho temple", "Chola bronze"],
 "region_sudeste_asiatico": ["Borobudur relief", "Prambanan relief", "Pagan temple mural", "Dieng"],
 "region_maghreb": ["Blue Quran Kairouan", "Great Mosque of Kairouan", "Qur'an Kairouan manuscript", "Almoravid"],
 "region_nilo": ["Fatimid lustre ceramic", "Coptic icon Sinai", "Coptic manuscript", "Fatimid"],
 "region_africa_subsahariana": ["Garima Gospels", "Igbo-Ukwu bronze", "Aksum stele", "Ethiopian illuminated manuscript"],
 "region_norteamerica": ["Mimbres pottery", "Cahokia Monks Mound", "Chaco Canyon Pueblo Bonito", "Mississippian culture"],
 "region_mesoamerica_caribe": ["Dresden Codex", "Bonampak mural", "Cacaxtla mural", "Codex Zouche-Nuttall"],
 "region_sudamerica_andes": ["Wari textile", "Tiwanaku Gateway of the Sun", "Moche pottery", "Tiwanaku"],
 "region_sudamerica_este": ["Marajoara urn", "Serra da Capivara rock painting", "Tapajonica", "Santarem pottery"],
 "region_oceania": ["Rapa Nui moai", "Aboriginal rock art", "Lapita pottery", "Nan Madol"],
 "continente_europa": ["Bayeux Tapestry", "Book of Kells", "Hereford Mappa Mundi", "Beatus Osma"],
 "continente_asia": ["Guo Xi Early Spring", "Fan Kuan", "Dunhuang mural", "Night Revels of Han Xizai"],
 "continente_africa": ["Garima Gospels", "Blue Quran", "Igbo-Ukwu", "Aksum"],
 "continente_america_del_norte": ["Mimbres pottery", "Cahokia", "Chaco Canyon", "Mississippian"],
 "continente_america_del_sur": ["Wari textile", "Tiwanaku", "Moche", "Marajoara"],
 "continente_oceania": ["Rapa Nui moai", "Aboriginal rock art", "Nan Madol", "Lapita"],
 "mundo": ["Beatus Osma mappa mundi", "Bayeux Tapestry", "Mappa mundi Beatus", "Tabula Peutingeriana"]},
"1500": {
 "region_europa_occidental": ["Limbourg Tres Riches Heures", "Van Eyck Arnolfini Portrait", "Durer Four Horsemen", "Unicorn Tapestries"],
 "region_europa_norte": ["Albertus Pictor church painting", "Uppsala cathedral medieval fresco", "Kalmar Union Margaret", "Bernt Notke Saint George"],
 "region_europa_este": ["Andrei Rublev Trinity", "Rublev Zvenigorod Spas", "Voronet monastery fresco", "Wit Stwosz altarpiece"],
 "region_mediterraneo": ["Botticelli Birth of Venus", "Leonardo Last Supper", "Mantegna Camera degli Sposi", "Nuno Goncalves Panels"],
 "region_oriente_medio": ["Behzad Seduction of Yusuf", "Gentile Bellini Mehmed II", "Miraj Nameh Timurid", "Topkapi Timurid album"],
 "region_asia_central": ["Zafarnama Timur manuscript", "Bihzad Herat painting", "Timurid miniature", "Bibi-Khanym Samarkand"],
 "region_asia_este": ["Shen Zhou Poet on a Mountain", "Sesshu Long Scroll", "Dai Jin Ming painting", "Ming dynasty hanging scroll"],
 "region_asia_sur": ["Kalpasutra manuscript Jain", "Vijayanagara Hampi", "Gita Govinda manuscript", "Bahmani"],
 "region_sudeste_asiatico": ["Angkor Wat bas-relief", "Majapahit relief", "Ayutthaya mural", "Borobudur relief"],
 "region_maghreb": ["Catalan Atlas Mansa Musa", "Catalan Atlas North Africa", "Marinid madrasa Fez", "Nasrid Alhambra tile"],
 "region_nilo": ["Mamluk Qur'an manuscript", "Mamluk Cairo mosque lamp", "Sultan Hasan mosque", "Mamluk illuminated"],
 "region_africa_subsahariana": ["Catalan Atlas Mansa Musa", "Ife bronze head", "Ethiopian manuscript Gospel", "Great Zimbabwe"],
 "region_norteamerica": ["Mesa Verde cliff palace", "Etowah mounds", "Mississippian shell gorget", "Cahokia"],
 "region_mesoamerica_caribe": ["Codex Borgia", "Codex Zouche-Nuttall", "Aztec Sun Stone", "Codex Fejervary-Mayer"],
 "region_sudamerica_andes": ["Machu Picchu", "Inca quipu", "Chimu textile", "Inca tunic"],
 "region_sudamerica_este": ["Marajoara urn", "Tapajonica", "Serra da Capivara rock painting", "Santarem pottery"],
 "region_oceania": ["Rapa Nui moai", "Nan Madol", "Polynesian tapa", "Maori carving"],
 "continente_europa": ["Limbourg Tres Riches Heures", "Van Eyck Arnolfini", "Botticelli Birth of Venus", "Hereford Mappa Mundi"],
 "continente_asia": ["Shen Zhou", "Sesshu", "Behzad", "Ming dynasty scroll"],
 "continente_africa": ["Catalan Atlas Mansa Musa", "Ife bronze head", "Mamluk manuscript", "Ethiopian manuscript"],
 "continente_america_del_norte": ["Mesa Verde", "Etowah", "Cahokia", "Mississippian"],
 "continente_america_del_sur": ["Machu Picchu", "Inca", "Chimu textile", "Quipu"],
 "continente_oceania": ["Rapa Nui moai", "Nan Madol", "Polynesian tapa", "Maori carving"],
 "mundo": ["Catalan Atlas", "Fra Mauro map", "Hereford Mappa Mundi", "Martellus world map"]}}

if __name__ == "__main__":
    ep = sys.argv[1]
    ent = [{"id": "%s/%s" % (ep, k), "q": Q[ep][k], "max": 8} for k in R + C]
    json.dump({"ayuda": "Consultas de pinturas de epoca %s" % ep, "entradas": ent}, open("lista_epoca_%s.json" % ep, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(ep, len(ent), "entradas")
