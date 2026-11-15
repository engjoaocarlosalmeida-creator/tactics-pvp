extends Node
class_name MatchInputController

signal command_requested(cmd: Dictionary)
signal refresh_requested

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")

var game_view_ref


func setup(gv) -> void:
    game_view_ref = gv


func click_tile(p: Vector2i, _screen_pos: Vector2 = Vector2(40, 40)) -> bool:
    var gv = game_view_ref
    if gv.m == null or gv.m.is_over() or gv.busy > 0 or gv.hud.confirm_visible() or gv.screen != null:
        return false
    var special: int = gv._click_special(p)
    if special != 0:
        return special > 0
    gv.selected_tile = p
    gv.overlay_renderer.update_click_marker()
    gv.hud.hide_context_menu()
    gv.hud.hide_target_window()
    gv.hud.hide_items_window()
    if gv.mode_pending != "" and gv._human_turn():
        var u: Unit = gv.m.active
        if gv.mode_pending == "move" and gv.move_tiles.has(p):
            preview_move(p)
            return true
        if gv.mode_pending == "attack" and gv.attack_area.has(p):
            var t: Unit = gv._unit_at(p)
            var text := "Atacar a casa (%d, %d)?\nNão há ninguém lá." % [p.x, p.y]
            var cmd := {"t": "attack", "unit": u.id, "x": p.x, "y": p.y}
            if t != null:
                text = gv._attack_text(u, t) + ("\n[color=#ffaa33]É um aliado![/color]" if t.team == u.team else "")
                cmd = {"t": "attack", "unit": u.id, "target": t.id}
            ask_confirm(text, func(): command_requested.emit(cmd))
            return true
        gv.mode_pending = ""
        gv.hud.set_hint("")
        gv.menu_wanted = true
        refresh_requested.emit()
        return false
    var target: Unit = gv._unit_at(p)
    if target == gv.m.active:
        gv.menu_wanted = true
        refresh_requested.emit()
        return true
    if target != null and target.team == gv.m.active.team:
        if gv._human_turn() and not gv.m.active.moved and not gv.m.active.acted and gv.m.ready_alternates(gv.m.active).has(target) \
                and gv.m.has_actions(target):
            gv.menu_wanted = true
            gv.camera_rig.trigger_follow()
            command_requested.emit({"t": "switch", "unit": gv.m.active.id, "to": target.id})
        return false
    gv.menu_wanted = false
    if target != null:
        gv.hud_presenter.open_target_window(target)
    refresh_requested.emit()
    return true

func preview_move(p: Vector2i) -> void:
    var gv = game_view_ref
    var u: Unit = gv.m.active
    var path := Pathing.path_to(gv.m.reachable_for(u), p)
    gv.preview = {"unit": u, "from": u.pos, "to": p}
    var n: Node3D = gv.unit_nodes[u.id]
    var ask := func(): ask_confirm(gv._move_text(u, p), func(): commit_preview())
    if not gv.animate:
        n.position = MapGeometry.tile_pos(gv.m.map, p)
        ask.call()
        return
    gv.game_visual_presenter._animate_unit_path(u, path, ask)


func commit_preview() -> void:
    var gv = game_view_ref
    if gv.preview.is_empty():
        return
    var u: Unit = gv.preview["unit"]
    var to: Vector2i = gv.preview["to"]
    gv.game_visual_presenter.committing_unit = u.id
    gv.preview = {}
    command_requested.emit({"t": "move", "unit": u.id, "x": to.x, "y": to.y})
    gv.game_visual_presenter.committing_unit = -1


func cancel_preview() -> void:
    var gv = game_view_ref
    if gv.preview.is_empty():
        return
    var u: Unit = gv.preview["unit"]
    var node: Node3D = gv.unit_nodes[u.id]
    node.position = MapGeometry.tile_pos(gv.m.map, gv.preview["from"])
    CHARACTER_MODEL.play_animation(node.get_node("Body"), "Idle")
    CHARACTER_MODEL.set_facing(node.get_node("Body"), u.facing)
    gv.preview = {}


func ask_confirm(text: String, action: Callable) -> void:
    var gv = game_view_ref
    gv.pending_confirm = action
    gv.hud.hide_context_menu()
    gv.hud.set_hint("")
    gv.hud.show_confirm(text, gv.get_viewport().get_visible_rect().size)


func confirm_accept() -> void:
    var gv = game_view_ref
    var action: Callable = gv.pending_confirm
    gv.pending_confirm = Callable()
    gv.hud.hide_confirm()
    gv.mode_pending = ""
    if action.is_valid():
        action.call()


func confirm_reject() -> void:
    var gv = game_view_ref
    gv.pending_confirm = Callable()
    gv.hud.hide_confirm()
    cancel_preview()
    if gv.mode_pending == "":
        gv.menu_wanted = true
    refresh_requested.emit()


func choose(id: String) -> bool:
    var gv = game_view_ref
    if gv.m == null or gv.m.is_over():
        return false
    if id == "stand":
        if not gv._human_turn() or not gv.m.active.down or gv.m.active.moved:
            return false
        gv.hud.hide_context_menu()
        var act: Unit = gv.m.active
        ask_confirm("Levantar [b]%s[/b]?\n(gasta a ação de movimento)" % act.display_name, func(): command_requested.emit({"t": "stand", "unit": act.id}))
        return true
    return gv._choose_base(id)


func cancel_all() -> void:
    var gv = game_view_ref
    if gv.hud.confirm_visible():
        confirm_reject()
        return
    if gv.m != null and not gv.m.pending_reaction.is_empty():
        var o: Unit = gv.m.pending_unit()
        if o != null and gv._owner_human(o):
            command_requested.emit({"t": "react_skip", "unit": o.id})
        return
    if gv.m != null and gv.m.awaiting_facing and gv._owner_human(gv.m.active):
        command_requested.emit({"t": "face", "unit": gv.m.active.id, "dir": maxi(0, BattleMap.DIRS.find(gv.m.active.facing))})
        return
    cancel_preview()
    gv.hud.hide_popups()
    if gv.mode_pending != "":
        gv.mode_pending = ""
        gv.hud.set_hint("")
        gv.menu_wanted = true
        refresh_requested.emit()
    else:
        gv.menu_wanted = true


func wait() -> void:
    var gv = game_view_ref
    if gv._human_turn() and not gv.hud.confirm_visible():
        choose("end_turn")


func _unhandled_input(event: InputEvent) -> void:
    var gv = game_view_ref
    if gv == null:
        return
    if gv.m != null and gv.m.awaiting_facing and gv.screen == null and event is InputEventKey and event.pressed and not event.echo \
            and gv._owner_human(gv.m.active) and not event.shift_pressed:
        var sd := Vector2.ZERO
        match event.keycode:
            KEY_LEFT, KEY_A:
                sd = Vector2(-1, 0)
            KEY_RIGHT, KEY_D:
                sd = Vector2(1, 0)
            KEY_UP, KEY_W:
                sd = Vector2(0, -1)
            KEY_DOWN, KEY_S:
                sd = Vector2(0, 1)
            KEY_ENTER, KEY_SPACE, KEY_ESCAPE:
                cancel_all()
                return
        if sd != Vector2.ZERO:
            command_requested.emit({"t": "face", "unit": gv.m.active.id, "dir": gv._dir_from_screen(sd)})
            return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if gv.screen != null:
            cancel_all()
        elif gv.m != null:
            gv.game_pause_controller.toggle_pause()
        return
    if gv.m == null or gv.screen != null:
        return
    if event is InputEventMouseButton and event.pressed:
        match event.button_index:
            MOUSE_BUTTON_RIGHT:
                cancel_all()
            MOUSE_BUTTON_LEFT:
                var p: Vector2i = gv.pick_at(event.position)
                if p != Picking.NONE:
                    click_tile(p, event.position)
                else:
                    cancel_all()
    elif event is InputEventMouseMotion:
        if not (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
            gv.overlay_renderer.set_hover(gv.pick_at(event.position))
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.shift_pressed and (event.keycode == KEY_RIGHT or event.keycode == KEY_LEFT):
            gv._cycle_actor(1 if event.keycode == KEY_RIGHT else -1)
        elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            wait()
        elif event.keycode == KEY_ESCAPE:
            cancel_all()
