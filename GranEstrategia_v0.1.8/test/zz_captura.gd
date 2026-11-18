extends Node
## Herramienta (no es una prueba): saca capturas de pantalla del juego a un tamaño de ventana dado. Se corre con xvfb y OpenGL:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://test/zz_captura.tscn -- --w=1920 --h=1080 --salida=/ruta/carpeta [--epoca=2026]
var main
var m
var W := 1920
var H := 1080
var salida := "/tmp"
var epoca := 2026


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--w="):
			W = int(a.substr(4))
		elif a.begins_with("--h="):
			H = int(a.substr(4))
		elif a.begins_with("--salida="):
			salida = a.substr(9)
		elif a.begins_with("--epoca="):
			epoca = int(a.substr(8))
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	run.call_deferred()


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [salida, nombre])
	print("[C] %s %dx%d" % [nombre, img.get_width(), img.get_height()])


func mp(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) * 2400.0 / 360.0, (90.0 - lat) * 1200.0 / 180.0)


func poner_zr(zr: float, centro: Vector2) -> void:
	main.camara.position = centro
	main.camara.zoom = Vector2(1.0, 1.0)
	main._actualizar_zoom()
	var base: float = main._zoom_real()
	var z: float = zr / base
	main.camara.zoom = Vector2(z, z)
	main._actualizar_zoom()


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(W, H)
	await esperar(0.5)
	await foto("00_menu")
	var cfg := {"modo": "campana", "pais": "España", "ia": 1}
	if epoca != 2026:
		cfg = {"modo": "dev", "epoca": epoca, "pais": "", "ia": 1}
	main._iniciar_partida(cfg)
	await esperar(1.5)
	main.reloj.velocidad = 0
	m = main.mundo
	poner_zr(3.0, mp(-3.7, 40.4))
	await esperar(0.8)
	await foto("01_mapa")
	main._seleccion_pais("España", "Europa", mp(-3.7, 40.4))
	await esperar(1.0)
	await foto("02_panel_pais")
	var hud = main.hud
	for t in ["general", "poblacion", "progreso", "economia", "militar", "diplomacia", "politica", "territorio", "cultura"]:
		hud.abrir_pestana(t) if hud.has_method("abrir_pestana") else null
		await esperar(0.5)
		await foto("03_pestana_" + t)
	main._limpiar_seleccion()
	await esperar(0.3)
	main._seleccion_provincia(int(m.paises["España"].provincias[0]), "Europa", mp(-3.7, 40.4))
	await esperar(1.0)
	await foto("04_panel_provincia")
	for t in ["poblacion", "economia", "territorio"]:
		hud.abrir_pestana(t)
		await esperar(0.5)
		await foto("05_prov_" + t)
	get_tree().quit()
