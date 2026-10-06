# Steam achievements: what to enter on Steamworks

App **5375170**, My Dirty Little Lake. Steamworks: App Admin, then Stats & Achievements,
then Achievements. Enter each row with **New Achievement**, then **Publish** the changes on
the Publish tab. The game sets them by API name, so the API names must match exactly.

Every achievement: English only, **not hidden**, no progress stat. "Set by" stays Client.
Icons are 64 x 64 PNGs in `Marketing/My Dirty Little Lake/steam/achievements/`, built by
`tools/build_achievement_icons.py --write`. Achieved icon: `<API name>.png`. Unachieved
icon: `<API name>_locked.png`.

| API name | Display name | Description |
|---|---|---|
| `DECORAHOLIC` | Decoraholic | Catch and wash every decoration piece in the lake. |
| `FRIEND_OF_NATURE` | Friend of Nature | Clean the entire lake. |
| `BEST_PALS` | Best Pals | Have all four dogs and pet each of them at least once. |
| `GREAT_NET` | Great Net | Catch 100 or more objects in a single throw. |
| `MAXIMALIST` | Maximalist | Buy every upgrade in the shop to its maximum level. |
| `TWISTERED` | Twistered | Tame a tornado until it is gone. |
| `HONEYMAKER` | Honeymaker | Complete the beehive and bottle your first honey. |
| `ISLAND_DJ` | Island DJ | Play with the record player. |
| `CHEAPSKATE` | Cheapskate | Have $100,000 unspent in your purse. |

## Testing before release

- Steam must be running and signed in to an account that owns the app (the developer
  account does). Launching from the editor or the exported exe both work: the game starts
  Steam's API itself with the app ID, and `steam_appid.txt` in the project root covers
  anything else.
- Unlocks made while testing are real on that account. Reset them from Steamworks (Stats &
  Achievements has a reset for your own account), or delete them by hand in the Steam
  client's console: `achievement_clear 5375170 <API name>`.
- `user://achievements.cfg` (in `%APPDATA%\My Dirty Little Lake\`) holds what
  the game has earned on this machine and is pushed to Steam on every start. Delete it too
  when resetting, or the game will hand the achievements straight back.
