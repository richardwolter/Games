# Protótipo completo: reciclar, dia com meta, lojas, log de playtest

**Richard em 2026-10-29:** "prosseguir, vamos estruturar todo o protótipo para eu testar
como um todo." Fecha o que faltava de `docs/scope.md`. Números e controles são **padrões
nossos, a confirmar jogando**.

## Reciclar
- No painel do clone (E no clone), **R** manda reciclar. O clone anda até a máquina, trabalha
  2 s nela e some. Devolve **2** ao estoque da máquina (clonar custa 3: reciclar nunca dá lucro).

## Dia com meta
- Dia de **4 min**, relógio no topo. Meta = dinheiro **vendido naquele dia**: **$5 no dia 1,
  +$3 por dia** ($5, $8, $11...).
- Fim do dia: o jogo pausa num resumo (vendido, meta, clones, comida usada, dinheiro).
  Bateu: E/Enter vai para o próximo dia (fazenda continua como está). Não bateu: **fim de
  jogo** com os dias sobrevividos; E/Enter/R começa outra partida.

## Comida
O pedido foi "comem no fim do dia". **Mantive a ida ao cocho**, mas de 120 em 120 s: 2
refeições por dia de 4 min, consumo base **2 por dia** (Glutão 4, Preguiçoso 1).
- Por quê: comer no fim do dia seria "mágico" (a comida some sem ninguém ir ao cocho), e
  Richard pediu que nada aconteça por mágica. Indo ao cocho, a fome e o custo da comida
  aparecem na hora, no meio do dia.
- Sem comida: COM FOME (-50% Vel. de trabalho) até comer.

## Lojas
Na Venda: **E de mãos vazias** abre o menu; 1-3 compram. Preços chutados:
| Loja | Efeito | Níveis e preço |
|---|---|---|
| Terra | +3 canteiros (uma fileira) | $10, $20 |
| Máquina | +1 característica nos clones novos (3 em vez de 2) | $15 |
| Ferramentas | +25% Vel. de trabalho do fazendeiro e dos clones | $12, $24 |
A % do painel do clone já leva em conta os canteiros e as ferramentas compradas.

**Contradição aberta continua:** a melhoria da Máquina dá mais características, mas como
todas são trocas, isso não deixa o clone "melhor" por si só. Richard também disse "clones
novos tendem a ser melhores". O teste deve mostrar se falta essa sensação.

## Log de playtest
Cada partida grava `docs/playtests/AAAA-MM-DD_runN.log`, um bloco por dia: vendido, meta,
dinheiro, estoques, comida, entregas por destino, compras, e por clone: características,
função, tarefas feitas, pulos, cochilos, conversas, caixotes beliscados, plantas pisoteadas,
tempo com fome e tempo parado.

## Como jogar
Cartão com todas as teclas no canto da tela; **H** mostra/esconde.
