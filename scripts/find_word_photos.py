"""Finds a free-to-use photo for each word in SooFunny/Words/kids_words.txt.

Searches Wikimedia Commons for CC0 (or public domain) photos, ranks them, and writes the best
few per word to a candidates file. Every pick is reviewed by eye with contact sheets (see
--sheets) before scripts/bundle_word_photos.py copies the chosen ones into the app.

Usage (needs Pillow and internet):
    python3 scripts/find_word_photos.py OUT_DIR            # search (resumes if interrupted)
    python3 scripts/find_word_photos.py OUT_DIR --sheets   # download thumbnails, make sheets
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDS = ROOT / "SooFunny" / "Words" / "kids_words.txt"
API = "https://commons.wikimedia.org/w/api.php"
AGENT = "SooFunnyBuild/0.1 (https://github.com/chengjianglong/SooFunny-app)"
CC0 = "haswbstatement:P275=Q6938433"
PUBLIC_DOMAIN = "haswbstatement:P6216=Q19652"

# Words that need a nudge toward the meaning a child expects.
CATEGORY_HINTS = {
    "Bugs": "insect", "Birds": "bird", "Sea Creatures": "", "Fruit": "fruit",
    "Vegetables": "vegetable", "Music": "", "Space": "", "Sports": "",
}

BAD = re.compile(r"\b(MET|DP\d+|painting|drawing|engraving|etching|lithograph|sculpture|statue|"
                 r"illustration|map|logo|poster|stamp|coin|diagram|museum|specimen|skull|skeleton|"
                 r"dead|nude|naked|blood|hunt|kill|war|gun|rifle|weapon|carcass|slaughter|"
                 r"Smithsonian|Library of Congress|LOC|NARA|archive|manuscript|plate|herbarium|"
                 r"1[5-8]\d\d|19[0-6]\d|fossil|church|grave|cemetery|cigarette|beer|wine|vodka)\b",
                 re.IGNORECASE)
GOOD = re.compile(r"(unsplash|pexels|pixabay)", re.IGNORECASE)


def words():
    category = None
    for line in WORDS.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        text = line.split("|")[0].strip()
        if line.startswith("Category:"):
            category = text[len("Category:"):].strip()
        else:
            yield category, text


def get(params):
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001 - retry anything, the API is flaky under load
            time.sleep(2 + attempt * 3)
            last = e
    raise last


def search(query, license_filter):
    data = get({
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6,
        "gsrlimit": 40, "gsrsearch": f"{query} filemime:image/jpeg {license_filter}",
        "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": 330,
    })
    results = []
    for page in data.get("query", {}).get("pages", {}).values():
        info = page["imageinfo"][0]
        meta = info.get("extmetadata", {})
        results.append({
            "title": page["title"], "rank": page.get("index", 99),
            "width": info["width"], "height": info["height"],
            "thumb": info.get("thumburl"), "url": info["descriptionurl"], "file": info["url"],
            "license": meta.get("LicenseShortName", {}).get("value", ""),
            "author": re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip(),
            "description": re.sub("<[^>]+>", "", meta.get("ImageDescription", {}).get("value", ""))[:300],
        })
    return results


def score(word, c):
    title = c["title"]
    s = -c["rank"]
    if re.search(r"\b" + re.escape(word) + r"s?\b", title, re.IGNORECASE):
        s += 25
    if GOOD.search(title):
        s += 12
    if BAD.search(title) or BAD.search(c["description"]):
        s -= 60
    w, h = c["width"], c["height"]
    if min(w, h) < 600:
        s -= 30
    if max(w, h) / max(1, min(w, h)) > 2:
        s -= 20
    return s


def candidates_for(category, word):
    hint = CATEGORY_HINTS.get(category, "")
    queries = [f"{word} {hint}".strip()] + ([word] if hint else [])
    candidates = []
    enough = lambda: len([c for c in candidates if score(word, c) > -20]) >= 4  # noqa: E731
    for query in queries:
        for license_filter in (CC0, PUBLIC_DOMAIN):
            candidates += search(query, license_filter)
            if enough():
                break
        if enough():
            break
    seen, ranked = set(), []
    for c in sorted(candidates, key=lambda c: -score(word, c)):
        free = c["license"] == "CC0" or "public domain" in c["license"].lower()
        if c["title"] not in seen and c["thumb"] and free:
            seen.add(c["title"])
            ranked.append(c)
    return ranked[:6]


def find(out):
    from concurrent.futures import ThreadPoolExecutor

    out.mkdir(parents=True, exist_ok=True)
    path = out / "candidates.json"
    found = json.loads(path.read_text()) if path.exists() else {}
    todo = [(c, w) for c, w in words() if f"{c}|{w}" not in found]
    with ThreadPoolExecutor(4) as pool:
        for (category, word), ranked in zip(todo, pool.map(lambda cw: candidates_for(*cw), todo)):
            found[f"{category}|{word}"] = ranked
            path.write_text(json.dumps(found, indent=1, ensure_ascii=False))
            print(f"{category}|{word}: {ranked[0]['title'] if ranked else 'NOTHING'}", flush=True)
    # Keep the word list's order.
    order = [f"{c}|{w}" for c, w in words()]
    path.write_text(json.dumps({k: found[k] for k in order}, indent=1, ensure_ascii=False))


def sheets(out, per_word=3):
    from PIL import Image, ImageDraw, ImageFont, ImageOps

    found = json.loads((out / "candidates.json").read_text())
    thumbs = out / "thumbs"
    thumbs.mkdir(exist_ok=True)
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
    keys = list(found)
    cell, size, cols, rows = (3 * 124 + 8, 150), 120, 3, 8
    for sheet in range(0, len(keys), cols * rows):
        canvas = Image.new("RGB", (cols * cell[0], rows * cell[1]), "white")
        draw = ImageDraw.Draw(canvas)
        for i, key in enumerate(keys[sheet:sheet + cols * rows]):
            x, y = (i % cols) * cell[0], (i // cols) * cell[1]
            draw.text((x + 4, y + 2), f"{sheet + i}: {key.split('|')[1]}", fill="black", font=font)
            for j, c in enumerate(found[key][:per_word]):
                name = thumbs / f"{sheet + i}-{j}.jpg"
                if not name.exists():
                    req = urllib.request.Request(c["thumb"], headers={"User-Agent": AGENT})
                    for attempt in range(5):
                        try:
                            name.write_bytes(urllib.request.urlopen(req, timeout=30).read())
                            break
                        except Exception:  # noqa: BLE001
                            time.sleep(3 + attempt * 5)
                try:
                    image = ImageOps.fit(Image.open(name).convert("RGB"), (size, size))
                    canvas.paste(image, (x + 4 + j * 124, y + 22))
                except Exception:  # noqa: BLE001
                    pass
        canvas.save(out / f"sheet-{sheet // (cols * rows):02d}.jpg", quality=80)
        print("sheet", sheet // (cols * rows), flush=True)


if __name__ == "__main__":
    target = Path(sys.argv[1])
    sheets(target) if "--sheets" in sys.argv else find(target)
