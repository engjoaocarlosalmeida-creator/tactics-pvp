class_name OnlineMenu
extends Control

signal host_requested
signal join_requested(address: String)
signal back_pressed

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var host_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HostButton
@onready var ip_edit: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/IpEdit
@onready var join_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/JoinButton
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
    var ui_theme := UITheme.get_theme()
    $CenterContainer/PanelContainer.add_theme_stylebox_override("panel", ui_theme.get_stylebox("panel", "PanelContainer"))
    title_label.add_theme_font_override("font", UITheme.title_font)
    title_label.add_theme_font_size_override("font_size", 28)
    title_label.add_theme_color_override("font_color", UITheme.GOLD)

    for btn in [host_button, join_button, back_button]:
        _apply_button_theme(btn, ui_theme)

    ip_edit.add_theme_font_override("font", UITheme.body_font)
    ip_edit.add_theme_font_size_override("font_size", 18)
    ip_edit.add_theme_color_override("font_color", UITheme.CREAM)
    ip_edit.add_theme_stylebox_override("normal", ui_theme.get_stylebox("normal", "LineEdit").duplicate())
    ip_edit.add_theme_stylebox_override("focus", ui_theme.get_stylebox("focus", "LineEdit").duplicate())

    host_button.pressed.connect(func(): host_requested.emit())
    join_button.pressed.connect(func(): join_requested.emit(ip_edit.text.strip_edges()))
    ip_edit.text_submitted.connect(func(txt: String): join_requested.emit(txt.strip_edges()))
    back_button.pressed.connect(func(): back_pressed.emit())


func _apply_button_theme(btn: Button, ui_theme: Theme) -> void:
    btn.focus_mode = Control.FOCUS_NONE
    for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
        btn.add_theme_stylebox_override(state, ui_theme.get_stylebox(state, "Button").duplicate())
    btn.add_theme_color_override("font_color", UITheme.CREAM)
    btn.add_theme_color_override("font_hover_color", UITheme.GOLD)
    btn.add_theme_color_override("font_pressed_color", UITheme.GOLD)
    btn.add_theme_color_override("font_hover_pressed_color", UITheme.GOLD)
    btn.add_theme_color_override("font_disabled_color", UITheme.DIM)