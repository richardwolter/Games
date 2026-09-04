"""Render body_plan.gd as an SVG design map.

Parses PARTS / LINKS / FORKS straight out of the GDScript so the drawing can
never drift from the data. Output is tools/out/body_map.svg -- open it in a
browser or drop it into any art tool to sketch over.
"""
import re, pathlib, math

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / "src" / "body_plan.gd").read_text(encoding="utf-8")

PART_RE = re.compile(
    r'"(\w+)":\s*\{"name":\s*"([^"]+)",\s*"cell":\s*Vector2i\((-?\d+),\s*(-?\d+)\),'
    r'\s*"region":\s*Region\.(\w+),\s*"color":\s*Color\(([\d.]+),\s*([\d.]+),\s*([\d.]+)\)')
LINK_RE = re.compile(r'\{"a":\s*"(\w+)",\s*"b":\s*"(\w+)",\s*"a_dir":\s*"(\w)"\}')
FORK_RE = re.compile(r'\{"from":\s*"(\w+)",\s*"branches":\s*\[([^\]]+)\],\s*"join":\s*"(\w+)"\}')

parts = {}
for m in PART_RE.finditer(SRC):
    pid, name, x, y, region, r, g, b = m.groups()
    parts[pid] = dict(name=name, cell=(int(x), int(y)), region=region,
                      color="#%02x%02x%02x" % tuple(round(float(c) * 255) for c in (r, g, b)))

links = [m.groups() for m in LINK_RE.finditer(SRC)]
forks = [(m.group(1), [s.strip().strip('"') for s in m.group(2).split(",")], m.group(3))
         for m in FORK_RE.finditer(SRC)]

CHAMBER_OVERRIDES = set(re.search(r'const CHAMBER_OVERRIDES.*?\[(.*?)\]', SRC, re.S).group(1).replace("\n", "").split(","))
CHAMBER_OVERRIDES = {s.strip().strip('"') for s in CHAMBER_OVERRIDES if s.strip()}
ENTRY = {s.strip().strip('"') for s in re.search(r'const ENTRY_POINTS.*?\[(.*?)\]', SRC, re.S).group(1).replace("\n", "").split(",") if s.strip()}
NO_ITEM = {s.strip().strip('"') for s in re.search(r'const NO_ITEM.*?\[(.*?)\]', SRC, re.S).group(1).split(",") if s.strip()}


def shape_of(pid):
    if pid in CHAMBER_OVERRIDES:
        return "CHAMBER"
    region = parts[pid]["region"]
    if region in ("ARM", "LEG"):
        return "LANE"
    if region == "CORE_ORGAN":
        return "CAVERN"
    return "CHAMBER"


# --- spine: rooms on no fork branch ---
neigh = {}
for a, b, _ in links:
    neigh.setdefault(a, []).append(b)
    neigh.setdefault(b, []).append(a)

def branch_cells(branch, frm, others, join):
    blocked = {frm, join} | (set(others) - {branch})
    seen, queue, out = {branch}, [branch], []
    while queue:
        cur = queue.pop(0)
        out.append(cur)
        for n in neigh.get(cur, []):
            if n in blocked or n in seen:
                continue
            seen.add(n)
            queue.append(n)
    return out

spine = {p: True for p in parts}
for frm, branches, join in forks:
    for br in branches:
        for member in branch_cells(br, frm, branches, join):
            spine[member] = False

# --- geometry ---
CELL = 190          # grid pitch in px
PAD = 130
SIZES = {"CHAMBER": (128, 104), "LANE": (168, 62), "CAVERN": (152, 126)}

xs = [c["cell"][0] for c in parts.values()]
ys = [c["cell"][1] for c in parts.values()]
minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
W = (maxx - minx) * CELL + PAD * 2
H = (maxy - miny) * CELL + PAD * 2

def px(cell):
    return (cell[0] - minx) * CELL + PAD, (cell[1] - miny) * CELL + PAD

def box(pid):
    cx, cy = px(parts[pid]["cell"])
    w, h = SIZES[shape_of(pid)]
    # lanes in arms run horizontally, lanes in legs run vertically
    if shape_of(pid) == "LANE" and parts[pid]["region"] == "LEG":
        w, h = h, w
    return cx, cy, w, h

out = []
A = out.append
A(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Segoe UI, sans-serif">')
A(f'<rect width="{W}" height="{H}" fill="#12100f"/>')
# faint grid to sketch against
A('<g stroke="#221e1c" stroke-width="1">')
for gx in range(minx, maxx + 1):
    x = (gx - minx) * CELL + PAD
    A(f'<line x1="{x}" y1="0" x2="{x}" y2="{H}"/>')
for gy in range(miny, maxy + 1):
    y = (gy - miny) * CELL + PAD
    A(f'<line x1="0" y1="{y}" x2="{W}" y2="{y}"/>')
A('</g>')

fork_pairs = set()
for frm, branches, join in forks:
    for br in branches:
        fork_pairs.add(tuple(sorted((frm, br))))

# --- links ---
A('<g stroke-linecap="round">')
for a, b, d in links:
    ax, ay = px(parts[a]["cell"])
    bx, by = px(parts[b]["cell"])
    is_fork = tuple(sorted((a, b))) in fork_pairs
    col = "#c8863c" if is_fork else "#4a4340"
    wdt = 5 if is_fork else 3.5
    A(f'<line x1="{ax}" y1="{ay}" x2="{bx}" y2="{by}" stroke="{col}" stroke-width="{wdt}"/>')
    # door pip on a's wall
    mx, my = (ax + bx) / 2, (ay + by) / 2
    A(f'<circle cx="{mx}" cy="{my}" r="4" fill="{col}"/>')
A('</g>')

# --- rooms ---
for pid, p in parts.items():
    cx, cy, w, h = box(pid)
    sh = shape_of(pid)
    x, y = cx - w / 2, cy - h / 2
    stroke = "#f0e6d8" if spine[pid] else "#8a7f76"
    dash = '' if spine[pid] else ' stroke-dasharray="7 5"'
    rx = h / 2 if sh == "LANE" else (26 if sh == "CAVERN" else 10)
    A(f'<rect x="{x:.0f}" y="{y:.0f}" width="{w}" height="{h}" rx="{rx:.0f}" '
      f'fill="{p["color"]}" fill-opacity="0.88" stroke="{stroke}" stroke-width="2.5"{dash}/>')
    if pid in ENTRY:
        A(f'<circle cx="{cx}" cy="{cy}" r="{max(w, h) / 2 + 16:.0f}" fill="none" '
          f'stroke="#5ad0c0" stroke-width="3" stroke-dasharray="6 6"/>')
    if pid in NO_ITEM:
        A(f'<text x="{cx}" y="{cy + h / 2 + 34:.0f}" fill="#5ad0c0" font-size="15" text-anchor="middle">no item</text>')
    label = p["name"]
    A(f'<text x="{cx}" y="{cy - 2:.0f}" fill="#15100e" font-size="17" font-weight="600" text-anchor="middle">{label}</text>')
    A(f'<text x="{cx}" y="{cy + 17:.0f}" fill="#2a1f1b" font-size="13" text-anchor="middle" opacity="0.75">{sh.lower()}</text>')

# --- legend ---
lx, ly = PAD - 60, PAD - 90
A(f'<g transform="translate({lx},{ly})">')
A('<rect x="-16" y="-28" width="470" height="176" rx="12" fill="#1b1715" stroke="#3a3330"/>')
A('<text x="0" y="0" fill="#f0e6d8" font-size="22" font-weight="700">The Uncle — floor map</text>')
rows = [
    ("#f0e6d8", "solid outline = spine (always reachable; boss + exits live here)"),
    ("#8a7f76", "dashed outline = fork branch (sealed if you pick the other side)"),
    ("#c8863c", "orange edge = fork door (exclusive choice)"),
    ("#5ad0c0", "teal ring = possible entry wound"),
]
for i, (c, t) in enumerate(rows):
    yy = 30 + i * 27
    A(f'<rect x="0" y="{yy - 11}" width="22" height="14" rx="4" fill="{c}"/>')
    A(f'<text x="32" y="{yy}" fill="#cfc4b8" font-size="15">{t}</text>')
A(f'<text x="0" y="146" fill="#8a7f76" font-size="14">{len(parts)} rooms · {len(links)} doors · {len(forks)} forks · shape: lane / chamber / cavern</text>')
A('</g>')
A('</svg>')

dest = ROOT / "tools" / "out"
dest.mkdir(exist_ok=True)
(dest / "body_map.svg").write_text("\n".join(out), encoding="utf-8")
print("wrote", dest / "body_map.svg", f"{W}x{H}", len(parts), "rooms")
