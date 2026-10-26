"""Builds the app icon from the Soo artwork in design/soo-icon.png.

iOS draws its own rounded corners and rejects icons with transparency, so this crops just
inside the artwork's rounded, glossy rim and writes an opaque 1024x1024 PNG.

Usage (needs Pillow):  python3 scripts/make_icon.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "design" / "soo-icon.png"
TARGET = ROOT / "SooFunny" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

# (left, top, right, bottom) in source pixels: inside the rim at every corner.
CROP = (50, 55, 814, 797)

art = Image.open(SOURCE).convert("RGB").crop(CROP)
art.resize((1024, 1024), Image.LANCZOS).save(TARGET)
print(f"wrote {TARGET.relative_to(ROOT)}")
