# Máquina de clonagem e primeiro clone

**Richard aprovou a fatia em 2026-10-07** ("sim" à proposta da conversa do projeto:
máquina + clone + função + características). Os números e os controles abaixo são padrões nossos,
**a confirmar com ele jogando**.

## Como ficou
- **Máquina**: caixa roxa na fazenda. O fazendeiro chega, aperta E, fica 2 s trabalhando
  nela (mesma regra dos canteiros: fixo no lugar, E de novo cancela) e sai um clone ao lado.
  Custa **3 de produção**; sem produção suficiente a máquina não aceita.
- A fazenda começa com **5 de produção**, para dar o primeiro clone logo.
- **Dar função**: E perto de um clone abre a escolha no HUD; **1 Plantar, 2 Regar,
  3 Colher, 0 nenhuma**. E de novo, ou se afastar, fecha.
- **Clone sem função fica parado.** Com função, ele escolhe o canteiro mais perto que
  precisa daquela função e que ninguém está trabalhando, vai até ele, trabalha (mesmas
  regras do fazendeiro: fixo no canteiro, balançando, barra) e repete.
- Clones são azuis, o fazendeiro vermelho; etiqueta sobre o clone com nome e função.
- Trabalhadores (fazendeiro e clones) se atravessam; não se empurram.

## Características nesta fatia
Cada clone nasce com **2 características diferentes**, sorteadas entre as 4 que não dependem
de comida nem de carregar (lista aprovada em `2026-10-07-caracteristicas.md`). Os dados
ficam em `scripts/traits.gd`, como lista de modificadores; o clone recalcula tudo do zero.

| Característica | Lado bom | Lado ruim (sempre visível) |
|---|---|---|
| Apressado | anda e trabalha 1,5x | 25% de chance de terminar o tempo e **não** fazer: balão "pulou!" e larga o canteiro por 3 s |
| Caprichoso | nunca erra (anula o "pulou"); colheita rende +1 | trabalha a 0,6x |
| Dedo Verde | canteiro que ele planta ou rega cresce 2x mais rápido | colhe a 0,33x |
| Animado | clones a até 3 m dele trabalham 1,3x | a cada 8 s, se tem clone perto, para 2 s (mesmo no meio da tarefa): balão "conversando..." |

Forte, Glutão, Beliscador e Preguiçoso entram junto com Carregar e comida.

## Fora desta fatia
Comer/cocho, Carregar, reciclar, lojas, dia e meta.

## Padrões a confirmar
Custo 3, produção inicial 5, 2 s para clonar, E + números para dar função, clone sem
função parado, e todos os números da tabela de características.
