# Clone Farm: escopo do protótipo 1 (rascunho para travar)

Consolida as decisões de 2026-10-07 (detalhes e descartes em `docs/decisoes/2026-10-07-nucleo.md`). Engine: **Godot**. Visual: **cinza** (formas simples), sem Synty.

## Pergunta que o protótipo responde
Escolher qual clone faz qual função, de acordo com características que são trocas, e correr atrás dos desastres deles, é divertido?

## Dentro
- **Fazendeiro** (você): WASD, faz qualquer função sem fraqueza; único que conserta desastres.
- **4 funções**: Plantar, Regar, Colher, Carregar. Clone recebe uma função e a executa na fazenda inteira até você trocar.
- **Máquina de clonagem**: consome produção; clone nasce com 2 características aleatórias (trocas).
- **Clones comem** produção todo dia (cocho). Não expiram.
- **Reciclar** clone: volta para a máquina, devolve parte da produção (menos que o custo).
- **Carregar** leva a produção a 3 destinos: máquina, cocho, venda.
- **3 lojas** com 1-2 itens cada: Terra (mais canteiros), Máquina (+1 característica por clone), Ferramentas (tarefa mais rápida).
- **Dia de 3-5 min**, meta diária em dinheiro vendido, crescente. Falhou = fim. Placar: dias sobrevividos.
- **Desastres visíveis** (canteiro pisoteado, carga no chão) que se acumulam.
- **Log de playtest** em arquivo: o que cada clone fez, desastres, tempo ocioso, dinheiro por dia.

## Fora
Arte final/Synty, som, menus, save, animais, noite, história, progressão longa, mais de 1-2 itens por loja.

## Abertos (não bloqueiam o início)
- Lista de características: aprovada para o protótipo (`docs/decisoes/2026-10-07-caracteristicas.md`).
- Contradição: "clones novos tendem a ser melhores" vs "melhoria = só mais slots". Protótipo vai mostrar.
- Números (custos, reembolso, metas): definidos no balanceamento, depois de jogar.

## Sucesso / corte (você julga, jogando)
- Sucesso: você troca funções entre clones várias vezes por dia; pelo menos uma situação engraçada por sessão; vontade de "mais um dia".
- Corte: após 2-3 iterações a atribuição continua óbvia → problema estrutural, rever decisões antes de qualquer arte.
