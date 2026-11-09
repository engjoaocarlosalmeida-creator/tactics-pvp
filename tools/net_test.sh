#!/usr/bin/env bash
# Teste de rede de verdade: duas copias do jogo (anfitriao e cliente) jogam uma partida
# completa pela rede, cada uma com um bot, e os resultados sao comparados.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FLAGS=(--rendering-driver opengl3 --audio-driver Dummy --path .)
RUN=(xvfb-run -a -s "-screen 0 800x600x24")
T=$(mktemp -d)
fail=0

run_pair() {  # $1=nome  $2=extra do cliente  $3=seed
    local port=$((20000 + RANDOM % 20000))
    timeout 120 "${RUN[@]}" "$GODOT" "${FLAGS[@]}" -- --net=host --port=$port --seed=$3 --auto-play --quit-on-end --fast \
        --report=$T/$1_host.json --roster=$T/$1_host_roster.json > $T/$1_host.log 2>&1 &
    local hp=$!
    sleep 5
    timeout 120 "${RUN[@]}" "$GODOT" "${FLAGS[@]}" -- --net=join --ip=127.0.0.1 --port=$port --auto-play --quit-on-end --fast $2 \
        --report=$T/$1_client.json --roster=$T/$1_client_roster.json > $T/$1_client.log 2>&1 &
    local cp=$!
    wait $hp; echo "host saiu: $?" > $T/$1_host.exit
    wait $cp; echo "cliente saiu: $?" > $T/$1_client.exit
}

run_pair completa "" 33
run_pair abandono "--quit-after-turns=6" 5

python3 - "$T" <<'PY'
import json, sys, os
T = sys.argv[1]
bad = []
def load(n):
    p = f"{T}/{n}.json"
    return json.load(open(p)) if os.path.exists(p) else None
h, c = load("completa_host"), load("completa_client")
if not h or not c:
    bad.append("relatorios da partida completa ausentes")
else:
    print("anfitriao:", h); print("cliente:  ", c)
    if h["hash"] != c["hash"]: bad.append("estado final diferente entre os lados")
    if h["winner"] != c["winner"]: bad.append("vencedor diferente")
    if h["turns"] != c["turns"]: bad.append("numero de turnos diferente")
    if h["desync"] or c["desync"]: bad.append("dessincronia detectada")
    if h["my_team"] != 0 or c["my_team"] != 1: bad.append("times errados")
    if h["xp"] <= 0 or c["xp"] <= 0: bad.append("XP por acoes nao aplicado")
    if h["winner"] < 0: bad.append("partida sem vencedor")
    for who in ("host", "client"):
        r = json.load(open(f"{T}/completa_{who}_roster.json"))
        chars = r["characters"]
        gained = [sum(x["job_xp"].values()) for x in chars]
        if sum(gained[:4]) <= 0: bad.append(f"{who}: time local sem progresso salvo")
        if any(g > 0 for g in gained[4:]): bad.append(f"{who}: progresso indevido nos outros personagens")
a = load("abandono_host")
if not a or not a["opponent_left"]: bad.append("anfitriao nao percebeu o abandono")
else: print("abandono detectado:", a)
for f in sorted(os.listdir(T)):
    if f.endswith(".exit"):
        line = open(f"{T}/{f}").read().strip(); print(f"{f[:-5]}: {line}")
        if not line.endswith(": 0"): bad.append(f"{f}: {line}")
errs = []
for f in sorted(os.listdir(T)):
    if f.endswith(".log"):
        for l in open(f"{T}/{f}", errors="ignore"):
            if ("ERROR" in l or "SCRIPT ERROR" in l) and "ALSA" not in l and "Condition \"status < 0\"" not in l:
                errs.append(f"{f}: {l.strip()}")
bad += errs[:6]
print("RESULTADO REDE:", "FALHOU - " + "; ".join(bad) if bad else "OK")
sys.exit(1 if bad else 0)
PY
exit $?
