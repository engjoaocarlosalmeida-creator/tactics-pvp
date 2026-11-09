#!/usr/bin/env bash
# Gera o executavel jogavel e o pacote de entrega: exporta Windows e Linux (teste), abre o jogo exportado
# numa partida de verdade (fumaca) e grava DOIS zips em /mnt/user-data/outputs:
#   TacticsPVP-windows.zip (jogo) e tactics-pvp-projeto.zip (CODIGO-FONTE, para nunca perder o projeto).
# Uso: tools/entregar.sh   (rode antes tools/test.sh e tools/net_test.sh)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${OUT:-/mnt/user-data/outputs}"
VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")
set -e
"$GODOT" --headless --import >/dev/null 2>&1 || true
mkdir -p build/windows build/linux build/shots "$OUT"
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/TacticsPVP.exe 2>&1 | grep -E "ERROR" && { echo "FALHA na exportacao Windows"; exit 1; } || true
"$GODOT" --headless --path . --export-release "Linux (teste)" build/linux/TacticsPVP.x86_64 2>&1 | grep -E "ERROR" && { echo "FALHA na exportacao Linux"; exit 1; } || true
out=$(timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" ./build/linux/TacticsPVP.x86_64 --rendering-driver opengl3 --audio-driver Dummy -- --mode=demo --seed=7 --bot-turns=60 --shot=build/shots/exportado.png --roster=/tmp/entrega_roster.json 2>&1 || true)
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|ERROR:"; then echo "$out" | grep -E "SCRIPT ERROR|ERROR:" | head -5; echo "FALHA: erro no jogo exportado"; exit 1; fi
colors=$(python3 -c "
from PIL import Image
im = Image.open('build/shots/exportado.png').convert('RGB')
print(len(set(im.resize((320, 180)).getdata())))" 2>/dev/null || echo 0)
[ "$colors" -lt 300 ] && { echo "FALHA: captura do jogo exportado vazia"; exit 1; }
python3 - "$OUT" "$VERSION" <<'PY'
import sys, zipfile, os
out, version = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out + "/TacticsPVP-windows.zip", "w", zipfile.ZIP_DEFLATED) as z:
    z.write("build/windows/TacticsPVP.exe", "TacticsPVP/TacticsPVP.exe")
    z.write("release/COMO-JOGAR.txt", "TacticsPVP/COMO-JOGAR.txt")
    z.writestr("TacticsPVP/VERSAO.txt", version + "\n")
with zipfile.ZipFile(out + "/tactics-pvp-projeto.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for d, dirs, fs in os.walk("."):
        dirs[:] = [x for x in dirs if x not in ("build", ".godot")]
        for f in fs:
            p = os.path.join(d, f)
            z.write(p, os.path.join("tactics", os.path.relpath(p, ".")))
print("pacotes em", out)
PY
echo "ENTREGA OK (versao $VERSION, $colors cores na captura)"
