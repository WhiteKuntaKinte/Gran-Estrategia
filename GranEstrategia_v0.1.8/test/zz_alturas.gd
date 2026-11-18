extends Node
var main
func _ready() -> void:
	run.call_deferred()
func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout
func primer_texto(n: Node) -> String:
	for h in n.get_children():
		if h is Label and (h as Label).text != "":
			return (h as Label).text
		var r := primer_texto(h)
		if r != "":
			return r
	return ""
func run() -> void:
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	await esperar(1.0)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.3)
	main._seleccion_pais("España", "Europa", Vector2(1175.0, 330.0))
	await esperar(0.4)
	var hud = main.hud
	print("VP ", hud.raiz.get_viewport().get_visible_rect().size, " ancho_panel ", hud.ancho_panel, " cols ", hud._ult_cols)
	for k in ["general", "progreso"]:
		hud.abrir_pestana(k)
		await esperar(0.25)
		print("== ", k, " total ", hud.cuerpo.get_combined_minimum_size().y)
		for c in hud.cuerpo.get_children():
			print("   %4.0f  %s" % [(c as Control).get_combined_minimum_size().y, primer_texto(c).substr(0, 40)])
	get_tree().quit()
