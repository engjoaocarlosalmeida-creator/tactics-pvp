## Barra generica (vida, MP, acao) com cor propria e parte 'gasta'.
class_name HpBar
extends Control


var fill_color := Color(0, 0, 0, 0)
var ghost := 0.0:
    set(v):
        ghost = clampf(v, 0.0, 1.0)
        queue_redraw()
var ratio := 1.0:
    set(v):
        ratio = clampf(v, 0.0, 1.0)
        queue_redraw()


static func color_for(r: float) -> Color:
    if r > 0.5:
        return Color(0.3, 0.85, 0.35)
    if r > 0.25:
        return Color(0.95, 0.8, 0.2)
    return Color(0.9, 0.25, 0.2)


func _init() -> void :
    custom_minimum_size = Vector2(120, 12)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void :
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.12, 0.95))
    draw_rect(Rect2(Vector2(1, 1), Vector2(maxf(0.0, (size.x - 2.0) * ratio), size.y - 2.0)), fill_color if fill_color.a > 0.0 else color_for(ratio))
    if ghost > 0.0:
        var x0 := 1.0 + (size.x - 2.0) * ratio
        draw_rect(Rect2(Vector2(x0, 1), Vector2(minf((size.x - 2.0) * ghost, size.x - 1.0 - x0), size.y - 2.0)), Color(0.55, 0.45, 0.15, 0.55))
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.9, 0.9), false, 1.0)
