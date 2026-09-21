"""Keeps locale/translations.csv in step with the game (issue #28).

    python tools/build_translations.py

The CSV is the source of truth and is edited by hand (and by the artifact page's export).
This does exactly two mechanical things to it and nothing else:

1. **The find titles follow `assets/pieces.json`.** A `DECOR_*` row per titled decoration
   piece: added when a find is added, its `en` updated when a title is renamed. A row whose
   piece is gone is **reported, not deleted** — its translations are somebody's work, and a
   renamed slug looks exactly like a deleted one from here.
2. **The `qps` pseudo-locale is rebuilt from `en`.** Every string wrapped in brackets,
   its vowels accented and padded about 40% longer, so in play a word the game still hard
   codes stands out as the one with no brackets, and a box too small for a longer language
   overflows before any real translation exists. `%d` and `%s` are carried through intact.
   **Only glyphs Bungee has**: system font fallback is off (`Style._no_system`), so anything
   else would draw as tofu and be mistaken for a bug in the words.

Every other cell is left exactly as it was found.
"""
import csv
import io
import json
import math
import re
import sys

CSV_PATH = "locale/translations.csv"
PIECES = "assets/pieces.json"
FIND_NOTE = "A piece of furniture the player finds."
FIND_BUDGET = ("13", "11", "180")

# Latin-1 accents only: all of these are in Bungee's 1082 codepoints, measured.
ACCENT = str.maketrans({
    "a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú", "n": "ñ", "c": "ç",
    "A": "Á", "E": "É", "I": "Í", "O": "Ó", "U": "Ú", "N": "Ñ", "C": "Ç",
})
PAD = "ëxtràlóng"
GROW = 0.4
MARK = re.compile(r"%[ds]")


def pseudo(text: str) -> str:
    if not text:
        return ""
    # Accent the words, never a placeholder: `%d` must survive for the `%` operator.
    parts = MARK.split(text)
    marks = MARK.findall(text)
    out = parts[0].translate(ACCENT)
    for mark, part in zip(marks, parts[1:]):
        out += mark + part.translate(ACCENT)
    want = math.ceil(len(text) * GROW)
    pad = (PAD * (want // len(PAD) + 1))[:want]
    return "[" + out + "·" + pad + "]"


def main() -> int:
    rows = list(csv.reader(open(CSV_PATH, encoding="utf-8")))
    head = rows[0]
    if "qps" not in head:
        head.append("qps")
    col = {name: i for i, name in enumerate(head)}
    body = [r + [""] * (len(head) - len(r)) for r in rows[1:]]
    by_key = {r[col["keys"]]: r for r in body}

    pieces = json.load(open(PIECES, encoding="utf-8"))["pieces"]
    titles = {
        "DECOR_" + p["name"][6:].upper(): p["title"]
        for p in pieces if "title" in p and p["name"].startswith("decor_")
    }
    added, renamed = [], []
    for key, title in titles.items():
        row = by_key.get(key)
        if row is None:
            row = [""] * len(head)
            row[col["keys"]] = key
            row[col["_where"]] = "pieces.json"
            row[col["_size"]], row[col["_least"]], row[col["_width"]] = FIND_BUDGET
            row[col["_note"]] = FIND_NOTE
            row[col["en"]] = title
            body.append(row)
            by_key[key] = row
            added.append(key)
        elif row[col["en"]] != title:
            renamed.append("%s: %r -> %r" % (key, row[col["en"]], title))
            row[col["en"]] = title
    orphans = [k for k in by_key if k.startswith("DECOR_") and k not in titles]

    for row in body:
        row[col["qps"]] = pseudo(row[col["en"]])

    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(head)
    writer.writerows(body)
    open(CSV_PATH, "w", encoding="utf-8", newline="").write(out.getvalue())

    print("%d rows, %d find titles" % (len(body), len(titles)))
    for key in added:
        print("  added   ", key)
    for line in renamed:
        print("  renamed ", line)
    for key in orphans:
        print("  ORPHAN  ", key, "- no piece in pieces.json has this title any more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
