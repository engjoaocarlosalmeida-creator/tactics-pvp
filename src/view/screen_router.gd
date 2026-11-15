extends Node
class_name ScreenRouter

var game_view_ref


func setup(gv) -> void:
    game_view_ref = gv


func open_screen(kind: String) -> void:
    var gv = game_view_ref
    close_screen()
    gv.hud.hide_overlay()

    var new_screen
    match kind:
        "team":
            new_screen = TeamScreen.new()
        "classes":
            new_screen = ClassScreen.new()
        "items":
            new_screen = ItemsScreen.new()
        "account":
            new_screen = AccountScreen.new()
            new_screen.account = gv.account
        "wiki":
            new_screen = WikiScreen.new()
        _:
            show_menu()
            return

    gv.screen = new_screen
    gv.add_child(gv.screen)
    gv.screen.setup(gv.rules, gv.catalog, gv.roster)
    if gv.screen.has_signal("changed"):
        gv.screen.changed.connect(save_roster)
    if gv.screen.has_signal("open_other"):
        gv.screen.open_other.connect(func(k, char_index): open_from_screen(k, char_index))
    gv.screen.closed.connect(func():
        close_screen()
        show_menu())


func open_from_screen(kind: String, char_index: int) -> void:
    var gv = game_view_ref
    open_screen(kind)
    if gv.screen != null and gv.screen.has_method("focus_character"):
        gv.screen.focus_character(char_index)


func close_screen() -> void:
    var gv = game_view_ref
    if gv.screen != null:
        gv.remove_child(gv.screen)
        gv.screen.queue_free()
        gv.screen = null


func save_roster() -> void:
    var gv = game_view_ref
    if not gv.test_mode or gv.save_in_test:
        gv.roster.save(gv.roster_path)
    save_account()


func save_account() -> void:
    var gv = game_view_ref
    if not gv.test_mode or gv.save_in_test:
        gv.account.save(gv.account_path)


func show_menu(with_splash := false) -> void:
    var gv = game_view_ref
    gv.net.close()
    gv.awaiting = false
    gv._clear_world()
    gv.m = null
    gv.hud.hide_popups()
    gv.hud.clear_unit_info()
    gv.hud.set_order_items([])
    gv.hud.set_hint("")
    gv.hud.clear_log()
    gv.hud.show_game_hud(false)
    gv.hud.set_account(gv.account)
    if with_splash:
        gv.hud.show_splash()
    else:
        gv.hud.show_menu()


func options_values() -> Dictionary:
    var s: Settings = game_view_ref.settings
    return {"display_mode": Settings.MODE_NAMES[s.display_mode], "resolution": s.resolution_text(),
            "can_resize": s.display_mode == Settings.MODE_WINDOW, "volume": s.volume}


func show_options() -> void:
    game_view_ref.hud.show_options(options_values())


func on_option_changed(key: String, delta: int) -> void:
    var gv = game_view_ref
    var screen_size := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i(1920, 1080)
    gv.settings.change(key, delta, screen_size)
    if not gv.test_mode:
        gv.settings.save()
        gv.settings.apply_to_window()
    gv.hud.show_options(options_values())
