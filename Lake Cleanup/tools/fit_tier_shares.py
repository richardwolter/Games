"""Rescale LakeGrid.TIER_BY_DEPTH's columns so the fresh lake's tier shares land on TARGET.

Each column (a tier) is multiplied by target / measured, read off the "tier N" lines of
tools/last_fill_economy.log, so every depth band keeps its own lean. Rows are normalised
where the fill reads them, and FILL_BAIT_CHANCE and the ring's trade blur the result, so
this is one step of a loop:

    godot --path . --headless res://tools/probe_fill_economy.tscn --log-file <path>
    python tools/fit_tier_shares.py      prints the shares and rescales the table

Repeat until it says every tier is within TOLERANCE.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# 2026-10-03, Richard: a smooth ladder, tier 3 about 12% and tier 4 about 10%.
TARGET = [0.30, 0.25, 0.23, 0.12, 0.10]
TOLERANCE = 0.004


def main():
    log = (ROOT / "tools/last_fill_economy.log").read_text()
    got = [float(x) for x in re.findall(r"^tier \d  ([\d.]+)$", log, re.M)]
    print("measured", got)
    if all(abs(g - t) <= TOLERANCE for g, t in zip(got, TARGET)):
        print("within tolerance")
        return 0
    src = ROOT / "scripts/lake_grid.gd"
    text = src.read_text(encoding="utf-8")
    block = re.search(r"const TIER_BY_DEPTH := \[\n(.*?)\n\]", text, re.S)
    rows = [[float(x) for x in re.findall(r"[\d.]+", line)] for line in block.group(1).splitlines()]
    scale = [t / g for t, g in zip(TARGET, got)]
    rows = [[v * s for v, s in zip(row, scale)] for row in rows]
    # Each row back to a sum of 1, so the table still reads as shares.
    rows = [[v / sum(row) for v in row] for row in rows]
    body = "\n".join("\t[%s]," % ", ".join("%.3f" % v for v in row) for row in rows)
    text = text[:block.start(1)] + body + text[block.end(1):]
    src.write_text(text, encoding="utf-8", newline="")
    print("rescaled")
    for row in rows:
        print("  ", ["%.3f" % v for v in row])
    return 1


if __name__ == "__main__":
    sys.exit(main())
