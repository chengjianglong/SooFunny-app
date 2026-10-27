"""Copies the reviewed word photos into the app as small square JPEGs, with their credits.

Reads scripts/word_photo_picks.json ({"Group|word": the chosen Commons photo, or null when no
photo suits the word}), made by reviewing the candidates from scripts/find_word_photos.py by
eye. Writes SooFunny/Words/Photos/word-<group>-<word>.jpg and word_photo_credits.json.

Usage (needs Pillow and internet):  python3 scripts/bundle_word_photos.py
"""
import io
import json
import re
import time
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
PHOTOS = ROOT / "SooFunny" / "Words" / "Photos"
PICKS = ROOT / "scripts" / "word_photo_picks.json"
AGENT = "SooFunnyBuild/0.1 (https://github.com/chengjianglong/SooFunny-app)"
SIZE = 480


def slug(text):
    """Matches WordPhotos.slug in the app."""
    return "-".join(p for p in re.sub(r"[^0-9a-z]", "-", text.lower()).split("-") if p)


def fetch(url):
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": AGENT})
            return urllib.request.urlopen(req, timeout=60).read()
        except Exception as e:  # noqa: BLE001 - thumbnails are rate limited; back off and retry
            last = e
            time.sleep(4 + attempt * 6)
    raise last


def main():
    picks = json.loads(PICKS.read_text())
    PHOTOS.mkdir(parents=True, exist_ok=True)
    credits, wanted = [], set()
    for key, c in picks.items():
        category, word = key.split("|", 1)
        if c is None:
            continue
        # Only photos anyone may use freely: Commons search sometimes returns other licenses.
        if not (c["license"] == "CC0" or "public domain" in c["license"].lower()):
            raise SystemExit(f"{key}: {c['title']} is {c['license']}, not CC0 or public domain")
        name = f"word-{slug(category)}-{slug(word)}.jpg"
        wanted.add(name)
        target = PHOTOS / name
        # Keep the pick in sync: re-download when the chosen photo changed.
        if not target.exists() or not any(x["file"] == name and x["source"] == c["title"] for x in old_credits()):
            thumb = re.sub(r"/\d+px-", "/960px-", c["thumb"]) if c["width"] > 960 else c["file"]
            image = Image.open(io.BytesIO(fetch(thumb))).convert("RGB")
            ImageOps.fit(image, (SIZE, SIZE), Image.LANCZOS).save(target, quality=74, optimize=True, progressive=True)
            print("saved", name, flush=True)
            time.sleep(0.5)
        credits.append({"file": name, "category": category, "title": word, "source": c["title"],
                        "license": "CC0" if "CC0" in c["license"] else (c["license"] or "Public domain"),
                        "author": c["author"] or "Unknown", "url": c["url"]})
    for stale in PHOTOS.glob("word-*.jpg"):
        if stale.name not in wanted:
            stale.unlink()
    (PHOTOS / "word_photo_credits.json").write_text(json.dumps(credits, indent=1, ensure_ascii=False))
    print(len(credits), "photos")


def old_credits():
    path = PHOTOS / "word_photo_credits.json"
    if not hasattr(old_credits, "cache"):
        old_credits.cache = json.loads(path.read_text()) if path.exists() else []
    return old_credits.cache


if __name__ == "__main__":
    main()
