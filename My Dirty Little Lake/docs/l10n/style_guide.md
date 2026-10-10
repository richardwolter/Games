# My Dirty Little Lake — translation style guide

Read by every translator and reviewer agent, for every language. The glossary
(`docs/l10n/glossary.md`) fixes the game's terms; this file fixes how the game speaks.

## The source

- **Brazilian Portuguese (`pt_BR`) is the source text.** Richard wrote it. Translate its
  meaning, not its words. English (`en`) is a second view of the same meaning; when the two
  disagree, PT wins, and the disagreement is reported.
- Each string comes with `_where` (the script that draws it), `_note` (where it shows and
  what it must keep), `_size`/`_least`/`_width` (its box). A string over its box is a
  failed string, whatever it says.

## The game, for context

A cosy, slightly silly idle/active game. You inherit a filthy little lake with an island,
a house, boats and dogs. You cast a net, the boats carry the rubbish to recycling piers for
money, the dogs fetch, you wash and decorate with what you find, and nature comes back as
the water clears: fish, frogs, birds, bees, a hive with honey. No violence, no villains.
Players are of all ages; assume a 10-year-old may read every line.

## Voice

- **Warm, light, plainly friendly.** Short sentences. A small joke is fine where the PT has
  one; never add one where it has none.
- **Talk to the player directly**, in the second person, as PT does.
- **Instructions are instructions**: verb first where the language allows, no filler.
- **Never preachy** about pollution or ecology. The lake getting cleaner is a reward, not a
  lecture.
- **UI labels are names, not sentences**: no full stop on a label, button or heading.
- Match PT's capitalisation style for the target language's own norms (German capitalises
  nouns; French and Spanish use sentence case; titles are not Title Case outside English).

## Formatting that must survive

- `%d`, `%s`: same count, same kind. Word order may move them. `%s` may be a key name, a
  button picture or a number; never decline it or put an article on it.
- `*asterisks*`: mark words drawn in a highlight colour. Keep the same number of marked
  parts, around the words that carry the same meaning (they may move).
- `\n`: a paragraph break. Keep the same number.
- `→` (U+2192) and the `·` (middle dot): keep.
- Two spaces before `%d` in plank titles (`Decorar  %d`): keep.
- **No double spaces, no leading or trailing spaces** (except where the source has them:
  `LETTER_GREETING_LEAD` keeps its trailing space where the language puts a space before
  the name; `SHOP_TIER_PREFIX` keeps one if the language needs a space before a number).
- Japanese and Chinese: **no spaces between CJK characters**; full-width punctuation
  (`。、！？「」`); a space between CJK and a Latin word or a number is not used (`Strengthを`,
  `3個`). The game breaks lines between CJK characters by itself; never insert breaks.
- Korean: spaces between words as normal Korean; Korean punctuation follows Latin style.
- **Do not translate**: `My Dirty Little Lake`, `Dirty Little Lake`, `Godot Engine`, song
  names, `Nuven`, `VSync`, `FPS`, gamepad button names (A, B, X, Y, LB, RT…), `$` amounts.

## Register, per language

- **en**: plain international English, US spelling (`color`, `favorite`), contractions OK.
- **es**: neutral Spanish for Spain and Latin America both. **Tú**, not usted, not vos.
  Avoid words that are vulgar in some regions (`coger` → `tomar`/`agarrar`; avoid `concha`,
  `pija`, `chucha`, `bicho` as anything but a creature, `pisar` used loosely). Prefer
  `computadora`-neutral wording that works in both (or avoid the word).
- **de**: **du**, informal, as German games address players. Short words where a box is
  tight; prefer a clear noun over an English loan unless the loan is standard in German games.
- **fr**: **tu**, informal, as French games for all ages do. France French. French
  typography: a **no-break space (U+00A0)** before `! ? : ;`, so the mark is never left
  alone at the start of a row (the game breaks rows only on ordinary spaces). Straight
  apostrophe `'`, as the rest of the table.
- **ja**: polite, friendly **です／ます** in sentences; noun phrases for labels. Kana over
  hard kanji where a child would stumble. Katakana for loanwords only where they are normal
  in Japanese games (`アップグレード` is fine).
- **zh_CN**: Simplified Chinese, Mainland standard. Friendly and concise; no internet slang.
  Use `你`. Mind sensitive terms (see below).
- **ko**: **해요체** (polite informal) in sentences; noun labels. Standard Seoul spelling.

## Safeguards — what a reviewer hunts for

A reviewer reads every string as a native player, looking for anything that could offend,
embarrass, confuse or alienate. Flag, then fix:

1. **Vulgar or sexual readings**, including regional ones and second meanings of innocent
   words (the dirty lake, the net, "pick up", "catch", "wood", "rubber", "box", "bush",
   "pussy willow", "cock", "balls", "hole", "pole", "hose"…). "Dirty" must read as *filthy
   water*, never as sexual or as an insult to people.
2. **Slurs or insults** hidden in a word, including old or dialect meanings.
3. **Religious, political or national sensitivity**: no reference to borders, flags beyond
   the language picker, regions, history, religion. zh_CN: avoid terms with political
   connotations; ja/ko: avoid anything touching historical tensions.
4. **Gender**: neutral wherever the language allows without strain. The angler is male in
   the art; the player is not assumed to be. Avoid "the player (he)". In gendered languages
   prefer phrasings that skip the player's gender (imperatives, "you").
5. **Animals**: dogs, pigeons, bees are treated kindly; no wording that suggests harming
   them. "Catch" a pigeon is netting it, not killing it.
6. **Money and luck**: "luck", "bonus", "double" must not read as gambling or betting.
7. **Trash and people**: no wording that equates people, places or cultures with rubbish.
8. **Tone slips**: condescending, robotic, overly formal, or machine-translated phrasing.
9. **False friends and calques** from the source languages.
10. **Consistency**: every glossary term used as fixed; the same thing named the same way
    on every screen.

## Output a translator returns, per string

`key`, the translation, a back-translation into English (literal enough to show drift),
and a note for anything doubtful (a glossary clash, a box that is tight, a meaning that did
not carry). A reviewer returns, per string: `ok`, or a corrected translation with the
reason, and a severity (`offensive`, `wrong`, `awkward`, `style`).
