# Steam Pricing — My Dirty Little Lake

> **Decided by Richard, 2026-10-10: US$4.99, 15% launch discount (Nov 16-30).** Regional
> prices: entered 2026-10-10, see **Regional prices for US$4.99** below.
>
> **Revisited 2026-10-24** (`/grill-me` with Richard, a sanity check after Next Fest):
> - US$4.99 and the 15% launch discount stay.
> - **Japan goes to ¥700**, from Valve's ¥705.
> - **Entered in Steamworks by Richard, 2026-10-25**: every regional price in the table below
>   (JPY ¥700 among them) and the launch discount, 15% for 14 days from Nov 16.
> - **If Japan converts under 70% of the US rate by Nov 30, Japan drops to ¥600 on Dec 16**,
>   the first day Valve allows a price change. See **Japan, revisited** below.
> - **The store page says the game is short**, in the About heading of every language, with
>   no hour count (Richard's call). Drafted in `store_text/`; **not yet on the store page**,
>   which Richard reviews in a session of its own.
> - Still open: the Winter Sale at 20%, recommended on 2026-10-10 and not reconfirmed.

Researched 2026-10-10 for the 2026-11-16 launch (app 5375170). Prices and review counts
were read from the Steam store API (US and BR storefronts) the same day.

> **Recommendation**
> - **Base price: US$4.99.** About an hour to clear the lake, plus washing and decorating.
>   That sits between the 1–2 hour cozy games that sell well at $4.99–5.99 (Spilled! $5.99,
>   A Game About Digging A Hole $4.99) and the pure incrementals at $2.99 (Nodebuster,
>   Tower Wizard), which run longer but have far less art, no house and no localisation.
> - **Launch discount: 15% for 14 days** (US$4.24, Nov 16 – Nov 30). Valve suggests 10–15%
>   and caps it at 40%.
> - **Winter Sale (Dec 17 – Jan 4): join at 20% (US$3.99), only if the game is out on
>   Nov 16 by 10am PT.** New releases are locked out of seasonal sales for 30 days, which
>   leaves about one day of slack. A slip of a day or two means no Winter Sale.
> - **Regional prices: accept Valve's recommendations** (for $4.99 that is R$16,99 in
>   Brazil). Fill in the LATAM-USD and MENA-USD rows from the tool too; if they are left
>   empty those regions pay the full US price.
> - **State the length on the store page**, along the lines of: "A short, cozy game: about an
>   hour to clean the lake, then more time to wash, decorate and look around." Spilled! says
>   the same thing about itself and has 94% positive reviews. **Decided 2026-10-24: say
>   "short", give no hours.**

## Comparables

These are prices on the US storefront on 2026-10-10. Length comes from HowLongToBeat where
a copy of its data could be found, and from the developer or reviews otherwise (marked `~`).

| Game | US price | BR price | Length | Steam reviews | Notes |
|---|---|---|---|---|---|
| Spilled! (2025) | $5.99 | R$20,49 | ~1 h (dev, Wikipedia) | Very Positive, 94% of 5,340 | Closest match: cozy pollution cleanup, solo dev. Launched at about 10% off (€5.30 against €5.89). |
| A Game About Digging A Hole (2025) | $4.99 | R$16,99 | ~1–2 h (reviews; one database says 3 h) | Very Positive, 89% of 20,232 | Short incremental, upgrade loop |
| Nodebuster (2024) | $2.99 | R$10,49 | ~3–5 h (review summaries) | Overwhelmingly Positive, 97% of 14,107 | Short incremental, minimal art |
| Tower Wizard (2025) | $2.99 | R$10,49 | ~2–5 h (itch comments, gg.deals) | Overwhelmingly Positive, 97% of 9,032 | Short idle incremental |
| Cats Organized Neatly (2020) | $2.99 | R$6,49 | 2.5 h main / 4 h with extras (HLTB via DekuDeals) | Overwhelmingly Positive, 97% of 4,853 | Cozy puzzle. Its BR price is set well below the tool's. |
| Placid Plastic Duck Simulator (2022) | $1.99 | R$9,00 | 5.5 h main (HLTB via DekuDeals), effectively endless | Overwhelmingly Positive, 98% of 20,335 | An ambient toy rather than a game you finish |
| Ropuka's Idle Island (2025) | $3.99 | R$9,99 | idle, open-ended | Overwhelmingly Positive, 95% of 4,331 | Cozy idle |
| Tiny Pasture (2025) | $5.99 | R$20,49 | idle, open-ended | Very Positive, 92% of 8,661 | Cozy idle |
| A Short Hike (2019) | $7.99 | R$16,59 | 1.5 h main / 4.5 h completionist (HLTB via DekuDeals) | Overwhelmingly Positive, 99% of 22,856 | The benchmark for a short game that is well liked |
| Is This Seat Taken? (2025) | $9.99 | R$34,99 | ~2–3 h | Overwhelmingly Positive, 97% of 9,781 | Cozy puzzle with more production |
| A Game About Feeding A Black Hole (2025) | $6.99 | R$26,75 | short | Very Positive, 88% of 3,578 | Short incremental |
| Rusty's Retirement (2024) | $6.99 | R$23,50 | idle, long | Overwhelmingly Positive, 97% of 14,890 | Cozy idle farm |
| Stacklands (2022) | $7.99 | R$26,49 | ~10 h | Overwhelmingly Positive, 96% of 30,445 | Small, deep incremental |
| Unpacking (2021) | $19.99 | R$59,99 | 3.5 h (HLTB via Galaxus) | Very Positive, 93% of 41,066 | The top of the range for a short cozy game, with far more production |
| PowerWash Simulator (2022) | $24.99 | R$74,90 | 25+ h | Overwhelmingly Positive, 96% of 58,890 | The genre ceiling; not a direct comparable |

**What the table says:** short incrementals with simple art cluster at **$2.99**. Short
cozy games with real art and a theme cluster at **$4.99–7.99**. Spilled! is the nearest
match in theme, length and scope; it sells at $5.99 with no length complaints dominating
its reviews. MDLL has as much or more on top of that (a house, the wash mini-game, wildlife,
tornadoes, 8 languages, controller support), so it belongs in the cozy band, not the $2.99 one.

## Rules That Matter (Steamworks)

- **Launch discount:** optional, 10–40% (Valve suggests 10–15%), runs 7–14 days from
  release, ends at 10am PT. It has to be set up **before** the release date. It counts
  toward the 30-day cooldown between discounts.
- **Release cooldown:** "A product cannot be discounted for 30 days following its
  release." It also applies to seasonal sales: "Any product on a 30-day Release Cooldown or a
  30-day Price Increase cooldown cannot join a Seasonal Sale."
  - Released Nov 16, the cooldown ends Dec 16. The Winter Sale starts **Dec 17**, so the
    game is eligible, by about a day.
  - **Check in the Steamworks discount dashboard that the Winter Sale opt-in shows the game
    as eligible** as soon as it opens. Don't rely on the arithmetic.
- **Seasonal sales are exempt from the 30-day discount cooldown**, so a launch discount
  ending Nov 30 does not block the Winter Sale.
- **Discount size:** a game at $4.99 may be discounted up to 90% in later sales (a $0.99
  game only 50%, a $1.99 game 75%). Every discount is at least 10%.
- **Price changes:** none within 30 days of release. Any price **increase** blocks discounts
  for 30 days. So start at the price you want to keep: raising $2.99 to $4.99 later costs a
  month without sales and reads badly. Cutting a price later is free.
- **Refunds:** any buyer can refund within 14 days with **under 2 hours played**. That is
  longer than one run of this game. A low impulse price and an honest length line are the
  two defences. Valve may refuse refunds to users it thinks are abusing the system, but a
  single refund after finishing will go through.

## Reasoning

- **$4.99 over $2.99.** At this end of the market a $2 difference barely changes the sales
  count, and the length is already a "costs less than a coffee" decision either way.
  $2.99 puts the game among jam-sized incrementals and earns about 60% of $4.99 per sale,
  before Valve's 30% and regional discounts. It also leaves no room for a later increase,
  for the cooldown reason above.
- **$4.99 over $5.99.** Spilled! proves $5.99 can work for an hour, but it had a strong
  launch story behind it. $4.99 is the top of Richard's range and the usual "under five"
  impulse price. It also leaves room for a later rise if the game grows (more content, an
  endless mode), as long as the rise is timed outside a planned sale.
- **15% launch discount.** It puts "-15%" and US$4.24 on the capsule in launch week. A
  deeper launch cut (25–40%) makes the first seasonal sale look stingy, and anchors early
  buyers at a price the game will rarely go back to.
- **20% in the Winter Sale.** This is slightly deeper than the launch discount, so wishlists
  that did not convert in November get a reason to buy. It is not so deep that buyers from
  a month earlier feel cheated. Go deeper in 2027 sales.
- **Regional prices.** Valve's multi-variable tool weighs purchasing power and local prices
  of comparable goods, and is the norm for indies. The comparables above show what it gives
  in Brazil: $2.99 → R$10,49, $4.99 → R$16,99, $5.99 → R$20,49, and a few developers set
  theirs lower (Cats Organized Neatly R$6,49, Ropuka R$9,99).
  - **Brazil:** R$16,99 is fine. As a Brazilian developer with a PT-BR translation and a
    likely home audience, Richard could round to **R$14,99**, a common round price there.
    Lowering a regional price later is always allowed, so starting at the tool's figure
    costs nothing.
  - **The two USD regions:** Argentina and Turkey pay in USD inside the LATAM-USD and
    MENA-USD regions since Nov 2023. **Fill those rows from the tool**, or they default to
    the full US price.
  - **Floors:** don't hand-lower any currency under Steam's $0.99-equivalent floor, or the
    game becomes unavailable there and no discount can be scheduled.

## Regional prices for US$4.99 (2026-10-10)

**Entered in Steamworks by Richard, 2026-10-10**: Valve's recommendations, with GBP set to
£3.99 and CNY to ¥18.00, and the four USD regions filled. **JPY changes to ¥700**
(decided 2026-10-24, entered 2026-10-25).

**A lesson on method.** Before the tool was opened, its output was guessed by reading two
$4.99 games (*A Game About Digging A Hole*, *Brotato*) off the store API in 42 storefronts.
They agreed to the cent in 38, which looked like the tool, but **the real tool differed in
about 30 currencies** (JPY 705 vs 580, THB 96 vs 115, AUD 7.05 vs 7.50…). Games keep the
recommendations of the day they were priced; Valve updates the tool. **Read the tool itself,
never a published game.**

| Currency | Price | Note |
|---|---|---|
| USD | 4.99 | |
| GBP | 3.99 | tool said 4.29; £x.99 under a pound line is the UK convention |
| EUR | 4,99 | |
| CHF | 4.99 | |
| RUB | 245 | |
| PLN | 20,49 | |
| BRL | 16,99 | kept, see below |
| JPY | 700 | **¥700 decided 2026-10-24, entered 2026-10-25** (the tool said 705). ¥600 on Dec 16 if Japan converts poorly: see **Japan, revisited** |
| NOK | 52,50 | |
| IDR | 50 999 | |
| MYR | 12.49 | |
| PHP | 179.00 | |
| SGD | 5.39 | |
| THB | 96.00 | |
| VND | 74.000 | |
| KRW | 5,600 | |
| UAH | 130 | |
| MXN | 66.99 | |
| CAD | 6.29 | |
| AUD | 7.05 | |
| NZD | 7.89 | |
| CNY | 18.00 | tool said 18.50; Steam China prices are whole yuan |
| INR | 279 | |
| CLP | 3.299 | |
| PEN | 12.49 | |
| COP | 12.999 | |
| ZAR | 49.49 | |
| HKD | 27.00 | |
| TWD | 108 | |
| SAR | 15.49 | |
| AED | 16.99 | |
| ILS | 17.99 | |
| KZT | 1 490 | |
| KWD | 1.40 | |
| QAR | 16.49 | |
| CRC | 2.450 | |
| UYU | 169 | |
| CIS-USD | 3.29 | must be filled by hand |
| South Asia-USD | 2.99 | must be filled by hand |
| LATAM-USD (Argentina…) | 2.99 | must be filled by hand |
| MENA-USD (Turkey…) | 2.99 | must be filled by hand |

**Brazil, thought through.** The pull is to go lower at home. Not doing it:
- R$16,99 is already under the R$20 impulse line, and the 15% launch discount puts it at about
  R$14,44 in launch week, under the R$14,99 a hand-cut would have set.
- R$16,99 against US$4.99 is about 3.4 reais to the dollar, well under the market rate, so
  Valve's tool already gives Brazil a large cut. (Exchange rate not checked here; compare with
  the day's rate if the size of the cut matters.)
- A home-market cut is one-way in practice. Lowering a regional price later is always allowed;
  raising it reads as a betrayal to the very audience that would talk about the game first.
- Keep the change in reserve: if PT-BR wishlists convert poorly in launch week, R$14,99 is a
  quick, reversible-in-spirit move after the launch discount ends.

**What was looked at and left alone.**
- **Odd-looking figures** (NOK 52,50, AUD 7.05): Valve's. Rounding them buys nothing measurable.
- **Russia and Ukraine**: Steam still lists RUB and UAH prices; payment in Russia is hard and
  out of the developer's hands. Valve's figures, no stance taken through pricing.
- **Key arbitrage**: Steam blocks gifting across regions with large price gaps and the game is
  not sold as keys elsewhere, so the cheap regions are not a leak.
- **The launch discount and sales apply as a percentage in every currency**, so this table only
  has to be right once.

## Japan, revisited (2026-10-24)

**Why it came up.** Japan is the biggest wishlist country by far. Steamworks, Regional
Wishlists by country, lifetime to 2026-10-24 (the store page went public about Oct 8):
**908 net wishlists.**

| Country | Net | Share |
|---|---|---|
| Japan | 417 | 46% |
| United States | 148 | 16% |
| China | 46 | 5% |
| Brazil | 41 | 4.5% |
| Germany | 41 | 4.5% |
| United Kingdom | 24 | 2.6% |
| Korea, Taiwan, Hong Kong together | 32 | 3.5% |

- **245 of Japan's 432 adds came on one day, Oct 9**, from a post by the curator account
  [Indie_FreaksJP](https://x.com/Indie_FreaksJP) on X. Otherwise Japan ran at 1–23 a day.
- **During Next Fest (Oct 19–24) Japan added 115 and the US 123.** So there is a real
  Japanese audience, about level with the US day to day, and one curator post was worth
  half of it. A repeat post at launch would move more sales than a few yen.
- Steamworks' "Asia" region (495 net) is mostly Japan; the other Asian prices barely matter
  at these numbers.

**What Japanese players see.** JP storefront, read 2026-10-24 through the store API:

| Game | US | JP | Yen per US dollar |
|---|---|---|---|
| Nodebuster, Tower Wizard | $2.99 | ¥350 | 117 |
| Cats Organized Neatly | $2.99 | ¥295 | 99 |
| Ropuka's Idle Island | $3.99 | ¥400 | 100 |
| A Game About Digging A Hole | $4.99 | ¥580 | 116 |
| Tiny Pasture | $5.99 | ¥600 | 100 |
| Spilled! | $5.99 | ¥700 | 117 |
| Rusty's Retirement | $6.99 | ¥750 | 107 |
| A Short Hike | $7.99 | ¥820 | 103 |
| Stacklands | $7.99 | ¥920 | 115 |
| Unpacking | $19.99 | ¥2,050 | 103 |
| PowerWash Simulator | $24.99 | ¥2,970 | 119 |
| **MDLL at ¥700** | **$4.99** | **¥700** | **140** |

Valve's pricing tool raised its yen suggestions about 12% in March 2026, and games priced
before that kept their lower yen. Most comparables sit at 100–120 yen to the dollar; MDLL
sits at 140. **In Japan MDLL costs as much as Spilled!, which is US$1 dearer.**

**Decision: ¥700**, Richard's call, kept after one push back. ¥600 (recommended: 120 yen to
the dollar, the same gap under Spilled! as in the US) and ¥580 (Digging A Hole's price) were
the alternatives. What speaks for ¥700: the full Japanese translation, the curator's
interest, and launch week at **¥595** (15% off), level with the comparables. The gap shows
from Dec 1.

**The fallback, decided:**
- **On Nov 30** (the launch discount's last day), open Steamworks, Regional Wishlists by
  country, and compare Japan's conversion rate (purchases over wishlists) with the US's.
- **If Japan's rate is under 70% of the US's, lower JPY to ¥600 on Wednesday Dec 16.**
  Valve asks "that price changes wait until after 30 days from release", and Nov 16 + 30
  days is Dec 16. The Winter Sale's 20% (from Thursday Dec 17) then puts Japan at ¥480.
- Valve reviews a price change in one or two business days and it can't be scheduled, so a
  change submitted Dec 16 may land a day into the Winter Sale.
- A price **decrease** starts no discount cooldown (only increases do), so the cut does not
  cost the Winter Sale. Still check the sale's opt-in shows the game as eligible afterwards.
- Leave the other Asian currencies alone: China, Korea, Taiwan and Hong Kong are 78
  wishlists together.

**Checked and left as it was:**
- **Short games.** No measured median price by playtime exists. Short cozy games with real
  art sit at $4.99–7.99; short incrementals with plain art at $2.99.
- **Cozy games.** Median list price US$4.99 (Steam's Cozy tag, released Jan 2024 to Jun 2025,
  counted Sep 2026), the same as all of Steam; 52% of paid cozy games are under $5. Under $5,
  2.7% reached 1,000 reviews; at $5–9.99, 7.8%. A correlation: dearer games tend to be
  bigger productions.
- **Asset packs.** Not a reason to price lower: buyers price what they see, and the art
  reads as one style.
- **Length.** Richard puts a full run with washing and decorating at about 1.5 hours (the
  logged clearing runs were 50 and 65 minutes). Still under the 2-hour refund window; the
  store page now says the game is short.

## Risks

- **"Too short for the price" reviews.** These come from surprise, not from the length
  itself. Short games with a clear length line (Spilled!, A Short Hike) review at 94–99%.
  So **state the length** in the short description or the first lines of the About text,
  and say there is one run per save (no endless mode). Don't oversell it as "hours of
  content".
- **Too low reads as low effort.** $1.99–2.99 is where asset-flips and jam games sit. The
  art, the 8 languages, Steam Deck support and the achievements are worth a price that
  matches them. $4.99 is still an impulse buy.
- **Refund after finishing.** It is possible inside 2 hours. You can't prevent it; a fair
  price and honest expectations keep it rare. The free demo helps the right players
  self-select.
- **Missing the Winter Sale.** A release delay of even a day or two pushes the game past
  the Dec 17 cut-off. Treat Nov 16 as fixed, or accept that the first seasonal sale will be
  Lunar New Year or the Spring Sale.

## Sources

- Steamworks, Discounting: https://partner.steamgames.com/doc/marketing/discounts
- Steamworks, Pricing: https://partner.steamgames.com/doc/store/pricing
- Steam refunds: https://store.steampowered.com/steam_refunds
- Steam Support, LATAM-USD / MENA-USD change: https://help.steampowered.com/faqs/view/2720-4EC7-B95A-1D2A
- Game World Observer on the 2023 USD switch: https://gameworldobserver.com/2023/10/25/steam-turkey-argentina-usd-convert-regional-pricing-abandoned
- 2026 sale dates (Winter Sale Dec 17 – Jan 4): https://www.steampageanalyzer.com/blog/steam-winter-sale-2026 and https://www.gameswelt.de/steam-valve/news/termine-fuer-sales-und-feste-in-2026-stehen-fest-332734
- Steam store API, prices and review counts (US and BR, 2026-10-10): `store.steampowered.com/api/appdetails?appids=<id>&cc=us|br` and `store.steampowered.com/appreviews/<id>?json=1&language=all`
- Store pages: [Spilled!](https://store.steampowered.com/app/2240080/), [A Game About Digging A Hole](https://store.steampowered.com/app/3244220/), [Nodebuster](https://store.steampowered.com/app/3107330/), [Tower Wizard](https://store.steampowered.com/app/3372980/), [Cats Organized Neatly](https://store.steampowered.com/app/1369340/), [Placid Plastic Duck Simulator](https://store.steampowered.com/app/1999360/), [Ropuka's Idle Island](https://store.steampowered.com/app/3416070/), [Tiny Pasture](https://store.steampowered.com/app/3167550/), [A Short Hike](https://store.steampowered.com/app/1055540/), [Is This Seat Taken?](https://store.steampowered.com/app/3035120/), [A Game About Feeding A Black Hole](https://store.steampowered.com/app/3694480/), [Rusty's Retirement](https://store.steampowered.com/app/2666510/), [Stacklands](https://store.steampowered.com/app/1948280/), [Unpacking](https://store.steampowered.com/app/1135690/), [PowerWash Simulator](https://store.steampowered.com/app/1290000/)
- Spilled! length and launch: https://en.wikipedia.org/wiki/Spilled! and https://www.giga.de/entertainment/ich-hab-das-perfekte-steam-spiel-gefunden-um-mich-wie-ein-besserer-mensch-zu-fuehlen--01JQERFZ24TZVMQ7G59Q6TF33B
- HowLongToBeat figures as copied by DekuDeals: https://www.dekudeals.com/items/cats-organized-neatly, https://dekudeals.com/items/a-short-hike, https://dekudeals.com/items/placid-plastic-duck-simulator
- Unpacking length (HLTB, via Galaxus): https://www.galaxus.ch/en/page/the-26-best-short-games-41395
- Digging A Hole length: https://thefilibusterblog.com/digging-a-hole-game-estimated-completion-time-and-how-long-to-beat/
- Nodebuster length (review summary): https://vaporlens.app/app/3107330/nodebuster.md
- Tower Wizard length: https://gg.deals/game/tower-wizard/ and https://itch.io/post/12511584
- Added 2026-10-24:
  - Steam store API, JP storefront prices: `store.steampowered.com/api/appdetails?appids=<id>&cc=jp`
  - Steamworks Regional Wishlists export, lifetime to 2026-10-24 (Richard's download, not in the repo)
  - Cozy games niche report (Steam Page Analyzer): https://www.steampageanalyzer.com/blog/cozy-games-steam-2026-niche-report
  - Valve's 2026 pricing-tool update and the yen: https://automaton-media.com/en/news/steams-updated-pricing-tools-could-push-game-prices-in-japan-higher-with-weak-yen-reflected/
  - Median Steam price trend (GameDiscoverCo): https://gamedevreports.substack.com/p/gamediscoverco-people-are-spending
