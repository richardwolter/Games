# The Donation Bank: what to enter on Steamworks

App **5375170**, My Dirty Little Lake. The game sums every player's gift through two
**aggregated stats**. Steam keeps each player's value and a global total of each, and the game
reads the totals back. No server of our own.

Steamworks: App Admin, then **Stats & Achievements**, then **Stats**. Add each row with
**New Stat**, then **Publish** the changes on the Publish tab. The game sets them by API name,
so the API names must match exactly. Until they are published, a gift waits in
`user://achievements.cfg` and is sent once Steam takes it.

| API name | Type | Set by | Increment only | Max change | Min | Max | Default | Aggregated | Display name |
|---|---|---|---|---|---|---|---|---|---|
| `DONATED` | INT | Client | yes | 1000000 | 0 | 1000000 | 0 | yes | Money donated |
| `DONORS` | INT | Client | yes | 1 | 0 | 1 | 0 | yes | Donated |

- `DONATED` is this account's one gift, in the game's money. `DONORS` is 1 once it has given.
  The game's goal (`DonationBank.GOAL`) is **5,000,000** of `DONATED`'s global total.
- **Max 1000000 is the cheat ceiling.** "Set by Client" means a player's own machine sets the
  stat, and tools exist that edit stats. The max and the max change hold any one account to
  one gift's worth, so faking the goal takes several accounts that own the game. The pledge is
  fixed, so a fake can only make it come sooner, never cost more.
- The numbers in `scripts/donation_bank.gd` (`GOAL`, `MOST`) and here must agree.

## Reading the total yourself

Steamworks shows each aggregated stat's global total on the Stats page once players have set
it. This is the number the game shows on the bar, and the one to check before donating.

## When the goal is reached

1. Check the global total of `DONATED` on Steamworks.
2. Donate 100 US dollars to The Nature Conservancy Brasil and keep the receipt.
3. Post a Steam announcement with the receipt, in English and Portuguese at least.
4. If you pledge again, raise `DonationBank.GOAL` in an update and say the new pledge in
   `BANK_PLEDGE` (all eight languages).

## Before the store page says anything

- **Ask The Nature Conservancy Brasil for permission to use their name.** Large charities
  usually require an agreement before their name is used to promote a product. Without it,
  change `BANK_CHARITY` to a generic name ("an environmental charity") in every language.
- **Check the legal side** where you donate from and where the game is sold. In some US states,
  telling buyers that a product leads to a donation is a "commercial co-venture" with
  registration and disclosure rules. A fixed pledge paid by you, not a share of sales, is the
  safest shape. This sheet is not legal advice.

Draft for the store's About This Game, English, **not on the store yet**:

> Finished your lake? Give the money left in your purse to the Donation Bank. Every player's
> gifts add up, and when the bank reaches $5,000,000 in-game, we will donate 100 US dollars
> of real money to The Nature Conservancy Brasil.

## Testing before release

- Steam must be running and signed in to an account that owns the app. A gift made while
  testing is real on that account: reset your own stats from Steamworks (Stats &
  Achievements has a reset for your account), and delete the `[donation]` section of
  `user://achievements.cfg` (in `%APPDATA%\My Dirty Little Lake\`). Otherwise the game hands
  the gift straight back to Steam.
- The demo is another app and has no bank.
