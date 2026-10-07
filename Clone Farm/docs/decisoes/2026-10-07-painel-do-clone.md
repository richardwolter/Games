# Painel do clone: atributos e recomendação de função

**Pedidos de Richard em 2026-10-07:** "mostrar os efeitos dos atributos de forma concisa na
UI, para que a decisão seja mais prática"; depois: "se formos recomendar algo, precisa fazer
sentido matematicamente", com termos comuns de video game ("-40% trabalha" não dizia se era
tarefa ou movimento). O formato é proposta nossa, a confirmar jogando.

## Nomes fixos dos atributos (usados em todo lugar)
| Atributo | O que é |
|---|---|
| Vel. de movimento | quão rápido anda |
| Vel. de trabalho | quão rápido faz a tarefa (por função quando difere, ex. Dedo Verde colhe -67%) |
| Chance de falha | trabalha o tempo todo e a tarefa não sai (Apressado) |
| Rendimento | produção extra por colheita (Caprichoso) |
| Crescimento | velocidade de crescimento dos canteiros que ele planta ou rega (Dedo Verde) |
| Pausas | para X s a cada Y s quando tem clone perto (Animado) |
| Aura | bônus de vel. de trabalho dos clones perto (Animado); **fora da %** |

O painel mostra o atributo **combinado** do clone (as características multiplicam), verde se
bom, vermelho se ruim; só aparecem os que mudam.

## A % de cada função
"Produção da fazenda com ele nessa função, comparada com um clone comum nessa função."
Modelo de regime estável: um trabalhador comum em cada uma das outras duas funções, os
canteiros atuais, 3 m de caminhada entre tarefas.

- Tempo por tarefa concluída: `T = (3 m / vel. de movimento + tempo da tarefa / vel. de trabalho) / (1 - chance de falha) / (1 - fração em pausa)`
- Ciclo de um canteiro: `C = T_plantar + T_regar + T_colher + 8 s / crescimento`
- Tarefas por segundo: `R = mín(1/T_plantar, 1/T_regar, 1/T_colher, canteiros / C)`
- Produção por segundo: `R × (1 + rendimento)`

Fica de fora a Aura (depende de onde os clones estão). As Pausas contam como se sempre houvesse
clone perto (pior caso). "(melhor)" só aparece se a melhor função passa a segunda por 10
pontos ou mais; senão, nenhuma recomendação.

### Exemplo (6 canteiros, Caprichoso colhendo)
Comum: T = 0,5 + 1 = 1,5 s; C = 3 × 1,5 + 8 = 12,5 s; R = mín(0,667; 6/12,5 = 0,48) = 0,48/s.
Caprichoso colhendo: T_colher = 0,5 + 1/0,6 = 2,167 s; C = 1,5 + 1,5 + 2,167 + 8 = 13,17 s;
R = mín(0,667; 0,667; 0,462; 0,456) = 0,456/s; produção = 0,456 × 2 = 0,911/s.
0,911 / 0,48 = **190%**. Plantando: 95%. Regando: 95%. Recomendação: Colher.

O que o modelo mostra: com 6 canteiros o gargalo é o canteiro (o crescimento), então andar
ou trabalhar mais rápido quase não ajuda (Apressado plantando: 101%), e o Dedo Verde
plantando ou regando vale 139%.

Texto e % saem dos dados de `scripts/traits.gd` (`stat_rows`, `role_rating`); o harness
confere a % contra valores calculados à mão.
