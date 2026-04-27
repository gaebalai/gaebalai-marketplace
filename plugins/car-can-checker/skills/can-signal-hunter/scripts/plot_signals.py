#!/usr/bin/env python3
"""확정된 신호 매핑(JSON) + CAN 로그 → 4단 검증 패널 PNG.

mapping.json 예:
{
    "rpm":      {"id": "0x202", "byte": 0, "width": 16, "endian": "big",       "scale": 0.25, "offset": 0},
    "speed":    {"id": "0x202", "byte": 2, "width": 16, "endian": "big",       "scale": 0.01, "offset": 0},
    "steering": {"id": "0x082", "byte": 0, "width": 16, "endian": "big_signed","scale": 0.1,  "offset": 0},
    "gear":     {"id": "0x228", "byte": 0, "width": 8,  "endian": "uint",      "scale": 1,    "offset": 0}
}
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from hunt_can_signals import load_log


def decode(data: bytes, byte: int, width: int, endian: str, scale: float, offset: float) -> float:
    if width == 8:
        v = data[byte] if byte < len(data) else 0
    else:
        if byte + 1 >= len(data):
            return 0.0
        if endian.startswith("big"):
            v = (data[byte] << 8) | data[byte + 1]
        else:
            v = (data[byte + 1] << 8) | data[byte]
        if endian.endswith("signed") and v & 0x8000:
            v -= 0x10000
    return v * scale + offset


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", type=Path)
    ap.add_argument("mapping", type=Path)
    ap.add_argument("--out", type=Path, default=Path("signals.png"))
    args = ap.parse_args()

    df = load_log(args.log)
    mapping = json.loads(args.mapping.read_text())

    fig, axes = plt.subplots(4, 1, figsize=(14, 10), sharex=True)
    fig.patch.set_facecolor("#0f1729")
    for ax in axes:
        ax.set_facecolor("#0f1729")
        ax.tick_params(colors="white")
        for spine in ax.spines.values():
            spine.set_color("#444")

    colors = {"rpm": "#e74c3c", "speed": "#3498db", "steering": "#f1c40f", "gear": "#2ecc71"}
    for ax, key in zip(axes, ["rpm", "speed", "steering", "gear"]):
        if key not in mapping:
            ax.set_visible(False)
            continue
        m = mapping[key]
        cid = int(m["id"], 0)
        sub = df[df["id"] == cid]
        if sub.empty:
            ax.set_title(f"{key}: ID {m['id']} not found", color="white")
            continue
        ts = sub["t"].to_numpy() - df["t"].iloc[0]
        vals = np.array([decode(d, m["byte"], m["width"], m["endian"], m["scale"], m["offset"]) for d in sub["data"]])
        ax.fill_between(ts, vals, alpha=0.4, color=colors[key])
        ax.plot(ts, vals, color=colors[key], linewidth=1.0)
        ax.set_ylabel(f"{key}\n({m['id']})", color="white")
        ax.grid(alpha=0.2)

    axes[-1].set_xlabel("Time (s)", color="white")
    fig.suptitle(f"CAN Log Analysis: {args.log.name}", color="white", fontweight="bold")
    fig.tight_layout()
    fig.savefig(args.out, dpi=120, facecolor=fig.get_facecolor())
    print(f"[*] wrote {args.out}")


if __name__ == "__main__":
    main()
