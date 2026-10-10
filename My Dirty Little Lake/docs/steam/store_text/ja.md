# Steam store text: Japanese

Translated 2026-10-10 from `en.md`. Paste each block into the matching Steamworks field
(language: Japanese). Machine translation with a self-review; no native check yet.

## Short description (300 characters at most)

```
あみを投げて、よごれた湖をきれいにし、自然を取りもどしましょう。のんびりくつろげる、ほっこりゲームです。かわいい犬たちもお手伝い。ゴミをリサイクルしてお金をかせぎ、道具を強化しましょう。湖にはお宝がたくさんかくれています。見つけたら、スッキリ気持ちいいミニゲームで洗って、家をかざりましょう。生き物たちも、あなたのがんばりに感謝しています。
```

## About This Game

```
[h2][b][i]のんびりスッキリ、ほっこりゲーム。[/i][/b][/h2]
[p][i][b]あみを強化[/b][/i]
パワー、大きさ、ラッキー投げ、ダブル投げなどを強化して、湖のものをぜんぶ取りましょう。[img src="{STEAM_APP_IMAGE}/extras/01_cast_west"][/img][/p]
[p][b][i]取ったものが、ぜんぶゴミとはかぎりません。[/i][/b]
かくれたお宝を洗って、居心地のいい家をかざりましょう。
[img src="{STEAM_APP_IMAGE}/extras/06_wash_place"][/img][/p]
[p][b][i]よごれた湖から、美しい湖へ。[/i][/b]
湖をきれいにしていくと、生き物たちがすみかを取りもどしていきます。[/p]
[p][img src="{STEAM_APP_IMAGE}/extras/08_grime_to_beauty"][/img]

[i][b]自然の力に立ち向かう。[/b][/i]
たつまきを、あみでしずめましょう。
[img src="{STEAM_APP_IMAGE}/extras/09_tornado_orbit"][/img][/p]
[p][b][i]ゲームの特徴[/i][/b]

- 自分のペースで遊べます。ゲームにせかされることはありません。
- XboxとPlayStationのコントローラーに対応
- Steam実績
- 洗ってかざれるアイテムが50個以上
- あなたに反応する、生き生きとした生き物たち
- のんびりスッキリ、気持ちのいいゲームプレイ[/p]
```

## Back-translation

Short description:

> Throw the net, clean the dirty lake, and bring nature back. It is a relaxing,
> heartwarming game. Cute dogs help too. Recycle the trash, earn money, and upgrade your
> tools. Lots of treasures are hidden in the lake. When you find them, wash them in a
> refreshing, feel-good mini-game and decorate your house. The living creatures are
> grateful for your hard work, too.

About This Game:

> **Laid-back and refreshing, a heartwarming game.**
> **Upgrade the net**
> Upgrade Power, Size, Lucky casts, Double casts and more, and catch every object in the
> lake. [video]
> **Not everything you catch is necessarily trash.**
> Wash the hidden treasures and decorate your comfortable house. [video]
> **From a dirty lake to a beautiful lake.**
> As you keep cleaning the lake, the living creatures take back their home. [video]
> **Stand up to the forces of nature.**
> Calm the tornado with your net. [video]
> **Features of the game**
> - You can play at your own pace. You will never be rushed by the game.
> - Supports Xbox and PlayStation controllers
> - Steam Achievements
> - More than 50 items you can wash and decorate with
> - Lively living creatures that react to you
> - Laid-back, refreshing, feel-good gameplay

## Notes

- **Short description: 170 characters** (python `len()`), limit 300.
- **Register**: sentences in です／ます, as the style guide asks and as the game itself speaks
  (Japanese store blurbs commonly do the same for a gentle, all-ages tone). Headings are
  short noun or plain phrases with no です／ます, which is how Japanese store headings read;
  the bullet list is noun phrases except the first, which is two full sentences in English.
- **Game terms**: net is あみ in hiragana (the game never writes 網); Strength is パワー and
  Size 大きさ (the shop's rows); luck and double cast are written ラッキー投げ／ダブル投げ, the
  game's in-sentence forms (its shop rows are bare ラッキー／ダブル, which read oddly in a
  list); house 家; trash ゴミ; wildlife 生き物たち; tornado たつまき; "tame" しずめる, as in
  `TORNADO_FIRST`. "Cozy house" is 居心地のいい家.
- **"cozy game"** is ほっこりゲーム, the usual Japanese tag for cosy games. **"satisfying"** is
  スッキリ (the word for the satisfaction of cleaning) and 気持ちいい／気持ちのいい; check these
  read as natural store copy and not as a second meaning.
- **"treasures"** is お宝 (the English store says treasures; the game calls a washed find
  インテリア). Kept as the marketing word, by choice; swap for インテリア if the store should
  echo the game.
- **"gear"** is 道具 (tools/equipment), not a katakana loan.
- **"Face the elements"** became 自然の力に立ち向かう ("stand up to the forces of nature"); a
  literal "elements" (エレメント) means nothing here.
- **"collectibles"** became アイテム, counted 個 (each find is unique, so 50個以上).
- **"interactable wildlife"** became "creatures that react to you": the animals flee,
  frogs croak, the peacock fans its tail; ふれあえる ("you can touch/pet them") was avoided
  because only the dogs are petted.
- Tags, `[video ...]` lines, URLs and `{STEAM_APP_IMAGE}` are byte-for-byte from `en.md`;
  line structure kept, including the blank lines. No spaces between Japanese and Latin
  words (XboxとPlayStation, Steam実績), per the style guide. "Playstation" fixed to
  "PlayStation".
- Safeguards checked: よごれた (filthy, not indecent); ゴミ only for objects, never people;
  ラッキー／ダブル in a fishing sense, no gambling words (賭け, ギャンブル); no ほりもの or other
  traps; the player is "あなた", no gender.

## Review

Independent review, 2026-10-10.

Nothing changed. Read for second meanings (よごれた, スッキリ, ゴミ only for objects, no
ほりもの), gambling (ラッキー投げ／ダブル投げ, no 賭け or ギャンブル), です／ます in sentences with
plain headings, game terms (あみ, パワー, 大きさ, たつまき, しずめる, 家, 生き物たち), Steam's
term "Steam実績", PlayStation, and spacing: no space between Japanese and Latin words or
numbers anywhere in the file. "Interactable wildlife" is rendered as creatures that react to
you, which is what the game does.

Left for the owner:
- お宝 (treasure) is the marketing word; the game calls a washed find インテリア.

Checked by script: every BBCode tag, `[video ...]` line, URL and `{STEAM_APP_IMAGE}` is the
same as `en.md`, line by line, with the same 21 lines and the same blank lines.
