# src/view/game_pause_controller.gd
class_name GamePauseController
extends Node

var pause_layer: CanvasLayer
var game_options_menu: Control

# Public method to open/close game options menu (and pause the game if needed)
func open_game_options() -> void:
	# Assuming game_options_menu visibility control is sufficient for the pause effect
	if game_options_menu.visible:
		game_options_menu.visible = false
		# Optional: Resume game or just change state
	else:
		game_options_menu.visible = true
		# Optional: Pause game logic here if required by the original implementation
		pass # Placeholder for pause logic
		
# Public method to toggle pause state
func toggle_pause() -> void:
	game_options_menu.visible = !game_options_menu.visible
	# Real pause logic would involve setting game state/pausing time, but for Step 1,
	# we focus on the UI/Control flow migration.
	pass

func _ready() -> void:
	# Rule 1: Create and configure the CanvasLayer and GameOptionsMenu
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 100
	add_child(pause_layer)

	game_options_menu = Control.new()
	var options_script = load("res://src/view/game_options_menu.gd")
	if options_script:
		game_options_menu.set_script(options_script)
	else:
		print("Error: Could not load game_options_menu.gd")
	
	pause_layer.add_child(game_options_menu) # Add menu inside the layer