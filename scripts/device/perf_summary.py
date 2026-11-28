#!/usr/bin/env python3
"""Summarise a PerfProbe CSV (Documents/perf.csv copied off the phone).

    python3 scripts/device/perf_summary.py build/device-verify/<run>/perf.csv

Works with the old 5-column files and the B0 files (terrain work and
scene snapshot columns, benchmark/PLAN.md). Exit status 0 = PASS, 1 = CHECK.
"""
import sys

WARMUP_S = 5      # skip the first seconds (shader compile, first chunks)
HITCH_MS = 20     # a frame longer than this is a visible hitch at 60 fps


def load(path):
    header, rows = None, []
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line[0].isalpha():
            header = line.split(",")
            continue
        rows.append(line.split(","))
    if header is None:
        header = ["seconds", "fps", "worst_frame_ms", "memory_mb", "thermal_state"]
    return [dict(zip(header, r)) for r in rows]


def pct(sorted_values, p):
    return sorted_values[min(len(sorted_values) - 1, int(len(sorted_values) * p))]


def main(path):
    rows = [r for r in load(path) if float(r["seconds"]) >= WARMUP_S]
    if not rows:
        print("no rows after warm-up")
        return 1
    fps = sorted(float(r["fps"]) for r in rows)
    worst = max(float(r["worst_frame_ms"]) for r in rows)
    mem = max(float(r["memory_mb"]) for r in rows)
    therm = max(int(r["thermal_state"]) for r in rows)
    p5 = pct(fps, 0.05)
    print(f"seconds {len(rows)}  fps median {pct(fps, 0.5):.1f}  5th pct {p5:.1f}  "
          f"worst frame {worst:.0f} ms  peak memory {mem:.0f} MB  thermal max {therm} (0 nominal … 3 critical)")

    if "chunk_builds" in rows[0]:
        builds = sum(int(r["chunk_builds"]) for r in rows)
        chunk = sorted(float(r["chunk_worst_ms"]) for r in rows if int(r["chunk_builds"]) > 0)
        far = [float(r["far_worst_ms"]) for r in rows if float(r["far_worst_ms"]) > 0]
        hitches = [r for r in rows if float(r["worst_frame_ms"]) > HITCH_MS]
        with_terrain = [r for r in hitches
                        if int(r["chunk_builds"]) > 0 or float(r["far_worst_ms"]) > 0]
        if chunk:
            print(f"terrain  chunk builds {builds}  chunk ms median {pct(chunk, 0.5):.1f}  "
                  f"worst {chunk[-1]:.1f}  far-terrain rebuilds {len(far)}  "
                  f"worst {max(far, default=0):.1f} ms")
        else:
            print("terrain  no chunk builds after warm-up")
        print(f"hitches  seconds with a frame > {HITCH_MS} ms: {len(hitches)}  "
              f"of those with terrain work: {len(with_terrain)}")
        snaps = [r for r in rows if int(r["scene_nodes"]) > 0]
        if snaps:
            tri = sorted(int(r["scene_triangles"]) for r in snaps)
            draws = max(int(r["scene_draws"]) for r in snaps)
            nodes = max(int(r["scene_nodes"]) for r in snaps)
            parts = max(int(r["scene_particles"]) for r in snaps)
            print(f"scene    triangles median {pct(tri, 0.5):,}  max {tri[-1]:,}  "
                  f"draw elements max {draws}  nodes max {nodes}  particle systems max {parts}")

    ok = p5 >= 55 and mem < 250 and therm < 2
    print("PASS" if ok else "CHECK: target is 60 fps (5th pct ≥ 55), < 250 MB, thermal below 'serious'")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
