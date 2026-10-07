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
fazendeiro (cápsula) andando com WASD.

**Fase 2 (loop cinza de `docs/scope.md`), primeira fatia feita:** 6 canteiros; o fazendeiro
planta, rega e colhe com E (ou Espaço) no canteiro mais perto. Cada ação tem tempo de
trabalho, e o trabalhador anda até o canteiro e fica fixo lá trabalhando; E de novo cancela
([decisão](docs/decisoes/2026-10-07-tempo-de-trabalho.md)). A colheita soma em "Produção"
no HUD.

**Fase 2, segunda fatia feita:** máquina de clonagem (E, 2 s, custa 3 de produção; começa
com 5) e clones com função (E no clone, depois 1/2/3/0) que trabalham os canteiros sozinhos
com as mesmas regras, cada um com 2 características sorteadas (Apressado, Caprichoso,
Dedo Verde, Animado) ([decisão](docs/decisoes/2026-10-07-maquina-e-primeiro-clone.md),
números a confirmar). Perto de um clone, o HUD mostra cada efeito com +/- e uma nota
em % por função ([painel](docs/decisoes/2026-10-07-painel-do-clone.md)). Ainda sem comida,
Carregar, reciclar, lojas nem dia.

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
- Câmera olha pela diagonal; o fazendeiro converte a entrada pela base da câmera
  (`screen_to_ground`) para W ser cima na tela.
- `scripts/workplace.gd` (`Workplace`): onde se trabalha (canteiro, máquina): `next_task()`,
  `work_time()`, `perform()`, `half_size()` (o trabalhador fica fora da borda).
- `scripts/machine.gd` (`Machine`): tarefa `clone`; a fazenda (`main.gd`) diz se dá pra
  pagar e cria o clone no sinal `cloned`.
- `scripts/clone.gd` (`Clone`): `Worker` com `role` e `traits`; escolhe o canteiro mais perto
  que quer a função e que nenhum outro trabalhador pegou. Balão mostra o lado ruim.
- `scripts/traits.gd` (`Traits`): características como dados (modificadores);
  `combine()` recalcula do zero; `describe()` e `role_rating()` geram o texto e a nota do
  painel a partir dos mesmos dados (`main.clone_panel`). O `Worker` tem ganchos (`move_mult`, `task_speed`,
  `harvest_bonus`, `grow_boost`, `is_paused`, `_finish_task`) que o clone sobrescreve.
- `scripts/bed.gd` (`Bed`): canteiro vazio → plantado → crescendo → maduro. `next_task()` diz
  o que ele espera, `perform(task)` faz. Não sabe quem trabalha: os clones vão chamar as mesmas
  funções que o fazendeiro. `Bed.WORK_TIME` dá o tempo de cada tarefa.
- `scripts/worker.gd` (`Worker`): quem trabalha (fazendeiro agora, clones depois). `work()`
  escolhe o canteiro, anda até o ponto ao lado dele, vira, fica travado contando o tempo
  (`work_speed` multiplica) e só então chama `perform`. O filho decide o que fazer em
  `_think()`/`wanted_move()`; o `Farmer` lê WASD, E e 0-3. A animação mexe no filho "Body".
  Trabalhadores ficam na camada física 2 e se atravessam.
- Produção colhida fica em `main.stock` (via sinal `Bed.harvested`) até existir o Carregar.
- Renderer: Forward+ (3D, pensando nos assets Synty depois).

## Testes

- `tools/test_smoke.tscn` (headless): a fazenda monta, o fazendeiro anda, e um canteiro faz
  o ciclo inteiro (direto e pelo fazendeiro), a máquina cobra e cria um clone, e o clone
  com função planta sozinho, e os dois lados de cada característica.
  `Godot --headless --path . res://tools/test_smoke.tscn --quit-after 600`
  O resultado está em `tools/last_test.log`; a última linha tem que ser `smoke: PASS`.
  Erro de script não muda o código de saída: confie no log, não no exit code.
  Script novo com `class_name`: rode antes `Godot --headless --path . --import`, senão o
  harness não acha a classe (e o `last_test.log` antigo fica lá parecendo PASS).
- Cada sistema novo do loop ganha checagens no harness.
- Playtest: logs e notas do Richard em `docs/playtests/`.

## Ferramentas

- `addons/godot_ai` (MCP do Godot, cópia do My Dirty Little Lake), habilitado no `project.godot`.
