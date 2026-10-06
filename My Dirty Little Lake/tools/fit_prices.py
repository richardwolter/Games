"""Fit resources/economy.tres's price table so each yard's mean pay per piece holds.

Prices are B_material x SHAPE[tier]. SHAPE's steps are each at least 1.3, over the 1.25
the yards' bases spread by, so every heavier tier pays more than any piece of the tier
below in every yard. B is solved from each material's tier mix, read off
tools/last_fill_economy.log (the "mix" lines from tools/probe_fill_economy.tscn).

    python tools/fit_prices.py        writes the table into resources/economy.tres
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# test_lake's PAY_PRICED halved (the lake is twice as dense since 2026-09-24): mean pay per
# piece, Plastic, Wood, Metal, Rubber, that shop.json was priced on.
PAY_TARGET = [22.0, 22.88, 18.25, 20.29]
SHAPE = [1.0, 1.5, 2.0, 2.6, 3.4]


def main():
    log = (ROOT / "tools/last_fill_economy.log").read_text()
    mixes = [[float(x) for x in m.split()] for m in re.findall(r"^mix \d (.+)$", log, re.M)]
    prices = []
    for m in range(4):
        mix = mixes[m]
        base = PAY_TARGET[m] / (sum(s * g for s, g in zip(mix, SHAPE)) / sum(mix))
        prices.append([round(base * g, 2) for g in SHAPE])
    tres = ROOT / "resources/economy.tres"
    text = tres.read_text()
    flat = ", ".join("%g" % p for row in prices for p in row)
    text = re.sub(r"piece_prices = PackedFloat32Array\([^)]*\)",
                  "piece_prices = PackedFloat32Array(%s)" % flat, text)
    tres.write_text(text, newline="\n")
    for m, row in enumerate(prices):
        print(["Plastic", "Wood", "Metal", "Rubber"][m], row)


if __name__ == "__main__":
    main()
