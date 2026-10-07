# Painel do clone: atributos e recomendação de função

**Pedidos de Richard em 2026-10-07:** "mostrar os efeitos dos atributos de forma concisa na
UI, para que a decisão seja mais prática"; depois: "se formos recomendar algo, precisa fazer
sentido matematicamente", com termos comuns de video game ("-40% trabalha" não dizia se era
tarefa ou movimento). Richard: "ok, está bom por enquanto"; um card melhor ficou para depois
(`docs/ideias.md`).

## Nomes fixos dos atributos (usados em todo lugar)
| Atributo | O que é |
|---|---|
| Vel. de movimento | quão rápido anda |
| Vel. de trabalho | quão rápido faz a tarefa (por função quando difere, ex. Dedo Verde colhe -67%) |
| Pós-refeição | bônus de vel. de trabalho por um tempo depois de comer (Glutão) |
| Chance de falha | trabalha o tempo todo e a tarefa no canteiro não sai (Apressado) |
| Rendimento | caixotes extras por colheita (Caprichoso) |
| Crescimento | velocidade de crescimento dos canteiros que ele planta ou rega (Dedo Verde) |
| Capacidade de carga | caixotes que leva de uma vez (Forte) |
| Consumo | comida do cocho por refeição, ou "não usa o cocho" (Glutão, Preguiçoso, Beliscador) |
| Desperdício | caixotes que ele come ao colher ou pegar (Beliscador) |
| Pausas | conversa com clone perto (Animado), cochila (Preguiçoso) |
| Aura | bônus de vel. de trabalho dos clones perto (Animado); **fora da %** |
| Pisoteio | destrói plantas por onde anda (Forte); **fora da %** |

O painel mostra o atributo **combinado** do clone (as características multiplicam), verde se
bom, vermelho se ruim; só aparecem os que mudam.

## A % de cada função
"Produção líquida da fazenda com ele nessa função, comparada com um clone comum nessa
função." Líquida = caixotes entregues por segundo menos o que ele come do cocho.

Modelo de regime estável:
- Funções de canteiro: um trabalhador comum em cada uma das outras duas, carregadores
  suficientes, os canteiros atuais, 3 m de caminhada entre tarefas.
- Carregar: caixotes suficientes, 3 m entre um caixote e outro, 8 m até o destino.
- Ele come todo minuto e o cocho tem comida (sem fome).

Fórmulas:
- Tempo de trabalho com Pós-refeição: média ponderada, `f = tempo do bônus / 60 s` com o
  bônus e `1 - f` sem.
- Fração em pausa `p`: cada pausa vem depois de X s de atividade, então `p = pausa / (X + pausa)`
  (Animado 2/(8+2) = 20%, conta como se sempre houvesse clone perto; Preguiçoso 4/(15+4)).
- Tarefa de canteiro: `T = (3 m / vel. de movimento + tempo da tarefa / vel. de trabalho) / (1 - chance de falha) / (1 - p)`
- Ciclo de um canteiro: `C = T_plantar + T_regar + T_colher + 8 s / crescimento`
- Colheitas por segundo: `R = mín(1/T_plantar, 1/T_regar, 1/T_colher, canteiros / C)`
- Caixotes por segundo: `R × (1 + rendimento) × (1 - desperdício)` (rendimento e desperdício só
  se ele é quem colhe)
- Carregar, por caixote: `(cap × (3 m / vel. mov + 0,5 s / vel. trab) + 8 m / vel. mov + 0,5 s / vel. trab) / cap / (1 - p)`;
  caixotes por segundo `= 1 / isso × (1 - desperdício)`
- Comida por segundo: `consumo / 60` (0 se não usa o cocho)
- **% = (caixotes/s - comida/s) com ele ÷ o mesmo com um clone comum**

Fica de fora: Aura e Pisoteio (dependem de onde as coisas estão) e a caminhada até o cocho.
"(melhor)" só aparece se a melhor função passa a segunda por 10 pontos ou mais.

### Exemplo (6 canteiros, Caprichoso colhendo)
Comum: T = 0,5 + 1 = 1,5 s; C = 3 × 1,5 + 8 = 12,5 s; R = mín(0,667; 6/12,5 = 0,48) = 0,48/s;
líquido 0,48 - 1/60 = 0,463/s.
Caprichoso colhendo: T_colher = 0,5 + 1/0,6 = 2,167 s; C = 1,5 + 1,5 + 2,167 + 8 = 13,17 s;
R = mín(0,667; 0,667; 0,462; 0,456) = 0,456/s; caixotes = 0,456 × 2 = 0,911/s; líquido 0,895/s.
0,895 / 0,463 = **193%**. Plantando: 95%. Regando: 95%. Recomendação: Colher.

O que o modelo mostra: com 6 canteiros o gargalo é o canteiro (o crescimento), então andar
ou trabalhar mais rápido quase não ajuda (Apressado plantando: 101%), e o Dedo Verde
plantando ou regando vale 140%. No Carregar, o Forte vale 150% e o Beliscador 79%.

Texto e % saem dos dados de `scripts/traits.gd` (`stat_rows`, `role_rating`); o harness
confere a % contra valores calculados à mão.
