## Janela que pode ser arrastada (menu de acoes nao arrasta: fica preso ao personagem).
class_name DragPanel
extends PanelContainer



var dragging := false
var draggable := true


func _gui_input(event: InputEvent) -> void :
    if not draggable:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        dragging = event.pressed
        accept_event()
    elif event is InputEventMouseMotion and dragging:
        position += event.relative
        var vs := get_viewport_rect().size
        position = position.clamp(Vector2( - size.x + 80.0, 0.0), Vector2(vs.x - 80.0, vs.y - 40.0))
        accept_event()
