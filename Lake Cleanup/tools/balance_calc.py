#!/usr/bin/env python3
"""Balance calculator for Lake Cleanup's upgrade tracks and trash catalogue.

Purpose: give an instant, math-only sanity check on a `.tres` edit, so a
balance-doc entry can quote real numbers instead of hand-reasoned ones —
and so a change that *claims* to have been made can be checked against what
the file on disk actually says (2026-09-06's balance pass logged a
net_strength change that was never actually saved; this would have caught
that in one run).

This does NOT replace playtesting or test_lake.gd's headless mechanical
checks (does the net come home, is nothing eating clicks, etc). It only
knows the price/value formulas from scripts/upgrade_track.gd:

    cost(level) = price_base * price_mult ^ min(level, level_cap)
    value(level) = min(curve_a + curve_b*level + curve_c*level^2, value_cap)
                   (floored if is_integer)

Usage:
    python3 tools/balance_calc.py                # run from the project root
    python3 tools/balance_calc.py /path/to/project

No third-party dependencies. Godot .tres files here are simple enough
(flat key = value pairs under a [resource] section) that a small regex
parser is enough — this is NOT a general .tres/Godot resource parser.
"""

import re
import sys
from pathlib import Path

NUM_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$')


def parse_tres(path: Path) -> dict:
    """Pulls flat scalar fields out of a .tres [resource] block.

    Strings are kept quoted-stripped; numbers become float/int/bool.
    Vector2/Color/etc. are kept as their raw source text (not parsed) since
    nothing here does math with them today.
    """
    fields = {}
    in_resource = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("[resource]"):
            in_resource = True
            continue
        if line.startswith("[") and line.endswith("]"):
            in_resource = False
            continue
        if not in_resource:
            continue
        m = NUM_RE.match(line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        if val.startswith('"') and val.endswith('"'):
            fields[key] = val[1:-1]
        elif val in ("true", "false"):
            fields[key] = (val == "true")
        else:
            try:
                fields[key] = int(val)
            except ValueError:
                try:
                    fields[key] = float(val)
                except ValueError:
                    fields[key] = val  # Vector2(...), Color(...), ExtResource(...), etc.
    return fields


def upgrade_report(path: Path) -> str:
    f = parse_tres(path)
    required = ["price_base", "price_mult", "level_cap", "curve_a", "curve_b", "curve_c", "value_cap"]
    missing = [k for k in required if k not in f]
    if missing:
        return f"{path.name}: SKIPPED (missing fields: {', '.join(missing)}, not an UpgradeTrack .tres?)"

    price_base = f["price_base"]
    price_mult = f["price_mult"]
    level_cap = int(f["level_cap"])
    curve_a, curve_b, curve_c = f["curve_a"], f["curve_b"], f["curve_c"]
    value_cap = f["value_cap"]
    is_integer = bool(f.get("is_integer", False))

    def cost(level):
        return price_base * (price_mult ** min(level, level_cap))

    def value(level):
        l = min(level, level_cap)
        v = min(curve_a + curve_b * l + curve_c * l * l, value_cap)
        return int(v) if is_integer else round(v, 3)

    total_cost = sum(cost(lvl) for lvl in range(level_cap))
    lines = [f"== {path.stem} ==  (levels: {level_cap}, total cost to max: {total_cost:,.1f})"]
    lines.append(f"  {'lvl':>3}  {'cost this level':>16}  {'cumulative':>12}  {'value after':>12}")
    cumulative = 0.0
    for lvl in range(level_cap):
        c = cost(lvl)
        cumulative += c
        lines.append(f"  {lvl + 1:>3}  {c:>16,.1f}  {cumulative:>12,.1f}  {value(lvl + 1):>12}")
    return "\n".join(lines)


def trash_report(paths: list) -> str:
    rows = []
    for p in paths:
        f = parse_tres(p)
        rows.append((
            f.get("tier", "?"),
            f.get("display_name", p.stem),
            f.get("material", "?"),
            f.get("pollution", "?"),
            f.get("haul_cost", "?"),
        ))
    rows.sort(key=lambda r: (r[0] if isinstance(r[0], (int, float)) else 99))
    lines = ["== trash catalogue (sorted by tier) =="]
    lines.append(f"  {'tier':>4}  {'name':<16}  {'material':>8}  {'pollution':>9}  {'haul_cost':>9}")
    for tier, name, material, pollution, haul in rows:
        lines.append(f"  {tier:>4}  {name:<16}  {material!s:>8}  {pollution!s:>9}  {haul!s:>9}")
    return "\n".join(lines)


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    upgrades_dir = root / "resources" / "upgrades"
    trash_dir = root / "resources" / "trash"
    economy_path = root / "resources" / "economy.tres"

    if not upgrades_dir.is_dir():
        print(f"error: {upgrades_dir} not found — pass the project root as an argument", file=sys.stderr)
        sys.exit(1)

    print("BALANCE CALCULATOR — math only, not a playtest, not test_lake.gd's mechanical checks.\n")

    reports = []
    skipped = []
    for tres_path in sorted(upgrades_dir.glob("*.tres")):
        r = upgrade_report(tres_path)
        (skipped if "SKIPPED" in r else reports).append((tres_path.stem, r))

    for _, r in sorted(reports, key=lambda kv: kv[0]):
        print(r)
        print()

    if skipped:
        print("-- skipped (not a price/value UpgradeTrack, e.g. skimmer's chance curve) --")
        for _, r in skipped:
            print(" ", r)
        print()

    if trash_dir.is_dir():
        print(trash_report(sorted(trash_dir.glob("*.tres"))))
        print()

    if economy_path.is_file():
        econ = parse_tres(economy_path)
        print("== economy.tres ==")
        for k, v in econ.items():
            if k != "script":
                print(f"  {k} = {v}")
        print()
        print("  (no per-piece income formula is computed here — that lives in lake.gd and")
        print("   wasn't read for this tool; don't infer one without checking the source.)")


if __name__ == "__main__":
    main()
