## Interface: painel do personagem, fila de turnos, log, menu de acoes pequeno, janela do alvo,
## confirmacao, itens, tela de abertura, menu so de textos, conta, icones, wiki, opcoes.
class_name Hud
extends CanvasLayer

const HUD_POPUP_CONTROLLER := preload("res://src/view/hud_popup_controller.gd")
const HUD_OVERLAY_CONTROLLER := preload("res://src/view/hud_overlay_controller.gd")
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.35, 0.3)]

signal confirm_ok
signal confirm_cancel
signal order_clicked(unit_id: int)
signal splash_done

var info_head: RichTextLabel
var info_label: RichTextLabel
var hp_bar: HpBar
var hp_text: Label
var mp_bar: HpBar
var mp_text: Label
var order_box: VBoxContainer
var log_label: RichTextLabel
var overlay: PanelContainer
var overlay_box: VBoxContainer
var context_panel: DragPanel
var context_box: VBoxContainer
var context_ids: Array[String] = []
var target_panel: DragPanel
var target_box: VBoxContainer
var confirm_panel: DragPanel
var confirm_label: RichTextLabel
var items_panel: DragPanel
var items_box: VBoxContainer
var portrait_slot: PanelContainer
var _portrait_rect: TextureRect
var _log_lines: Array[String] = []
var _game_nodes: Array = []
var _order_window: Control
var hint_panel: PanelContainer
var hint_label: Label
var _game_on := true
var menu_bg: Control
var splash: Control
var account_panel: PanelContainer
var wiki_button: TextureButton
var menu_icons: HBoxContainer
var menu_icon_label: Label
var ap_bar: HpBar
var ap_text: Label
var overlay_ctrl
var popup_ctrl


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	overlay_ctrl = HUD_OVERLAY_CONTROLLER.new()
	add_child(overlay_ctrl)
	overlay_ctrl.setup(self, root)
	popup_ctrl = HUD_POPUP_CONTROLLER.new()
	add_child(popup_ctrl)
	popup_ctrl.setup(self)


	var left := _window(root, Control.PRESET_TOP_LEFT)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	left[1].add_child(lrow)
	portrait_slot = PanelContainer.new()
	portrait_slot.add_theme_stylebox_override("panel", UITheme.portrait_frame())
	portrait_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_rect = UITheme.pixel_image(null, 2)
	_portrait_rect.custom_minimum_size = Vector2(96, 96)
	portrait_slot.add_child(_portrait_rect)
	lrow.add_child(portrait_slot)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 3)
	lrow.add_child(lcol)
	info_head = _rich(250)
	lcol.add_child(info_head)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	lcol.add_child(hp_row)
	hp_bar = HpBar.new()
	hp_bar.custom_minimum_size = Vector2(150, 14)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(hp_bar)
	hp_text = Label.new()
	hp_text.add_theme_font_size_override("font_size", 16)
	hp_row.add_child(hp_text)
	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 8)
	lcol.add_child(mp_row)
	mp_bar = HpBar.new()
	mp_bar.custom_minimum_size = Vector2(150, 9)
	mp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mp_bar.fill_color = Color(0.35, 0.55, 1.0)
	mp_row.add_child(mp_bar)
	mp_text = Label.new()
	mp_text.add_theme_font_size_override("font_size", 14)
	mp_text.add_theme_color_override("font_color", UITheme.DIM)
	mp_row.add_child(mp_text)
	var ap_row := HBoxContainer.new()
	ap_row.add_theme_constant_override("separation", 8)
	lcol.add_child(ap_row)
	ap_bar = HpBar.new()
	ap_bar.name = "ActionBar"
	ap_bar.custom_minimum_size = Vector2(150, 9)
	ap_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ap_bar.fill_color = Color(1.0, 0.82, 0.25)
	ap_row.add_child(ap_bar)
	ap_text = Label.new()
	ap_text.add_theme_font_size_override("font_size", 14)
	ap_text.add_theme_color_override("font_color", UITheme.DIM)
	ap_row.add_child(ap_text)
	info_label = _rich(250)
	lcol.add_child(info_label)


	var right := _window(root, Control.PRESET_TOP_RIGHT)
	right[0].grow_horizontal = Control.GROW_DIRECTION_BEGIN
	order_box = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 4)
	right[1].add_child(order_box)
	_order_window = right[0]


	var bottom := _window(root, Control.PRESET_BOTTOM_LEFT)
	bottom[0].grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_label = _rich(430)
	bottom[1].add_child(log_label)

	_game_nodes = [left[0], bottom[0]]

	hint_panel = PanelContainer.new()
	hint_panel.visible = false
	root.add_child(hint_panel)
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label = Label.new()
	hint_label.add_theme_color_override("font_color", UITheme.GOLD)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(hint_label)
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


	context_panel = _drag_window(root)
	context_box = _vbox(context_panel, 4)
	target_panel = _drag_window(root)
	target_box = _vbox(target_panel, 6)
	confirm_panel = _drag_window(root)
	var cbox := _vbox(confirm_panel, 10)
	confirm_label = _rich(340)
	confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(confirm_label)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	cbox.add_child(crow)
	var ok := _button("OK", func(): confirm_ok.emit())
	ok.name = "ConfirmOk"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(ok)
	var cancel := _button("Cancelar", func(): confirm_cancel.emit())
	cancel.name = "ConfirmCancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(cancel)
	items_panel = _drag_window(root)
	items_box = _vbox(items_panel, 4)


	overlay = PanelContainer.new()
	overlay.visible = false
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 8)
	overlay_box.custom_minimum_size = Vector2(460, 0)
	overlay.add_child(overlay_box)
	overlay_ctrl.build_menu_extras(root)


func set_account(acc: Account) -> void:
	overlay_ctrl.set_account(acc)


func _input(event: InputEvent) -> void:
	if splash != null and splash.visible:
		var press: bool = (event is InputEventKey and event.pressed and not event.echo) \
or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
		if press:
			pass
			splash.visible = false
			splash_done.emit()


func _window(parent: Control, preset: int) -> Array:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 10)
	var holder := VBoxContainer.new()
	panel.add_child(holder)
	return [panel, holder]


func _drag_window(parent: Control) -> DragPanel:
	var p := DragPanel.new()
	p.visible = false
	parent.add_child(p)
	return p


func _vbox(parent: Control, sep: int) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _rich(width: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _button(text: String, cb: Callable, focusable := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _focus_first() -> void:
	for b in overlay_box.find_children("*", "Button", true, false):
		if not (b as Button).disabled:
			(b as Button).grab_focus()
			return


func _place(panel: Control, want: Vector2, view_size: Vector2) -> void:
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.position = Vector2(clampf(want.x, 4.0, maxf(4.0, view_size.x - sz.x - 4.0)),
			clampf(want.y, 4.0, maxf(4.0, view_size.y - sz.y - 4.0)))
	panel.visible = true


func show_game_hud(on: bool) -> void:
	_game_on = on
	if on:
		menu_bg.visible = false
		splash.visible = false
		overlay_ctrl.set_menu_chrome(false)
	for n in _game_nodes:
		n.visible = on
	_order_window.visible = on and order_box.get_child_count() > 0


func set_unit_info(head_bbcode: String, hp: int, max_hp: int, stats_bbcode: String, face: Texture2D,
		hp_color := Color(0, 0, 0, 0), mp := 0, max_mp := 0) -> void:
	info_head.text = head_bbcode
	hp_bar.fill_color = hp_color
	hp_bar.ratio = float(hp) / maxf(1.0, float(max_hp))
	hp_text.text = "%d/%d" % [hp, max_hp]
	mp_bar.ratio = float(mp) / maxf(1.0, float(max_mp))
	mp_text.text = "MP %d/%d" % [mp, max_mp]
	info_label.text = stats_bbcode
	_portrait_rect.texture = face
	portrait_slot.visible = face != null


func set_action_bar(remaining: float, spent: float) -> void:
	ap_bar.ratio = remaining
	ap_bar.ghost = spent
	ap_text.text = "Ação %d%%" % int(round(remaining * 100.0)) + (("  (gastou %d%%)" % int(round(spent * 100.0))) if spent > 0.0 else "")


func clear_unit_info() -> void:
	info_head.text = ""
	info_label.text = ""
	hp_text.text = ""
	mp_text.text = ""
	ap_text.text = ""
	ap_bar.ratio = 0.0
	ap_bar.ghost = 0.0
	mp_bar.ratio = 0.0
	hp_bar.ratio = 0.0
	_portrait_rect.texture = null
	portrait_slot.visible = false


func set_order_items(items: Array) -> void:
	_clear(order_box)
	_order_window.visible = _game_on and not items.is_empty()
	for it in items:
		var slot := PanelContainer.new()
		var frame := UITheme.portrait_frame()
		slot.add_theme_stylebox_override("panel", frame)
		slot.custom_minimum_size = Vector2(56, 56)
		slot.modulate = Color(1, 1, 1, 1) if bool(it["current"]) or bool(it["switchable"]) else Color(1, 1, 1, 0.85)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(44, 44)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(holder)
		var face := TextureRect.new()
		face.texture = it["face"]
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(face)
		var team_color: Color = TEAM_COLORS[int(it["team"])]
		var bar := ColorRect.new()
		bar.color = team_color
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 5)
		bar.offset_top = -5
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bar)
		var num := Label.new()
		num.text = str(it["number"])
		num.add_theme_font_override("font", UITheme.bold_font)
		num.add_theme_font_size_override("font_size", 18)
		num.add_theme_color_override("font_color", UITheme.GOLD if bool(it["current"]) else UITheme.CREAM)
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		num.add_theme_constant_override("outline_size", 5)
		num.position = Vector2(2, -2)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(num)
		if bool(it["switchable"]):
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.tooltip_text = "Alternar para este personagem"
			var uid := int(it["id"])
			slot.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					order_clicked.emit(uid))
			var glow := ColorRect.new()
			glow.color = Color(1, 0.85, 0.3, 0.0)
			holder.add_child(glow)
			glow.set_anchors_preset(Control.PRESET_FULL_RECT)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.self_modulate = Color(1.3, 1.2, 0.8)
		order_box.add_child(slot)


func set_hint(text: String) -> void:
	hint_label.text = text
	hint_panel.visible = _game_on and text != ""
	hint_panel.reset_size()


func add_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	log_label.text = "\n".join(_log_lines)


func clear_log() -> void:
	_log_lines.clear()
	log_label.text = ""


func show_context_menu(title: String, items: Array, screen_pos: Vector2, view_size: Vector2, face: Texture2D = null) -> void:
	popup_ctrl.show_context_menu(title, items, screen_pos, view_size, face)


func move_context_menu(screen_pos: Vector2, view_size: Vector2) -> void:
	popup_ctrl.move_context_menu(screen_pos, view_size)


func hide_context_menu() -> void:
	popup_ctrl.hide_context_menu()


func show_target_window(data: Dictionary, actions: Array, view_size: Vector2) -> void:
	popup_ctrl.show_target_window(data, actions, view_size)


func hide_target_window() -> void:
	popup_ctrl.hide_target_window()


func show_confirm(text_bbcode: String, view_size: Vector2) -> void:
	popup_ctrl.show_confirm(text_bbcode, view_size)


func hide_confirm() -> void:
	popup_ctrl.hide_confirm()


func confirm_visible() -> bool:
	return popup_ctrl.confirm_visible()


func show_items_window(title: String, summary: String, rows: Array, view_size: Vector2, face: Texture2D = null) -> void:
	popup_ctrl.show_items_window(title, summary, rows, view_size, face)


func hide_items_window() -> void:
	popup_ctrl.hide_items_window()


func any_popup_visible() -> bool:
	return popup_ctrl.any_popup_visible()


func hide_popups() -> void:
	popup_ctrl.hide_popups()

func show_splash() -> void:
	overlay_ctrl.show_splash()


func show_menu() -> void:
	overlay_ctrl.show_menu()


func show_options(values: Dictionary) -> void:
	overlay_ctrl.show_options(values)


func show_online_menu() -> void:
	overlay_ctrl.show_online_menu()


func show_waiting(title: String, bbcode: String) -> void:
	overlay_ctrl.show_waiting(title, bbcode)


func show_message(title: String, bbcode: String) -> void:
	overlay_ctrl.show_message(title, bbcode)


func show_end(title: String, bbcode: String) -> void:
	overlay_ctrl.show_end(title, bbcode)


func hide_overlay() -> void:
	overlay_ctrl.hide_overlay()
