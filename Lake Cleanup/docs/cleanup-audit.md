# Cleanup audit (2026-10-03)

The list for step 1 of the pre-release cleanup. Nothing has been deleted yet.

**Method.** I scanned every file under `assets/ resources/ scenes/ scripts/ shaders/ locale/`
and the project root. A file counts as referenced when its res path, its file name, its uid or
its `class_name` appears in game code, scenes, resources or JSON, with GDScript comments
stripped. References were followed outward from `project.godot`, so a file used only by a
dead file is dead too. Loaders that build a path in code were checked by hand: sfx names,
`Slice %d`, letter stills, prompts, flags, `dog_%02d`, trash/upgrade `.tres` ids and
music slugs.

## Contradiction found

- **CLAUDE.md "Rubbish Sheets" is stale.** It says `art_source/New_Objects_Lake.psd` is the
  only source of the lake's rubbish, with 81 kinds cut by `build_lake_objects.py`. The code
  says otherwise. `lake.gd:384` says "The rubbish is the 0_mem0ry packs' art since
  2026-10-01 (tools/build_pack_rubbish.py)". That builder writes `assets/lake_objects.png`,
  which now holds 240 kinds. So the code is authoritative, `build_lake_objects.py` is dead,
  and the CLAUDE.md section gets rewritten.

## A. Shipped, dead: deleted outright

| File | Size | Why |
|---|---|---|
| `assets/Blue_Boat/PixZels_Model_BlueBoat.json` + `.DS_Store` | 9.0 MB | The pirate-ship model. It ships only because of the `*.json` include filter. |
| `assets/consoles.png`, `consoles_dirty.png`, `consoles.json` | 0.56 MB | The console spike was deleted on 2026-09-29. |
| `assets/sliced_character.png`, `sliced_shed.png` | 0.66 MB | Slicer debug pictures. |
| `assets/pigeon_contact.png` | 41 KB | Output of a contact-sheet probe. |
| `resources/trash/_old/*.tres` (25 files) | 10 KB | The first catalogue, never loaded. |
| `scripts/wood_ui.gd` | 5 KB | Nothing loads it; only comments in `style.gd` mention it. |
| `assets/Forest Isometric Pack Free/Tileset/` | ~45 KB | 37 of the 44 slices are dead. Keep 1, 2, 18, 19, 20, 21 and 67 (the game plus `extract_palette` and `build_wash_backdrop`). |
| `locale/translations.qps.translation` | 21 KB | Goes with qps. |

The UI_Buttons/ui.png deletion is already staged by another session.

## A2. Source art in `assets/`: moved to `art_source/`, not deleted (a live builder reads it)

- `assets/Pigeons/Pidgeon_head.jpg`: `slice_pigeon_head.gd` reads it.

## B. Debug code, stripped (your decision: "strip everything debug")

| What | Where |
|---|---|
| GroundTuner (F4) | `scripts/ground_tuner.gd`, plus hooks in `ground.gd`, `lake.gd` and `test_lake` |
| ButtonTuner (F7) | `scripts/button_tuner.gd`, plus hooks in `hud_buttons.gd` (`BAKED`/`tune`/`traced`) and `lake.gd` |
| Perf overlay (F3) | `scripts/perf_hud.gd`, plus its node in `scenes/main.tscn` |
| PlayLog | `scripts/play_log.gd`, plus calls in `lake.gd` |
| Screenshot key (F12) | `scripts/shot_key.gd`, plus its hook in `pad.gd` |
| F6 wipe-reload and F9 tornado | `lake.gd` `_unhandled_input` |
| qps pseudo-locale | `prefs.gd` (`languages()`), the CSV column, `build_translations.py` |

The `BENCH_OFF` / `BENCH_*` hooks stay. They serve `bench_frames`, which stays.

## C. Unused symbols in `scripts/`: 90, nothing in the game or the tools names them

These get deleted, and `test_lake` plus a windowed run confirm nothing broke. Exception:
`close_button.gd _get_tooltip` is an engine override and stays.

- **hive_art.gd**: BEE_THORAX, BEE_HEAD, WING, WING_EDGE, TRIM_SHADE, DARK_GLASS, SMOKE*,
  SKY*, CORAL* (18 colour consts), `comb_cell`
- **hive steps**: `steps_done`, `ROOM_LOOPS`, `is_recorded`, queen `lens_pos`/`is_found`/`miss_at`,
  smoke `ring_pos`, uncap `rows_open`/`rows_total`/`cut_share`/`knife_y`/`_draw_tray`/`SPILL_AT`
- **hud_buttons.gd**: SIDE_IN, DECOR_BAND, DECOR_SPREAD, COIN_RIM, COIN_RING, COIN_GLINT
- **style.gd**: COOL, SCRIM_LIGHT, CONTROL_H, SEP, `button_box`, `button_bites`
- **iso.gd**: `shore_point`, `past_island`, `island_ring`, `island_outline`
- **lake.gd**: SHOP_RANGE, `_pin_close`, `_sold_tally`, `_tiles_in_radius`
- **sheets.gd**: `wash_scale_of`, `has_seat`, `fill_of`, `texture_of`
- **tornado_look.gd**: `harness_opts`, `_paint_lip`, `_puff_lobes`, `_paint_cloud` (the
  pre-thread painters). **tornado_debris_draw.gd**: `draw_debris`, `pixel_ring`, `pixel_line`
- **wildlife.gd**: CRAY_SHY, `_nearest`, `track_count`, `_cray_fright` (crayfish no longer dart)
- **elsewhere**: boat `engine_effort`, dropoff POST_WIDE, ground `cover_count`, lake_grid
  `tiles_around`, net `_reach_along`, palette `histogram`/`get_color`/`set_color`,
  sfx `_wade_opening`/`play_splash`, shed_room ROOM_SHADE_NO_DAY/STATE_OFF/`_clear_of`,
  wash_backdrop LAWN_D, wash_stand STAND_AT/FRONT_ON_LANDING/STAND_TALL,
  water_splash `splash_for`

Another 81 symbols are named only by `tools/` (test API). They stay.

## D. Possibly dead, not touched (save risk)

- **The old PSD finds** (`decor_clean.png`, `decor_dirty.png` and their `pieces.json` entries,
  ~37 defs) are no longer dealt. Removing them shifts every def index, which means a
  `SAVE_VERSION` bump. I'm leaving them unless you say so.

## E. tools/: deleted

- **Mockups and one-offs**: `_build_hive_backup.py`, `_patch_menu.*`, `hive_mockup.py`,
  `hive_mockup2.py`, `net_mockup.py`, `net_lucky_mockup.py`, `hand_mockup.py`,
  `sky_reflect_mockup.py`, `lakebed_mockup.py`, `ground_volume_mockup.py`,
  `tutorial_mockup.py`, `decor_tour_mockup.*`, `shop_tour_mockup.*`,
  `build_record_menu_mockup.py`, `shop_mock.gd`, `shot_shop_mock.*`, `shot_pack_mock.*`,
  `tornado_mock/` (1.1 GB), `film_devlog.*`, `shot_steam.*`, `shot_keyart.*`,
  `shot_wash_place.*`, `pt_source_pass.py`, `review_rubbish_map.py` (+ `rubbish_map.json`
  if `build_pack_rubbish` does not need it), `check_mark_jitter.py`, `tile_edges.gd`,
  `balance_calc.py` (predates the shop), `prompt_contact.py`
- **Builders for retired art**: `build_consoles.py`, `build_lake_objects.py`,
  `trim_box_sides.py`, `downres_shed.py`, `recolor_box.py`, `recolor_shed.py` (only
  `downres_shed` imports it)
- **Scratch folders**: `specks/` (572 MB, untracked; this is the cleanup memory said to wait
  for), `hd_rubbish/` (56 MB), `menu_bg/`, `cursor/`, `_logs/`, `__pycache__/`
- **Files**: 603 `last_*` files (1.3 GB), ~45 stray `*.log`, `_old_hive.*`, `_old_pump.*`,
  `_claude_section.md`, `overnight_report.md`
- **Root junk**: `SERSADMINI~1APPDATAocaltempbed.patch`, `_b.tmp`, `pier_positioner.html`

## E2. tools/: kept

- `test_lake`, `bench_frames`, `census`
- every `probe_*` and `shot_*` not named above, plus `play_clean`, `play_decor`,
  `wash_spike`, `inspect_save`, `check_real_save`, `pigeon_contact`, `font_samples`,
  `beat_click`, `bases/`
- `film_trailer.gd`/`.tscn`: `shot_rope` extends it
- **Live builders**: build_boat_sheet, build_coin, build_cursor, build_decor, build_fish,
  build_flora, build_hive, build_icon, build_lakebed, build_music, build_nozzle,
  build_pack_decor, build_pack_rubbish, build_pet_frames, build_piers, build_pose_mockup
  (imported by build_rest_frames), build_prompts, build_pump, build_recycle_box,
  build_rest_frames, build_sfx, build_shed_v2, build_spotify_icon, build_stove_on,
  build_tag_atlas, build_translations, build_wash_backdrop, build_wildlife, cut_packs,
  fetch_mem0ry_packs, show_ids, extract_palette, slice_character, slice_dog,
  slice_pigeon_head, slice_pigeons, ink_pigeons, recolor_meter, measure_beats, fit_prices,
  fit_tier_shares, plus their inputs `decor_sets.json` and `pack_rubbish.json`

## F. Elsewhere on disk

- `build/`: every old zip and folder (760 MB)
- `_builds/lake_cleanup_v10..v20_*.save` (v21 kept)
- `tools/film/` is kept (7 GB)
