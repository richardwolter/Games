"""Download 0_mem0ry's free asset packs into art_source/packs_local/ (git-ignored).

Their licence allows use and modification in commercial games but forbids
redistribution, so the raw packs never enter the public repo; only the game's own
cut sheets in assets/ do. A fresh clone runs this to get them back.

itch's free-download flow, as the site does it: the game page gives a CSRF token
and a session cookie, POST /<slug>/download_url gives the download page, which
lists the uploads, and POST /<slug>/file/<id> gives a signed link good for 60 s.

    python tools/fetch_mem0ry_packs.py
"""
import http.cookiejar, json, re, urllib.parse, urllib.request, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art_source/packs_local"
HOST = "https://0-mem0ry.itch.io"
SLUGS = [
    "post-apoc-office-mega-bundle-free", "post-apoc-shelter-mega-bundle-free",
    "messy-furniture-set-mega-bundle-free", "public-bathroom-furniture-set-free",
    "retro-bathroom-furniture-set-free", "stylish-furniture-set-free", "graveyard-set-free",
    "50s-diner-furniture-set-free", "xmas-decorations-free", "professional-kitchen-set-free",
    "classic-furniture-set-free", "coastal-furniture-set-free",
    "post-apocalyptic-workshop-set-free", "rustic-furniture-set-free",
    "camping-furniture-set-free", "makeshift-furniture-set-free",
    "fancy-mansion-furniture-set-free", "midcentury-modern-furniture-set-free",
    "garden-planters-free", "canned-goods-free",
]

jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
opener.addheaders = [("User-Agent", "Mozilla/5.0 (asset fetch for My Dirty Little Lake)")]


def get(url):
    return opener.open(url).read().decode("utf-8", "replace")


def post(url, csrf):
    data = urllib.parse.urlencode({"csrf_token": csrf}).encode()
    req = urllib.request.Request(url, data, {"X-Requested-With": "XMLHttpRequest"})
    return json.loads(opener.open(req).read())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for slug in SLUGS:
        dest = OUT / slug
        if dest.exists() and any(dest.iterdir()):
            print("have", slug)
            continue
        dest.mkdir(exist_ok=True)
        page = get(f"{HOST}/{slug}/purchase")
        csrf = re.search(r'name="csrf_token" value="([^"]+)"', page) or re.search(r'csrf_token" content="([^"]+)"', page)
        csrf = csrf.group(1)
        dl = post(f"{HOST}/{slug}/download_url", csrf)["url"]
        dpage = get(dl)
        again = re.search(r'name="csrf_token" (?:value|content)="([^"]+)"', dpage)
        csrf = again.group(1) if again else csrf
        for uid, name in re.findall(r'data-upload_id="(\d+)".*?<strong title="([^"]+)" class="name"', dpage, re.S):
            url = post(f"{HOST}/{slug}/file/{uid}?source=game_download", csrf)["url"]
            data = opener.open(url).read()
            path = dest / name
            path.write_bytes(data)
            print(slug, name, len(data))
            if name.lower().endswith(".zip"):
                with zipfile.ZipFile(path) as z:
                    z.extractall(dest)


if __name__ == "__main__":
    main()
