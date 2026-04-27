#!/usr/bin/env python3
"""ZIP(or 디렉토리) → 차량 이상음 리포트 생성.

Usage:
    python noise_report.py <take_dir_or_zip> [--out OUT_DIR]
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import soundfile as sf
from scipy.signal import stft


def to_wav(audio: Path) -> Path:
    if audio.suffix == ".wav":
        return audio
    out = audio.with_suffix(".wav")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(audio), "-ac", "1", "-ar", "16000", str(out)],
        check=True,
    )
    return out


def extract_take(src: Path, work: Path) -> list[Path]:
    if src.is_dir():
        return [src]
    if src.suffix.lower() == ".zip":
        zipfile.ZipFile(src).extractall(work)
        return [p for p in work.iterdir() if p.is_dir()]
    raise SystemExit(f"unsupported input: {src}")


def analyze_take(take_dir: Path, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    audio_path = next((take_dir / n for n in ("audio.webm", "audio.wav") if (take_dir / n).exists()), None)
    can_csv = take_dir / "can.csv"
    meta = json.loads((take_dir / "metadata.json").read_text())
    if not audio_path or not can_csv.exists():
        return {"name": take_dir.name, "error": "missing audio or can.csv"}

    wav = to_wav(audio_path)
    y, sr = sf.read(wav)
    if y.ndim > 1:
        y = y.mean(axis=1)

    # RMS energy (40ms hop)
    hop = int(sr * 0.04)
    rms = np.sqrt(np.array([np.mean(y[i:i+hop]**2) for i in range(0, len(y) - hop, hop)]))
    t_audio = np.arange(len(rms)) * 0.04

    # STFT
    f, t_stft, Z = stft(y, fs=sr, nperseg=4096, noverlap=3584)
    mag = np.abs(Z)
    cut = np.searchsorted(f, 500)  # 0~500Hz 영역만
    f, mag = f[:cut], mag[:cut, :]
    peak_freq = f[np.argmax(mag, axis=0)]

    # CAN
    can_df = pd.read_csv(can_csv)
    if can_df.empty:
        can_t = np.array([0.0])
        rpm = speed = np.array([0.0])
        gear = np.array(["?"])
    else:
        can_df = can_df.sort_values("t").reset_index(drop=True)
        can_t0 = can_df["t"].iloc[0]
        can_t = (can_df["t"] - can_t0).to_numpy()
        rpm = can_df["rpm"].fillna(0).to_numpy()
        speed = can_df["speed"].fillna(0).to_numpy()
        gear = can_df["gear"].fillna("?").astype(str).to_numpy()

    # 이상음 후보: RMS 상위 1% 구간 + 그 시점 RPM/속도
    if len(rms) > 100:
        thresh = np.percentile(rms, 99)
        spike_idx = np.where(rms > thresh)[0]
        spikes = []
        for i in spike_idx[:10]:
            ts = t_audio[i]
            j = np.searchsorted(can_t, ts)
            j = min(j, len(rpm) - 1)
            spikes.append({
                "t": float(ts),
                "rms": float(rms[i]),
                "peak_hz": float(peak_freq[min(int(ts/(t_stft[1]-t_stft[0])), len(peak_freq)-1)]) if len(t_stft) > 1 else 0.0,
                "rpm": float(rpm[j]),
                "speed": float(speed[j]),
                "gear": str(gear[j]),
            })
    else:
        spikes = []

    # overview.png
    fig, axes = plt.subplots(4, 1, figsize=(14, 10), sharex=True)
    fig.patch.set_facecolor("#0f1729")
    for ax in axes:
        ax.set_facecolor("#0f1729")
        ax.tick_params(colors="white")
        for s in ax.spines.values():
            s.set_color("#444")
    axes[0].pcolormesh(t_stft, f, 20*np.log10(mag + 1e-9), cmap="magma", shading="auto")
    axes[0].set_ylabel("Hz", color="white")
    axes[0].set_title(take_dir.name, color="white")
    axes[1].plot(can_t, rpm, color="#e74c3c"); axes[1].set_ylabel("RPM", color="white")
    axes[2].plot(can_t, speed, color="#3498db"); axes[2].set_ylabel("km/h", color="white")
    axes[3].plot(t_audio, rms, color="#2ecc71"); axes[3].set_ylabel("RMS", color="white")
    axes[3].set_xlabel("s", color="white")
    fig.tight_layout()
    fig.savefig(out / "overview.png", dpi=110, facecolor=fig.get_facecolor())
    plt.close(fig)

    # 리포트
    lines = [f"# Take: {take_dir.name}", ""]
    lines.append(f"- 길이: {len(y)/sr:.1f}s,  RPM 범위 {rpm.min():.0f}~{rpm.max():.0f}")
    lines.append(f"- 의심 구간: {len(spikes)}건")
    lines.append("")
    if spikes:
        lines.append("| 시각(s) | 피크(Hz) | RPM | 속도 | 기어 |")
        lines.append("|---|---|---|---|---|")
        for s in spikes:
            lines.append(f"| {s['t']:.2f} | {s['peak_hz']:.0f} | {s['rpm']:.0f} | {s['speed']:.1f} | {s['gear']} |")
    (out / "report.md").write_text("\n".join(lines), encoding="utf-8")
    return {"name": take_dir.name, "spikes": spikes, "duration": len(y)/sr}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("--out", type=Path, default=Path("report_out"))
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    work = args.out / "_extract"
    work.mkdir(exist_ok=True)
    takes = extract_take(args.input, work)

    summaries = []
    for t in takes:
        print(f"[*] analyzing {t.name}", file=sys.stderr)
        summaries.append(analyze_take(t, args.out / t.name))

    overview = ["# 차량 이상음 분석 — 종합 리포트", ""]
    for s in summaries:
        if "error" in s:
            overview.append(f"- {s['name']}: ERROR {s['error']}")
            continue
        overview.append(f"## {s['name']} — {s['duration']:.1f}s, 의심 {len(s['spikes'])}건")
        overview.append(f"![overview]({s['name']}/overview.png)")
        overview.append(f"[자세히]({s['name']}/report.md)")
        overview.append("")
    (args.out / "INDEX.md").write_text("\n".join(overview), encoding="utf-8")
    shutil.rmtree(work, ignore_errors=True)
    print(f"[*] done → {args.out}/INDEX.md", file=sys.stderr)


if __name__ == "__main__":
    main()
