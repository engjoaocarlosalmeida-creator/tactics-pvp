extends Control

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_main_menu_pressed() -> void:
	# Ação: Voltar para o menu principal. Se o jogador sair durante o jogo ativo, é considerado derrotado.
	if has_node('/root/NetworkManager') and get_node('/root/NetworkManager').is_online():
		# Sinaliza penalidade/derrota ao NetworkManager
		show()
	else:
		# Volta ao menu principal sem penalidade, se não estiver online
		_exit_to_menu()

func _on_quit_pressed() -> void:
	# Ação: Fechar o jogo.
	get_tree().quit()

func _exit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file('res://scenes/main_menu.tscn')

func _ready():
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel'):
		# Abre o menu de opções globalmente.
		self.visible = not self.visible