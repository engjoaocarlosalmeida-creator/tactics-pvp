extends Control

signal resume_requested
signal options_requested
signal main_menu_requested
signal quit_requested

@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var options_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton

# GameOptionsMenu.gd
# Este script DEVE ser usado SOMENTE para o menu pop-up de opções DURANTE a partida.
# Ele deve ser instanciado e controlado EXCLUSIVAMENTE pela cena de JOGO.
# Não deve ser chamado por nenhuma outra cena.

# Variáveis de estado: A cena de jogo deve gerenciar a visibilidade (self.visible) e o estado de 'pausado'.

func _ready() -> void:
	# Garante que o menu NUNCA tenha transparência.
	modulate = Color(1, 1, 1, 1)

	# Configura o Overlay para ignorar o mouse
	$Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Aplica o tema global da UI a todos os nós relevantes
	var menu_theme = UITheme.get_theme()
	$CenterContainer/PanelContainer.add_theme_stylebox_override("panel", menu_theme.get_stylebox("panel", "PanelContainer"))
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel.add_theme_font_override("font", UITheme.title_font)
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel.add_theme_font_size_override("font_size", 26)
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel.add_theme_color_override("font_color", UITheme.GOLD)

	var buttons = [
		{"node": $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton, "signal": "resume_requested"},
		{"node": $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsButton, "signal": "options_requested"},
		{"node": $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuButton, "signal": "main_menu_requested"},
		{"node": $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton, "signal": "quit_requested"}
	]

	for item in buttons:
		var btn = item["node"]
		# Aplica os estilos
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
			var stylebox = menu_theme.get_stylebox(state, "Button").duplicate()
			btn.add_theme_stylebox_override(state, stylebox)
		btn.add_theme_color_override("font_color", UITheme.CREAM)
		btn.add_theme_color_override("font_hover_color", UITheme.GOLD)
		btn.add_theme_color_override("font_pressed_color", UITheme.GOLD)
		btn.add_theme_color_override("font_hover_pressed_color", UITheme.GOLD)
		btn.add_theme_color_override("font_focus_color", UITheme.CREAM)
		btn.add_theme_color_override("font_disabled_color", UITheme.DIM)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		btn.add_theme_constant_override("outline_size", 0)
		btn.add_theme_constant_override("h_separation", 10)

	resume_button.pressed.connect(func(): resume_requested.emit())
	options_button.pressed.connect(func(): options_requested.emit())
	main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	quit_button.pressed.connect(func(): quit_requested.emit())

# Chama quando o botão "Voltar ao menu principal" é pressionado
func _on_back_button_pressed() -> void:
	# Esta função força o retorno ao menu principal da cena.
	_exit_to_menu()

# Chama quando o botão "Sair do jogo" é pressionado
func _on_quit_button_pressed() -> void:
	# Fecha o jogo.
	get_tree().quit()

func _exit_to_menu() -> void:
	# Simplesmente muda para a cena principal.
	# Assume-se que a cena que chamou este menu está pausada quando ele é exibido.
	get_tree().change_scene_to_file('res://scenes/main_menu.tscn')
