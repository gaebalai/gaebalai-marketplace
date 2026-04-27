#!/usr/bin/env python3
"""candump 텍스트 로그 → 표준 CSV 변환.

candump 형식:
    (1700000000.123456) can0 202#1F4017700000000

출력 CSV:
    timestamp,id,data
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

LINE_RE = re.compile(r"\(([0-9.]+)\)\s+\S+\s+([0-9A-Fa-f]+)#([0-9A-Fa-f]*)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("candump_log", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    n = 0
    with args.candump_log.open() as fin, args.out.open("w", newline="") as fout:
        w = csv.writer(fout)
        w.writerow(["timestamp", "id", "data"])
        for line in fin:
            m = LINE_RE.match(line)
            if not m:
                continue
            ts, cid_hex, data_hex = m.groups()
            w.writerow([ts, f"0x{cid_hex.upper()}", data_hex.upper()])
            n += 1
    print(f"[*] converted {n} frames -> {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
