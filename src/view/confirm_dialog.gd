class_name ConfirmDialog
extends DragPanel

signal confirmed
signal cancelled

@onready var message_label: RichTextLabel = $VBoxContainer/ConfirmLabel
@onready var ok_button: Button = $VBoxContainer/ButtonRow/ConfirmOk
@onready var cancel_button: Button = $VBoxContainer/ButtonRow/ConfirmCancel


func _ready() -> void:
    visible = false
    var ui_theme := UITheme.get_theme()
    add_theme_stylebox_override("panel", ui_theme.get_stylebox("panel", "PanelContainer"))

    message_label.bbcode_enabled = true
    message_label.fit_content = true
    message_label.scroll_active = false
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    message_label.add_theme_font_override("normal_font", UITheme.body_font)
    message_label.add_theme_font_override("bold_font", UITheme.bold_font)
    message_label.add_theme_font_size_override("normal_font_size", 18)
    message_label.add_theme_font_size_override("bold_font_size", 18)
    message_label.add_theme_color_override("default_color", UITheme.CREAM)

    for btn in [ok_button, cancel_button]:
        _apply_button_theme(btn, ui_theme)

    ok_button.pressed.connect(func(): confirmed.emit())
    cancel_button.pressed.connect(func(): cancelled.emit())


func _apply_button_theme(btn: Button, ui_theme: Theme) -> void:
    btn.focus_mode = Control.FOCUS_NONE
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
        btn.add_theme_stylebox_override(state, ui_theme.get_stylebox(state, "Button").duplicate())
    btn.add_theme_color_override("font_color", UITheme.CREAM)
    btn.add_theme_color_override("font_hover_color", UITheme.GOLD)
    btn.add_theme_color_override("font_pressed_color", UITheme.GOLD)
    btn.add_theme_color_override("font_hover_pressed_color", UITheme.GOLD)