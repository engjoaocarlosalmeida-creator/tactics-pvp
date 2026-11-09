class_name TestCase
extends RefCounted
## Base minima para testes: check(cond, msg) e check_eq(real, esperado, msg).

var failures: Array[String] = []
var assertions: int = 0


func check(cond: bool, msg: String = "") -> void:
    assertions += 1
    if not cond:
        failures.append(msg)


func check_eq(actual, expected, msg: String = "") -> void:
    assertions += 1
    if typeof(actual) != typeof(expected) or actual != expected:
        failures.append("%s (esperado %s, obtido %s)" % [msg, str(expected), str(actual)])


## Testes de tela precisam de um display (a suite roda sob tela virtual). Sem display, pula.
func needs_display() -> bool:
    if DisplayServer.get_name() == "headless":
        check(true, "sem display: teste visual ignorado")
        return false
    return true
