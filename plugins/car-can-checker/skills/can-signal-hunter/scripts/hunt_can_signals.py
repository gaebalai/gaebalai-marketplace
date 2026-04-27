#!/usr/bin/env python3
"""CAN 로그 → ID·바이트별 후보 신호 추정.

Usage:
    python hunt_can_signals.py <log_path> [--out OUT_DIR]

지원 포맷: .asc / .log / .blf / .csv (timestamp,id,data 형식)
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd


def load_log(path: Path) -> pd.DataFrame:
    suffix = path.suffix.lower()
    if suffix in {".asc", ".log", ".blf"}:
        import can  # type: ignore

        reader = can.LogReader(str(path))
        rows = [(m.timestamp, m.arbitration_id, bytes(m.data)) for m in reader]
    elif suffix == ".csv":
        rows = []
        with path.open() as f:
            for row in csv.reader(f):
                if not row or row[0].startswith("#"):
                    continue
                ts = float(row[0])
                cid = int(row[1], 0)
                data = bytes.fromhex(row[2].replace(" ", ""))
                rows.append((ts, cid, data))
    else:
        raise ValueError(f"unsupported log format: {suffix}")

    return pd.DataFrame(rows, columns=["t", "id", "data"])


def per_id_stats(df: pd.DataFrame) -> pd.DataFrame:
    out = []
    for cid, g in df.groupby("id"):
        ts = g["t"].to_numpy()
        if len(ts) < 2:
            continue
        period = float(np.median(np.diff(ts))) if len(ts) > 1 else 0.0
        hz = 1.0 / period if period > 0 else 0.0
        max_len = max(len(d) for d in g["data"])
        byte_var = []
        word_be_var = []
        for i in range(max_len):
            col = np.array([d[i] if i < len(d) else 0 for d in g["data"]], dtype=np.float64)
            byte_var.append(float(col.std()))
        for i in range(max_len - 1):
            col = np.array(
                [
                    (d[i] << 8 | d[i + 1]) if i + 1 < len(d) else 0
                    for d in g["data"]
                ],
                dtype=np.float64,
            )
            word_be_var.append(float(col.std()))
        out.append(
            {
                "id_hex": f"0x{cid:03X}",
                "hz": round(hz, 1),
                "frames": len(g),
                "byte_var": byte_var,
                "word_be_var": word_be_var,
            }
        )
    return pd.DataFrame(out).sort_values("hz", ascending=False)


def classify_candidates(stats: pd.DataFrame) -> list[dict]:
    """간단한 휴리스틱으로 RPM/속도/조향각/기어 후보를 추린다."""
    candidates = []
    for _, row in stats.iterrows():
        hz = row["hz"]
        wv = row["word_be_var"]
        bv = row["byte_var"]
        # RPM/속도 후보: 100Hz 근처, 16비트 워드 분산 큼
        if 80 <= hz <= 120 and wv:
            top_words = sorted(enumerate(wv), key=lambda x: -x[1])[:2]
            for idx, var in top_words:
                if var > 50:
                    candidates.append(
                        {
                            "id": row["id_hex"],
                            "guess": "RPM_or_SPEED",
                            "byte": idx,
                            "width": 16,
                            "endian": "big",
                            "score": round(var, 1),
                            "hz": hz,
                        }
                    )
        # 조향각 후보: 50~64Hz, 부호 워드 분산
        elif 40 <= hz <= 70 and wv:
            top = max(range(len(wv)), key=lambda i: wv[i])
            if wv[top] > 30:
                candidates.append(
                    {
                        "id": row["id_hex"],
                        "guess": "STEERING",
                        "byte": top,
                        "width": 16,
                        "endian": "big_signed",
                        "score": round(wv[top], 1),
                        "hz": hz,
                    }
                )
        # 기어 후보: ≤50Hz, 단일 바이트 이산값
        elif hz <= 50 and bv:
            for idx, var in enumerate(bv):
                if 0 < var < 5:  # 이산적
                    candidates.append(
                        {
                            "id": row["id_hex"],
                            "guess": "GEAR",
                            "byte": idx,
                            "width": 8,
                            "endian": "uint",
                            "score": round(var, 2),
                            "hz": hz,
                        }
                    )
                    break
    return candidates


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", type=Path)
    ap.add_argument("--out", type=Path, default=Path("can_analysis_out"))
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    print(f"[*] loading {args.log} ...", file=sys.stderr)
    df = load_log(args.log)
    print(f"[*] {len(df)} frames, {df['id'].nunique()} unique IDs", file=sys.stderr)

    stats = per_id_stats(df)
    stats_out = stats.copy()
    stats_out["byte_var"] = stats_out["byte_var"].apply(lambda xs: ",".join(f"{x:.1f}" for x in xs))
    stats_out["word_be_var"] = stats_out["word_be_var"].apply(lambda xs: ",".join(f"{x:.1f}" for x in xs))
    stats_out.to_csv(args.out / "id_stats.csv", index=False)

    candidates = classify_candidates(stats)
    cand_df = pd.DataFrame(candidates)
    if not cand_df.empty:
        cand_df = cand_df.sort_values(["guess", "score"], ascending=[True, False])
        cand_df.to_csv(args.out / "candidates.csv", index=False)

    summary = ["# CAN Signal Hunter — Summary", ""]
    summary.append(f"- frames: {len(df)}")
    summary.append(f"- unique IDs: {df['id'].nunique()}")
    summary.append(f"- duration: {df['t'].iloc[-1] - df['t'].iloc[0]:.1f}s")
    summary.append("")
    summary.append("## Top candidates")
    summary.append("")
    if cand_df.empty:
        summary.append("_(no strong candidates found — try a longer log with varied driving)_")
    else:
        summary.append("| guess | id | byte | width | endian | score | Hz |")
        summary.append("|---|---|---|---|---|---|---|")
        for _, c in cand_df.head(20).iterrows():
            summary.append(
                f"| {c['guess']} | {c['id']} | {c['byte']} | {c['width']} | {c['endian']} | {c['score']} | {c['hz']} |"
            )
    (args.out / "summary.md").write_text("\n".join(summary), encoding="utf-8")
    print(f"[*] wrote {args.out}/summary.md", file=sys.stderr)


if __name__ == "__main__":
    main()
