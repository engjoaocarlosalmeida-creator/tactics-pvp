extends TestCase


func test_conta_nome_e_sexo_so_uma_vez() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4
    var a := Account.create_new(rng)
    check(a.player_name.contains(" "), "nome sorteado")
    check(a.edit_identity("Ana Costa", "f"), "primeira edicao")
    check_eq([a.player_name, a.sex, a.avatar], ["Ana Costa", "f", "escudeiro_f"], "aplicou")
    check(not a.edit_identity("Outro", "m"), "so uma vez")
    check_eq(a.sex, "f", "sexo nao mudou")


func test_scores_rank_e_patentes() -> void:
    var a := Account.new()
    a.record_match(3, true, false)
    check_eq([a.matches, a.wins, a.kills, a.rank_points], [1, 1, 3, 0], "contra o computador: so scores")
    a.record_match(2, true, true)
    a.record_match(0, false, true)
    check_eq([a.rank_points, a.losses], [15, 1], "PVP: +25 e -10")
    for i in 10:
        a.record_match(0, false, true)
    check_eq(a.rank_points, 0, "rank nao fica negativo")
    var cases := {0: "Recruta", 100: "Soldado", 450: "Sargento", 1000: "Capitão", 2500: "General"}
    for pts in cases:
        a.rank_points = pts
        check_eq(a.rank_name(), cases[pts], "%d pontos" % pts)


func test_titulos_bordas_e_salvamento() -> void:
    var a := Account.new()
    check(not a.set_title("veterano"), "bloqueado")
    a.matches = 10
    check(a.set_title("veterano"), "liberado")
    check(not a.set_border("ouro"), "borda bloqueada")
    a.rank_points = 1000
    check(a.set_border("ouro"), "borda liberada")
    check(a.set_avatar("arqueiro_f") and not a.set_avatar("dragao_f"), "avatar")
    check(a.save("user://test_account.json"), "salvou")
    check_eq(Account.load_or_create("user://test_account.json").to_dict(), a.to_dict(), "ida e volta")
    DirAccess.remove_absolute("user://test_account.json")


func test_opcoes_de_tela_e_volume() -> void:
    var s := Settings.new()
    check_eq(s.display_mode, Settings.MODE_BORDERLESS, "padrao: tela cheia em janela")
    s.change("display_mode")
    check_eq(s.display_mode, Settings.MODE_FULLSCREEN, "tela cheia")
    check_eq(Settings.available_resolutions(Vector2i(1920, 1080)), [0, 1] as Array[int], "1080p comporta ate 1600x900")
    s.change("volume", 5)
    check_eq(s.volume, 1.0, "volume limitado")
    check(s.save("user://test_settings.cfg") and Settings.load_from("user://test_settings.cfg").display_mode == Settings.MODE_FULLSCREEN, "salva e carrega")
    DirAccess.remove_absolute("user://test_settings.cfg")
