# Steam Cloud and Rich Presence: what to set on Steamworks

App **5375170**. Both are Steamworks settings plus, for Rich Presence, one uploaded file.
Publish them from the **Publish** tab like the achievements.

## Steam Cloud (Auto-Cloud, no code)

App Admin, then Steam Cloud, then Settings:

- **Byte quota per user**: 4,000,000 (a save is about 160 KB, kept twice).
- **Number of files allowed per user**: 10.
- **Enable Cloud support for developers only**: off once it has been tried; on is fine for
  the first test.

Under **Root Paths**, add one row per file. All three use the root
`WinAppDataRoaming` and the subdirectory `My Dirty Little Lake`, with no recursion:

| Pattern | What it is |
|---|---|
| `my_dirty_little_lake.save` | the run |
| `my_dirty_little_lake.save.bak` | the run one write earlier (the load falls back to it) |
| `achievements.cfg` | what has been earned, pushed to Steam on every start |

Platforms: Windows only.

**Not synced, by decision**: `settings.cfg`. It holds the window mode, the resolution and the
binds, which belong to the machine: a PC's settings must not land on a Steam Deck.
`my_dirty_little_lake.save.tmp` is a write in progress and never synced.

**The path is the game's own user dir** (`application/config/use_custom_user_dir`, named
`My Dirty Little Lake` in project.godot), so `%APPDATA%\My Dirty Little Lake\`. Changing that
name moves the saves, and Cloud must be changed with it. Files from before the rename
(`Godot/app_userdata/Lake Cleanup`) are copied over once by `Prefs._bring_old_files`.

## Rich Presence (percent only)

Friends see **"Cleaning the lake: 42% clean"** under the game's name, whatever the player is
doing. The game sets `steam_display` to `#Status` and `percent` to the figure, only when the
whole percent changes (`Achievements.presence_clean`).

Upload `docs/steam/rich_presence.vdf` on the app's Steamworks settings, on the Community
tab under Rich Presence (one file per language, in Valve's own `"Language"` / `"Tokens"`
layout). It is English only, like the achievements. The figure arrives with its own `%`
("42%"), so the token never has to escape one.

To test: run the game under Steam and look at your own profile from another account, or from
a friend's list.
