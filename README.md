# Tactics PVP

Jogo de tática por turnos inspirado em Final Fantasy Tactics, focado em partidas PVP,
personagens customizáveis e mapas 3D procedurais. Engine: Godot 4.7.2.

## Como o projeto está organizado
- `data/rules.json` — todas as regras numéricas (movimento, pulo, queda, turnos, combate). Edite aqui para balancear.
- `src/core/` — lógica pura do jogo (sem visual): mapa, unidades, movimento, turnos, partida, gerador de mapas.
- `src/ai/` — bots (usados nos testes e, depois, no modo contra o computador).
- `tests/cases/` — casos de teste automatizados.
- `tools/` — execução do jogo, testes, automação de assets e entrega.
- `scenes/` — camada visual (próxima etapa).

## Ambiente de desenvolvimento
- No Windows, abra o projeto pelo arquivo `project.godot` no Godot 4.7.2. O VS Code e as tarefas usam por padrão o executável da raiz do projeto.
- Os scripts aceitam `-Godot caminho\godot.exe` para uma substituição pontual; se o executável do projeto não estiver presente, tentam a variável `GODOT` e depois `godot` no PATH.
- No VS Code, use `Terminal > Run Task` para abrir o jogo, iniciar a demo ou executar testes.
- Para abrir o jogo no PowerShell: `.\tools\run_game.ps1`; para a demo: `.\tools\run_game.ps1 -Demo`.

## Testes
- Windows: `.\tools\test.ps1` roda a suíte; `.\tools\test.ps1 -Filter combat` filtra pelo nome do arquivo de teste.
- Linux/macOS/WSL/Git Bash: `tools/test.sh`; use `GODOT=/c/caminho/godot tools/test.sh` para indicar outro executável.
- `tools/test.sh` inclui testes de fumaça com capturas quando `xvfb-run` está disponível. `SKIP_SMOKE=1` pula essa etapa.
- Rede: `tools/net_test.sh` executa partidas entre duas instancias em ambiente Linux com `xvfb-run`.

Regra do projeto: nada é entregue sem a suíte passando.

## Contexto para assistentes de codigo
`AGENTS.md` registra o contexto permanente do projeto, os comandos de validação e os limites de escopo para tarefas assistidas.
