#!/usr/bin/env python3
"""Turn a `flutter drive --profile` PERF_SUMMARY line into a readable table.

Usage:
  python tool/perf_report.py [evidence/t09e/.t09e_perf_run_log.txt]

Writes evidence/t09e/profile_frame_timings.json (the numbers quoted in WORKLOG)
and prints a one-page table: per-phase frame build/rasterizer averages,
percentiles, worst frame and missed 16.67 ms budget counts.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOG = ROOT / "evidence" / "t09e" / ".t09e_perf_run_log.txt"
OUT = ROOT / "evidence" / "t09e" / "profile_frame_timings.json"

FRAME_BUDGET_MS = 1000 / 60


def main() -> int:
    log = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LOG
    text = log.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"PERF_SUMMARY (\{.*\})", text, re.S)
    if not match:
        raise SystemExit(f"no PERF_SUMMARY line in {log}")

    data = json.loads(match.group(1))
    rows = []
    for phase, stats in data.items():
        if not isinstance(stats, dict) or "average_frame_build_time_millis" not in stats:
            continue
        rows.append(
            {
                "phase": phase,
                "frames": stats["frame_count"],
                "build_avg_ms": round(stats["average_frame_build_time_millis"], 3),
                "build_p90_ms": round(
                    stats["90th_percentile_frame_build_time_millis"], 3
                ),
                "build_p99_ms": round(
                    stats["99th_percentile_frame_build_time_millis"], 3
                ),
                "build_worst_ms": round(stats["worst_frame_build_time_millis"], 3),
                "raster_avg_ms": round(
                    stats["average_frame_rasterizer_time_millis"], 3
                ),
                "raster_p99_ms": round(
                    stats["99th_percentile_frame_rasterizer_time_millis"], 3
                ),
                "raster_worst_ms": round(stats["worst_frame_rasterizer_time_millis"], 3),
                "missed_frame_build_budget_count": stats[
                    "missed_frame_build_budget_count"
                ],
                "missed_frame_rasterizer_budget_count": stats[
                    "missed_frame_rasterizer_budget_count"
                ],
            }
        )

    header = (
        f"{'phase':26s} {'frames':>6s} {'build_avg':>9s} {'build_p90':>9s} "
        f"{'build_p99':>9s} {'build_max':>9s} {'rast_avg':>8s} {'rast_p99':>8s} "
        f"{'missed_build':>12s} {'missed_rast':>11s}"
    )
    print(header)
    print("-" * len(header))
    for r in rows:
        print(
            f"{r['phase']:26s} {r['frames']:6d} {r['build_avg_ms']:9.3f} "
            f"{r['build_p90_ms']:9.3f} {r['build_p99_ms']:9.3f} "
            f"{r['build_worst_ms']:9.3f} {r['raster_avg_ms']:8.3f} "
            f"{r['raster_p99_ms']:8.3f} "
            f"{r['missed_frame_build_budget_count']:12d} "
            f"{r['missed_frame_rasterizer_budget_count']:11d}"
        )

    OUT.write_text(
        json.dumps(
            {
                "mode": "profile",
                "device": "windows-desktop (debug/rasterizer numbers are not evidence)",
                "frame_budget_ms": FRAME_BUDGET_MS,
                "source_log": log.relative_to(ROOT).as_posix(),
                "phases": rows,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"\nwrote {OUT.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
