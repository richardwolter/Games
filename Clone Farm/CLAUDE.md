# Clone Farm

## Papel

Você é o programador principal e designer técnico de um protótipo em **Godot 4.7** (mesma
instalação dos outros jogos; ver o `CLAUDE.md` da raiz). Richard é o game designer e o
testador: **ele decide o design e julga se é divertido**. Decisões de design são tomadas
com ele, uma pergunta por vez, **antes** de construir. Não invente mecânica: pergunte.

## Regras deste projeto (lições do My Dirty Little Lake)

1. **Este arquivo fica curto (≤300 linhas).** Ele diz o estado atual e onde estão as coisas.
   Cada decisão de design vira um arquivo em `docs/decisoes/AAAA-MM-DD-titulo.md` (decisão,
   porquê, o que foi descartado). Aqui entra só um link e uma linha.
2. **O escopo vem antes do código.** `docs/scope.md` diz o que está dentro e fora da fase
   atual. Ideia nova fora do escopo vai para `docs/ideias.md`, não para issue nem código.
3. **Synty nunca entra no git.** O repo é público e a licença proíbe distribuir os assets.
   Eles ficam em `assets/synty/` (ignorado pelo `.gitignore`).
4. **Regra de vigilância** (raiz): contradição entre doc, código e issue → parar e perguntar.

## Conceito

Um fazendeiro tem uma máquina de clonagem. Os clones automatizam o trabalho da fazenda, mas
cada um nasce com características que são **trocas** (lado bom + lado ruim). O jogador
distribui funções aos clones e corre atrás dos desastres deles.

## Estado atual

**Fase 0 (setup) feita.** Projeto 3D em cinza: chão, luz, câmera ortográfica isométrica e o
fazendeiro (cápsula) andando com WASD. Próximo: Fase 2, o loop cinza de `docs/scope.md`.

## Design decidido (protótipo 1)

Resumo; detalhes e descartes em `docs/decisoes/2026-10-07-nucleo.md`.

- Clonar consome **produção** (não dinheiro). Clones **comem** produção todo dia; não expiram.
- Clone inútil é **reciclado**: devolve parte da produção (sempre menos que o custo).
- Características **aleatórias**, todas **trocas**. Lista: `docs/decisoes/2026-10-07-caracteristicas.md`.
- Melhoria da Máquina = **só mais características por clone**.
  **Contradição aberta:** Richard também disse "clones novos tendem a ser melhores". Não resolver sozinho.
- Tarefas **por função**: Plantar, Regar, Colher, Carregar. O clone faz a função na fazenda toda.
- Carregar leva a produção a 3 destinos: máquina, cocho, venda.
- Dinheiro vai para 3 lojas: Terra, Máquina, Ferramentas (1-2 itens cada no protótipo).
- Dia de 3-5 min com **meta diária crescente** (dinheiro vendido); falhou, acabou.
- O fazendeiro **tapa buraco** (qualquer função, sem fraqueza) e é o **único que conserta**
  os desastres dos clones, que se acumulam.

## Arquitetura

- `scripts/main.gd` monta a cena em código (chão, luz, câmera, fazendeiro). `scenes/main.tscn`
  só aponta para ele. Preferir montar em código a editar `.tscn` à mão.
- `scripts/controls.gd` registra as teclas no `InputMap` (jogo e harness usam o mesmo).
- Câmera olha pela diagonal; o fazendeiro gira a entrada em -45° para "cima" ser cima na tela.
- Renderer: Forward+ (3D, pensando nos assets Synty depois).

## Testes

- `tools/test_smoke.tscn` (headless): a fazenda monta e o fazendeiro anda.
  `Godot --headless --path . res://tools/test_smoke.tscn --quit-after 600`
  O resultado está em `tools/last_test.log`; a última linha tem que ser `smoke: PASS`.
  Erro de script não muda o código de saída: confie no log, não no exit code.
- Cada sistema novo do loop ganha checagens no harness.
- Playtest: logs e notas do Richard em `docs/playtests/`.

## Ferramentas

- `addons/godot_ai` (MCP do Godot, cópia do My Dirty Little Lake), habilitado no `project.godot`.
