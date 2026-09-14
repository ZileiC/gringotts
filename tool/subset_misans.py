"""Subset the official MiSans SC TTFs to the glyphs the app really renders.

Ticket T-14b (DESIGN_MAIN section 8.4): the UI font is MiSans, subset to the
actual usage - the bottom tab labels (analysis / assets / stats) plus the home
month button (digits, space, the two CJK glyphs). A full MiSans SC TTF is
~8 MB per face; this script keeps only the glyphs in DEFAULT_GLYPHS so the
bundled subset stays far inside the 0.6-1.5 MB budget from the ticket.

Source (official Xiaomi distribution, see fonts/README.md for hashes):
    https://hyperos.mi.com/font/           (MiSans.zip)
    https://hyperos.mi.com/font-download/MiSans.zip

Usage (fontTools required; the tracked evidence used Python 3.8 +
fonttools 4.57.0):
    python tool/subset_misans.py --src <unzipped>/MiSans/ttf --out fonts

Faces written: MiSans-Regular.ttf (400), MiSans-Medium.ttf (500),
MiSans-Demibold.ttf (600) - the three weights pubspec.yaml declares.
"""

from __future__ import annotations

import argparse
import os
import sys

# 0-9, space, 年 月 分 析 资 产 统 计
DEFAULT_GLYPHS = "0123456789 \u5e74\u6708\u5206\u6790\u8d44\u4ea7\u7edf\u8ba1"

FACES = {
    "MiSans-Regular.ttf": "MiSans-Regular.ttf",
    "MiSans-Medium.ttf": "MiSans-Medium.ttf",
    "MiSans-Demibold.ttf": "MiSans-Demibold.ttf",
}


def subset_face(src: str, dst: str, glyphs: str) -> dict:
    from fontTools.subset import Options, Subsetter
    from fontTools.ttLib import TTFont

    font = TTFont(src, fontNumber=0, lazy=False)
    options = Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.hinting = False
    options.drop_tables += ["DSIG"]

    subsetter = Subsetter(options=options)
    subsetter.populate(text=glyphs)
    subsetter.subset(font)
    font.save(dst)
    font.close()

    check = TTFont(dst, fontNumber=0, lazy=True)
    cmap = check.getBestCmap()
    missing = [ch for ch in sorted(set(glyphs)) if ord(ch) not in cmap]
    glyph_count = len(check.getGlyphOrder())
    check.close()
    return {"bytes": os.path.getsize(dst), "glyphs": glyph_count, "missing": missing}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", required=True, help="folder with the official MiSans TTFs")
    parser.add_argument("--out", required=True, help="output folder (fonts/)")
    parser.add_argument("--glyphs", default=DEFAULT_GLYPHS, help="glyphs to keep")
    args = parser.parse_args(argv)

    os.makedirs(args.out, exist_ok=True)
    failed = False
    for src_name, dst_name in FACES.items():
        src = os.path.join(args.src, src_name)
        dst = os.path.join(args.out, dst_name)
        if not os.path.isfile(src):
            print(f"missing source: {src}", file=sys.stderr)
            failed = True
            continue
        report = subset_face(src, dst, args.glyphs)
        status = "OK" if not report["missing"] else "MISSING " + ",".join(report["missing"])
        print(
            f"{dst_name}: {report['bytes']} bytes, {report['glyphs']} glyphs, {status}"
        )
        if report["missing"]:
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
