class_name GamePauseController
extends Node

var pause_layer: CanvasLayer
var game_options_menu: Node
var game_view_ref: Node

func setup(view: Node) -> void:
	game_view_ref = view

func _ready() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 100
	add_child(pause_layer)

	var scene_paths := [
		"res://src/view/game_options_menu.tscn",
		"res://scenes/game_options_menu.tscn",
		"res://scenes/ui/game_options_menu.tscn"
	]
	for path in scene_paths:
		if ResourceLoader.exists(path):
			var packed: PackedScene = load(path)
			game_options_menu = packed.instantiate()
			break

	if game_options_menu == null:
		var script_res = load("res://src/view/game_options_menu.gd")
		if script_res:
			game_options_menu = script_res.new()

	if game_options_menu != null:
		game_options_menu.visible = false
		pause_layer.add_child(game_options_menu)

		# Conecta os sinais do menu de opções
		game_options_menu.resume_requested.connect(toggle_pause)
		game_options_menu.options_requested.connect(_on_options_requested)
		game_options_menu.main_menu_requested.connect(_on_main_menu_requested)
		game_options_menu.quit_requested.connect(func(): get_tree().quit())

func toggle_pause() -> void:
	if game_options_menu == null:
		return
	game_options_menu.visible = not game_options_menu.visible

func _on_resume_requested() -> void:
	toggle_pause()

func _on_options_requested() -> void:
	if game_view_ref:
		game_view_ref._show_options()

func _on_main_menu_requested() -> void:
	if game_view_ref:
		game_view_ref._show_menu()

func _on_quit_requested() -> void:
	get_tree().quit()
