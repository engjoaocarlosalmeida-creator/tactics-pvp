extends TestCase

func test_rules_tem_todas_as_chaves() -> void:
    var r := Rules.load_default()
    var required := {
        "match": ["units_per_team", "max_turns"],
        "map": ["width", "depth", "max_height", "spawn_zone", "spawn_buffer",
                "noise_frequency", "slippery_noise_threshold", "blocked_chance"],
        "unit_defaults": ["hp", "atk", "defense", "speed", "mp"],
        "movement": ["base_move", "base_jump", "safe_fall", "fall_damage_percent_per_level",
                "climb_extra_cost_per_level"],
        "turn": ["ct_threshold", "cost_move", "cost_attack", "cost_wait", "tie_die", "auto_end"],
        "progression": ["job_xp_thresholds", "char_xp_base", "max_char_level", "xp_per_attack", "xp_per_kill",
                "xp_mod_cap_percent", "xp_flag_percent"],
        "items": ["capacity_base", "capacity_per_forca", "free_fraction", "step_fraction", "max_overload"],
        "reactions": ["dodge_base", "parry_base", "block_base", "oa_base", "per_point", "min", "max", "front_bonus_pct",
                "flank_penalty_pct", "back_penalty_pct", "second_ratio", "second_chance", "extra_move"],
        "combat": ["attack_range", "height_tolerance", "height_damage_bonus_per_level", "min_damage"],
    }
    for section in required:
        check(r.data.has(section), "falta secao " + section)
        if r.data.has(section):
            for key in required[section]:
                check(r.data[section].has(key), "falta chave %s.%s" % [section, key])


func test_config_cabe_no_mapa() -> void:
    var r := Rules.load_default()
    var d := r.get_int("map", "depth")
    var zone := r.get_int("map", "spawn_zone") + r.get_int("map", "spawn_buffer")
    check(d >= zone * 2, "mapa precisa ser fundo o bastante para as duas zonas de inicio")
    check(r.get_int("map", "spawn_zone") * r.get_int("map", "spawn_zone") >= r.get_int("match", "units_per_team"),
            "zona de inicio precisa comportar todas as unidades")


func test_tamanho_do_mapa() -> void:
    var r := Rules.load_default()
    check_eq([r.get_int("map", "width"), r.get_int("map", "depth")], [18, 18], "mapa 18x18")
    check_eq(r.get_int("map", "spawn_zone"), 4, "zona de preparacao 4x4")


func test_acessos_ausentes_ficam_em_zero_sem_crashar() -> void:
    var r := Rules.new()
    check_eq(r.get_int("missing", "key"), 0, "inteiro ausente = 0")
    check_eq(r.get_float("missing", "key"), 0.0, "float ausente = 0.0")
    check_eq(r.get_bool("missing", "key"), false, "bool ausente = falso")
    r.data = {"turn": {"ct_threshold": 100}}
    check_eq(r.get_int("turn", "ct_threshold"), 100, "chave existente continua funcionando")
    check_eq(r.get_int("turn", "cost_move"), 0, "chave faltante continua segura")
