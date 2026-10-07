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
- Um aperto de E começa a tarefa; o fazendeiro fica no canteiro até terminar; andar cancela,
  e o canteiro fica como estava. Barra amarela sobre o fazendeiro e "plantando... 40%" no HUD.
  (Escolha de implementação, não do Richard: aperto único em vez de segurar E.)

## Descartado
- Ações instantâneas (versão da primeira fatia): sem motivo para Ferramentas.
