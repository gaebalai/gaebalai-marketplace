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


def write_dbc(candidates: list[dict], out_path: Path) -> bool:
    """Top 후보들을 cantools DBC로 dump.

    분류별 우선순위: 같은 ID에 RPM_or_SPEED 후보 둘이 있으면 score 1위를 RPM,
    2위를 SPEED. STEERING/GEAR는 ID별 score 1위만. **추정값**이므로 사용 전 검증 필수.
    """
    try:
        import cantools  # noqa: F401
        from cantools.database.can import Database, Message, Signal
    except ImportError:
        print("[!] cantools 미설치 — DBC 작성 건너뜀 (pip install cantools)", file=sys.stderr)
        return False

    presets = {
        "RPM":      {"scale": 0.25, "offset": 0, "unit": "rpm",  "is_signed": False},
        "SPEED":    {"scale": 0.01, "offset": 0, "unit": "km/h", "is_signed": False},
        "STEERING": {"scale": 0.1,  "offset": 0, "unit": "deg",  "is_signed": True},
        "GEAR":     {"scale": 1,    "offset": 0, "unit": "",     "is_signed": False},
    }

    by_id: dict[int, list[dict]] = {}
    for c in candidates:
        cid = int(c["id"], 0)
        by_id.setdefault(cid, []).append(c)

    db = Database()
    for cid, group in by_id.items():
        signals: list = []
        rpm_speed = sorted(
            (c for c in group if c["guess"] == "RPM_or_SPEED"),
            key=lambda x: -x["score"],
        )
        for i, c in enumerate(rpm_speed[:2]):
            name = "RPM" if i == 0 else "SPEED"
            p = presets[name]
            signals.append(Signal(
                name=name,
                start_bit=c["byte"] * 8 + 7,  # big_endian: MSB of given byte
                length=c["width"],
                byte_order="big_endian",
                is_signed=p["is_signed"],
                scale=p["scale"],
                offset=p["offset"],
                unit=p["unit"],
            ))
        for guess in ("STEERING", "GEAR"):
            top = max(
                (c for c in group if c["guess"] == guess),
                key=lambda x: x["score"],
                default=None,
            )
            if top is None:
                continue
            p = presets[guess]
            if guess == "STEERING":
                signals.append(Signal(
                    name="STEERING",
                    start_bit=top["byte"] * 8 + 7,
                    length=top["width"],
                    byte_order="big_endian",
                    is_signed=True,
                    scale=p["scale"],
                    offset=p["offset"],
                    unit=p["unit"],
                ))
            else:  # GEAR — 1바이트 uint
                signals.append(Signal(
                    name="GEAR",
                    start_bit=top["byte"] * 8,
                    length=top["width"],
                    byte_order="little_endian",
                    is_signed=False,
                    scale=p["scale"],
                    offset=p["offset"],
                    unit=p["unit"],
                ))

        if signals:
            db.messages.append(Message(
                frame_id=cid,
                name=f"GUESS_{cid:03X}",
                length=8,
                signals=signals,
                comment="auto-detected by can-signal-hunter — heuristic, verify before use",
            ))

    if not db.messages:
        return False
    db.refresh()
    out_path.write_text(db.as_dbc_string(), encoding="utf-8")
    return True


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

    dbc_path = args.out / "guess.dbc"
    if write_dbc(candidates, dbc_path):
        print(f"[*] wrote {dbc_path}", file=sys.stderr)

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
    if dbc_path.exists():
        summary.append("")
        summary.append("## DBC")
        summary.append("")
        summary.append("`guess.dbc` 자동 생성됨 — 휴리스틱 기반 추정. 실차 검증 전에 ECU 쓰기 명령에 사용 금지.")
    (args.out / "summary.md").write_text("\n".join(summary), encoding="utf-8")
    print(f"[*] wrote {args.out}/summary.md", file=sys.stderr)


if __name__ == "__main__":
    main()
