## Interface: painel do personagem, fila de turnos, log, menu de acoes pequeno, janela do alvo,
## confirmacao, itens, tela de abertura, menu so de textos, conta, icones, wiki, opcoes.
class_name Hud
extends CanvasLayer

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")

signal menu_choice(mode: int)
signal restart_pressed
signal menu_pressed
signal quit_pressed
signal menu_item_chosen(id: String)
signal confirm_ok
signal confirm_cancel
signal order_clicked(unit_id: int)
signal team_requested
signal splash_done
signal account_requested
signal wiki_requested
signal options_requested
signal option_changed(key: String, delta: int)
signal items_requested
signal host_requested
signal join_requested(address: String)

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


func _ready() -> void :
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	menu_bg = UITheme.background(0.18)
	menu_bg.visible = false
	root.add_child(menu_bg)


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
	_build_menu_extras(root)




func _build_menu_extras(root: Control) -> void :
	account_panel = PanelContainer.new()
	account_panel.visible = false
	account_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.add_child(account_panel)
	account_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	account_panel.gui_input.connect( func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			account_requested.emit())
	wiki_button = TextureButton.new()
	wiki_button.name = "WikiButton"
	wiki_button.texture_normal = UIIcons.get_icon("help")
	wiki_button.ignore_texture_size = true
	wiki_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	wiki_button.custom_minimum_size = Vector2(44, 44)
	wiki_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wiki_button.tooltip_text = "Wiki: regras e mecânicas"
	wiki_button.visible = false
	wiki_button.pressed.connect( func(): wiki_requested.emit())
	root.add_child(wiki_button)
	wiki_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	wiki_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var holder := VBoxContainer.new()
	holder.visible = false
	holder.name = "MenuIcons"
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu_icons = HBoxContainer.new()
	menu_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_icons.add_theme_constant_override("separation", 26)
	holder.add_child(menu_icons)
	menu_icon_label = Label.new()
	menu_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_icon_label.add_theme_font_override("font", UITheme.title_font)
	menu_icon_label.add_theme_font_size_override("font_size", 20)
	menu_icon_label.add_theme_color_override("font_color", UITheme.GOLD)
	menu_icon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	menu_icon_label.add_theme_constant_override("outline_size", 6)
	menu_icon_label.custom_minimum_size = Vector2(0, 26)
	holder.add_child(menu_icon_label)
	for spec in [["items", "Itens", "items", items_requested], ["team", "Personalizar time", "class_escudeiro", team_requested]]:
		var b := TextureButton.new()
		b.name = "Icon_" + spec[0]
		b.texture_normal = UIIcons.get_icon(spec[2])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(72, 72)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.tooltip_text = spec[1]
		var label_text: String = spec[1]
		var sig: Signal = spec[3]
		b.mouse_entered.connect( func():
			menu_icon_label.text = label_text
			b.modulate = Color(1.3, 1.2, 0.8))
		b.mouse_exited.connect( func():
			menu_icon_label.text = ""
			b.modulate = Color.WHITE)
		b.pressed.connect( func(): sig.emit())
		menu_icons.add_child(b)
	splash = Control.new()
	splash.visible = false
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(splash)
	var sbox := VBoxContainer.new()
	sbox.set_anchors_preset(Control.PRESET_CENTER)
	sbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	sbox.add_theme_constant_override("separation", 40)
	splash.add_child(sbox)
	var big := UITheme.title("TACTICS PVP", 86)
	big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	big.add_theme_constant_override("outline_size", 14)
	sbox.add_child(big)
	var press := Label.new()
	press.name = "PressAnyKey"
	press.text = "Pressione qualquer tecla para iniciar"
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.add_theme_font_size_override("font_size", 26)
	press.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	press.add_theme_constant_override("outline_size", 8)
	sbox.add_child(press)
	var tw := create_tween().set_loops()
	tw.tween_property(press, "modulate:a", 0.25, 0.9)
	tw.tween_property(press, "modulate:a", 1.0, 0.9)



func set_account(acc: Account) -> void :
	for c in account_panel.get_children():
		account_panel.remove_child(c)
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(AccountScreen.avatar_frame(acc, 1))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	var name_l := RichTextLabel.new()
	name_l.bbcode_enabled = true
	name_l.fit_content = true
	name_l.scroll_active = false
	name_l.custom_minimum_size = Vector2(190, 0)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.text = "[b]%s[/b] [img=14]res://assets/icons/sex_%s.png[/img]" % [acc.player_name, acc.sex]
	col.add_child(name_l)
	var t := Label.new()
	t.text = acc.title_name()
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", UITheme.DIM)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var rk := Label.new()
	rk.text = acc.rank_name()
	rk.add_theme_font_size_override("font_size", 16)
	rk.add_theme_color_override("font_color", UITheme.GOLD)
	rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rk)
	row.add_child(col)
	account_panel.add_child(row)


func _set_menu_chrome(on: bool) -> void :
	account_panel.visible = on
	wiki_button.visible = on
	menu_icons.get_parent().visible = on
	if not on:
		menu_icon_label.text = ""


func _input(event: InputEvent) -> void :
	if splash != null and splash.visible:
		var press: bool = (event is InputEventKey and event.pressed and not event.echo)\
or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
		if press:
			get_viewport().set_input_as_handled()
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


func _clear(box: Control) -> void :
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



func _focus_first() -> void :
	for b in overlay_box.find_children("*", "Button", true, false):
		if not (b as Button).disabled:
			(b as Button).grab_focus()
			return


func _place(panel: Control, want: Vector2, view_size: Vector2) -> void :
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.position = Vector2(clampf(want.x, 4.0, maxf(4.0, view_size.x - sz.x - 4.0)), 
			clampf(want.y, 4.0, maxf(4.0, view_size.y - sz.y - 4.0)))
	panel.visible = true



func show_game_hud(on: bool) -> void :
	_game_on = on
	if on:
		menu_bg.visible = false
		splash.visible = false
		_set_menu_chrome(false)
	for n in _game_nodes:
		n.visible = on
	_order_window.visible = on and order_box.get_child_count() > 0




func set_unit_info(head_bbcode: String, hp: int, max_hp: int, stats_bbcode: String, face: Texture2D, 
		hp_color := Color(0, 0, 0, 0), mp := 0, max_mp := 0) -> void :
	info_head.text = head_bbcode
	hp_bar.fill_color = hp_color
	hp_bar.ratio = float(hp) / maxf(1.0, float(max_hp))
	hp_text.text = "%d/%d" % [hp, max_hp]
	mp_bar.ratio = float(mp) / maxf(1.0, float(max_mp))
	mp_text.text = "MP %d/%d" % [mp, max_mp]
	info_label.text = stats_bbcode
	_portrait_rect.texture = face
	portrait_slot.visible = face != null



func set_action_bar(remaining: float, spent: float) -> void :
	ap_bar.ratio = remaining
	ap_bar.ghost = spent
	ap_text.text = "Ação %d%%" % int(round(remaining * 100.0)) + (("  (gastou %d%%)" % int(round(spent * 100.0))) if spent > 0.0 else "")


func clear_unit_info() -> void :
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



func set_order_items(items: Array) -> void :
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
		var team_color: Color = GameView.TEAM_COLORS[int(it["team"])]
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
			slot.gui_input.connect( func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					order_clicked.emit(uid))
			var glow := ColorRect.new()
			glow.color = Color(1, 0.85, 0.3, 0.0)
			holder.add_child(glow)
			glow.set_anchors_preset(Control.PRESET_FULL_RECT)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.self_modulate = Color(1.3, 1.2, 0.8)
		order_box.add_child(slot)


func set_hint(text: String) -> void :
	hint_label.text = text
	hint_panel.visible = _game_on and text != ""
	hint_panel.reset_size()


func add_log(line: String) -> void :
	_log_lines.append(line)
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	log_label.text = "\n".join(_log_lines)


func clear_log() -> void :
	_log_lines.clear()
	log_label.text = ""




func _header(title: String, face: Texture2D, sex := "", small := false) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face != null:
		head.add_child(UITheme.pixel_image(face, 1))
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", UITheme.title_font if not small else UITheme.body_font)
	t.add_theme_font_size_override("font_size", 22 if not small else 10)
	t.add_theme_color_override("font_color", UITheme.GOLD if not small else UITheme.DIM)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)
	if sex != "":
		head.add_child(UITheme.pixel_image(UIIcons.get_icon("sex_" + sex), 1))
	return head



func show_context_menu(title: String, items: Array, screen_pos: Vector2, view_size: Vector2, _face: Texture2D = null) -> void :
	hide_context_menu()
	context_panel.draggable = false
	context_panel.add_theme_stylebox_override("panel", UITheme.small_window())
	if title != "":
		context_box.add_child(_header(title, null, "", true))
	for it in items:
		var b := Button.new()
		b.text = str(it["label"])
		b.disabled = not bool(it["enabled"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(96, 0)
		UITheme.compact(b, 2)
		var id := str(it["id"])
		b.pressed.connect( func(): menu_item_chosen.emit(id))
		context_box.add_child(b)
		context_ids.append(id)
	_place(context_panel, screen_pos, view_size)



func move_context_menu(screen_pos: Vector2, view_size: Vector2) -> void :
	if not context_panel.visible:
		return
	var sz := context_panel.size
	context_panel.position = Vector2(clampf(screen_pos.x, 2.0, maxf(2.0, view_size.x - sz.x - 2.0)), 
			clampf(screen_pos.y, 2.0, maxf(2.0, view_size.y - sz.y - 2.0)))


func hide_context_menu() -> void :
	_clear(context_box)
	context_ids.clear()
	context_panel.visible = false



func show_target_window(data: Dictionary, actions: Array, view_size: Vector2) -> void :
	hide_target_window()
	target_box.add_child(_header(str(data["title"]), null, str(data.get("sex", ""))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_box.add_child(row)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UITheme.portrait_frame())
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(128, 160)
	stage.add_child(CHARACTER_MODEL.create_preview(
			CHARACTER_MODEL.team_color(int(data["team"])), Vector2i(128, 160)))
	row.add_child(stage)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var info := _rich(230)
	info.text = str(data["text"])
	col.add_child(info)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := HpBar.new()
	bar.custom_minimum_size = Vector2(140, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.ratio = float(data["hp"]) / maxf(1.0, float(data["max_hp"]))
	hp_row.add_child(bar)
	var hp_l := Label.new()
	hp_l.text = "%d/%d" % [data["hp"], data["max_hp"]]
	hp_l.add_theme_font_size_override("font_size", 16)
	hp_row.add_child(hp_l)
	col.add_child(hp_row)
	var stats := _rich(230)
	stats.text = str(data["stats"])
	col.add_child(stats)
	context_ids.clear()
	for it in actions:
		var b := Button.new()
		b.text = str(it["label"])
		b.disabled = not bool(it["enabled"])
		b.focus_mode = Control.FOCUS_NONE
		var id := str(it["id"])
		b.pressed.connect( func(): menu_item_chosen.emit(id))
		target_box.add_child(b)
		context_ids.append(id)
	_place(target_panel, Vector2(view_size.x * 0.5 - 40.0, 90.0), view_size)


func hide_target_window() -> void :
	_clear(target_box)
	target_panel.visible = false


func show_confirm(text_bbcode: String, view_size: Vector2) -> void :
	confirm_label.text = text_bbcode
	_place(confirm_panel, Vector2(view_size.x * 0.5 - 190.0, view_size.y * 0.5 - 90.0), view_size)


func hide_confirm() -> void :
	confirm_panel.visible = false


func confirm_visible() -> bool:
	return confirm_panel.visible



func show_items_window(title: String, summary: String, rows: Array, view_size: Vector2, face: Texture2D = null) -> void :
	hide_items_window()
	items_box.add_child(_header(title, face))
	var s := _rich(300)
	s.text = summary
	items_box.add_child(s)
	if rows.is_empty():
		var l := Label.new()
		l.text = "Nenhum item."
		items_box.add_child(l)
	for r in rows:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.add_child(UITheme.pixel_image(UIIcons.get_icon(str(r.get("icon", "items"))), 1))
		var n := Label.new()
		n.text = str(r["name"])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(n)
		var w := Label.new()
		w.text = "peso %d" % int(r["weight"])
		w.add_theme_color_override("font_color", UITheme.DIM)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(w)
		items_box.add_child(row)
	items_box.add_child(_button("Fechar", func(): menu_item_chosen.emit("items_close")))
	_place(items_panel, Vector2(view_size.x * 0.5 - 160.0, 120.0), view_size)


func hide_items_window() -> void :
	_clear(items_box)
	items_panel.visible = false


func any_popup_visible() -> bool:
	return context_panel.visible or target_panel.visible or confirm_panel.visible or items_panel.visible


func hide_popups() -> void :
	hide_context_menu()
	hide_target_window()
	hide_confirm()
	hide_items_window()




func _clear_overlay() -> void :
	_clear(overlay_box)
	overlay.remove_theme_stylebox_override("panel")
	_set_menu_chrome(false)
func show_splash() -> void :
	_clear_overlay()
	overlay.visible = false
	menu_bg.visible = true
	splash.visible = true



func show_menu() -> void :
	_clear_overlay()
	splash.visible = false
	menu_bg.visible = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.12, 0.42)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	overlay.add_theme_stylebox_override("panel", sb)
	overlay_box.custom_minimum_size = Vector2(420, 0)
	var entries := [
		["2 jogadores (mesmo PC)", func(): menu_choice.emit(GameView.Mode.LOCAL)], 
		["Jogar contra o computador", func(): menu_choice.emit(GameView.Mode.VS_CPU)], 
		["Computador x computador", func(): menu_choice.emit(GameView.Mode.DEMO)], 
		["Jogar online", show_online_menu], 
		["Opções", func(): options_requested.emit()], 
		["Sair", func(): quit_pressed.emit()], 
	]
	for e in entries:
		var b := UITheme.menu_text(str(e[0]), 26)
		b.pressed.connect(e[1])
		overlay_box.add_child(b)
	overlay.visible = true
	_set_menu_chrome(true)
	_focus_first.call_deferred()



func show_options(values: Dictionary) -> void :
	_clear_overlay()
	menu_bg.visible = not _game_on
	overlay_box.add_child(UITheme.title("OPÇÕES", 30))
	overlay_box.add_child(_button("Modo de tela: %s" % values["display_mode"], func(): option_changed.emit("display_mode", 0)))
	var res := _button("Resolução da janela: %s" % values["resolution"], func(): option_changed.emit("resolution", 0))
	res.disabled = not values["can_resize"]
	overlay_box.add_child(res)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var minus := _button("−", func(): option_changed.emit("volume", -1))
	minus.custom_minimum_size = Vector2(60, 38)
	row.add_child(minus)
	var vol := Label.new()
	vol.text = "Volume geral: %d%%" % int(round(float(values["volume"]) * 100.0))
	vol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vol)
	var plus := _button("+", func(): option_changed.emit("volume", 1))
	plus.custom_minimum_size = Vector2(60, 38)
	row.add_child(plus)
	overlay_box.add_child(row)
	overlay_box.add_child(_button("Voltar", func(): menu_pressed.emit()))
	overlay.visible = true
	_focus_first.call_deferred()


func show_online_menu() -> void :
	_clear_overlay()
	menu_bg.visible = not _game_on
	overlay_box.add_child(UITheme.title("JOGAR ONLINE", 28))
	overlay_box.add_child(_button("Hospedar uma partida", func(): host_requested.emit()))
	var edit := LineEdit.new()
	edit.name = "IpEdit"
	edit.text = "127.0.0.1"
	edit.placeholder_text = "IP de quem hospeda"
	edit.custom_minimum_size = Vector2(0, 38)
	overlay_box.add_child(edit)
	overlay_box.add_child(_button("Entrar na partida desse IP", func(): join_requested.emit(edit.text.strip_edges())))
	overlay_box.add_child(_button("Voltar", func(): menu_pressed.emit()))
	overlay.visible = true
	_focus_first.call_deferred()


func show_waiting(title: String, bbcode: String) -> void :
	_clear_overlay()
	menu_bg.visible = not _game_on
	overlay_box.add_child(UITheme.title(title.to_upper(), 24))
	var body := _rich(460)
	body.text = bbcode
	overlay_box.add_child(body)
	overlay_box.add_child(_button("Cancelar", func(): menu_pressed.emit()))
	overlay.visible = true


func show_message(title: String, bbcode: String) -> void :
	_clear_overlay()
	menu_bg.visible = not _game_on
	overlay_box.add_child(UITheme.title(title.to_upper(), 24))
	var body := _rich(460)
	body.text = bbcode
	overlay_box.add_child(body)
	overlay_box.add_child(_button("Voltar ao menu", func(): menu_pressed.emit()))
	overlay.visible = true


func show_end(title: String, bbcode: String) -> void :
	_clear_overlay()
	menu_bg.visible = false
	overlay_box.add_child(UITheme.title(title.to_upper(), 28))
	var body := _rich(460)
	body.text = bbcode
	overlay_box.add_child(body)
	overlay_box.add_child(_button("Revanche (nova partida)", func(): restart_pressed.emit()))
	overlay_box.add_child(_button("Voltar ao menu", func(): menu_pressed.emit()))
	overlay.visible = true


func hide_overlay() -> void :
	overlay.visible = false
	menu_bg.visible = false
