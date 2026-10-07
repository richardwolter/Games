# Carregar, comida e as 4 características que faltavam

**Richard disse "pode" em 2026-10-07** a Carregar com 3 destinos, comida e as 4
características restantes. O desenho geral já estava decidido (`2026-10-07-nucleo.md`):
produção vai para máquina, cocho e venda; clones comem todo dia e não expiram; só o
fazendeiro conserta desastres. Os detalhes e números abaixo são **padrões nossos, a confirmar
jogando**.

## Carregar
- A colheita não vai mais direto pra um contador: **cai como caixote no chão**, no canto do
  canteiro (Caprichoso: 2 caixotes).
- Pegar um caixote: ir até ele, E, 0,5 s. Leva **1 por vez** (Forte: 2). O caixote vai em
  cima da cabeça.
- Entregar: ir até o destino, E, 0,5 s. Destinos:
  - **Máquina**: o estoque dela é o que clonar gasta (3 por clone). Começa com 5.
  - **Cocho**: comida dos clones.
  - **Venda**: cada caixote vira $1 (contador de dinheiro no HUD).
- **Função Carregar**: no painel do clone, 4 = Carregar, e depois 1 Máquina, 2 Cocho,
  3 Venda. O clone pega os caixotes livres mais perto até encher as mãos e leva ao destino.
- Com caixote na mão, E na máquina entrega (não clona).

## Comida (sem ciclo de dia ainda)
- A cada **60 s** cada clone deve 1 de comida (Glutão 2, Preguiçoso 0,5). Quando deve 1
  inteiro, **vai até o cocho e come** (1 s), mesmo com caixote na mão.
- Cocho sem comida: fica **COM FOME** (Vel. de trabalho -50%, etiqueta vermelha) e tenta de
  novo a cada 10 s.
- O intervalo é constante (`Traits.MEAL_EVERY`); vira "por dia" quando o dia existir.

## As 4 características novas
| Característica | Lado bom | Lado ruim (sempre visível) |
|---|---|---|
| Forte | Capacidade de carga +1 (leva 2) | Pisoteio: planta por onde ele anda vira canteiro pisoteado; só o fazendeiro conserta (E, 2 s, volta a vazio); balão "ops! pisou" |
| Glutão | +50% vel. de trabalho por 20 s depois de comer | Consumo x2 |
| Beliscador | Não usa o cocho (se alimenta sozinho, nunca passa fome) | Desperdício: come 1 a cada 4 caixotes que colhe ou pega; balão "nham!" |
| Preguiçoso | Consumo x0,5 | Pausas: cochila 4 s a cada 15 s, mesmo no meio da tarefa; balão "zzz" |

Com isso as 8 características do rascunho aprovado estão no jogo, e o sorteio é entre as 8.

## O que ainda falta da Fase 2
Reciclar clone, as 3 lojas, o dia com meta.
