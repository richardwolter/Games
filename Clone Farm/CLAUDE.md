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

**Fase 0 (setup) feita.** Projeto 3D em cinza, câmera ortográfica isométrica, WASD.

**Fase 2 (loop cinza de `docs/scope.md`) em andamento.** Feito:
- Canteiros (plantar, regar, colher) com tempo de trabalho; o trabalhador vai até o lugar e
  fica fixo; E de novo cancela ([decisão](docs/decisoes/2026-10-07-tempo-de-trabalho.md)).
- Máquina de clonagem e clones com função e 2 características sorteadas entre as 8
  ([máquina](docs/decisoes/2026-10-07-maquina-e-primeiro-clone.md)).
- Carregar (colheita vira caixote; destinos máquina, cocho, venda), comida a cada 60 s e
  fome, e Forte, Glutão, Beliscador, Preguiçoso
  ([decisão](docs/decisoes/2026-10-07-carregar-comida-e-caracteristicas.md)).
- Painel do clone com atributos de nomes fixos e a % de produção por função, de um modelo
  ([painel](docs/decisoes/2026-10-07-painel-do-clone.md)).

Números são padrões nossos, a confirmar jogando. Falta: reciclar clone, 3 lojas, dia com meta.

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

- `scripts/main.gd` monta a cena em código (chão, luz, câmera, canteiros, depósitos,
  fazendeiro, HUD, painel do clone) e solta os caixotes da colheita. `scenes/main.tscn` só
  aponta para ele. Preferir montar em código a editar `.tscn` à mão.
- `scripts/controls.gd` registra as teclas no `InputMap` (jogo e harness usam o mesmo).
- Câmera olha pela diagonal; o fazendeiro converte a entrada pela base da câmera
  (`screen_to_ground`) para W ser cima na tela.
- `scripts/workplace.gd` (`Workplace`): onde se trabalha. `next_task_for(worker)`,
  `work_time()`, `perform(task, by)`, `half_size()` (o trabalhador fica fora da borda).
  Filhos: `Bed` (canteiro; pisoteado só o `Farmer` conserta), `Crate` (caixote; pegar),
  `Depot` (entregar; o cocho também dá `eat`), `Machine` (um `Depot` que também clona).
- `scripts/worker.gd` (`Worker`): quem trabalha. `work()` anda até o ponto ao lado do lugar,
  vira, fica travado contando o tempo e só então chama `perform`. Leva `carrying` caixotes.
  Ganchos que o clone sobrescreve: `move_mult`, `task_speed`, `harvest_bonus`, `grow_boost`,
  `capacity`, `keep_of`, `is_paused`, `_finish_task`, `_after_move`. O `Farmer` lê WASD, E e
  0-4. Trabalhadores ficam na camada física 2 e se atravessam.
- `scripts/clone.gd` (`Clone`): `role` (+ `dest` no Carregar), `traits`, refeições e fome,
  pausas, balões do lado ruim.
- `scripts/traits.gd` (`Traits`): as 8 características como dados (modificadores);
  `combine()` recalcula do zero; `stat_rows()` e `role_rating()` geram o texto e a % do
  painel a partir dos mesmos dados.
- Renderer: Forward+ (3D, pensando nos assets Synty depois).

## Testes

- `tools/test_smoke.tscn` (headless): fazenda, WASD, ciclo do canteiro, trava e cancelamento,
  máquina e clone, cada característica dos dois lados, a % contra contas feitas à mão,
  caixotes para cada destino, clone Carregar, fome e comida, cochilo, pisoteio e conserto.
  `Godot --headless --path . res://tools/test_smoke.tscn --quit-after 3000`
  O resultado está em `tools/last_test.log`; a última linha tem que ser `smoke: PASS`.
  Erro de script não muda o código de saída: confie no log, não no exit code.
  `--quit-after` conta quadros do motor, que no headless passam mais rápido que os de
  física em que o harness anda; com 900 ele parava antes do fim, sem linha de PASS.
  Script novo com `class_name`: rode antes `Godot --headless --path . --import`, senão o
  harness não acha a classe (e o `last_test.log` antigo fica lá parecendo PASS).
- Cada sistema novo do loop ganha checagens no harness.
- Playtest: logs e notas do Richard em `docs/playtests/`.

## Ferramentas

- `addons/godot_ai` (MCP do Godot, cópia do My Dirty Little Lake), habilitado no `project.godot`.
