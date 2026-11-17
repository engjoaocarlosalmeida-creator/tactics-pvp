# TACTICS-PVP
## Pipeline de Arte e Tecnologias
### Versão 1.0

# Propósito

Este documento define o fluxo técnico oficial de produção artística de Tactics-PvP, garantindo velocidade de execução, custo zero com ferramentas locais e total fidelidade à Visual Bible e à Lore do projeto.

Toda produção visual segue a regra absoluta do projeto: **nenhuma modelagem manual no Blender**. Todos os ativos visuais são gerados localmente por Inteligência Artificial e integrados diretamente na Godot.

---

# Orçamento de Atenção Visual

Todo o esforço de produção artística é distribuído conforme o impacto no jogador:

1. **Arena e Atmosfera (40%):** Biomas vivos, iluminação dupla (dois sóis e lua), clima dinâmico e terreno reativo aos elementos.
2. **Personagens e Classes (35%):** Unidades chibi estilizadas com leitura instantânea de silhueta por classe.
3. **Efeitos Visuais / VFX (25%):** Magias, invocação temporária de armas e reações elementais de alto impacto.

---

# Stack Tecnológica (100% Local — RTX 3060 12GB VRAM)

| Etapa                     | Ferramenta / Modelo Local                                     | Função no Projeto                                                                             | Formato de Saída                  |
| :------------------------ | :------------------------------------------------------------ | :-------------------------------------------------------------------------------------------- | :-------------------------------- |
| **Geração 2D e Conceito** | **ComfyUI + Flux.1** (Dev / Schnell)                          | Concept art de classes, retratos de personagens, ícones de UI e referências isoladas para 3D. | `.png` (fundo limpo/transparente) |
| **Geração 3D de Malhas**  | **ComfyUI + Hunyuan3D / TRELLIS** (quantizado para 12GB VRAM) | Conversão de imagens isoladas em modelos 3D fechados com textura estilizada pintada.          | `.glb`                            |
| **Rigging e Esqueleto**   | **AccuRIG** (Desktop gratuito) ou **Mixamo**                  | Aplicação automática de esqueleto humanoide sobre as malhas `.glb` de personagens.            | `.fbx` / `.glb`                   |
| **Animação**              | **Biblioteca de Animações + Retargeting Godot**               | Reaproveitamento de ciclos de movimento, combate e reação compartilhados por classe.          | `.res` / `.glb`                   |
| **Engine, Terreno e VFX** | **Godot Engine**                                              | Geração procedural da arena, shaders de terreno/água, partículas elementais e iluminação.     | `.tscn` / `.tres`                 |

---

# Regras de Coesão Visual (Padrão de Produção)

Para evitar que ativos gerados por IA pareçam pertencentes a jogos diferentes, toda geração deve obedecer a três travas visuais:

1. **Prompt-Base Unificado:** Todos os conceitos 2D no Flux devem compartilhar o mesmo sufixo de estilo (ex.: *stylized chibi tactical RPG art, hand-painted textures, soft global illumination, clean silhouette, isolated on neutral background*).
2. **Iluminação Única na Engine:** Modelos 3D entram na Godot com materiais padronizados (`StandardMaterial3D` / `ShaderMaterial` com leve *rim light* e *cel-shading* suave) para que luzes e sombras dos dois sóis unifiquem todos os elementos na cena.
3. **Simplificação de Equipamentos:** Armaduras e acessórios não trocam a malha do personagem; armas aparecem apenas durante animações de ataque e habilidades (via VFX ou acoplamento temporário). Heróis únicos são variações visuais (*skins*) sobre o mesmo rig da classe.

---

# Fluxo de Produção por Categoria

## 1. Personagens e Inimigos
1. Gerar folha frontal limpa (A-Pose / T-Pose) no **ComfyUI + Flux** priorizando a silhueta da classe.
2. Converter a imagem em malha 3D `.glb` usando **Hunyuan3D / TRELLIS** no ComfyUI.
3. Aplicar esqueleto automático no **AccuRIG** mantendo a hierarquia padrão de ossos.
4. Importar na **Godot** e vincular à biblioteca de animações compartilhada da classe (*Idle*, *Move*, *Attack*, *Defend*, *Dodge*, *Parry*, *Impact*).

## 2. Arenas Dinâmicas e Reatividade Elemental
Como cada partida gera uma arena inédita (rios de larguras variadas, pontes de tamanhos diferentes e terrenos mutáveis), o cenário é construído em três camadas na Godot:

* **Camada 1 — Malha Procedural e Shaders (Terreno e Rios):** O grid lógico gera a malha base e o leito dos rios via código. Shaders de terreno alternam visualmente os estados das células em tempo real:
  * **Água + Raio:** Propaga descarga elétrica e VFX de arcos voltaicos por todas as células de água conectadas.
  * **Terra + Água:** Transforma a textura e o brilho da célula em **Lama**, aplicando penalidade de movimento.
  * **Estruturas + Fogo:** Ativa partículas de chamas em objetos com tag `Inflamavel`, substituindo-os por destroços carbonizados após o tempo de queima.
* **Camada 2 — Estruturas Modulares:** Pontes, escadas e muralhas usam peças base simples combinadas com adornos 3D gerados pela IA para adaptar-se a qualquer comprimento exigido pelo gerador.
* **Camada 3 — Props de Bioma:** Árvores, cristais mágicos, rochas e ruínas são gerados isoladamente em `.glb` via **Flux → Hunyuan3D / TRELLIS** e dispersos nas bordas e células bloqueadas da arena.

## 3. UI, Retratos e Ícones
1. Gerados diretamente no **ComfyUI + Flux** com molduras e paletas fixas por escola mágica (**Arcana**: azul/violeta; **Luz**: dourado/branco; **Trevas**: roxo/verde espectral).

---

# Estrutura Oficial de Diretórios (`J:\TacticsPVP`)

```text
J:\TacticsPVP
│
├── Game                        # Projeto principal da Godot Engine
│
├── AI                          # Ferramentas e modelos locais
│   ├── ComfyUI                 # Instalação e workflows salvos (.json)
│   ├── Models                  # Checkpoints Flux, Hunyuan3D / TRELLIS
│   └── Outputs                 # Saídas brutas antes da curadoria
│
├── Arenas                      # Kits modulares por bioma (40% do foco)
│   ├── FlorestaMagica          # Bioma âncora do projeto
│   ├── CidadeArcana
│   ├── Pantanos
│   ├── Desertos
│   ├── Montanhas
│   └── SharedProps             # Pontes, cristais, ruínas e itens inflamáveis
│
├── Characters                  # Unidades e classes (35% do foco)
│   ├── Concepts                # Imagens base em A-Pose/T-Pose (.png)
│   ├── Portraits               # Retratos de UI (.png)
│   ├── Models3D                # Malhas brutas geradas por IA (.glb)
│   └── Rigged                  # Modelos com esqueleto pronto para Godot
│
├── VFX                         # Efeitos e habilidades (25% do foco)
│   ├── Elemental               # Raio na água, fogo, lama, clima
│   ├── Skills                  # Magias Arcanas, Luz e Trevas
│   └── Weapons                 # Armas invocadas em animação
│
└── Design                      # Documentação oficial (Lore, Guides, Pipeline)
    ├── Lore
    ├── Classes
    └── Pipeline
```
