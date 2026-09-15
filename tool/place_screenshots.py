"""Place the supplied device screenshots into docs/screenshots/.

Run: uv run --with pillow --python 3.12 python tool/place_screenshots.py
- trims dead background above/below the real content (some captures carry a long
  empty tail)
- downscales to 420 px wide (2x the README display width of 210)
- writes PNGs (flat UI compresses well and stays crisp)
- removes the SVG placeholders they replace
"""
from pathlib import Path
from PIL import Image

UPLOADS = Path(r"C:\Users\JHarayden\.hermes-web-ui\upload\default")
OUT = Path(__file__).resolve().parent.parent / "docs" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)

SHOTS = [
    ("01-analysis", "c8396633aa35411e.jpg", "analysis page"),
    ("02-quick-entry", "8394bc52025f3775.jpg", "quick entry"),
    ("03-ledger", "045132c4933fe56a.jpg", "ledger"),
    ("04-assets", "235bf73e39638242.jpg", "assets"),
    ("05-stats-daily", "e8612cb4697b7725.jpg", "statistics day"),
    ("06-stats-month", "7f7d07a62d7fd9d7.jpg", "statistics month"),
    ("07-splash", "82274e0fb46f4f1f.jpg", "splash"),
    ("08-asset-detail", "4789e996d3cc5a00.jpg", "asset detail"),
]

WIDTH = 420
MARGIN = 16
THRESHOLD = 10


def trim_flat(image: Image.Image) -> Image.Image:
    """Drop uniform background bands at the top and bottom."""
    w, h = image.size
    px = image.load()
    bg = px[2, 2]
    first, last = 0, h - 1
    for y in range(h):
        if any(
            max(abs(px[x, y][i] - bg[i]) for i in range(3)) > THRESHOLD
            for x in range(0, w, 8)
        ):
            first = y
            break
    for y in range(h - 1, -1, -1):
        if any(
            max(abs(px[x, y][i] - bg[i]) for i in range(3)) > THRESHOLD
            for x in range(0, w, 8)
        ):
            last = y
            break
    top = max(0, first - MARGIN)
    bottom = min(h, last + 1 + MARGIN)
    return image.crop((0, top, w, bottom))


total = 0
print(f"{'target':18} {'orig':>12} {'trimmed':>12} {'out':>11} {'bytes':>8}")
for name, src, label in SHOTS:
    src_path = UPLOADS / src
    if not src_path.exists():
        print(f"{name:18} MISSING SOURCE {src}")
        continue
    im = Image.open(src_path).convert("RGB")
    orig = im.size
    im = trim_flat(im)
    trimmed = im.size
    height = round(im.height * WIDTH / im.width)
    im = im.resize((WIDTH, height), Image.LANCZOS)
    dst = OUT / f"{name}.png"
    im.save(dst, format="PNG", optimize=True)
    size = dst.stat().st_size
    total += size
    print(f"{name:18} {str(orig):>12} {str(trimmed):>12} {f'{WIDTH}x{height}':>11} {size:>8}")

for old in OUT.glob("*.svg"):
    old.unlink()
    print("removed placeholder", old.name)

print(f"total {total/1024:.0f} KB across {len(SHOTS)} screenshots")
