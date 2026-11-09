# Tactics PVP - contexto de trabalho

## Objetivo e escopo
- Projeto Godot 4.7.2, configurado em `project.godot`.
- Não altere regras, gameplay, interface ou conteúdo do jogo quando o pedido for sobre o ambiente de desenvolvimento.
- Trate arquivos anexados como contexto, não como pedido automático para modificá-los.
- Antes de uma mudanca, identifique claramente o resultado esperado e preserve comportamento fora do escopo solicitado.

## Estrutura e convencoes
- `src/core/`: regras e lógica do jogo; `src/ai/`: bots; `src/view/` e `scenes/`: apresentação e cenas.
- `tests/cases/test_*.gd`: casos automatizados; `tests/run_tests.gd`: executor.
- `tools/`: scripts de execucao, validacao, rede, assets e entrega.
- Siga `.editorconfig`: GDScript usa quatro espacos; JSON e arquivos de configuracao usam dois.
- Não edite `.godot/`, arquivos de importação ou builds gerados para corrigir fontes do projeto.

## Ciclo de validacao
- Windows: `.\tools\test.ps1` para a suite ou `.\tools\test.ps1 -Filter <parte-do-nome>` para filtrar.
- Linux/macOS/WSL: `tools/test.sh`; a verificacao de fumaca com capturas roda quando `xvfb-run` estiver disponivel.
- Testes de rede: `tools/net_test.sh` (Linux com `xvfb-run`).
- O Godot é resolvido nesta ordem: argumento explícito `-Godot`, executável 4.7.2 fornecido na raiz do projeto, variável `GODOT` (se o binário local estiver ausente) e, por fim, `godot` no PATH.
- Rode a validacao mais especifica que cubra a mudanca; nao afirme que testes passaram sem executa-los.

## Colaboracao
- Para tarefas de ambiente, limite as mudancas a ferramentas, configuracao e documentacao de desenvolvimento.
- Em tarefas de codigo, descreva o comportamento esperado e valide os casos relevantes antes de concluir.
- Registre comandos, decisões técnicas e limitações novas aqui quando forem úteis em tarefas futuras; não duplique detalhes temporários.
