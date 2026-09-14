# Bundled UI font: MiSans (subset)

Gringotts bundles MiSans as its UI font for the bottom tab labels and the
analysis-page month button (DESIGN_MAIN section 8.4). This project uses the
MiSans font / 本软件使用了 MiSans 字体 - the attribution the official
MiSans FAQ asks for when the font is embedded in software.

## Official source

- Font page: https://hyperos.mi.com/font/
- Archive: https://hyperos.mi.com/font-download/MiSans.zip
  - SHA-256: `b6aa1fc827035922612df8edf36e5609bca1c5441e25cd57572204569b7b81d9`
  - size: 227,880,072 bytes
- License: `MiSans-LICENSE.pdf` (《MiSans字体知识产权许可协议》, official
  PDF served next to the archive at
  https://hyperos.mi.com/font-download/MiSans字体知识产权许可协议.pdf)
  - SHA-256: `4a93a27cd2bd81b3b5ecfd0a853144a876fa26938a93a68443c67d74172fcb86`

## Bundled faces (subsets)

The official SC TTFs are ~8 MB per face; `tool/subset_misans.py` keeps only the
glyphs the app actually renders, so the three bundled faces together stay far
inside the ticket's 0.6-1.5 MB budget.

| file | pubspec weight | used by |
|---|---|---|
| MiSans-Regular.ttf | 400 | analysis month button text |
| MiSans-Medium.ttf | 500 | unselected bottom tab label |
| MiSans-Demibold.ttf | 600 | selected bottom tab label |

Glyphs kept: `0-9`, space, `年 月 分 析 资 产 统 计`.

## Rebuild

```sh
python tool/subset_misans.py --src <unzipped>/MiSans/ttf --out fonts
```
