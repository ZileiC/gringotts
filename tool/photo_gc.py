#!/usr/bin/env python3
"""T-13a photo orphan GC (dry-run first, then apply).

Scope: the development photo directory
(%APPDATA%/dev.jharayden/gringotts/photos, the same directory PhotoService
writes into - `getApplicationSupportDirectory()/photos`).

Rule (a file is deletable only when ALL of these hold):
  1. it sits directly in the photos directory,
  2. its name is content-hash shaped (``<sha256>.jpg``, i.e. PhotoService
     output) - anything else is a foreign file and is never touched,
  3. no database row references it, comparing full normalised paths first and
     falling back to the file name. "No row" includes tombstoned rows:
     ``asset_photos.path`` and ``assets.photo_path`` are read in full, so a
     soft-deleted photo keeps its file (the app never physically deletes).

Safety rails (each one is asserted, not assumed):
  * the delete set is recomputed from the same reference set that produced the
    plan, and the run aborts if any member is referenced,
  * a run with an empty reference set aborts unless --allow-empty-references is
    passed (a broken/unreadable database must not look like "everything is an
    orphan"),
  * every deletion is re-checked to be inside the photos directory and inside
    the planned orphan set,
  * after --apply the tool re-verifies that every referenced file that existed
    before the run still exists (the "zero false deletions" assertion).

Usage:
  python tool/photo_gc.py --selftest          # rule regression on a temp fixture
  python tool/photo_gc.py                     # dry run on the dev directory
  python tool/photo_gc.py --apply             # delete the orphans + report
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sqlite3
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HASH_NAME = re.compile(r"^[0-9a-f]{64}\.jpg$")
REPORT = ROOT / "evidence" / "t13a" / "photo_gc_report.json"

DEFAULT_APP_DIR = (
    Path(os.environ.get("APPDATA") or (Path.home() / "AppData" / "Roaming"))
    / "dev.jharayden"
    / "gringotts"
)


def norm(path: str | Path) -> str:
    """Case- and separator-insensitive key for path comparison."""
    return os.path.normcase(os.path.normpath(str(path)))


def load_references(db: Path) -> tuple[set[str], set[str], dict[str, int]]:
    """Full-path and file-name reference sets from every photo-bearing column."""
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    cur = con.cursor()
    rows = cur.execute("select path from asset_photos").fetchall()
    legacy = cur.execute(
        "select photo_path from assets where photo_path is not null"
    ).fetchall()
    counts = {
        "asset_photos_rows": len(rows),
        "assets_photo_path_rows": len(legacy),
        "asset_photos_tombstoned": cur.execute(
            "select count(*) from asset_photos where deleted_at is not null"
        ).fetchone()[0],
        "assets_photo_path_tombstoned": cur.execute(
            "select count(*) from assets "
            "where photo_path is not null and deleted_at is not null"
        ).fetchone()[0],
    }
    con.close()
    paths: set[str] = set()
    names: set[str] = set()
    for (value,) in rows + legacy:
        if value:
            paths.add(norm(value))
            names.add(norm(Path(value).name))
    return paths, names, counts


def plan(photos_dir: Path, paths: set[str], names: set[str]) -> dict[str, list[Path]]:
    """Classify every file in the photos directory (pure decision function)."""
    out: dict[str, list[Path]] = {"referenced": [], "foreign": [], "orphan": []}
    for entry in sorted(photos_dir.iterdir()):
        if not entry.is_file():
            out["foreign"].append(entry)  # directories are never touched
            continue
        if norm(entry) in paths or norm(entry.name) in names:
            out["referenced"].append(entry)
        elif HASH_NAME.match(entry.name):
            out["orphan"].append(entry)
        else:
            out["foreign"].append(entry)
    return out


def files_of(paths: list[Path]) -> list[dict[str, object]]:
    return [{"name": p.name, "bytes": p.stat().st_size} for p in paths]


def report(payload: dict[str, object]) -> None:
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8"
    )


def run(db: Path, photos_dir: Path, apply: bool, backup_dir: Path | None,
        allow_empty: bool) -> int:
    if not db.exists():
        raise SystemExit(f"dev database not found: {db}")
    if not photos_dir.is_dir():
        raise SystemExit(f"photo directory not found: {photos_dir}")

    paths, names, ref_counts = load_references(db)
    before = plan(photos_dir, paths, names)
    before_all = files_of(sorted(p for group in before.values() for p in group))
    print(f"-- references: {json.dumps(ref_counts, ensure_ascii=False)}")
    print(f"-- photos dir: {photos_dir}")
    print(
        f"-- before: total={len(before_all)} referenced={len(before['referenced'])} "
        f"foreign={len(before['foreign'])} orphan={len(before['orphan'])}"
    )
    for p in before["orphan"]:
        print(f"   orphan {p.name} ({p.stat().st_size} bytes)")

    if not paths and not names and not allow_empty:
        print("ABORT: no database reference found - refusing to treat every file "
              "as an orphan (pass --allow-empty-references to override)")
        return 2

    # Safety rail: the delete set must be exactly the planned orphans, all
    # hash-named, all directly inside the photos directory, none referenced.
    for p in before["orphan"]:
        assert HASH_NAME.match(p.name), f"not hash-shaped: {p}"
        assert norm(p.parent) == norm(photos_dir), f"outside photos dir: {p}"
        assert norm(p) not in paths and norm(p.name) not in names, (
            f"referenced file in the delete set: {p}"
        )
    planned = {norm(p) for p in before["orphan"]}
    # Sizes are captured before any deletion (stat after unlink would fail).
    orphan_info = files_of(before["orphan"])
    orphan_bytes = {f["name"]: f["bytes"] for f in orphan_info}

    removed: list[dict[str, object]] = []
    if apply:
        if backup_dir is not None:
            backup_dir.mkdir(parents=True, exist_ok=True)
        for p in before["orphan"]:
            assert norm(p) in planned
            if backup_dir is not None:
                shutil.copy2(p, backup_dir / p.name)
            p.unlink()
            removed.append({"name": p.name, "bytes": orphan_bytes[p.name]})
        # Zero false deletion: every referenced file that existed before the
        # run must still exist afterwards.
        survivors = [p.name for p in before["referenced"] if p.exists()]
        assert len(survivors) == len(before["referenced"]), (
            "referenced file disappeared: "
            f"{set(p.name for p in before['referenced']) - set(survivors)}"
        )
        for p in before["foreign"]:
            assert p.exists(), f"foreign file disappeared: {p}"

    after = plan(photos_dir, paths, names)
    after_all = files_of(sorted(p for group in after.values() for p in group))
    print(
        f"-- after : total={len(after_all)} referenced={len(after['referenced'])} "
        f"foreign={len(after['foreign'])} orphan={len(after['orphan'])}"
    )
    print(f"-- removed={len(removed)} retained_bytes={sum(f['bytes'] for f in after_all)}")

    report(
        {
            "ticket": "T-13a",
            "tool": "tool/photo_gc.py",
            "applied": apply,
            "database": str(db),
            "photos_dir": str(photos_dir),
            "backup_dir": str(backup_dir) if backup_dir else None,
            "reference_counts": ref_counts,
            "before": {
                "total": len(before_all),
                "referenced": len(before["referenced"]),
                "foreign": len(before["foreign"]),
                "orphan": len(before["orphan"]),
            },
            "after": {
                "total": len(after_all),
                "referenced": len(after["referenced"]),
                "foreign": len(after["foreign"]),
                "orphan": len(after["orphan"]),
            },
            "orphans": orphan_info,
            "removed": removed,
            "foreign_kept": files_of(before["foreign"]),
            "reference_rule": "asset_photos.path + assets.photo_path, "
                              "live AND tombstoned rows",
        }
    )
    print(f"-- report -> {REPORT.relative_to(ROOT).as_posix()}")
    if not apply:
        print("-- (dry run - re-run with --apply to delete the orphans)")
    return 0


def selftest() -> int:
    """Rule regression on a disposable fixture (no dev data involved)."""
    global REPORT  # the fixture run must not touch the real evidence report
    tmp = Path(tempfile.mkdtemp(prefix="t13a-gc-"))
    try:
        REPORT = tmp / "selftest_report.json"
        photos = tmp / "photos"
        photos.mkdir()
        live = photos / ("a" * 64 + ".jpg")
        tomb = photos / ("b" * 64 + ".jpg")
        orphan = photos / ("c" * 64 + ".jpg")
        foreign = photos / "notes.txt"
        nested = photos / "sub"
        nested.mkdir()
        for p in (live, tomb, orphan, foreign):
            p.write_bytes(b"x")

        db = tmp / "gringotts.sqlite"
        con = sqlite3.connect(db)
        cur = con.cursor()
        cur.execute("create table assets (id text, photo_path text, deleted_at int)")
        cur.execute(
            "create table asset_photos (id text, path text, deleted_at int)"
        )
        # live row -> full path match; tombstoned row -> name fallback.
        cur.execute("insert into asset_photos values ('p1', ?, null)", (str(live),))
        cur.execute("insert into asset_photos values ('p2', ?, 123)", (str(tomb),))
        cur.execute(
            "insert into assets values ('a1', ?, 456)",
            (str(photos / "moved-elsewhere" / tomb.name),),
        )
        con.commit()
        con.close()

        paths, names, _ = load_references(db)
        result = plan(photos, paths, names)
        ok = True

        def check(cond: bool, label: str) -> None:
            nonlocal ok
            print(("PASS  " if cond else "FAIL  ") + label)
            ok = ok and cond

        check([p.name for p in result["referenced"]] == [live.name, tomb.name],
              "live + tombstoned + name-fallback rows are all referenced")
        check([p.name for p in result["foreign"]] == [foreign.name, nested.name],
              "foreign file and subdirectory are never delete candidates")
        check([p.name for p in result["orphan"]] == [orphan.name],
              "only the unreferenced hash-named file is an orphan")
        check(not (set(result["orphan"]) & set(result["referenced"])),
              "delete set and reference set are disjoint")

        # apply + the zero-false-deletion assertion
        backup = tmp / "backup"
        rc = run(db, photos, apply=True, backup_dir=backup, allow_empty=False)
        check(rc == 0, "apply run exits 0")
        check(not orphan.exists(), "orphan deleted")
        check(live.exists() and tomb.exists(), "referenced files survive apply")
        check(foreign.exists() and nested.is_dir(), "foreign entries survive apply")
        check((backup / orphan.name).exists(), "deleted file was backed up")
        print("selftest:", "OK" if ok else "FAILED")
        return 0 if ok else 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_APP_DIR / "gringotts.sqlite")
    parser.add_argument("--photos", type=Path, default=DEFAULT_APP_DIR / "photos")
    parser.add_argument("--apply", action="store_true", help="delete the orphans")
    parser.add_argument("--backup-dir", type=Path, default=None,
                        help="copy orphans here before deleting (session backup)")
    parser.add_argument("--allow-empty-references", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        return selftest()
    return run(args.db, args.photos, args.apply, args.backup_dir,
               args.allow_empty_references)


if __name__ == "__main__":
    raise SystemExit(main())
