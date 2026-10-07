# Painel do clone: efeitos das características na tela

**Pedido de Richard em 2026-10-07:** "mostrar os efeitos dos atributos de forma concisa na
UI, para que a decisão seja mais prática". O formato abaixo é proposta nossa, a confirmar
jogando.

## Como ficou
Perto de um clone (e ao apertar E nele) o HUD mostra:
- Nome e função atual.
- Uma linha por característica, cada efeito com sinal e cor: verde "+50% anda", vermelho
  "-pula 25% das tarefas".
- Uma linha por função com uma **nota em %**, 100% = clone sem características; verde
  acima, vermelho abaixo; a melhor em negrito com "(melhor)". Com E aberto, as linhas
  ganham os números 1-3 para escolher.

A etiqueta sobre o clone continua curta: nome, função e nomes das características.

## Como a nota é calculada
`Traits.role_rating`: velocidade da tarefa × fração que ele não pula × fração do tempo que
não está conversando × produção extra na colheita. Fica de fora: andar (depende da
distância) e o bônus do Animado vizinho (depende de onde ele está). O "plantas crescem" do
Dedo Verde aparece na linha da característica mas não entra na nota (acelera o canteiro, não
o clone).

Tudo sai dos mesmos dados de `scripts/traits.gd`; nada é escrito à mão, então texto e nota
acompanham qualquer mudança de número.
