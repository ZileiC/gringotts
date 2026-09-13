#!/usr/bin/env python3
"""T-09E dev-database cleanup.

Every integration/evidence run seeded rows into the development database
(%APPDATA%/dev.jharayden/gringotts/gringotts.sqlite). This script retires those
pure development rows the project's way: a tombstone (deleted_at), never a
physical delete (AGENTS.md data rule).

Rule (measured, not guessed):
  * transactions  - every live row (all 42 came from evidence runs of the
                    speed-entry / review / stats flows; there is no real
                    bookkeeping data in the dev database)
  * assets        - every live row (T-04 demo rows + T-09x evidence assets)
  * asset_photos  - every live row (all attached to those assets)
  * categories    - NEVER touched: the nine built-in seeds are app data.

A timestamped copy of the database is written next to it before any write, and
a JSON report lands in evidence/t09e/development_db_cleanup.json.

Usage:
  python tool/clean_dev_db.py            # dry run (report only)
  python tool/clean_dev_db.py --apply    # tombstone + backup

Report path: --report <path> (default evidence/dev_db_cleanup.json - a neutral
tool-owned record). Passing another ticket's path would overwrite that ticket's
evidence (T-13a挂账), so give each run its own, e.g.
--report evidence/t13b/dev_db_cleanup.json. Printing a repo-relative path is
guarded for report paths outside the repository.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DB = (
    Path(os.environ.get("APPDATA") or (Path.home() / "AppData" / "Roaming"))
    / "dev.jharayden"
    / "gringotts"
    / "gringotts.sqlite"
)
DEFAULT_REPORT = ROOT / "evidence" / "dev_db_cleanup.json"
REPORT = DEFAULT_REPORT


def display(path: Path) -> str:
    """Repo-relative when possible; absolute otherwise."""
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)

RETIRE_TABLES = ("transactions", "assets", "asset_photos")
KEEP_TABLES = ("categories",)


def inventory(cur: sqlite3.Cursor) -> dict[str, dict[str, int]]:
    out: dict[str, dict[str, int]] = {}
    for table in RETIRE_TABLES + KEEP_TABLES:
        total = cur.execute(f"select count(*) from {table}").fetchone()[0]
        live = cur.execute(
            f"select count(*) from {table} where deleted_at is null"
        ).fetchone()[0]
        out[table] = {"total": total, "live": live, "tombstoned": total - live}
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT,
                        help="where to write the JSON record (default: %(default)s)")
    parser.add_argument("--apply", action="store_true", help="tombstone the rows")
    args = parser.parse_args()
    global REPORT
    REPORT = args.report

    if not args.db.exists():
        raise SystemExit(f"dev database not found: {args.db}")

    backup: Path | None = None
    if args.apply:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = args.db.with_suffix(f".sqlite.pre-t09e-{stamp}.bak")
        shutil.copy2(args.db, backup)
        print(f"backup -> {backup}")

    con = sqlite3.connect(args.db)
    cur = con.cursor()
    for table in RETIRE_TABLES + KEEP_TABLES:
        ddl = cur.execute(
            "select sql from sqlite_master where type='table' and name=?", (table,)
        ).fetchone()
        print(f"-- {table}: {ddl[0].splitlines()[0] if ddl else 'MISSING'}")

    before = inventory(cur)
    print("\nbefore:", json.dumps(before, ensure_ascii=False))

    written: dict[str, int] = {}
    if args.apply:
        now = int(time.time())
        for table in RETIRE_TABLES:
            cur.execute(
                f"update {table} set deleted_at = ?, updated_at = ? "
                "where deleted_at is null",
                (now, now),
            )
            written[table] = cur.rowcount
        con.commit()
        print(f"\ntombstoned (unix ts {now}):", json.dumps(written, ensure_ascii=False))

    after = inventory(cur)

    report = {
        "database": str(args.db),
        "applied": bool(args.apply),
        "tombstone_timestamp": written and int(time.time()),
        "backup": str(backup) if backup else None,
        "retire_tables": list(RETIRE_TABLES),
        "kept_tables": list(KEEP_TABLES),
        "before": before,
        "after": after,
        "rows_tombstoned": written,
        "note": "tombstone only - no row is physically deleted (AGENTS.md data rule)",
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print("\nafter :", json.dumps(after, ensure_ascii=False))
    print(f"report -> {display(REPORT)}")
    if not args.apply:
        print("\n(dry run - re-run with --apply to tombstone)")
    con.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
