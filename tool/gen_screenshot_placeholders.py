"""Generate the screenshot placeholders for the public repo.

Run:  uv run --with pillow --python 3.12 python tool/gen_screenshot_placeholders.py
Writes docs/screenshots/<name>.svg (1080x2340, the phone aspect the README expects).
Replacing a placeholder = drop the real PNG next to it and point the README at it.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "docs" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)

SCREENS = [
    ("01-analysis", "Analysis", "分析页", "Hero allowance · progress · today donut · savings card"),
    ("02-quick-entry", "Quick entry", "快记页", "Name + amount inputs · keypad · 3x3 categories · outline confirm"),
    ("03-ledger", "Ledger", "明细页", "Month to day to entry · row-level edit · tombstones"),
    ("04-assets", "Assets", "资产页", "Serif gold net value · CPD per day · held days"),
    ("05-stats-daily", "Statistics - day", "统计页 · 日", "Spend bars + allowance line · dual-line trend"),
    ("06-stats-month", "Statistics - month", "统计页 · 月", "Paired bars per month · budget line · dual-line trend"),
    ("07-splash", "Splash", "启动画面", "Brand moment: logo, wordmark, single fade"),
    ("08-asset-detail", "Asset detail", "资产详情", "Parallax header · photos · sell / realised review"),
]

SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 2340" width="1080" height="2340" role="img" aria-label="{title} screenshot placeholder">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#14120E"/><stop offset="1" stop-color="#0C0B09"/>
    </linearGradient>
  </defs>
  <rect width="1080" height="2340" fill="url(#bg)"/>
  <rect x="40" y="40" width="1000" height="2260" rx="72" fill="none" stroke="#2C271C" stroke-width="3"/>
  <rect x="470" y="96" width="140" height="10" rx="5" fill="#2C271C"/>

  <g font-family="Segoe UI, Roboto, PingFang SC, Microsoft YaHei, sans-serif" text-anchor="middle">
    <text x="540" y="1010" fill="#E3C36B" font-size="64" font-weight="600" letter-spacing="2">{en}</text>
    <text x="540" y="1104" fill="#F4EFE2" font-size="72" font-weight="700">{zh}</text>
    <text x="540" y="1196" fill="#A69C86" font-size="34">{note}</text>

    <g transform="translate(540,1450)">
      <circle r="62" fill="none" stroke="#9C7A24" stroke-width="3"/>
      <path d="M-26 0h52M0 -26v52" stroke="#E3C36B" stroke-width="6" stroke-linecap="round"/>
    </g>
    <text x="540" y="1610" fill="#A69C86" font-size="32">Screenshot pending · 截图占位</text>
    <text x="540" y="1672" fill="#6F6A5C" font-size="28">Replace this placeholder with a real device capture</text>

    <text x="540" y="2140" fill="#6F6A5C" font-size="30" letter-spacing="6">GRINGOTTS</text>
  </g>
</svg>
"""

for name, en, zh, note in SCREENS:
    (OUT / f"{name}.svg").write_text(
        SVG.format(title=f"{en} / {zh}", en=en, zh=zh, note=note), encoding="utf-8"
    )
    print("wrote", (OUT / f"{name}.svg").relative_to(OUT.parent.parent))
print("total:", len(SCREENS))
