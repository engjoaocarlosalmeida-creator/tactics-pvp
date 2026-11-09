extends SceneTree
## Executa todos os tests/cases/test_*.gd. Uso: tools/test.sh

func _initialize() -> void:
    # Espera o primeiro quadro: so entao a arvore de cenas esta pronta (testes de tela precisam disso).
    process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
    MatchState.reactions_enabled = false   # testes antigos sao deterministicos; os de combate ligam por conta propria
    var dir := DirAccess.open("res://tests/cases")
    var files: Array[String] = []
    var only := OS.get_environment("TEST_FILTER")
    for f in dir.get_files():
        if f.begins_with("test_") and f.ends_with(".gd") and (only == "" or f.contains(only)):
            files.append(f)
    files.sort()
    var total := 0
    var failed := 0
    var checks := 0
    for f in files:
        var script: GDScript = load("res://tests/cases/" + f)
        if script == null:
            print("FAIL  %s nao carregou (erro de sintaxe)" % f)
            quit(1)
            return
        var probe = script.new()
        var names: Array[String] = []
        for m in probe.get_method_list():
            if str(m.name).begins_with("test_"):
                names.append(str(m.name))
        names.sort()
        for n in names:
            var inst = script.new()
            var t0 := Time.get_ticks_msec()
            inst.call(n)
            var ms := Time.get_ticks_msec() - t0
            total += 1
            checks += inst.assertions
            var problems: Array = inst.failures.duplicate()
            if inst.assertions == 0:
                problems.append("nenhuma verificacao executada (erro no teste?)")
            if problems.is_empty():
                print("PASS  %s::%s (%d ms)" % [f, n, ms])
            else:
                failed += 1
                print("FAIL  %s::%s" % [f, n])
                for p in problems:
                    print("      - ", p)
    print("")
    print("%d testes, %d verificacoes, %d falhas" % [total, checks, failed])
    quit(1 if failed > 0 else 0)
