# Steam store text: French

Translated 2026-10-10 from `en.md`. Paste each block into the matching Steamworks field
(French). Tags, video lines and placeholders are the English file's, byte for byte.

## Short description (300 characters at most)

```
Lance ton filet, nettoie un lac crasseux et ramène la nature dans ce jeu cosy et relaxant. Avec l'aide de chiens adorables, recycle les déchets et gagne de quoi améliorer ton matériel. Trouve et lave des trésors cachés dans un mini-jeu satisfaisant, puis décore ta maison. La faune te remercie.
```

## About This Game

```
[h2][b][i]Un jeu cosy, relaxant et satisfaisant.[/i][/b][/h2]
[p][i][b]Améliore ton filet[/b][/i]
Augmente sa force, sa taille, sa chance, le lancer double et bien plus pour attraper tous les objets du lac.[video mp4="{STEAM_APP_IMAGE}/extras/fbdd021108c853c82b6665cb58c471ec.mp4" webm="{STEAM_APP_IMAGE}/extras/fbdd021108c853c82b6665cb58c471ec.webm" poster="{STEAM_APP_IMAGE}/extras/fbdd021108c853c82b6665cb58c471ec.poster.avif" autoplay="true" controls="false"][/video][/p]
[p][b][i]Tout n'est pas bon à jeter.[/i][/b]
Lave des trésors cachés et décore ta maison douillette.
[video mp4="{STEAM_APP_IMAGE}/extras/e42907505f6800775e2db8fb3ee2ab2d.mp4" webm="{STEAM_APP_IMAGE}/extras/e42907505f6800775e2db8fb3ee2ab2d.webm" poster="{STEAM_APP_IMAGE}/extras/e42907505f6800775e2db8fb3ee2ab2d.poster.avif" autoplay="true" controls="false"][/video][/p]
[p][b][i]De la crasse à la beauté.[/i][/b]
Regarde la faune reprendre sa place à mesure que tu nettoies le lac.[/p]
[p][video mp4="{STEAM_APP_IMAGE}/extras/ed5eeb2f67e3b9a7d6ed11d137cc16c0.mp4" webm="{STEAM_APP_IMAGE}/extras/ed5eeb2f67e3b9a7d6ed11d137cc16c0.webm" poster="{STEAM_APP_IMAGE}/extras/ed5eeb2f67e3b9a7d6ed11d137cc16c0.poster.avif" autoplay="true" controls="false"][/video]

[i][b]Affronte les éléments.[/b][/i]
Dompte une tornade avec ton filet.
[video mp4="{STEAM_APP_IMAGE}/extras/6f3b5dd1de6130437f1fb34a8b96eb6d.mp4" webm="{STEAM_APP_IMAGE}/extras/6f3b5dd1de6130437f1fb34a8b96eb6d.webm" poster="{STEAM_APP_IMAGE}/extras/6f3b5dd1de6130437f1fb34a8b96eb6d.poster.avif" autoplay="true" controls="false"][/video][/p]
[p][b][i]Fonctionnalités[/i][/b]

- Joue à ton rythme. Rien dans le jeu ne viendra te presser.
- Compatible avec les manettes Xbox et PlayStation
- Succès Steam
- Plus de 50 objets de collection à laver pour décorer ta maison
- Une faune vivante et interactive
- Un gameplay relaxant et satisfaisant[/p]
```

## Back-translation

Short description:

> Cast your net, clean a filthy lake and bring nature back in this cozy and relaxing game.
> With the help of adorable dogs, recycle the trash and earn enough to upgrade your gear.
> Find and wash hidden treasures in a satisfying mini-game, then decorate your house. The
> wildlife thanks you.

About This Game:

> A cozy, relaxing and satisfying game.
> **Upgrade your net** — Increase its strength, its size, its luck, the double cast and
> much more to catch all the objects in the lake.
> **Not everything is fit to throw away.** — Wash hidden treasures and decorate your snug
> house.
> **From grime to beauty.** — Watch the wildlife take back its place as you clean the lake.
> **Face the elements.** — Tame a tornado with your net.
> **Features**
> - Play at your own pace. Nothing in the game will come to rush you.
> - Compatible with Xbox and PlayStation controllers
> - Steam Achievements
> - More than 50 collectibles to wash to decorate your house
> - A living and interactive wildlife
> - A relaxing and satisfying gameplay

## Notes

- **Short description: 294 characters** (Python `len`), under the 300 limit. To fit, "Cast
  your net to clean... and bring back" became three verbs in a row ("Lance, nettoie,
  ramène"), and "Wildlife appreciates your work" became "La faune te remercie" (thanks
  you), which echoes the game's own ending line (`END_LINE_1`, "La nature... te remercie").
- **"tu", not "vous"**, as the style guide and every string in the game. Many French store
  pages say "vous"; a reviewer may prefer it for the store, but then the page and the game
  speak in two registers.
- **"cosy"** kept as a loanword: it is Steam's own French tag and common in French gaming
  press. "Douillette" carries "cozy house" in the About text so the word is not repeated.
- **Glossary terms**: filet, maison, lac, faune, tornade, laver, décorer; "Dompte" is the
  game's verb for the tornado (`TORNADO_FIRST`). The upgrade list is written as prose
  ("sa force, sa taille, sa chance, le lancer double"), lower case, matching the game's
  rows Force / Taille / Chance / Double and its prose "lancers doubles" (`TOUR_SHOP_ON_CAST`).
- **"Chance" = luck** reads as good fortune, not gambling (no "pari", "jackpot", "mise").
- **"Not every find is trash" → "Tout n'est pas bon à jeter"**, an idiom (not everything is
  fit for the bin), not a calque of "find".
- **Gender**: "Avec l'aide de chiens adorables" avoids "Aidé de" (masculine). No participle
  agrees with the player anywhere.
- **"crasseux"** for dirty: filthy water only, no sexual or personal reading (unlike "sale"
  in some phrases).
- **"Succès Steam"** is Steam's French term for Achievements; "PlayStation" capitalised.
- **"Plus de 50 objets de collection à laver pour décorer ta maison"**: "to wash and
  decorate" made explicit as washing in order to decorate the house (in French "décorer des
  objets" would mean ornamenting them, and "pour décorer" with no object read unfinished).
- **No ! ? : ;** in the text, so no U+00A0 was needed. Straight apostrophes, as the game's table.
- "Features" → "Fonctionnalités", the usual Steam FR heading; "gameplay" is the accepted
  French gaming word.

## Review

Independent review, 2026-10-10.

Changed:
- Short description: "...dans un mini-jeu satisfaisant pour décorer ta maison" to "...dans
  un mini-jeu satisfaisant, puis décore ta maison": as written, the washing mini-game was
  what decorates the house. Same length (294).
- Features: "à laver pour décorer" ended with no object and read unfinished; now "à laver
  pour décorer ta maison". Back-translation and note updated.

Checked, no change: no "pigeon", "sale" or other second meaning; "chance" reads as good
fortune, not betting; tu throughout, no participle agreeing with the player ("Avec l'aide
de" kept); "Succès Steam" is Steam's term; no ! ? : ; anywhere, so no U+00A0 needed;
straight apostrophes.

Left for the owner:
- "tu" on the store page matches the game; many French store pages say "vous".

Checked by script: every BBCode tag, `[video ...]` line, URL and `{STEAM_APP_IMAGE}` is the
same as `en.md`, line by line, with the same 21 lines and the same blank lines.
