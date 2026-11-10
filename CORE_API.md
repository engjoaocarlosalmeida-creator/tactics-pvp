# Referência de API Core

Este arquivo lista os pilares da lógica de jogo para consulta rápida da IA.

- **`match_state.gd`**: Orquestrador central. Mantém o status global da partida.
- **`turn_system.gd`**: Gerencia a fila de ações e transições de turno.
- **`character.gd`**: Definição de atributos e métodos básicos.
- **`unit.gd`**: Representação de instância no mapa (referencia `character`).
- **`battle_map.gd`**: Lógica de ocupação e geometria de grade.
- **`rules.gd`**: Calculadora de danos, precisão e modificadores (regra de jogo pura).

*Dica de IA:* Ao alterar mecânicas, consulte `rules.gd`. Ao alterar fluxo, consulte `turn_system.gd` e `match_state.gd`.
