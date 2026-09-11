#!/usr/bin/env python3
"""Build one review sheet for the generated brand assets (T-09E).

Everything on the sheet comes from the files that ship (Android mipmaps +
Windows ico), so a visual pass over the sheet is a pass over the real assets.
Layout: legacy icons row, adaptive foreground (as-is + on the Android round
mask preview) and the Windows ico sizes on both the canvas plate and a light
background (to judge contrast).

Usage: python tool/brand_preview.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
OUT = ROOT / "evidence" / "t09e" / "brand_assets_preview.png"

CANVAS = (0x0C, 0x0B, 0x09, 0xFF)
LIGHT = (0xF2, 0xF2, 0xF2, 0xFF)
GAP = 16
PAD = 24


def labelled(tile: Image.Image) -> Image.Image:
    return tile


def main() -> int:
    rows: list[list[tuple[str, Image.Image]]] = []

    # Row 1: legacy launcher icon at every shipped density.
    legacy = [
        Image.open(RES / f"mipmap-{bucket}" / "ic_launcher.png").convert("RGBA")
        for bucket in ("xxxhdpi", "xxhdpi", "xhdpi", "hdpi", "mdpi")
    ]
    rows.append([(f"legacy {im.width}px", im) for im in legacy])

    # Row 2: adaptive foreground raw + on the round mask (Android 26+), both on
    # the canvas background the adaptive icon ships with.
    fg = Image.open(RES / "mipmap-xxxhdpi" / "ic_launcher_foreground.png").convert("RGBA")
    fg_small = fg.resize((216, 216), Image.LANCZOS)
    plate = Image.new("RGBA", fg_small.size, CANVAS)
    plate.alpha_composite(fg_small)
    masked = plate.copy()
    mask = Image.new("L", masked.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, masked.width - 1, masked.height - 1), fill=255)
    round_preview = Image.new("RGBA", masked.size, CANVAS)
    round_preview.paste(masked, (0, 0), mask)
    rows.append(
        [
            (f"adaptive fg {fg_small.width}px", plate),
            ("round mask", round_preview),
        ]
    )

    # Row 3: Windows ico sizes on the canvas plate and on a light background.
    ico = Image.open(ICO).convert("RGBA")
    sizes = (16, 32, 48, 64, 128)
    dark_row = []
    light_row = []
    for size in sizes:
        frame = ico.resize((size, size), Image.LANCZOS)
        for bg, row in ((CANVAS, dark_row), (LIGHT, light_row)):
            tile = Image.new("RGBA", (max(size, 64), max(size, 64)), bg)
            tile.alpha_composite(frame, ((tile.width - size) // 2, (tile.height - size) // 2))
            row.append((f"ico {size}", tile))
    rows.append(dark_row)
    rows.append(light_row)

    width = PAD * 2 + max(
        sum(tile.width for _, tile in row) + GAP * (len(row) - 1) for row in rows
    )
    height = PAD * 2 + sum(
        max(tile.height for _, tile in row) for row in rows
    ) + GAP * (len(rows) - 1) + 14 * len(rows)

    sheet = Image.new("RGBA", (width, height), (0x1A, 0x18, 0x12, 0xFF))
    draw = ImageDraw.Draw(sheet)
    y = PAD
    for row in rows:
        x = PAD
        row_height = max(tile.height for _, tile in row)
        for label, tile in row:
            sheet.alpha_composite(tile, (x, y))
            draw.text((x, y + tile.height + 2), label, fill=(0xED, 0xD9, 0xA3, 0xFF))
            x += tile.width + GAP
        y += row_height + 14 + GAP

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, format="PNG")
    print(f"wrote {OUT.relative_to(ROOT).as_posix()} {sheet.width}x{sheet.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
