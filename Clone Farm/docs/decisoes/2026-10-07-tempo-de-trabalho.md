# Tempo de trabalho por ação

**Decidido por Richard em 2026-10-07.**

## Decisão
Cada ação (plantar, regar, colher; carregar quando existir) leva um tempo de trabalho. Não é
instantânea.

## Por quê
Dá motivo para ferramentas melhores (loja Ferramentas: "tarefa mais rápida") e para
características que mexem na velocidade (Apressado, Caprichoso, Glutão).

## Como ficou no protótipo
- Tempo por tarefa é dado (`Bed.WORK_TIME`), 1 s cada por enquanto; o trabalhador tem um
  multiplicador `work_speed` (ferramentas e características vão mexer nele).
- **Um aperto de E** começa a tarefa, não segurar (Richard, 2026-10-07).
- **O trabalhador fica fixo no canteiro; nada acontece "por mágica"** (Richard, 2026-10-07:
  "o jogador/clone precisa se fixar na posição e não deixar algo magicamente acontecer").
  Ao apertar E, ele anda até um ponto fixo ao lado do canteiro, vira para ele, e só então o
  tempo corre. Enquanto trabalha, WASD é ignorado; ele se inclina e balança no ritmo do
  trabalho, com barra amarela na cabeça e "plantando... 40%" no HUD.
- **E de novo cancela** e o canteiro fica como estava (padrão escolhido por nós, a confirmar).
- Tudo isso mora em `Worker` (`scripts/worker.gd`), que o fazendeiro estende; os clones vão
  estender o mesmo.

## Números (Richard: "ficam assim por enquanto", 2026-10-07)
Tecla E (ou Espaço), 1 s por ação, 8 s para crescer depois de regado, 1 de produção por
colheita.

## Descartado
- Ações instantâneas (versão da primeira fatia): sem motivo para Ferramentas.
- Agir de longe (até 1,6 m do canteiro) e andar para cancelar (versão de 85e5fb4): o
  resultado aparecia sem o trabalhador estar no canteiro.
- Segurar E durante a ação.
