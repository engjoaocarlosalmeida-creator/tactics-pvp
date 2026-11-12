extends Control

func _on_resume_pressed() -> void:
    get_tree().paused = false
    queue_free()

func _on_main_menu_pressed() -> void:
    if has_node("/root/NetworkManager") and get_node("/root/NetworkManager").is_online():
        $PenaltyDialog.show()
    else:
        _exit_to_menu()

func _on_quit_pressed() -> void:
    get_tree().quit()

func _exit_to_menu() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _ready():
    pass

func _unhandled_input(event):
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        if is_visible():
            # Fechar o menu de pausa
            hide()
            if get_tree().get_current_scene() and get_tree().get_current_scene().has_method("_handle_pause_exit"):
                get_tree().get_current_scene()._handle_pause_exit()
        else:
            # Abrir o menu de pausa
            show()
            if get_tree().get_current_scene() and get_tree().get_current_scene().has_method("_handle_pause_enter"):
                get_tree().get_current_scene()._handle_pause_enter()
