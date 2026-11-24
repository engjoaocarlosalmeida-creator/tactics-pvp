"# Arquitetura do Projeto Tactics PVP

Este documento guia IAs e desenvolvedores sobre a estrutura do projeto.

## Estrutura de Diretórios
- `src/core/`: Regras de negócio, cálculos, estados de jogo (Single Source of Truth).
- `src/view/`: UI, animações, shaders. Apenas interpreta o estado de `core/`.
- `src/ai/`: Lógica de decisão dos agentes.
- `assets/`: Ativos brutos (não editar arquivos `.import`).
- `tests/`: Testes unitários (sempre rodar antes de commits).
- `TacticsPVP_Art/`: Studio de Produção.
    - `AI/`: Production Pipeline de geração de ativos via IA (ComfyUI, BlenderMCP).
    - `Arenas/`: Definições de biomas e cenários.
    - `Characters/`: Pipeline de personagens (Concepts -> Meshes -> Rigged -> Models3D).
    - `Design/`: Lore, Classes e Documentação de Design.
    - `VFX/`: Sistema modular de efeitos visuais (Elemental, Skills, Weapons).

## Core System Map (Lógica de Jogo)
Este mapa define os pilares da lógica de jogo para consulta rápida da IA:
- **`match_state.gd`**: Orquestrador central. Mantém o status global da partida.
- **`turn_system.gd`**: Gerencia a fila de ações e transições de turno.
- **`character.gd`**: Definição de atributos e métodos básicos.
- **`unit.gd`**: Representação de instância no mapa (referencia `character`).
- **`battle_map.gd`**: Lógica de ocupação e geometria de grade.
- **`rules.gd`**: Calculadora de danos, precisão e modificadores (regra de jogo pura).

*Dica de IA:* Ao alterar mecânicas, consulte `rules.gd`. Ao alterar fluxo, consulte `turn_system.gd` e `match_state.gd`.

## Production Pipeline (Studio)
Diretrizes para a criação e integração de ativos no `TacticsPVP_Art`:
- **Pipeline de Arte:** Ativos devem seguir o fluxo: Concept -> Mesh -> Rig -> Model3D. O Motor deve consumir apenas o estágio final (Model3D).
- **Modularidade de VFX:** Efeitos visuais devem ser compostos por módulos (Elemental, Skills, Weapons) para permitir reutilização entre diferentes arenas e personagens.
- **Escalabilidade de Arenas:** Cenários devem ser construídos usando `SharedProps` para garantir consistência visual e funcional entre biomas.
- **IA & Modelos:** O uso de ComfyUI e BlenderMCP deve focar em inferência e geração de ativos. O código de infraestrutura de IA deve ser desacoplado da lógica de jogo.
- **Integridade de Modelos:** Modelos devem ser tratados como \"frozen\" para inferência. Evite adicionar comportamentos de treinamento (dropout, etc.) em classes de inferência.

## Regras de Ouro para IA
1. Nunca modifique arquivos `.import` ou pastas `.godot`.
2. Ao editar `core/`, priorize o desacoplamento: a lógica não deve conhecer a existência de nós da cena.
3. Use os tipos explícitos do GDScript 2.0.
4. Mantenha o estado do jogo (MatchState) separado da persistência (Account).
5. **Comunicação:** Use sinais para que `view/` reaja a mudanças em `core/`. O `core/` nunca deve acessar instâncias de UI diretamente.
6. **Data-Driven:** O `core/` deve ser alimentado por arquivos JSON em `data/`. Evite hardcoding de atributos de personagens ou itens.
7. **Desenvolvimento Prático:** Prefira correções diretas e pequenas. Adicione abstrações apenas quando removerem lógica repetida real.
8. **Ciclo de Validação:** Rode a validação mais específica que cubra a mudança antes de concluir. Não afirme que testes passaram sem executá-los.
9. **Limpeza de Código:** Remova agressivamente código obsoleto, dead branches e prints de debug.

## Convenções de Código
- GDScript: 4 espaços.
- Nomenclatura: `snake_case` para variáveis/funções, `PascalCase` para classes.
- **Integração motor-studio:** O `core/` consome dados de `data/` e modelos de `Characters/Models3D`. O `view/` consome os ativos de `VFX/` e `Arenas/`.
- **Sinais de Estado:** Toda mudança de estado no modo `core/` deve emitir um sinal que a `view/` escuta. Nunca use `get_node()` para acessar elementos de UI a partir do `core/`.
- **Tipagem:** Use `static_typing` em todas as funções de cálculo no `core/` para garantir precisão matemática.
- **Imutabilidade:** Dados carregados de JSON devem ser tratados como imutáveis durante o ciclo de vida de uma partida (MatchState).

## Advanced Engineering Standards

### 1. State Management (Transient vs. Persistent)
- **Transient State:** Inclui animações, efeitos visuais, timers de UI e estados de entrada. Estes estados devem viver apenas na `view/` ou em objetos de sessão temporários.
- **Persistent State:** Inclui XP, Inventário, Nível e Progressão. Estes estados devem ser gerenciados pelo `core/` e persistidos apenas em momentos de salvamento/sincronização.
- **Regra:** Nunca tente persistir estados transientes no banco de dados ou arquivos de conta.

### 2. Signal Payload Protocol
- Para garantir que a a `view/` seja puramente reativa, os sinais emitidos pelo `core/` devem carregar um objeto de dados estruturado (Payload).
- **Exemplo:** Em vez de `signal_unit_died`, use `signal_unit_died(data: Dictionary)`, onde `data` contém o ID da unidade, o tipo de dano e a posição final.
- Isso evita que a View precise consultar o o Core para obter detalhes após o sinal ser disparado.
- **Ação:** A IA deve priorizar a criação de scripts de validação que verifiquem tipos, limites (min/max) e referências cruzadas antes da inicialização do MatchState.
- Erros de schema devem gerar logs claros indicando o arquivo e a linha do erro.

### 3. Data Schema Validation
- Como o projeto é Data-Driven, todos os arquivos em `data/` devem ser validados contra o `rules.json` no carregamento.
- **Ação:** A IA deve priorizar a criação de scripts de validação que verifiquem tipos, limites (min/max) e referências cruzadas antes da inicialização do MatchState.
- Erros de schema devem gerar logs claros indicando o arquivo e a linha do erro."