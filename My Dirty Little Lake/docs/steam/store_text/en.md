# Steam store text: English (source)

Rebuilt 2026-10-10 from the public store page (app 5375170). The other languages are
translated from this file. Paste each block into the matching Steamworks field.

**Video tags** are Steamworks' own, `[img src="{STEAM_APP_IMAGE}/extras/<name>"][/img]`,
copied from the English field on 2026-10-10.

One fix against the live page: "strenght" is spelled "strength" here.

## Short description (300 characters at most)

```
Cast your net to clean up a dirty lake and bring nature back in this cozy, relaxing game. With cute dogs as helpers, recycle trash and earn money to upgrade your gear. Lots of hidden treasures to find and wash, in a satisfying mini-game to decorate your house. Wildlife appreciates your work.
```

## About This Game

```
[h2][b][i]A short, relaxing and satisfying clean-up[/i][/b][/h2][p][i][b]Upgrade your net[/b][/i]
Increase its strength, size, luck, double cast and more to catch all the objects in the lake.[img src="{STEAM_APP_IMAGE}/extras/01_cast_west"][/img][/p][p][b][i]Not every find is trash.[/i][/b] 
Wash hidden treasures and decorate your cozy house.
[img src="{STEAM_APP_IMAGE}/extras/06_wash_place"][/img][/p][p][b][i]From grime to beauty.[/i][/b] 
Watch wildlife reclaim its place as you clean the lake. [/p][p][img src="{STEAM_APP_IMAGE}/extras/08_grime_to_beauty"][/img] [b][i]
[/i][/b]

[b][i]Face the elements.[/i][/b]  
Tame a tornado with your net.  
[img src="{STEAM_APP_IMAGE}/extras/09_tornado_orbit"][/img][/p][p]
[b][i]Features
[/i][/b]

- Play at your own pace. Nothing in the game is going to rush you.  
- Controller Support for Xbox and Playstation  
- Steam Achievements   
- More than 50 collectibles to wash and decorate  
- Living and interactable wildlife  
- Relaxing and satisfying gameplay[/p]
```

## Live page drift and the short heading (2026-10-24)

- **The live English page was edited in Steamworks after this file was written.** Its heading
  reads "Relaxing and satisfying clean-up" (this file said "Relaxing and satisfying cozy game."),
  and a **"Fix your house."** section with a video now stands after the tornado's.
- **The heading now says the game is short**: "A short, relaxing and satisfying clean-up"
  (Richard's call, 2026-10-24; no hour count; see `docs/steam/pricing.md`, Japan, revisited).
  In Steamworks, change only the words of the first heading. **Don't paste the About block
  above whole**: it has no house section, because that video's tag is not recorded here.
- The other seven languages still read as on 2026-10-10 and have no house section. Each file
  has its new heading in a section like this one.
- **`steamworks/*.json` are the 2026-10-10 import files.** Importing them would delete the
  English house section. To import, export from Steamworks first (Store Page > localization
  export) and rebuild on that export.
