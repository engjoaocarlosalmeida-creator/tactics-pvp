#!/usr/bin/env bash
# Roda a suite completa: testes automaticos (com renderizacao real em tela virtual)
# e um teste de fumaça do jogo com capturas de tela. Falha se houver qualquer erro.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import >/dev/null 2>&1

if command -v xvfb-run >/dev/null 2>&1; then
    RUN=(xvfb-run -a -s "-screen 0 1280x720x24")
    FLAGS=(--rendering-driver opengl3 --audio-driver Dummy)
else
    RUN=()
    FLAGS=(--headless --audio-driver Dummy)
fi

out=$(timeout "${TEST_TIMEOUT:-280}" "${RUN[@]}" "$GODOT" "${FLAGS[@]}" --path . --script res://tests/run_tests.gd 2>&1)
code=$?
echo "$out" | grep -v -E "^(ALSA|Godot Engine|OpenGL API|WARNING: Could not set V-Sync|     at: set_use_vsync)"
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|ERROR:"; then
    echo "ERRO DE SCRIPT DETECTADO"
    exit 1
fi
[ $code -ne 0 ] && exit $code

# Teste de fumaça: abre o jogo de verdade, joga e tira capturas de tela.
if [ "${#RUN[@]}" -gt 0 ] && [ -z "$SKIP_SMOKE" ]; then
    mkdir -p build/shots
    T_ROSTER=$(mktemp -u).json
    for spec in "mid:6" "end:900"; do
        name=${spec%%:*}; turns=${spec##*:}
        shot_out=$(timeout 120 "${RUN[@]}" "$GODOT" "${FLAGS[@]}" --path . -- --mode=demo --seed=7 --bot-turns=$turns --shot=build/shots/$name.png --roster=$T_ROSTER 2>&1)
        if echo "$shot_out" | grep -qE "SCRIPT ERROR|Parse Error|ERROR:"; then
            echo "$shot_out" | grep -E "SCRIPT ERROR|Parse Error|ERROR:|at:" | grep -v ALSA
            echo "FUMACA FALHOU ($name)"
            exit 1
        fi
        colors=$(python3 -c "
from PIL import Image
try:
    im = Image.open('build/shots/$name.png').convert('RGB')
    print(len(set(im.resize((320, 180)).getdata())))
except Exception:
    print(0)")
        if [ "${colors:-0}" -lt 300 ]; then
            echo "FUMACA FALHOU ($name): captura ausente ou quase vazia ($colors cores)"
            exit 1
        fi
        echo "FUMACA OK ($name): build/shots/$name.png ($colors cores)"
    done
fi
exit 0
