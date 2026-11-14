extends Control

# GameOptionsMenu.gd
# Este script DEVE ser usado SOMENTE para o menu pop-up de opções DURANTE a partida.
# Ele deve ser instanciado e controlado EXCLUSIVAMENTE pela cena de JOGO.
# Não deve ser chamado por nenhuma outra cena.

# Variáveis de estado: A cena de jogo deve gerenciar a visibilidade (self.visible) e o estado de 'pausado'.

func _ready() -> void:
	# Garante que o menu NUNCA tenha transparência.
	modulate = Color(1, 1, 1, 1)

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

func _input(event: InputEvent) -> void:
	# Permite fechar/voltar ao Menu Principal com ESC.
	# O controle de visibilidade deve ser gerenciado pelo script mestre da cena de jogo
	# para garantir que só seja ativado durante a partida.
	if event.is_action_pressed('ui_cancel'):
		self.visible = not self.visible
