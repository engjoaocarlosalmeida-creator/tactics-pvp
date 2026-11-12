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

extends Control

func _ready():
    pass

func _input(event):
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        if is_visible():
            # Fechar o menu de pausa
            hide()
            get_tree().get_current_scene()._handle_pause_exit()
        else:
            # Abrir o menu de pausa
            show()
            get_tree().get_current_scene()._handle_pause_enter()
func _process(delta: float):
    pass
    if Engine.is_editor_hint() == false and is_visible():
        if Input.is_action_just_pressed("ui_cancel"):
            # Forcing input handling via _process if _unhandled_input fails to capture events
            _on_main_menu_pressed()

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

