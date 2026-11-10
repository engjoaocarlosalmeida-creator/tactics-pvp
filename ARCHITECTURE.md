# Arquitetura do Projeto Tactics PVP

Este documento guia IAs e desenvolvedores sobre a estrutura do projeto.

## Estrutura de Diretórios
- `src/core/`: Regras de negócio, cálculos, estados de jogo (Single Source of Truth).
- `src/view/`: UI, animações, shaders. Apenas interpreta o estado de `core/`.
- `src/ai/`: Lógica de decisão dos agentes.
- `assets/`: Ativos brutos (não editar arquivos `.import`).
- `tests/`: Testes unitários (sempre rodar antes de commits).

## Regras de Ouro para IA
1. Nunca modifique arquivos `.import` ou pastas `.godot`.
2. Ao editar `core/`, priorize o desacoplamento: a lógica não deve conhecer a existência de nós da cena.
3. Use os tipos explícitos do GDScript 2.0.
4. Mantenha o estado do jogo (MatchState) separado da persistência (Account).
5. **Comunicação:** Use sinais para que `view/` reaja a mudanças em `core/`. O `core/` nunca deve acessar instâncias de UI diretamente.

## Convenções de Código
- GDScript: 4 espaços.
- Nomenclatura: `snake_case` para variáveis/funções, `PascalCase` para classes.
