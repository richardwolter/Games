"""Merge the translation pipeline's output into locale/translations.csv.

For each locale: out_<l>.json (translator) with review_<l>.json (reviewer) applied over it;
the text goes to the locale's column and the back-translation to `_back_<l>`. Validates every
cell against the PT source (placeholders, asterisks, newlines, edge spaces, the French
no-break space) and refuses to write if anything fails. Run from the project root:
    python tools/l10n_merge.py [--dry]
"""
import csv, io, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "locale", "translations.csv")
WORK = os.path.join(ROOT, "tools", "l10n_work")
LOCALES = ["en", "es", "de", "fr", "ja", "zh_CN", "ko"]
KEEP_EDGE = {"LETTER_GREETING_LEAD", "SHOP_TIER_PREFIX"}


def ph(t):
    return sorted(re.findall(r"%[ds]", t))


def main():
    dry = "--dry" in sys.argv
    raw = open(CSV, encoding="utf-8", newline="").read()
    rows = list(csv.reader(io.StringIO(raw)))
    head = rows[0]
    col = {name: i for i, name in enumerate(head)}
    by_key = {r[0]: r for r in rows[1:]}
    problems = []
    report = {}
    for loc in LOCALES:
        out = {e["key"]: e for e in json.load(open(os.path.join(WORK, f"out_{loc}.json"), encoding="utf-8"))}
        review_path = os.path.join(WORK, f"review_{loc}.json")
        review = json.load(open(review_path, encoding="utf-8")) if os.path.exists(review_path) else []
        fixes = {}
        for e in review:
            fixes[e["key"]] = e
        report[loc] = {"translated": len(out), "reviewed": len(fixes)}
        for key, e in out.items():
            if key not in by_key:
                problems.append(f"{loc} {key}: not in the CSV")
                continue
            row = by_key[key]
            pt = row[col["pt_BR"]]
            text = fixes[key]["text"] if key in fixes else e["text"]
            back = fixes[key].get("back", "") if key in fixes else e.get("back", "")
            if ph(text) != ph(pt):
                problems.append(f"{loc} {key}: placeholders {ph(text)} vs {ph(pt)}")
            if text.count("*") != pt.count("*") or text.count("*") % 2:
                problems.append(f"{loc} {key}: asterisks {text.count('*')} vs {pt.count('*')}")
            if text.count("\n") != pt.count("\n"):
                problems.append(f"{loc} {key}: paragraphs {text.count(chr(10))} vs {pt.count(chr(10))}")
            if key not in KEEP_EDGE and text != text.strip():
                problems.append(f"{loc} {key}: space at an end")
            if "  " in text and "  " not in pt:
                problems.append(f"{loc} {key}: double space")
            if loc == "fr" and re.search(r" [!?:;]", text):
                problems.append(f"{loc} {key}: ordinary space before a mark")
            if not text:
                problems.append(f"{loc} {key}: empty")
            row[col[loc]] = text
            if f"_back_{loc}" in col:
                row[col[f"_back_{loc}"]] = back
    print(json.dumps(report))
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if dry:
        print("dry run, nothing written")
        return
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    open(CSV, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("written")


if __name__ == "__main__":
    main()
