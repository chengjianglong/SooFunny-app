#!/usr/bin/env python3
"""Exports the content written in the iOS app's Swift sources to JSON for the Android app.

The word list (kids_words.txt) and the photos are read straight from SooFunny/ by the Gradle
build; only content that lives in Swift code needs this step:

  SooFunny/Sports/OlympicSports.swift      -> app/src/main/assets/data/sports.json
  SooFunny/Books/StoryBooks.swift
  + SooFunny/Books/StoryTranslations.swift -> app/src/main/assets/data/books.json

Run it after changing those Swift files:  python3 android/tools/export_ios_data.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
IOS = ROOT / "SooFunny"
OUT = ROOT / "android" / "app" / "src" / "main" / "assets" / "data"

STRING = r'"((?:[^"\\]|\\.)*)"'


def unescape(s: str) -> str:
    return (s.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t")
             .replace("\\'", "'").replace("\\\\", "\\"))


def strings(text: str) -> list[str]:
    return [unescape(m) for m in re.findall(STRING, text)]


def sports() -> list[dict]:
    src = (IOS / "Sports" / "OlympicSports.swift").read_text(encoding="utf-8")
    body = src[src.index("static let all"):]
    out = []
    # Each sport is a call `s("id", .season, "emoji", "English", "中文", "about", "关于"[, photo: "word"])`.
    for m in re.finditer(r'\bs\(\s*' + STRING + r'\s*,\s*\.(summer|winter)\s*,(.*?)\)\s*,\s*\n', body, re.S):
        rest = m.group(3)
        photo = re.search(r'photo:\s*' + STRING, rest)
        if photo:
            rest = rest[:photo.start()]
        values = strings(rest)
        if len(values) != 5:
            sys.exit(f"sport {m.group(1)}: expected 5 strings, found {len(values)}")
        emoji, english, chinese, about_en, about_zh = values
        out.append({
            "id": unescape(m.group(1)), "season": m.group(2), "emoji": emoji,
            "english": english, "chinese": chinese,
            "aboutEnglish": about_en, "aboutChinese": about_zh,
            "photo": {"category": "Sports", "word": unescape(photo.group(1))} if photo else None,
        })
    return out


def books() -> list[dict]:
    src = (IOS / "Books" / "StoryBooks.swift").read_text(encoding="utf-8")
    trans_src = (IOS / "Books" / "StoryTranslations.swift").read_text(encoding="utf-8")
    translations = {}
    for m in re.finditer(STRING + r'\s*:\s*Translation\(title:\s*' + STRING + r'\s*,\s*pages:\s*\[(.*?)\]\s*\)', trans_src, re.S):
        translations[unescape(m.group(1))] = {"title": unescape(m.group(2)), "pages": strings(m.group(3))}

    out = []
    starts = [m for m in re.finditer(r'StoryBook\(id:\s*' + STRING + r'\s*,\s*title:\s*' + STRING
                                     + r'\s*,\s*cover:\s*' + STRING + r'\s*,\s*color:\s*\.(\w+)\s*,\s*pages:\s*\[', src)]
    for i, m in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(src)
        chunk = src[m.end():end]
        pages = [{"scene": unescape(s), "text": unescape(t)}
                 for s, t in re.findall(r'StoryPage\(scene:\s*' + STRING + r'\s*,\s*text:\s*' + STRING + r'\s*\)', chunk)]
        lang = re.search(r'\]\s*,\s*language:\s*\.(\w+)\s*\)', chunk)
        book_id = unescape(m.group(1))
        t = translations.get(book_id)
        if t is None or len(t["pages"]) != len(pages):
            sys.exit(f"book {book_id}: translation missing or page count differs")
        out.append({
            "id": book_id, "title": unescape(m.group(2)), "cover": unescape(m.group(3)), "color": m.group(4),
            "language": lang.group(1) if lang else "english", "pages": pages,
            "translation": t,
        })
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    s, b = sports(), books()
    if len(s) != 51:
        sys.exit(f"expected 51 sports, found {len(s)}")
    if len(b) != 10:
        sys.exit(f"expected 10 books, found {len(b)}")
    for name, data in (("sports.json", s), ("books.json", b)):
        (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {len(s)} sports and {len(b)} books to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
