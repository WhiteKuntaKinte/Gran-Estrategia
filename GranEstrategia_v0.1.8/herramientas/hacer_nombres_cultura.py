#!/usr/bin/env python3
"""Genera datos/nombres_cultura.json (0.1.7.9.9D).

Contenido:
  · culturas: lista de nombres de pila y apellidos por cultura (solo masculinos por ahora) y el orden en que se escriben.
  · paises: a qué cultura pertenece cada país / territorio del juego (clave = nombre en datos/entidades.json).
  · defecto_continente: cultura de respaldo si algún país no está en `paises`.
  · eras: títulos de la cadena de mando según la época (año de corte: la era vale mientras año < `hasta`).

Son listas escritas a mano (sin fuente externa): sirven para que los mandos del juego suenen coherentes con su país.
Aproximaciones conocidas: un país con varias culturas usa la dominante (p. ej. Rusia, India, Nigeria); los territorios
dependientes usan la cultura de su soberano; faltan nombres femeninos.
Uso:  python3 herramientas/hacer_nombres_cultura.py   (desde la raíz del proyecto; verifica contra datos/entidades.json)
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def L(s):
    return [x.strip() for x in s.replace("\n", " ").split(",") if x.strip()]


# orden: "nombre_apellido" | "hispano" (nombre + dos apellidos) | "apellido_nombre" (apellido primero)
CULTURAS = {
    "hispano": ("Hispana", "hispano",
        "Juan, José, Carlos, Luis, Miguel, Javier, Andrés, Diego, Fernando, Ricardo, Alejandro, Santiago, Sebastián, Mauricio, Óscar, Héctor, Rafael, Eduardo, Gonzalo, Pablo, Álvaro, Camilo, Julián, Esteban, Hernán, Gustavo, Raúl, Iván, Jorge, Manuel, Francisco, Antonio",
        "García, Rodríguez, Martínez, López, González, Pérez, Sánchez, Ramírez, Torres, Flores, Rivera, Gómez, Díaz, Vargas, Castro, Morales, Ortiz, Herrera, Medina, Rojas, Mendoza, Silva, Ruiz, Jiménez, Navarro, Cardona, Restrepo, Valencia, Castillo, Cortés, Aguirre, Salazar, Peña, Guerrero, Ríos, Suárez, Moreno, Romero, Alvarez, Vega"),
    "lusofono": ("Lusófona", "nombre_apellido",
        "João, José, António, Manuel, Francisco, Carlos, Paulo, Pedro, Luís, Rui, Miguel, Tiago, Fernando, Ricardo, Rafael, Gonçalo, Bruno, Marcos, Henrique, Eduardo, Gabriel, Mateus, Lucas, Caio",
        "Silva, Santos, Oliveira, Souza, Pereira, Costa, Rodrigues, Almeida, Nascimento, Lima, Araújo, Fernandes, Carvalho, Gomes, Martins, Rocha, Ribeiro, Alves, Monteiro, Barbosa, Cardoso, Teixeira, Moreira, Correia, Dos Santos, Machado"),
    "anglo": ("Anglosajona", "nombre_apellido",
        "James, John, Robert, Michael, William, David, Richard, Thomas, Charles, Daniel, Matthew, Anthony, Mark, Paul, Steven, Andrew, Kenneth, George, Edward, Brian, Ronald, Timothy, Jason, Jeffrey, Gary, Nicholas, Patrick, Colin, Graham, Stuart",
        "Smith, Johnson, Williams, Brown, Jones, Miller, Davis, Wilson, Anderson, Taylor, Thomas, Moore, Martin, Jackson, Thompson, White, Harris, Clark, Lewis, Walker, Hall, Allen, Young, King, Wright, Scott, Green, Baker, Adams, Nelson, Carter, Mitchell, Roberts, Turner, Phillips, Campbell, Parker, Evans, Edwards, Collins, Stewart, Murphy, Kelly"),
    "frances": ("Francesa", "nombre_apellido",
        "Jean, Pierre, Michel, Philippe, Alain, Jacques, Bernard, Marcel, André, Louis, François, Henri, Claude, Laurent, Nicolas, Thierry, Olivier, Christophe, Stéphane, Patrick, Guillaume, Étienne, Antoine, Mathieu",
        "Martin, Bernard, Dubois, Thomas, Robert, Richard, Petit, Durand, Leroy, Moreau, Simon, Laurent, Lefebvre, Michel, Fournier, Girard, Bonnet, Dupont, Lambert, Fontaine, Rousseau, Vincent, Muller, Lefèvre, Faure, Mercier, Blanc, Guérin, Boyer, Chevalier"),
    "aleman": ("Alemana", "nombre_apellido",
        "Hans, Peter, Klaus, Wolfgang, Jürgen, Thomas, Michael, Andreas, Stefan, Markus, Matthias, Frank, Uwe, Bernd, Dieter, Helmut, Karl, Friedrich, Heinrich, Werner, Gerhard, Lukas, Jan, Tobias",
        "Müller, Schmidt, Schneider, Fischer, Weber, Meyer, Wagner, Becker, Schulz, Hoffmann, Schäfer, Koch, Bauer, Richter, Klein, Wolf, Schröder, Neumann, Schwarz, Zimmermann, Braun, Krüger, Hofmann, Hartmann, Lange, Schmitt, Werner, Krause, Lehmann, Köhler, Herrmann, König, Walter, Huber"),
    "italiano": ("Italiana", "nombre_apellido",
        "Giuseppe, Giovanni, Antonio, Mario, Luigi, Francesco, Angelo, Vincenzo, Pietro, Salvatore, Carlo, Franco, Domenico, Bruno, Paolo, Michele, Giorgio, Aldo, Sergio, Marco, Luca, Alessandro, Stefano, Roberto, Fabio",
        "Rossi, Russo, Ferrari, Esposito, Bianchi, Romano, Colombo, Ricci, Marino, Greco, Bruno, Gallo, Conti, De Luca, Mancini, Costa, Giordano, Rizzo, Lombardi, Moretti, Barbieri, Fontana, Santoro, Mariani, Rinaldi, Caruso, Ferrara, Galli, Martini, Leone, Longo, Gentile, Vitale, Serra, Coppola"),
    "neerlandes": ("Neerlandesa", "nombre_apellido",
        "Jan, Johannes, Pieter, Willem, Hendrik, Cornelis, Dirk, Jacob, Gerrit, Kees, Henk, Piet, Bas, Ruud, Maarten, Sander, Joost, Erik, Frank, Bart, Wouter, Jeroen, Thijs, Lars",
        "De Jong, Jansen, De Vries, Van den Berg, Van Dijk, Bakker, Janssen, Visser, Smit, Meijer, De Boer, Mulder, De Groot, Bos, Vos, Peters, Hendriks, Van Leeuwen, Dekker, Brouwer, De Wit, Dijkstra, Smits, De Graaf, Van der Meer, Kok, Jacobs, De Haan"),
    "nordico": ("Nórdica", "nombre_apellido",
        "Lars, Erik, Anders, Nils, Olof, Karl, Magnus, Johan, Per, Bjørn, Ola, Henrik, Thomas, Mikael, Gunnar, Sven, Stefan, Jens, Søren, Mads, Kristian, Ingvar, Einar, Sigurður, Jón",
        "Andersson, Johansson, Karlsson, Nilsson, Eriksson, Larsson, Olsson, Persson, Svensson, Gustafsson, Hansen, Nielsen, Jensen, Pedersen, Larsen, Andersen, Christensen, Madsen, Johansen, Olsen, Kristiansen, Berg, Lindqvist, Sørensen, Jónsson, Sigurðsson, Gunnarsson, Magnússon, Ólafsson"),
    "fines": ("Finlandesa", "nombre_apellido",
        "Matti, Juha, Jari, Kari, Mikko, Antti, Timo, Pekka, Heikki, Tapio, Ilkka, Jukka, Markku, Hannu, Teemu, Janne, Eero, Veikko, Olli, Risto, Petri, Sami, Ville, Tuomas",
        "Korhonen, Virtanen, Mäkinen, Nieminen, Mäkelä, Hämäläinen, Laine, Heikkinen, Koskinen, Järvinen, Lehtonen, Lehtinen, Saarinen, Salminen, Heinonen, Niemi, Heikkilä, Kinnunen, Salonen, Turunen, Salo, Laitinen, Tuominen, Rantanen"),
    "eslavo_occidental": ("Eslava occidental", "nombre_apellido",
        "Jan, Piotr, Andrzej, Krzysztof, Tomasz, Paweł, Michał, Marcin, Jakub, Marek, Stanisław, Tadeusz, Zbigniew, Wojciech, Petr, Pavel, Martin, Jiří, Josef, Miroslav, Karel, Václav, Ondřej, Ladislav, Peter, Milan",
        "Nowak, Kowalski, Wiśniewski, Wójcik, Kowalczyk, Kamiński, Lewandowski, Zieliński, Szymański, Woźniak, Dąbrowski, Kozłowski, Jankowski, Mazur, Krawczyk, Novák, Svoboda, Novotný, Dvořák, Černý, Procházka, Kučera, Veselý, Horák, Němec, Pospíšil, Hájek, Kolář"),
    "ruso": ("Rusa", "nombre_apellido",
        "Aleksandr, Serguéi, Vladímir, Dmitri, Andréi, Alekséi, Ígor, Nikolái, Mijaíl, Víktor, Yuri, Borís, Oleg, Pável, Iván, Maksim, Artiom, Román, Konstantín, Anatoli, Yevgueni, Valeri, Gennadi, Leonid, Vasili, Grigori, Pyotr, Ruslán",
        "Ivánov, Smirnov, Kuznetsov, Popov, Vasíliev, Petrov, Sokolov, Mijáilov, Nóvikov, Fiódorov, Morózov, Volkov, Alekséyev, Lébedev, Semiónov, Yegórov, Pávlov, Kozlov, Stepánov, Nikoláyev, Orlov, Andréyev, Makárov, Zaitsev, Gúsev, Titov, Kuzmín, Kudriávtsev"),
    "ucraniano": ("Ucraniana", "nombre_apellido",
        "Oleksandr, Volodímir, Mykola, Taras, Bohdan, Andrí, Serhí, Ihor, Oleh, Yuri, Dmytro, Vasyl, Ivan, Petro, Mykhailo, Viktor, Maksym, Roman, Anatolí, Stepán, Yaroslav, Vitalí, Valerí",
        "Bondarenko, Shevchenko, Kovalenko, Tkachenko, Kovalchuk, Melnyk, Boyko, Kravchenko, Oliynyk, Shevchuk, Polishchuk, Bondar, Tkachuk, Moroz, Marchenko, Lysenko, Rudenko, Savchenko, Petrenko, Koval, Karpenko, Klymenko, Savchuk"),
    "eslavo_sur": ("Eslava del sur", "nombre_apellido",
        "Marko, Nikola, Stefan, Milan, Jovan, Ivan, Petar, Luka, Ante, Josip, Mladen, Dragan, Zoran, Goran, Branko, Darko, Dejan, Miroslav, Vladimir, Aleksandar, Tomislav, Zlatko, Boris, Georgi, Dimitar, Hristo, Todor, Tihomir",
        "Jovanović, Petrović, Nikolić, Marković, Đorđević, Stojanović, Ilić, Kovačević, Horvat, Babić, Marić, Novak, Kovač, Perić, Matić, Božić, Knežević, Georgiev, Ivanov, Dimitrov, Petkov, Hristov, Todorov, Popov, Kolev, Stoyanov, Angelov, Vasilev"),
    "baltico": ("Báltica", "nombre_apellido",
        "Andris, Jānis, Mārtiņš, Edgars, Aivars, Kristaps, Raimonds, Valdis, Jonas, Petras, Antanas, Tomas, Darius, Mindaugas, Algirdas, Rimantas, Tõnu, Jüri, Mart, Andres, Toomas, Rein, Peeter, Kaido",
        "Bērziņš, Kalniņš, Ozols, Liepa, Jansons, Krūmiņš, Kazlauskas, Petrauskas, Jankauskas, Stankevičius, Vasiliauskas, Žukauskas, Butkus, Tamm, Saar, Sepp, Mägi, Kask, Kukk, Rebane, Ilves, Pärn"),
    "hungaro": ("Húngara", "apellido_nombre",
        "István, János, László, Ferenc, József, Zoltán, Gábor, Péter, Tamás, Attila, András, Sándor, Gyula, Béla, Lajos, Károly, Miklós, Imre, Zsolt, Balázs, Csaba, Dániel, Róbert, Viktor",
        "Nagy, Kovács, Tóth, Szabó, Horváth, Varga, Kiss, Molnár, Németh, Farkas, Balogh, Papp, Takács, Juhász, Lakatos, Mészáros, Oláh, Simon, Rácz, Fekete, Szilágyi, Török, Fehér, Balázs"),
    "rumano": ("Rumana", "nombre_apellido",
        "Ion, Gheorghe, Vasile, Nicolae, Mihai, Constantin, Alexandru, Andrei, Florin, Cristian, Marius, Adrian, Sorin, Dan, Radu, Ștefan, Bogdan, Viorel, Dumitru, Liviu, Ovidiu, Cătălin, Emil, Lucian",
        "Popescu, Ionescu, Popa, Radu, Dumitru, Stan, Stoica, Gheorghe, Matei, Ciobanu, Constantin, Rusu, Munteanu, Moldovan, Dinu, Lungu, Barbu, Dragomir, Preda, Neagu, Marin, Ene, Tudor, Cojocaru"),
    "griego": ("Griega", "nombre_apellido",
        "Giorgos, Dimitris, Nikos, Yannis, Kostas, Christos, Panagiotis, Vasilis, Thanasis, Michalis, Stelios, Antonis, Manolis, Spyros, Alexandros, Petros, Evangelos, Sotiris, Lefteris, Theodoros, Stavros, Pavlos, Andreas, Haris",
        "Papadopoulos, Vlachos, Angelopoulos, Nikolaidis, Georgiou, Dimitriou, Papadakis, Karagiannis, Oikonomou, Makris, Pappas, Ioannou, Vasiliou, Antoniou, Christodoulou, Konstantinou, Stavrou, Alexiou, Theodorou, Michailidis, Laskaris, Mavros, Kyriakou, Panagiotou"),
    "albanes": ("Albanesa", "nombre_apellido",
        "Arben, Besnik, Ilir, Agim, Ardian, Altin, Bujar, Fatmir, Gëzim, Kujtim, Luan, Naim, Shpend, Skënder, Valon, Dritan, Edmond, Fisnik, Hysen, Lirim",
        "Hoxha, Shehu, Prifti, Dervishi, Hysa, Gjoka, Leka, Marku, Murati, Kola, Rama, Berisha, Krasniqi, Gashi, Morina, Kelmendi, Shala, Bytyqi, Hasani, Zeqiri"),
    "turco": ("Turca", "nombre_apellido",
        "Mehmet, Mustafa, Ahmet, Ali, Hüseyin, İbrahim, Hasan, Murat, Emre, Yusuf, Ömer, Kemal, Burak, Cem, Erdal, Kadir, Serkan, Tolga, Volkan, Orhan, Süleyman, Osman, Ramazan, Hakan",
        "Yılmaz, Kaya, Demir, Şahin, Çelik, Yıldız, Yıldırım, Öztürk, Aydın, Özdemir, Arslan, Doğan, Kılıç, Aslan, Çetin, Kara, Koç, Kurt, Özkan, Şimşek, Polat, Korkmaz, Erdoğan, Güneş"),
    "turcomano": ("Túrquica de Asia central y Cáucaso", "nombre_apellido",
        "Nurlan, Bakyt, Askar, Timur, Rustam, Farhod, Bakhtiyar, Sardor, Dauren, Serik, Marat, Erlan, Azamat, Ruslan, Bolat, Aibek, Maksat, Kanat, Berdi, Elchin, Rashad, Farid, Kamran, Tural",
        "Akhmetov, Suleimenov, Karimov, Rakhimov, Abdullayev, Usmanov, Tursunov, Ismailov, Nurmatov, Aliyev, Mamedov, Kasymov, Sadykov, Omarov, Bekov, Dzhumabaev, Orazov, Berdiyev, Hojayev, Mammadov, Hasanov, Huseynov, Guliyev"),
    "persa": ("Persa", "nombre_apellido",
        "Mohammad, Ali, Reza, Hossein, Hassan, Mehdi, Mahmoud, Amir, Saeed, Majid, Abbas, Javad, Farhad, Kaveh, Dariush, Behrooz, Ehsan, Navid, Peyman, Arash, Babak, Kourosh, Siavash, Hamid",
        "Hosseini, Mohammadi, Ahmadi, Karimi, Rezaei, Jafari, Moradi, Hashemi, Rahimi, Mousavi, Ghorbani, Sadeghi, Tehrani, Shirazi, Isfahani, Kazemi, Najafi, Soltani, Bagheri, Zand, Farhadi, Daneshvar, Rostami, Yazdani"),
    "arabe": ("Árabe", "nombre_apellido",
        "Mohamed, Ahmed, Mahmoud, Mustafa, Ibrahim, Omar, Khalid, Hassan, Hussein, Abdullah, Yusuf, Tariq, Karim, Samir, Nabil, Walid, Faisal, Sultan, Rashid, Saad, Jamal, Salim, Fadi, Bilal, Adel, Marwan, Zayed, Nasser",
        "Al-Masri, Al-Sayed, Hassan, Khalil, Haddad, Nasser, Mansour, Saleh, Al-Najjar, Al-Hamad, Al-Rashid, Al-Mutairi, Al-Qahtani, Al-Otaibi, Al-Ghamdi, Al-Zahrani, Benali, Bouzid, Cherif, Mansouri, Trabelsi, Ben Youssef, Amrani, Idrissi, Alaoui, Tazi, El Fassi, Al-Khatib, Barakat, Jaber, Darwish, Shaheen"),
    "hebreo": ("Hebrea", "nombre_apellido",
        "David, Moshe, Yossi, Avi, Eli, Yaakov, Daniel, Ronen, Amir, Eitan, Uri, Gil, Noam, Itai, Oren, Shlomo, Yitzhak, Avraham, Tal, Yoav, Guy, Omer, Doron, Ari",
        "Cohen, Levi, Mizrahi, Peretz, Biton, Dahan, Avraham, Friedman, Malka, Azoulay, Katz, Goldberg, Shapira, Weiss, Barak, Shamir, Navon, Golan, Ben-David, Bar-On, Hadad, Amar, Ohana, Segal"),
    "india": ("India", "nombre_apellido",
        "Rajesh, Amit, Sanjay, Vijay, Anil, Sunil, Ramesh, Suresh, Manoj, Rakesh, Vikram, Arjun, Rohit, Deepak, Ashok, Prakash, Mahesh, Kiran, Naveen, Srinivas, Venkatesh, Krishna, Gopal, Harish",
        "Sharma, Verma, Gupta, Singh, Kumar, Patel, Reddy, Nair, Iyer, Rao, Mehta, Joshi, Desai, Chatterjee, Banerjee, Das, Bose, Pillai, Menon, Naidu, Yadav, Chauhan, Thakur, Kapoor, Malhotra, Bhatt, Kulkarni, Deshmukh, Thapa, Gurung, Perera, De Silva"),
    "sur_asia_islamico": ("Surasiática musulmana", "nombre_apellido",
        "Muhammad, Ahmed, Ali, Hassan, Hussain, Imran, Kamran, Faisal, Tariq, Naveed, Farooq, Asif, Shahid, Rashid, Zahid, Abdul Rahman, Rahim, Karim, Jamal, Habib, Khalid, Saeed, Nasir, Babar",
        "Khan, Ahmed, Ali, Hussain, Malik, Sheikh, Qureshi, Butt, Chaudhry, Mirza, Siddiqui, Ansari, Rahman, Islam, Hossain, Chowdhury, Miah, Uddin, Akhtar, Iqbal, Raza, Shah, Yousafzai, Durrani"),
    "chino": ("China", "apellido_nombre",
        "Jianguo, Zhiwei, Weiguo, Guoqiang, Jun, Lei, Tao, Ming, Hao, Jie, Peng, Bin, Chao, Kai, Long, Feng, Yong, Gang, Liang, Bo, Zhenhua, Xiaoming, Jianhua, Zhiming",
        "Wang, Li, Zhang, Liu, Chen, Yang, Huang, Zhao, Wu, Zhou, Xu, Sun, Ma, Zhu, Hu, Guo, He, Gao, Lin, Luo, Zheng, Liang, Xie, Song, Tang, Han, Feng, Deng, Cao, Peng, Zeng, Xiao, Tian, Dong, Pan, Yuan, Cai, Jiang, Yu, Du, Ye, Cheng, Wei, Su, Lu, Ding, Ren, Shen"),
    "japones": ("Japonesa", "apellido_nombre",
        "Hiroshi, Takashi, Kenji, Yuki, Daisuke, Takeshi, Masato, Kazuo, Satoshi, Naoki, Ryota, Shinji, Tetsuya, Koji, Akira, Haruki, Kenta, Yusuke, Makoto, Noboru, Shigeru, Toshiro, Isamu, Minoru",
        "Sato, Suzuki, Takahashi, Tanaka, Watanabe, Ito, Yamamoto, Nakamura, Kobayashi, Kato, Yoshida, Yamada, Sasaki, Yamaguchi, Matsumoto, Inoue, Kimura, Hayashi, Shimizu, Yamazaki, Mori, Abe, Ikeda, Hashimoto, Ishikawa, Ogawa, Goto, Okada, Hasegawa, Fujita"),
    "coreano": ("Coreana", "apellido_nombre",
        "Min-jun, Seo-jun, Ji-hoon, Hyun-woo, Dong-hyun, Sung-min, Jae-won, Young-ho, Joon-ho, Tae-yang, Woo-jin, Sang-hoon, Jin-woo, Seung-hyun, Kyung-soo, Byung-chul, Chang-min, Dae-hyun, Hyung-seok, Ki-tae",
        "Kim, Lee, Park, Choi, Jung, Kang, Cho, Yoon, Jang, Lim, Han, Oh, Seo, Shin, Kwon, Hwang, Ahn, Song, Yoo, Hong, Jeon, Ko, Moon, Yang, Son, Bae, Baek, Heo, Nam, Shim"),
    "vietnamita": ("Vietnamita", "apellido_nombre",
        "Văn Minh, Quang Huy, Đức Anh, Thanh Tùng, Minh Tuấn, Hữu Phước, Văn Hùng, Quốc Bảo, Trọng Nghĩa, Công Vinh, Anh Dũng, Hoàng Long, Tuấn Kiệt, Văn Thành, Đình Trọng, Xuân Trường, Hải Nam, Quang Hải",
        "Nguyễn, Trần, Lê, Phạm, Hoàng, Huỳnh, Phan, Vũ, Võ, Đặng, Bùi, Đỗ, Hồ, Ngô, Dương, Lý"),
    "tailandes": ("Tailandesa y laosiana", "nombre_apellido",
        "Somchai, Somsak, Prasert, Anan, Surachai, Kittisak, Wichai, Chaiwat, Narong, Pichai, Sombat, Thanakorn, Apichat, Nattapong, Sakda, Boonmee, Chalerm, Thawatchai, Suthep, Phirun",
        "Srisai, Wongsawat, Chaiyasit, Boonmee, Saetang, Rattanakorn, Jaidee, Thongchai, Sukhum, Kaewmanee, Phromsorn, Charoenwong, Suwannarat, Pongpanich, Intharakul, Wattanasin, Chantarasiri, Sisavath, Phommachanh, Keomany"),
    "jemer": ("Jemer", "nombre_apellido",
        "Sokha, Vannak, Sovann, Rithy, Piseth, Samnang, Dara, Vuthy, Sarun, Kosal, Narith, Ratana, Sopheak, Veasna, Chea, Bunthoeun",
        "Sok, Chan, Kim, Lim, Heng, Ly, Keo, Ouk, Chea, Pich, Sam, Mao, Nhem, Kong, Prak, Touch"),
    "birmano": ("Birmana", "nombre_apellido",
        "Aung, Kyaw, Zaw, Htet, Min, Myo, Thura, Tun, Win, Soe, Than, Naing, Hlaing, Maung, Ko, Nyi, Ye, Thein, Zin, Phyo",
        "Aung, Kyaw, Zaw, Htet, Myint, Oo, Lwin, Swe, Naing, Soe, Tun, Win, Hlaing, Moe, Thant, Khin, Lin, Htay"),
    "malayo": ("Malaya e indonesia", "nombre_apellido",
        "Budi, Agus, Joko, Bambang, Hendra, Rudi, Dedi, Eko, Hadi, Wahyu, Andi, Rizki, Fajar, Ahmad, Muhammad, Abdul Rahman, Hafiz, Azman, Zulkifli, Hishamuddin, Ismail, Faisal",
        "Santoso, Wijaya, Susanto, Hidayat, Pratama, Saputra, Nugroho, Kurniawan, Setiawan, Wibowo, Hakim, Siregar, Lubis, bin Abdullah, bin Ismail, bin Hassan, bin Yusof, Rahman, Hamid, Salleh, Othman, Zainal, Ibrahim"),
    "filipino": ("Filipina", "nombre_apellido",
        "Jose, Juan, Antonio, Ramon, Eduardo, Ricardo, Rolando, Danilo, Ernesto, Reynaldo, Rodrigo, Romeo, Benigno, Manuel, Fernando, Alfredo, Arnel, Jericho, Mark, Jun",
        "Santos, Reyes, Cruz, Bautista, Ocampo, Garcia, Mendoza, Torres, Tomas, Andrada, Castillo, Flores, Villanueva, Ramos, Aquino, Dela Cruz, Del Rosario, Gonzales, Aguilar, Pascual, Domingo, Soriano, Navarro, Salvador"),
    "mongol": ("Mongola", "nombre_apellido",
        "Batbayar, Ganbold, Enkhbat, Bold, Tuvshin, Munkh, Erdene, Altan, Dorj, Naranbaatar, Gantulga, Temuulen, Bayar, Chinbat, Ganzorig, Ochirbat, Tsogt, Davaa, Batsaikhan",
        "Dorj, Bat-Erdene, Jamsran, Purev, Tsend, Gombo, Sodnom, Namsrai, Baatar, Chuluun, Dashdorj, Lkhagva, Ochir, Damdin"),
    "georgiano": ("Georgiana", "nombre_apellido",
        "Giorgi, Davit, Levan, Nikoloz, Irakli, Zurab, Tamaz, Besik, Vakhtang, Merab, Lasha, Gela, Mamuka, Temur, Aleksandre, Shota, Otar, Zaza, Gocha, Koba",
        "Beridze, Kapanadze, Gelashvili, Maisuradze, Lomidze, Tsiklauri, Khachidze, Gogoladze, Bakradze, Japaridze, Mamulashvili, Chkheidze, Kvaratskhelia, Gurgenidze, Natsvlishvili, Abashidze, Dadiani, Jorjadze, Tabatadze, Meladze"),
    "armenio": ("Armenia", "nombre_apellido",
        "Armen, Aram, Arman, Hayk, Vahan, Levon, Sargis, Karen, Tigran, Artur, Vardan, Gevorg, Hovhannes, Narek, Samvel, Garik, Artak, Ashot, Davit, Grigor",
        "Petrosyan, Sargsyan, Grigoryan, Hakobyan, Harutyunyan, Mkrtchyan, Avetisyan, Vardanyan, Gevorgyan, Hovhannisyan, Mnatsakanyan, Ghazaryan, Karapetyan, Babayan, Danielyan, Manukyan, Simonyan, Davtyan, Asatryan, Melkonyan"),
    "africa_occidental": ("Africana occidental", "nombre_apellido",
        "Chinedu, Emeka, Oluwaseun, Adebayo, Ibrahim, Musa, Kwame, Kofi, Kwabena, Yaw, Kwesi, Ousmane, Mamadou, Moussa, Abdoulaye, Seydou, Boubacar, Idrissa, Amadou, Cheikh, Yacouba, Kouassi, Tunde, Olumide, Segun, Babatunde",
        "Okafor, Okonkwo, Adeyemi, Abubakar, Mensah, Owusu, Boateng, Asante, Appiah, Diallo, Traoré, Konaté, Coulibaly, Diop, Ndiaye, Sow, Camara, Keita, Ouédraogo, Sanogo, Bamba, Touré, Fofana, Bello, Ogunleye, Eze, Nwosu, Olawale, Danjuma, Yakubu"),
    "africa_oriental": ("Africana oriental", "nombre_apellido",
        "Juma, Hamisi, Otieno, Kamau, Mwangi, Njoroge, Omondi, Wafula, Kipchoge, Mutua, Musa, Okello, Mugisha, Byaruhanga, Habimana, Nsengiyumva, Mwenda, Chanda, Banda, Phiri, Tembo, Mulenga, Kiprono, Rotich, Kimani, Kariuki",
        "Odhiambo, Ochieng, Karanja, Kiplagat, Maina, Kibet, Mwakasege, Massawe, Mushi, Mrema, Ssebunya, Mukasa, Tumusiime, Kiggundu, Nsabimana, Uwimana, Mutabazi, Ndayizeye, Banda, Phiri, Tembo, Mulenga, Chanda, Zulu"),
    "africa_austral": ("Africana austral", "nombre_apellido",
        "Sipho, Thabo, Themba, Bongani, Mandla, Sibusiso, Tendai, Tafadzwa, Farai, Kudzai, Tapiwa, Kagiso, Tshepo, Mpho, Jabu, Johan, Pieter, Willem, Hendrik",
        "Nkosi, Dlamini, Zulu, Ndlovu, Khumalo, Mokoena, Molefe, Mahlangu, Sithole, Mthembu, Moyo, Ncube, Sibanda, Mutasa, Dube, Botha, Van der Merwe, Pretorius, Du Plessis, Kruger, Nel, Venter, Mokgosi"),
    "africa_central": ("Africana central", "nombre_apellido",
        "Jean-Pierre, Patrick, Joseph, Didier, Christian, Serge, Fabrice, Blaise, Guy, Emmanuel, Pascal, Alain, Jérôme, Trésor, Prosper, Papy, Bienvenu, Dieudonné, Héritier, Junior",
        "Mbuyi, Kabongo, Mukendi, Kalala, Ilunga, Mutombo, Mbemba, Ngoma, Makosso, Nzamba, Mba, Biyoghe, Essomba, Tchoumi, Fotso, Nkomo, Ekwalla, Mouko, Kasongo, Tshibangu"),
    "etiope": ("Etíope y eritrea", "nombre_apellido",
        "Abebe, Bekele, Tadesse, Girma, Haile, Kebede, Mulugeta, Getachew, Dawit, Yonas, Solomon, Berhanu, Teshome, Wondimu, Alemayehu, Yohannes, Tesfaye, Mesfin, Samuel, Eyob",
        "Tesfaye, Gebremariam, Hailu, Desta, Mekonnen, Alemu, Worku, Assefa, Gebre, Tekle, Negash, Abraha, Bereket, Gebremedhin, Kidane, Woldemichael, Habtemariam"),
    "polinesio": ("Del Pacífico", "nombre_apellido",
        "Sione, Tevita, Viliami, Mosese, Josefa, Semisi, Mika, Ioane, Tomasi, Setareki, Kalolo, Penitani, Manaia, Tama, Siaosi, Lemalu, Etuale",
        "Tupou, Vaka, Fifita, Havili, Taufa, Naqelevuki, Ravuvu, Tuilagi, Seiuli, Leota, Faleolo, Toala, Salesa, Tago, Kaufusi, Latu, Moala"),
}

# país / territorio -> cultura (clave = nombre en datos/entidades.json)
PAISES = {
    "hispano": "Andorra, Argentina, Bolivia, Chile, Colombia, Costa Rica, Cuba, Ecuador, El Salvador, España, Guatemala, Guinea Ecuatorial, Honduras, México, Nicaragua, Panamá, Paraguay, Perú, Puerto Rico, República Dominicana, Uruguay, Venezuela, Campo de hielo Patagónico Sur",
    "lusofono": "Portugal, Brasil, Angola, Mozambique, Cabo Verde, Guinea-Bisáu, Santo Tomé y Príncipe, Timor Oriental",
    "anglo": "Estados Unidos, Reino Unido, Irlanda, Canadá, Australia, Nueva Zelanda, Jamaica, Bahamas, Barbados, Belice, Trinidad y Tobago, Guyana, Antigua y Barbuda, Dominica, Granada, San Cristóbal y Nieves, Santa Lucía, San Vicente y las Granadinas, Anguila, Bermudas, Islas Caimán, Islas Turcas y Caicos, Islas Vírgenes Británicas, Islas Vírgenes de los Estados Unidos, Montserrat, Gibraltar, Guernsey, Jersey, Isla de Man, Isla Santa Elena, Islas Malvinas, Islas Georgias del Sur y Sandwich del Sur, Islas Pitcairn, Isla Norfolk, Islas Heard y McDonald, Guam, Islas Marianas del Norte, Samoa Estadounidense, Islas ultramarinas de Estados Unidos, Base Naval de la Bahía de Guantánamo, Akrotiri, Dekelia, Territorio Británico del Océano Índico, Territorios Australianos del Océano Índico, Zona de amortiguación de Chipre, Antártida",
    "frances": "Francia, Mónaco, Luxemburgo, Haití, San Bartolomé, San Martín (Francia), San Pedro y Miquelón, Nueva Caledonia, Tierras Australes Francesas, Seychelles",
    "aleman": "Alemania, Austria, Suiza, Liechtenstein",
    "italiano": "Italia, San Marino, Malta",
    "neerlandes": "Países Bajos, Bélgica, Surinam, Curazao, Aruba, Sint Maarten (Países Bajos)",
    "nordico": "Suecia, Noruega, Dinamarca, Islandia, Islas Feroe, Groenlandia, Åland",
    "fines": "Finlandia",
    "eslavo_occidental": "Polonia, Chequia, Eslovaquia",
    "ruso": "Rusia, Bielorrusia, Baikonur",
    "ucraniano": "Ucrania",
    "eslavo_sur": "Serbia, Croacia, Bosnia y Herzegovina, Montenegro, Macedonia del Norte, Eslovenia, Bulgaria",
    "albanes": "Albania, Kosovo",
    "baltico": "Estonia, Letonia, Lituania",
    "hungaro": "Hungría",
    "rumano": "Rumanía, Moldavia",
    "griego": "Grecia, Chipre",
    "turco": "Turquía, Chipre del Norte",
    "turcomano": "Azerbaiyán, Kazajistán, Uzbekistán, Kirguistán, Turkmenistán",
    "persa": "Irán, Tayikistán, Afganistán",
    "arabe": "Arabia Saudita, Argelia, Baréin, Catar, Egipto, Emiratos Árabes Unidos, Irak, Jordania, Kuwait, Líbano, Libia, Marruecos, Mauritania, Omán, Palestina, Siria, Sudán, Túnez, Yemen, Sahara Occidental, Comoras, Yibuti, Somalia, Somalilandia, Bir Tawil",
    "hebreo": "Israel",
    "india": "India, Nepal, Bután, Sri Lanka, Mauricio, Glaciar de Siachen",
    "sur_asia_islamico": "Pakistán, Bangladés, Maldivas",
    "chino": "China, Taiwán, Hong Kong, Macao, Singapur",
    "japones": "Japón",
    "coreano": "Corea del Norte, Corea del Sur",
    "vietnamita": "Vietnam",
    "tailandes": "Tailandia, Laos",
    "jemer": "Camboya",
    "birmano": "Myanmar",
    "malayo": "Indonesia, Malasia, Brunéi",
    "filipino": "Filipinas",
    "mongol": "Mongolia",
    "georgiano": "Georgia",
    "armenio": "Armenia",
    "africa_occidental": "Nigeria, Ghana, Sierra Leona, Liberia, Gambia, Togo, Benín, Costa de Marfil, Burkina Faso, Malí, Senegal, Guinea, Níger, Chad, Isla Santa Elena",
    "africa_oriental": "Kenia, Tanzania, Uganda, Ruanda, Burundi, Malaui, Zambia, Madagascar, Sudán del Sur",
    "africa_austral": "Sudáfrica, Zimbabue, Botsuana, Namibia, Lesoto, Esuatini",
    "africa_central": "República Democrática del Congo, República del Congo, Gabón, Camerún, República Centroafricana",
    "etiope": "Etiopía, Eritrea",
    "polinesio": "Fiyi, Samoa, Tonga, Islas Cook, Niue, Islas Salomón, Vanuatu, Kiribati, Tuvalu, Nauru, Palaos, Islas Marshall, Estados Federados de Micronesia, Papúa Nueva Guinea, Polinesia Francesa, Wallis y Futuna",
}
# (Isla Santa Elena figura en «anglo» y en africa_occidental: manda el último, así que se quita de aquí abajo.)
PAISES["africa_occidental"] = PAISES["africa_occidental"].replace(", Isla Santa Elena", "")

DEFECTO_CONTINENTE = {
    "Europa": "eslavo_occidental", "Asia": "india", "África": "africa_occidental", "América del Norte": "anglo",
    "América del Sur": "hispano", "Oceanía": "polinesio", "Antártida": "anglo",
}

# Títulos de la cadena de mando por época. «hasta»: la era vale mientras año < hasta.
# supremo = título si el jefe de Estado no tiene nombre real conocido; alto_mando = jefe de todo el ejército;
# region = comandante de la zona; pelotón = jefe de 1.000 hombres; segundo = su adjunto; oficial = los jefes de compañía.
ERAS = [
    {"nombre": "Antigüedad", "hasta": 500, "supremo": "Comandante supremo", "alto_mando": "Estratega", "region": "Legado",
     "peloton": "Quiliarca", "segundo": "Tribuno", "oficial": "Centurión"},
    {"nombre": "Edad Media", "hasta": 1500, "supremo": "Señor de la guerra", "alto_mando": "Condestable", "region": "Gobernador militar",
     "peloton": "Capitán de armas", "segundo": "Alférez", "oficial": "Sargento de armas"},
    {"nombre": "Edad Moderna", "hasta": 1800, "supremo": "Comandante supremo", "alto_mando": "Mariscal", "region": "Capitán general",
     "peloton": "Coronel", "segundo": "Teniente coronel", "oficial": "Capitán"},
    {"nombre": "Época contemporánea", "hasta": 100000, "supremo": "Comandante en jefe", "alto_mando": "General de ejército",
     "region": "General de brigada", "peloton": "Coronel", "segundo": "Teniente coronel", "oficial": "Capitán"},
]


def main():
    culturas = {}
    for cid, (etq, orden, nom, ape) in CULTURAS.items():
        n, a = L(nom), L(ape)
        assert len(n) >= 12 and len(a) >= 12, cid
        assert len(set(n)) == len(n), (cid, "nombres repetidos")
        culturas[cid] = {"nombre": etq, "orden": orden, "nombres": n, "apellidos": a}
    paises = {}
    for cid, lst in PAISES.items():
        assert cid in culturas, cid
        for p in L(lst):
            if p in paises:
                raise SystemExit("País repetido en dos culturas: %s (%s y %s)" % (p, paises[p], cid))
            paises[p] = cid
    ent = json.load(open(os.path.join(RAIZ, "datos", "entidades.json"), encoding="utf-8"))["paises"]
    faltan = [p for p in ent if p not in paises]
    sobran = [p for p in paises if p not in ent]
    if sobran:
        print("AVISO: no existen en entidades.json:", sobran)
    if faltan:
        print("Sin cultura explícita (usarán la del continente):", [(p, ent[p]["cont"]) for p in faltan])
    salida = {
        "version": "0.1.7.9.9D",
        "ayuda": "Nombres de mandos por cultura. orden: nombre_apellido | hispano (nombre + 2 apellidos) | apellido_nombre. "
                 "Generado por herramientas/hacer_nombres_cultura.py; se puede editar a mano (solo masculinos por ahora).",
        "culturas": culturas, "paises": paises, "defecto_continente": DEFECTO_CONTINENTE, "eras": ERAS,
    }
    ruta = os.path.join(RAIZ, "datos", "nombres_cultura.json")
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, indent=1)
    print("OK:", len(culturas), "culturas,", len(paises), "países mapeados,", os.path.getsize(ruta) // 1024, "KB ->", ruta)


if __name__ == "__main__":
    main()
