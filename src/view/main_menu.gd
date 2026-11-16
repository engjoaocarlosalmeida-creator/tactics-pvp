class_name MainMenu
extends Control

signal mode_selected(mode: int)
signal online_pressed
signal options_pressed
signal quit_pressed

enum MatchMode {LOCAL, VS_CPU, DEMO}

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var vbox: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer
@onready var local_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LocalButton
@onready var cpu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CpuButton
@onready var demo_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DemoButton
@onready var online_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OnlineButton
@onready var options_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.12, 0.42)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	vbox.custom_minimum_size = Vector2(420, 0)

	_style_menu_button(local_button, 26)
	_style_menu_button(cpu_button, 26)
	_style_menu_button(demo_button, 26)
	_style_menu_button(online_button, 26)
	_style_menu_button(options_button, 26)
	_style_menu_button(quit_button, 26)

	local_button.pressed.connect(func(): mode_selected.emit(MatchMode.LOCAL))
	cpu_button.pressed.connect(func(): mode_selected.emit(MatchMode.VS_CPU))
	demo_button.pressed.connect(func(): mode_selected.emit(MatchMode.DEMO))
	online_button.pressed.connect(func(): online_pressed.emit())
	options_button.pressed.connect(func(): options_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())


func _style_menu_button(b: Button, font_size: int) -> void:
	UITheme.get_theme()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(0, font_size + 18)
	b.add_theme_font_override("font", UITheme.title_font)
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UITheme.CREAM)
	for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UITheme.GOLD)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	b.add_theme_constant_override("outline_size", 7)
	var base := b.text
	var mark := func(on: bool): b.text = ("▶  %s  ◀" % base) if on else base
	b.mouse_entered.connect(func(): mark.call(true))
	b.mouse_exited.connect(func(): mark.call(false))
