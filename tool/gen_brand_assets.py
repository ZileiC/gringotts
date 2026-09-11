#!/usr/bin/env python3
"""Generate the Gringotts brand assets from brand/gringotts-logo.png (T-09E).

Reproducible: the same source + same rules produce byte-identical outputs, so
re-running this script is a verifiable action (see --verify).

Outputs
-------
android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
    Legacy launcher icon (API < 26): canvas plate + logo at 66%.
android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
    Adaptive-icon foreground: transparent 108dp canvas, logo inside the 66%
    safe zone (Android shrinks/masks the outer ring).
windows/runner/resources/app_icon.ico
    Multi-size Windows icon (16/24/32/48/64/128/256) on the canvas plate.

Brand rules (AGENTS.md / DESIGN_T09): canvas solid #0C0B09, champagne gold
mark, no neon, no gradient plate.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "brand" / "gringotts-logo.png"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

# AppColors.canvas = 0xFF0C0B09 (tokens.dart is the source of truth).
CANVAS = (0x0C, 0x0B, 0x09, 0xFF)

# density bucket -> scale factor (baseline mdpi)
DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

LEGACY_DP = 48.0
ADAPTIVE_DP = 108.0
# Fractions refer to the visible mark (gold ink), not to the source canvas:
# the source carries a wide dark halo, so cropping to the ink is what keeps the
# emblem at the intended size (ticket: foreground mark at 66% of the canvas).
LEGACY_LOGO_FRACTION = 0.66
ADAPTIVE_LOGO_FRACTION = 0.66
WINDOWS_LOGO_FRACTION = 0.82
WINDOWS_SIZES = (16, 24, 32, 48, 64, 128, 256)

# Ink detection: opaque enough to be seen and bright enough to be the gold mark
# (the dark halo around the emblem must not inflate the crop).
INK_MIN_ALPHA = 40
INK_MIN_LUMINANCE = 60.0


def mark() -> Image.Image:
    """The brand mark: cropped to its gold ink and padded to a square canvas."""
    src = Image.open(SRC).convert("RGBA")
    box = src.getbbox()
    if box is None:
        raise SystemExit(f"{SRC} is fully transparent")
    content = src.crop(box)
    ink_mask = Image.new("L", content.size, 0)
    src_px = content.load()
    mask_px = ink_mask.load()
    for y in range(content.height):
        for x in range(content.width):
            r, g, b, a = src_px[x, y]
            if a < INK_MIN_ALPHA:
                continue
            if 0.299 * r + 0.587 * g + 0.114 * b >= INK_MIN_LUMINANCE:
                mask_px[x, y] = 255
    ink = ink_mask.getbbox()
    if ink is None:
        raise SystemExit(f"{SRC} has no visible ink above the luminance threshold")
    emblem = content.crop(ink)
    edge = max(emblem.size)
    square = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
    square.paste(
        emblem,
        ((edge - emblem.width) // 2, (edge - emblem.height) // 2),
    )
    return square


def plate(edge: int, logo_fraction: float, background: tuple[int, int, int, int] | None):
    """A square plate of [edge] px with the mark centred at [logo_fraction]."""
    size = int(round(edge))
    canvas = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    logo_edge = max(1, int(round(size * logo_fraction)))
    logo = mark().resize((logo_edge, logo_edge), Image.LANCZOS)
    offset = ((size - logo_edge) // 2, (size - logo_edge) // 2)
    canvas.paste(logo, offset, logo)
    return canvas


def build() -> list[tuple[Path, str]]:
    written: list[tuple[Path, str]] = []

    for bucket, scale in DENSITIES.items():
        out_dir = ANDROID_RES / f"mipmap-{bucket}"
        out_dir.mkdir(parents=True, exist_ok=True)

        legacy = plate(LEGACY_DP * scale, LEGACY_LOGO_FRACTION, CANVAS)
        legacy_path = out_dir / "ic_launcher.png"
        legacy.save(legacy_path, format="PNG", optimize=True)
        written.append((legacy_path, f"{legacy.width}x{legacy.height} plate=canvas"))

        foreground = plate(
            ADAPTIVE_DP * scale, ADAPTIVE_LOGO_FRACTION, None
        )
        fg_path = out_dir / "ic_launcher_foreground.png"
        foreground.save(fg_path, format="PNG", optimize=True)
        written.append(
            (fg_path, f"{foreground.width}x{foreground.height} plate=transparent")
        )

    WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
    win = plate(max(WINDOWS_SIZES), WINDOWS_LOGO_FRACTION, CANVAS)
    win.save(
        WINDOWS_ICON,
        format="ICO",
        sizes=[(s, s) for s in WINDOWS_SIZES],
    )
    written.append((WINDOWS_ICON, f"sizes={','.join(str(s) for s in WINDOWS_SIZES)}"))

    return written


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def ink_fraction(path: Path) -> float:
    """Longest visible-mark edge as a fraction of the plate (size evidence)."""
    with Image.open(path).convert("RGBA") as im:
        mask = Image.new("L", im.size, 0)
        src = im.load()
        dst = mask.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = src[x, y]
                if a < INK_MIN_ALPHA:
                    continue
                if 0.299 * r + 0.587 * g + 0.114 * b >= INK_MIN_LUMINANCE:
                    dst[x, y] = 255
        box = mask.getbbox()
        if box is None:
            return 0.0
        return max(box[2] - box[0], box[3] - box[1]) / im.width


def verify(written: list[tuple[Path, str]]) -> int:
    manifest = []
    for path, note in written:
        rel = path.relative_to(ROOT).as_posix()
        with Image.open(path) as im:
            mode = im.mode
            size = im.size
            frames = getattr(im, "n_frames", 1)
            embedded = sorted(getattr(getattr(im, "ico", None), "sizes", lambda: [])())
        entry = {
            "path": rel,
            "note": note,
            "mode": mode,
            "size": list(size),
            "embedded_sizes": [list(s) for s in embedded],
            "ink_longest_fraction": round(ink_fraction(path), 4),
            "md5": md5(path),
            "bytes": path.stat().st_size,
        }
        manifest.append(entry)
        print(
            f"{rel:78s} {mode:5s} {size[0]:>4}x{size[1]:<4} "
            f"ink={entry['ink_longest_fraction']:.3f} "
            f"{'frames=' + str(frames) if frames > 1 else '':9s} {entry['md5'][:12]}"
        )

    out = ROOT / "evidence" / "t09e" / "brand_assets_manifest.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nmanifest -> {out.relative_to(ROOT).as_posix()} ({len(manifest)} files)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="re-read the existing outputs and print the manifest without writing",
    )
    args = parser.parse_args()

    if args.verify_only:
        existing = []
        for bucket, scale in DENSITIES.items():
            out_dir = ANDROID_RES / f"mipmap-{bucket}"
            existing.append((out_dir / "ic_launcher.png", f"density={bucket} legacy"))
            existing.append(
                (out_dir / "ic_launcher_foreground.png", f"density={bucket} adaptive")
            )
        existing.append((WINDOWS_ICON, "windows ico"))
        missing = [str(p) for p, _ in existing if not p.exists()]
        if missing:
            print("MISSING:\n  " + "\n  ".join(missing), file=sys.stderr)
            return 1
        return verify(existing)

    return verify(build())


if __name__ == "__main__":
    raise SystemExit(main())
