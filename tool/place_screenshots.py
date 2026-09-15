"""Place the supplied device screenshots into docs/screenshots/.

Run: uv run --with pillow --python 3.12 python tool/place_screenshots.py
- paints pure black over the number plate in the two captures that show the car
  (owner's request: 车牌用纯黑盖住)
- trims dead background above/below the real content
- downscales to 420 px wide (2x the README display width of 210)
- writes PNGs (flat UI compresses well and stays crisp)
- removes the SVG placeholders they replace
"""
from pathlib import Path
from PIL import Image, ImageDraw

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

# Redactions in ORIGINAL pixel coordinates (left, top, right, bottom) - number plates.
COVERS = {
    # list thumbnail of the car
    "04-assets": [(190, 1472, 272, 1502)],
    # hero photo on the asset detail page
    "08-asset-detail": [(548, 895, 910, 1000)],
}

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
    return image.crop((0, max(0, first - MARGIN), w, min(h, last + 1 + MARGIN)))


total = 0
print(f"{'target':18} {'orig':>12} {'trimmed':>12} {'out':>11} {'bytes':>8}  covers")
for name, src, label in SHOTS:
    src_path = UPLOADS / src
    if not src_path.exists():
        print(f"{name:18} MISSING SOURCE {src}")
        continue
    im = Image.open(src_path).convert("RGB")
    orig = im.size
    covers = COVERS.get(name, [])
    if covers:
        draw = ImageDraw.Draw(im)
        for box in covers:
            draw.rectangle(box, fill=(0, 0, 0))
    im = trim_flat(im)
    trimmed = im.size
    height = round(im.height * WIDTH / im.width)
    im = im.resize((WIDTH, height), Image.LANCZOS)
    dst = OUT / f"{name}.png"
    im.save(dst, format="PNG", optimize=True)
    size = dst.stat().st_size
    total += size
    print(
        f"{name:18} {str(orig):>12} {str(trimmed):>12} {f'{WIDTH}x{height}':>11} "
        f"{size:>8}  {covers if covers else '-'}"
    )

for old in OUT.glob("*.svg"):
    old.unlink()
    print("removed placeholder", old.name)

print(f"total {total/1024:.0f} KB across {len(SHOTS)} screenshots")
