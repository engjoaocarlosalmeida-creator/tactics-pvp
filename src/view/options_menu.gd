class_name OptionsMenu
extends Control

signal option_changed(key: String, delta: int)
signal back_pressed

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var display_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DisplayButton
@onready var resolution_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResolutionButton
@onready var volume_minus_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeRow/VolumeMinusButton
@onready var volume_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeRow/VolumeLabel
@onready var volume_plus_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VolumeRow/VolumePlusButton
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
    var theme := UITheme.get_theme()
    $CenterContainer/PanelContainer.add_theme_stylebox_override("panel", theme.get_stylebox("panel", "PanelContainer"))
    title_label.add_theme_font_override("font", UITheme.title_font)
    title_label.add_theme_font_size_override("font_size", 30)
    title_label.add_theme_color_override("font_color", UITheme.GOLD)

    for btn in [display_button, resolution_button, volume_minus_button, volume_plus_button, back_button]:
        _apply_button_theme(btn, theme)

    volume_label.add_theme_font_override("font", UITheme.body_font)
    volume_label.add_theme_font_size_override("font_size", 19)
    volume_label.add_theme_color_override("font_color", UITheme.CREAM)

    display_button.pressed.connect(func(): option_changed.emit("display_mode", 0))
    resolution_button.pressed.connect(func(): option_changed.emit("resolution", 0))
    volume_minus_button.pressed.connect(func(): option_changed.emit("volume", -1))
    volume_plus_button.pressed.connect(func(): option_changed.emit("volume", 1))
    back_button.pressed.connect(func(): back_pressed.emit())


func apply_values(values: Dictionary) -> void:
    display_button.text = "Modo de tela: %s" % str(values.get("display_mode", ""))
    resolution_button.text = "Resolução da janela: %s" % str(values.get("resolution", ""))
    resolution_button.disabled = not bool(values.get("can_resize", true))
    var vol_pct := int(round(float(values.get("volume", 1.0)) * 100.0))
    volume_label.text = "Volume geral: %d%%" % vol_pct


func _apply_button_theme(btn: Button, theme: Theme) -> void:
    btn.focus_mode = Control.FOCUS_NONE
    for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
        btn.add_theme_stylebox_override(state, theme.get_stylebox(state, "Button").duplicate())
    btn.add_theme_color_override("font_color", UITheme.CREAM)
    btn.add_theme_color_override("font_hover_color", UITheme.GOLD)
    btn.add_theme_color_override("font_pressed_color", UITheme.GOLD)
    btn.add_theme_color_override("font_hover_pressed_color", UITheme.GOLD)
    btn.add_theme_color_override("font_disabled_color", UITheme.DIM)