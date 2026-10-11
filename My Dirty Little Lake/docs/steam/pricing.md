# Steam Pricing — My Dirty Little Lake

> **Decided by Richard, 2026-10-10: US$4.99, 15% launch discount (Nov 16-30).** Regional
> prices: proposed in **Regional prices for US$4.99** below. The Winter Sale and the length
> line on the store page are still open.

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
>   the same thing about itself and has 94% positive reviews.

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

**Method.** Valve's tool is in Steamworks, but its output can be read off games that took it.
Two unrelated $4.99 games, *A Game About Digging A Hole* (2025) and *Brotato* (2023), were
read from the store API in 42 storefronts. They match to the cent in 38, including odd figures
like PHP 174.95, NOK 55.49 and AUD 7.50 that nobody picks by hand. Where they differ (UK,
China), the 2025 game is taken as the current tool and Brotato as an older one or a hand
choice. **Before entering anything, open the tool in Steamworks: its figures win** where they
differ from this table.

**Rule followed.** Take Valve's figure unless there is a reason that is about *this* game or
*that* market. Three changes, all small, all downwards, all things a later price review can undo.

| Currency | Valve's tool | **Use** | Why a change |
|---|---|---|---|
| USD (US) | 4.99 | **4.99** | |
| EUR | 4.99 | **4.99** | |
| GBP | 4.29 | **3.99** | £x.99 under a pound line is the UK convention; Brotato sits there too |
| CAD | 6.49 | **6.49** | |
| AUD | 7.50 | **7.50** | |
| NZD | 7.39 | **7.39** | |
| CHF | 5.49 | **5.49** | |
| NOK | 55.49 | **55.49** | |
| PLN | 22.99 | **22.99** | |
| JPY | 580 | **580** | |
| KRW | 5,600 | **5,600** | |
| CNY | 18.50 | **18** | Steam China prices are whole yuan (18, 22, 36…); a .50 looks like an error |
| TWD | 102 | **102** | |
| HKD | 33 | **33** | |
| SGD | 5.25 | **5.25** | |
| MYR | 13.99 | **13.99** | |
| IDR | 47,499 | **47,499** | |
| PHP | 174.95 | **174.95** | |
| THB | 115 | **115** | |
| VND | 73,500 | **73,500** | |
| INR | 250 | **250** | |
| BRL | 16.99 | **16.99** | Kept: see below |
| MXN | 64.49 | **64.49** | |
| CLP | 3,000 | **3,000** | |
| COP | 13,500 | **13,500** | |
| PEN | 12.00 | **12.00** | |
| UYU | 159 | **159** | |
| CRC | 2,400 | **2,400** | |
| UAH | 124 | **124** | |
| KZT | 1,500 | **1,500** | |
| RUB | 200 | **200** | |
| ZAR | 52 | **52** | |
| ILS | 18.50 | **18.50** | |
| SAR | 11.95 | **11.95** | |
| AED | 15.00 | **15.00** | |
| QAR | 12.99 | **12.99** | |
| KWD | 1.10 | **1.10** | |
| LATAM-USD (Argentina and others) | 2.99 | **2.99** | Must be filled, or these pay US$4.99 |
| MENA-USD (Turkey and others) | 2.99 | **2.99** | Must be filled |
| CIS-USD | 3.29 | **3.29** | Must be filled |
| South Asia-USD (Pakistan, Bangladesh…) | 2.99 | **2.99** | Must be filled |

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
- **Odd-looking figures** (NOK 55.49, NZD 7.39, KRW 5,600): they are Valve's and match what
  these storefronts show for every $4.99 game. Rounding them buys nothing measurable.
- **Russia and Ukraine**: Steam still lists RUB and UAH prices; payment in Russia is hard and
  out of the developer's hands. Valve's figures, no stance taken through pricing.
- **Key arbitrage**: Steam blocks gifting across regions with large price gaps and the game is
  not sold as keys elsewhere, so the cheap regions are not a leak.
- **The launch discount and sales apply as a percentage in every currency**, so this table only
  has to be right once.

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
