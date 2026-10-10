# Steam store text: Spanish

Translated 2026-10-10 from `en.md` (neutral Spanish for Spain and Latin America, tú).
Paste each block into the matching Steamworks field for Spanish.

## Short description (300 characters at most)

```
Lanza tu red, limpia un lago sucio y haz que vuelva la naturaleza en este juego acogedor y relajante. Con la ayuda de perros adorables, recicla basura y gana dinero para mejorar tu equipo. Encuentra tesoros, lávalos en un minijuego satisfactorio y decora tu casa. La vida silvestre te lo agradece.
```

## About This Game

```
[h2][b][i]Un juego acogedor, relajante y satisfactorio.[/i][/b][/h2]
[p][i][b]Mejora tu red[/b][/i]
Aumenta su fuerza, su tamaño, su suerte, el lanzamiento doble y más para atrapar todos los objetos del lago.[img src="{STEAM_APP_IMAGE}/extras/01_cast_west"][/img][/p]
[p][b][i]No todo lo que encuentras es basura.[/i][/b]
Lava tesoros escondidos y decora tu acogedora casa.
[img src="{STEAM_APP_IMAGE}/extras/06_wash_place"][/img][/p]
[p][b][i]De la mugre a la belleza.[/i][/b]
Mira cómo la vida silvestre recupera su lugar mientras limpias el lago.[/p]
[p][img src="{STEAM_APP_IMAGE}/extras/08_grime_to_beauty"][/img]

[i][b]Enfréntate a los elementos.[/b][/i]
Doma un tornado con tu red.
[img src="{STEAM_APP_IMAGE}/extras/09_tornado_orbit"][/img][/p]
[p][b][i]Características[/i][/b]

- Juega a tu ritmo. En este juego no hay ninguna prisa.
- Compatible con controles de Xbox y PlayStation
- Logros de Steam
- Más de 50 coleccionables para lavar y decorar
- Vida silvestre animada e interactiva
- Jugabilidad relajante y satisfactoria[/p]
```

## Back-translation

Short description:

> Cast your net, clean a dirty lake and make nature come back in this cozy and relaxing game. With the help of adorable dogs, recycle trash and earn money to improve your gear. Find treasures, wash them in a satisfying minigame and decorate your house. Wildlife thanks you for it.

About This Game:

> **A cozy, relaxing and satisfying game.**
> **Upgrade your net.** Increase its strength, its size, its luck, the double cast and more to catch all the objects in the lake.
> **Not everything you find is trash.** Wash hidden treasures and decorate your cozy house.
> **From grime to beauty.** Watch how wildlife recovers its place while you clean the lake.
> **Face the elements.** Tame a tornado with your net.
> **Features**
> - Play at your pace. In this game there is no hurry at all.
> - Compatible with Xbox and PlayStation controllers
> - Steam Achievements
> - More than 50 collectibles to wash and decorate
> - Lively and interactive wildlife
> - Relaxing and satisfying gameplay

## Notes

- Short description: **297 characters** (Python `len`), limit 300. To fit, "hidden" was dropped
  ("Encuentra tesoros", not "tesoros escondidos"); it is kept in About This Game. "Lots of"
  was dropped too.
- All BBCode tags, `[video ...]` lines, URLs and `{STEAM_APP_IMAGE}` placeholders are
  byte-for-byte the English ones (checked by script), same line count.
- Terms follow the game: red, fuerza, tamaño, suerte, lanzamiento doble (the tour cards'
  wording; the shop row itself reads just "Doble"), atrapar, casa, vida silvestre (glossary,
  not "fauna"), dómalo/doma for the tornado. The upgrade names are lowercase here, as in
  the English sentence, rather than the shop's capitalised labels.
- "Controller" is **"controles"**, not "mando": "mando" was flagged as a trap in the game's
  Spanish. "controles" is the Latin-American word and understood in Spain.
- "Logros de Steam" is Steam's own Spanish term for Steam Achievements.
- "Play at your own pace. Nothing in the game is going to rush you." became "Juega a tu
  ritmo. En este juego no hay ninguna prisa." because "apurar" (LatAm) means something
  else in Spain and "meter prisa" is Spain only.
- "Face the elements" is "Enfréntate a los elementos", which reads naturally on both
  sides of the Atlantic.
- "De la mugre a la belleza": "mugre" (grime) is common and harmless everywhere; a
  reviewer may prefer "De la suciedad a la belleza".
- "cute dogs" is "perros adorables" (neutral; "lindos" is LatAm-leaning, "monos" Spain-only).
- "lago sucio" reads only as filthy water, no second meaning.
- Player gender: every sentence speaks to "tú" with imperatives; no adjective agrees with
  the player.

## Review

Independent review, 2026-10-10.

Changed:
- Short description: "Con perros adorables de ayudantes" to "Con la ayuda de perros
  adorables" (smoother, and one character shorter: 297). Back-translation updated.

Checked, no change: no regional second meaning found (red, lago sucio, mugre, doma, atrapar;
no "coger", "manada", "goma", "mando", "bono"); "suerte" and "lanzamiento doble" read as
fishing luck, not betting; tú throughout with no adjective agreeing with the player;
"Logros de Steam" is Steam's own term; PlayStation spelled right.

Left for the owner:
- **Steamworks has two Spanish fields** (Spain, Latin America). This neutral text works in
  both, but "controles" is the Latin-American word (the game's own es column also says
  "Control"); a Spain-only field would normally say "mandos".
- "satisfactorio / satisfactoria" is common in Spanish gaming copy for "satisfying";
  "gratificante" is the alternative if it reads as "merely adequate" to a native.

Checked by script: every BBCode tag, `[video ...]` line, URL and `{STEAM_APP_IMAGE}` is the
same as `en.md`, line by line, with the same 21 lines and the same blank lines.
