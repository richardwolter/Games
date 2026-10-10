# Steam store text: Brazilian Portuguese

## Short description (300 characters at most)

```
Lance sua rede para limpar um lago sujo e trazer a natureza de volta neste jogo aconchegante e relaxante. Com a ajuda de cães fofos, recicle o lixo e ganhe dinheiro para melhorar seu equipamento. Ache e lave tesouros escondidos num minigame satisfatório e decore sua casa. A vida selvagem agradece.
```

## About This Game

```
[h2][b][i]Um jogo aconchegante, relaxante e satisfatório.[/i][/b][/h2]
[p][i][b]Melhore sua rede[/b][/i]
Aumente a força, o tamanho, a sorte, o lançamento duplo e muito mais para pegar todos os objetos do lago.[img src="{STEAM_APP_IMAGE}/extras/01_cast_west"][/img][/p]
[p][b][i]Nem tudo o que você encontra é lixo.[/i][/b]
Lave tesouros escondidos e decore sua casa aconchegante.
[img src="{STEAM_APP_IMAGE}/extras/06_wash_place"][/img][/p]
[p][b][i]Da sujeira à beleza.[/i][/b]
Veja a vida selvagem voltar ao seu lugar enquanto você limpa o lago.[/p]
[p][img src="{STEAM_APP_IMAGE}/extras/08_grime_to_beauty"][/img]

[i][b]Enfrente os elementos.[/b][/i]
Dome um tornado com sua rede.
[img src="{STEAM_APP_IMAGE}/extras/09_tornado_orbit"][/img][/p]
[p][b][i]Recursos[/i][/b]

- Jogue no seu ritmo. Nada no jogo vai te apressar.
- Suporte a controles de Xbox e PlayStation
- Conquistas Steam
- Mais de 50 colecionáveis para lavar e decorar
- Vida selvagem viva e interativa
- Jogabilidade relaxante e satisfatória[/p]
```

## Back-translation

Short description:

Cast your net to clean a dirty lake and bring nature back in this cozy and relaxing game. With the help of cute dogs, recycle the trash and earn money to improve your equipment. Find and wash hidden treasures in a satisfying minigame and decorate your house. The wildlife thanks you.

About This Game:

A cozy, relaxing and satisfying game.
Improve your net
Increase the Strength, the Size, the Luck, the Double and much more to catch all the objects in the lake.
Not everything you find is trash.
Wash hidden treasures and decorate your cozy house.
From dirt to beauty.
See the wildlife come back to its place while you clean the lake.
Face the elements.
Tame a tornado with your net.
Features
- Play at your own pace. Nothing in the game is going to rush you.
- Support for Xbox and PlayStation controllers
- Steam Achievements
- More than 50 collectibles to wash and decorate
- Living and interactive wildlife
- Relaxing and satisfying gameplay

## Notes

- Short description: 298 characters (Python `len()`), under the 300 limit.
- **Shop names capitalised** in "Aumente a Força, o Tamanho, a Sorte, o Dobro": they are the
  game's own row names (`TRACK_NET_STRENGTH`, `TRACK_NET_WIDTH`, `TRACK_LUCKY_HAUL`,
  `TRACK_DOUBLE_CAST`), so a player meets the same words in the shop. "o Dobro" only reads
  right as a name; written lowercase it would read as "twice as much". If that is too cryptic
  for a store reader, the alternative is "o lançamento duplo", which the game does not use.
- "Upgrade" is **melhorar / Melhore**, as the game's "Melhorias" and "Melhore a Força".
- "Catch" is **pegar**, the game's verb ("pegar objetos com a rede"); "Tame" is **domar**, as
  `TORNADO_FIRST` ("dome-o com sua rede").
- "Cozy" is **aconchegante**, the usual Steam pt-BR word for the genre.
- Short description: "in a satisfying mini-game to decorate your house" reordered to "Ache e
  lave tesouros escondidos num minigame satisfatório e decore sua casa" so the minigame is the
  washing and decorating is its own verb; "Lots of" dropped and "with cute dogs as helpers" made "com a ajuda de cães fofos" to fit the length. "Wildlife
  appreciates your work" became "A vida selvagem agradece" (the natural idiom).
- "Not every find is trash" → "Nem tudo o que você acha é lixo" (achar = find, as
  `TROPHY_FOUND` "Achou uma decoração!"). "Grime" → "sujeira".
- "Features" → **Recursos** (common on pt-BR Steam pages); "Destaques" is the alternative.
- "Steam Achievements" → **Conquistas Steam**, Steam's own pt-BR term. "Playstation" fixed to
  "PlayStation".
- "Nada no jogo vai te apressar" uses the informal "te", as the game's own text does
  ("te ensinarão"). Every line addresses "você" with no gendered adjective for the player.

## Review

Independent review, 2026-10-10.

Nothing changed. Read for second meanings (lago sujo, pegar, rede, cães fofos), gambling
(Sorte, Dobro), player gender (none: imperatives and "você"), meaning against `en.md`, and
Steam's terms ("Conquistas Steam", PlayStation). Short description 298 characters.

Left for Richard:
- **"o Dobro"** in the upgrade list is the shop's own row name and the game explains it
  (`CUE_DOUBLE`: "O Dobro lança uma cópia da sua rede"), but a store reader has not seen the
  shop yet. "o lançamento duplo" (`TOUR_SHOP_ON_CAST`) is the clearer alternative.
- **"Nem tudo o que você acha é lixo"**: "achar" is the game's verb (`TROPHY_FOUND`); it can
  also be read as "think", though not in this sentence. "encontra" removes that if wanted.

Checked by script: every BBCode tag, `[video ...]` line, URL and `{STEAM_APP_IMAGE}` is the
same as `en.md`, line by line, with the same 21 lines and the same blank lines.

## Owner decisions (2026-10-10)

- Upgrade list in plain words: "a força, o tamanho, a sorte, o lançamento duplo" (was the shop's row names, "o Dobro" unclear to a store reader).
- "Nem tudo o que você encontra é lixo" (was "acha", which can read as "think").
