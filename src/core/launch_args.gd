class_name LaunchArgs


static func parse_cmdline() -> Dictionary:
    var args := {}
    for a in OS.get_cmdline_user_args():
        var kv := a.trim_prefix("--").split("=", true, 1)
        args[kv[0]] = kv[1] if kv.size() > 1 else "true"
    return args


static func apply_to_view(gv, args: Dictionary) -> void:
    gv.auto_play = args.has("auto-play")
    gv.quit_on_end = args.has("quit-on-end")
    gv.quit_after_turns = int(args.get("quit-after-turns", 0))
    gv.report_path = args.get("report", "")
    if args.has("fast") or args.has("shot"):
        gv.animate = false
    gv._shot_path = args.get("shot", "")
    if args.has("give-xp"):
        for c in gv.roster.characters:
            c.add_xp(gv.rules, gv.catalog, int(args["give-xp"]))
    if args.has("focus"):
        gv._focus_arg = str(args["focus"])
    if args.has("cam"):
        var cv := str(args["cam"]).split(",")
        gv.yaw = float(cv[0])
        gv.pitch = float(cv[1])
        gv.distance = float(cv[2])
    var seed_arg := int(args.get("seed", -1))
    var port := int(args.get("port", NetSession.DEFAULT_PORT))
    if args.get("net", "") == "host":
        gv.net.forced_seed = seed_arg
        gv.net_bridge.start_host(port)
    elif args.get("net", "") == "join":
        gv.net_bridge.start_join(args.get("ip", "127.0.0.1"), port)
    elif args.has("open"):
        gv.open_screen(str(args["open"]))
    else:
        var autostart_mode: int = {"local": gv.Mode.LOCAL, "cpu": gv.Mode.VS_CPU, "demo": gv.Mode.DEMO}.get(args.get("mode", ""), -1)
        if autostart_mode >= 0:
            gv.start_match(autostart_mode, seed_arg)
            if args.has("bot-turns"):
                var previous_animate: bool = gv.animate
                gv.animate = false
                for i in int(args["bot-turns"]):
                    if gv.m == null or gv.m.is_over():
                        break
                    SimpleBot.take_turn(gv.m, gv.bot_rng)
                gv.animate = previous_animate
                gv._try_refresh()
            if args.has("click-unit") and gv.m != null and not gv.m.is_over():
                gv.click_tile(gv.m.units[int(args["click-unit"])].pos, Vector2(700, 300))
            if args.has("confirm-demo") and gv.m != null and not gv.m.is_over():
                var dest: Vector2i = gv.move_tiles.keys()[0] if not gv.move_tiles.is_empty() else gv.m.active.pos
                gv.choose("move_mode")
                gv.click_tile(dest)
        else:
            gv.screen_router.show_menu(not args.has("no-splash"))