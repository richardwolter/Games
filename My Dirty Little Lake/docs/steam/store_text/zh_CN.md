# Steam store text: Simplified Chinese

Translated 2026-10-10 from `en.md`. Paste each block into the matching Steamworks field
(language: Simplified Chinese). Tags, video lines, URLs and placeholders are byte-for-byte
the English field's.

## Short description (300 characters at most)

```
在这款温馨治愈的游戏里，撒下渔网，把一片脏兮兮的湖清理干净，让大自然重新焕发生机。有可爱的狗狗帮忙，回收垃圾赚钱，升级你的装备。湖里藏着许多宝物等你发现，在解压的清洗小游戏里把它们洗干净，用来装饰你的房子。野生动物也会感谢你的付出。
```

## About This Game

```
[h2][b][i]轻松解压的温馨游戏。[/i][/b][/h2][p][i][b]升级你的渔网[/b][/i]
提升力量、尺寸、幸运、双网等能力，把湖里的物品统统捞上来。[img src="{STEAM_APP_IMAGE}/extras/01_cast_west"][/img][/p][p][b][i]捞到的不全是垃圾。[/i][/b] 
清洗藏在湖里的宝物，装饰你温馨的房子。
[img src="{STEAM_APP_IMAGE}/extras/06_wash_place"][/img][/p][p][b][i]从污浊到美景。[/i][/b] 
随着你清理湖泊，看野生动物重回家园。 [/p][p][img src="{STEAM_APP_IMAGE}/extras/08_grime_to_beauty"][/img] [b][i]
[/i][/b]

[b][i]迎战风雨。[/i][/b]  
用你的渔网驯服龙卷风。  
[img src="{STEAM_APP_IMAGE}/extras/09_tornado_orbit"][/img][/p][p]
[b][i]游戏特色
[/i][/b]

- 按自己的节奏来玩，游戏里没有任何事会催促你。  
- 支持 Xbox 和 PlayStation 手柄  
- Steam 成就   
- 超过 50 件收藏品等你清洗和装饰  
- 生机勃勃、可以互动的野生动物  
- 轻松解压的玩法[/p]
```

## Back-translation

Short description:

> In this warm, healing game, cast down your fishing net and clean a grubby lake, letting
> nature come back to life. With cute doggies helping, recycle trash to earn money and
> upgrade your gear. The lake hides many treasures waiting for you to discover; in a
> stress-relieving washing mini-game, wash them clean and use them to decorate your house.
> The wildlife will also thank you for your efforts.

About This Game:

> **Relaxing, stress-relieving, warm game.**
> **Upgrade your fishing net**
> Raise strength, size, luck, double net and other abilities, and bring up every object in
> the lake. [video]
> **What you catch isn't all trash.**
> Wash the treasures hidden in the lake, decorate your warm house. [video]
> **From murk to beautiful scenery.**
> As you clean the lake, watch the wildlife return to their home. [video]
> **Face the wind and rain.**
> Tame the tornado with your fishing net. [video]
> **Game features**
> - Play at your own rhythm; nothing in the game will hurry you.
> - Supports Xbox and PlayStation controllers
> - Steam Achievements
> - More than 50 collectibles waiting for you to wash and decorate
> - Lively wildlife you can interact with
> - Relaxing, stress-relieving gameplay

## Notes

- **Short description: 116 characters** (Python `len()`), well under 300. Chinese packs the
  same meaning into far fewer characters; nothing was cut.
- **Glossary terms match the game's own zh_CN**: 渔网 (net), 撒网 (cast), 力量 / 尺寸 / 幸运 /
  双网 (Strength / Size / Luck / Double cast, the shop row names), 房子 (house), 清洗 (wash),
  装饰 (decorate), 野生动物 (wildlife), 龙卷风 (tornado), 驯服 (tame, as in `TORNADO_FIRST`).
  "Gear" is 装备, which the game never names; it stays generic, as in English.
- **"Cozy" is 温馨, "satisfying" is 解压** (stress-relieving), the usual words on Chinese store
  pages for this genre. 治愈 ("healing", as in 治愈系) appears once in the short description;
  standard store wording, not slang. A reviewer may prefer 轻松 in its place.
- **"Treasures" / "finds" is 宝物**, not the game's 装饰品 (decoration), to keep the English
  tease: the reader does not know yet that they become furniture. 收藏品 for "collectibles".
- **"Face the elements" is 迎战风雨** ("face the wind and rain"): a literal 面对自然元素 reads as
  a calque. It suits the tornado shown under it and the game's storms.
- **"From grime to beauty" is 从污浊到美景** ("from murk to scenery"). 脏兮兮 ("grubby") for
  the dirty lake reads only as filthy water, with no second meaning.
- **"Not every find is trash" is 捞到的不全是垃圾** ("what you catch isn't all trash"), so it
  ties to the net.
- **Spacing**: Latin words and numbers carry a half-width space on either side (`Xbox`,
  `PlayStation`, `Steam 成就`, `50`), as Steam's own Simplified Chinese pages and the asked-for
  term "Steam 成就" do. This departs from the style guide's in-game no-space rule, which is
  about the game's own line breaking; drop the spaces if consistency with the game matters
  more.
- The features list keeps the source's bare items with no full stop, except the first,
  which is a sentence in English too.
- No safeguard hits found: no gambling reading of 幸运 / 双网 (both are the shop's own words),
  no political or regional terms, player addressed as 你, no gender assumed.

## Review

Independent review, 2026-10-10.

Nothing changed. Read for second meanings and political terms (none: 脏兮兮, 污浊, 迎战风雨
are plain), gambling (幸运, 双网 are the shop's own words, no 赌 or 奖池), 你 throughout, game
terms (渔网, 撒网, 力量 / 尺寸 / 幸运 / 双网, 房子, 驯服, 野生动物), Steam's term "Steam 成就",
PlayStation, and spacing: every Latin word and number carries a half-width space, consistently,
and the short description has none to carry.

Left for the owner:
- The spaced Latin words follow Steam's own Chinese pages, not the game's in-game no-space
  rule; drop them if the two should match.

Checked by script: every BBCode tag, `[video ...]` line, URL and `{STEAM_APP_IMAGE}` is the
same as `en.md`, line by line, with the same 21 lines and the same blank lines.
