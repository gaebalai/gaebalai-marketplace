#!/usr/bin/env python3
"""ZIP(or 디렉토리) → 차량 이상음 리포트 생성 (v0.2).

Usage:
    python noise_report.py <take_dir_or_zip> [--out OUT_DIR]

v0.2 변경:
- 5종 패턴 분류 (engine_order / road / rpm_locked / shock / steering)
- RPM-주파수 / 속도-주파수 상관계수 → correlations.csv
- 의심 구간별 확대 PNG → candidate_<n>.png
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

# ------------------------------------------------------------------
# 휴리스틱 파라미터 (도메인 검증으로 보정 권장)
# ------------------------------------------------------------------
ENGINE_ORDER_R_MIN = 0.7   # RPM-주파수 상관계수 임계 (회전성)
ROAD_R_MIN = 0.7           # 속도-주파수 상관계수 임계 (노면성)
RPM_LOCK_BAND = 50.0       # RPM 락 판정 대역폭 (±rpm)
RPM_LOCK_MIN_HITS = 3      # RPM 락 판정 최소 spike 수
SHOCK_RPM_RATE_MAX = 100.0 # 충격 판정 RPM 변화율 상한 (rpm/s)
STEERING_RATE_MIN = 30.0   # 조향계통 판정 조향각 변화율 (deg/s)


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


def safe_corr(x: np.ndarray, y: np.ndarray) -> float:
    """길이 0 / 분산 0이면 0.0 반환하는 안전한 Pearson r."""
    if len(x) < 3 or len(y) < 3 or np.std(x) == 0 or np.std(y) == 0:
        return 0.0
    return float(np.corrcoef(x, y)[0, 1])


def classify_spike(
    spike: dict,
    can_t: np.ndarray,
    rpm_arr: np.ndarray,
    speed_arr: np.ndarray,
    steering_arr: np.ndarray,
    rpm_freq_r: float,
    speed_freq_r: float,
    rpm_locked_bands: list[float],
) -> str:
    """v0.2 5종 휴리스틱.

    우선순위(높은 → 낮음): rpm_locked > steering > shock > engine_order > road > unknown
    """
    spike_t = spike["t"]
    spike_rpm = spike["rpm"]

    # rpm_locked: 이 spike의 RPM이 locked band 중 하나에 속함
    if any(abs(spike_rpm - band) < RPM_LOCK_BAND for band in rpm_locked_bands):
        return "rpm_locked"

    # steering: spike 시점 부근 조향각 변화율
    if len(can_t) > 1 and len(steering_arr) > 1:
        j = np.searchsorted(can_t, spike_t)
        win_lo = max(0, j - 5)
        win_hi = min(len(can_t), j + 5)
        if win_hi - win_lo > 1:
            dt = can_t[win_hi - 1] - can_t[win_lo]
            if dt > 0:
                steering_rate = abs(steering_arr[win_hi - 1] - steering_arr[win_lo]) / dt
                if steering_rate > STEERING_RATE_MIN:
                    return "steering"

    # shock: spike 시점 RPM 변화율이 작음
    if len(can_t) > 1 and len(rpm_arr) > 1:
        j = np.searchsorted(can_t, spike_t)
        win_lo = max(0, j - 5)
        win_hi = min(len(can_t), j + 5)
        if win_hi - win_lo > 1:
            dt = can_t[win_hi - 1] - can_t[win_lo]
            if dt > 0:
                rpm_rate = abs(rpm_arr[win_hi - 1] - rpm_arr[win_lo]) / dt
                if rpm_rate < SHOCK_RPM_RATE_MAX:
                    return "shock"

    # engine_order / road: 전체 상관계수 기준
    if rpm_freq_r > ENGINE_ORDER_R_MIN:
        return "engine_order"
    if speed_freq_r > ROAD_R_MIN:
        return "road"
    return "unknown"


def find_rpm_locked_bands(spikes: list[dict]) -> list[float]:
    """spike RPM 분포에서 ±RPM_LOCK_BAND 안에 RPM_LOCK_MIN_HITS 이상 모이는 대역 추출."""
    if not spikes:
        return []
    rpms = sorted(s["rpm"] for s in spikes if s["rpm"] > 0)
    if len(rpms) < RPM_LOCK_MIN_HITS:
        return []

    bands: list[float] = []
    used = [False] * len(rpms)
    for i, r0 in enumerate(rpms):
        if used[i]:
            continue
        cluster = [j for j, r in enumerate(rpms) if abs(r - r0) < RPM_LOCK_BAND and not used[j]]
        if len(cluster) >= RPM_LOCK_MIN_HITS:
            bands.append(float(np.mean([rpms[j] for j in cluster])))
            for j in cluster:
                used[j] = True
    return bands


def render_candidate_png(
    spike: dict,
    spike_idx: int,
    classification: str,
    f: np.ndarray,
    t_stft: np.ndarray,
    mag: np.ndarray,
    can_t: np.ndarray,
    rpm_arr: np.ndarray,
    rms: np.ndarray,
    t_audio: np.ndarray,
    out_path: Path,
    window_sec: float = 2.0,
):
    """spike 시점 ±window_sec 확대 패널."""
    t0 = max(0.0, spike["t"] - window_sec)
    t1 = spike["t"] + window_sec

    # STFT 슬라이스
    stft_lo = np.searchsorted(t_stft, t0)
    stft_hi = np.searchsorted(t_stft, t1)
    # CAN 슬라이스
    can_lo = np.searchsorted(can_t, t0)
    can_hi = np.searchsorted(can_t, t1)
    # 오디오 RMS 슬라이스
    rms_lo = np.searchsorted(t_audio, t0)
    rms_hi = np.searchsorted(t_audio, t1)

    fig, axes = plt.subplots(3, 1, figsize=(12, 8), sharex=True)
    fig.patch.set_facecolor("#0f1729")
    for ax in axes:
        ax.set_facecolor("#0f1729")
        ax.tick_params(colors="white")
        for s in ax.spines.values():
            s.set_color("#444")

    if stft_hi > stft_lo:
        axes[0].pcolormesh(
            t_stft[stft_lo:stft_hi], f, 20 * np.log10(mag[:, stft_lo:stft_hi] + 1e-9),
            cmap="magma", shading="auto",
        )
    axes[0].axvline(spike["t"], color="#e74c3c", linewidth=1.0, alpha=0.7)
    axes[0].set_ylabel("Hz", color="white")
    axes[0].set_title(
        f"Candidate #{spike_idx + 1} — {classification} @ t={spike['t']:.2f}s, "
        f"peak={spike['peak_hz']:.0f}Hz, RPM={spike['rpm']:.0f}, {spike['speed']:.1f}km/h, gear={spike['gear']}",
        color="white",
    )

    if can_hi > can_lo:
        axes[1].plot(can_t[can_lo:can_hi], rpm_arr[can_lo:can_hi], color="#e74c3c")
    axes[1].axvline(spike["t"], color="#fff", linewidth=0.5, alpha=0.5)
    axes[1].set_ylabel("RPM", color="white")

    if rms_hi > rms_lo:
        axes[2].plot(t_audio[rms_lo:rms_hi], rms[rms_lo:rms_hi], color="#2ecc71")
    axes[2].axvline(spike["t"], color="#fff", linewidth=0.5, alpha=0.5)
    axes[2].set_ylabel("RMS", color="white")
    axes[2].set_xlabel("s", color="white")

    fig.tight_layout()
    fig.savefig(out_path, dpi=110, facecolor=fig.get_facecolor())
    plt.close(fig)


def analyze_take(take_dir: Path, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    audio_path = next((take_dir / n for n in ("audio.webm", "audio.wav") if (take_dir / n).exists()), None)
    can_csv = take_dir / "can.csv"
    meta = json.loads((take_dir / "metadata.json").read_text()) if (take_dir / "metadata.json").exists() else {}
    if not audio_path or not can_csv.exists():
        return {"name": take_dir.name, "error": "missing audio or can.csv"}

    wav = to_wav(audio_path)
    y, sr = sf.read(wav)
    if y.ndim > 1:
        y = y.mean(axis=1)

    # RMS energy (40ms hop)
    hop = int(sr * 0.04)
    rms = np.sqrt(np.array([np.mean(y[i:i + hop] ** 2) for i in range(0, len(y) - hop, hop)]))
    t_audio = np.arange(len(rms)) * 0.04

    # STFT (0~500Hz)
    f, t_stft, Z = stft(y, fs=sr, nperseg=4096, noverlap=3584)
    mag = np.abs(Z)
    cut = np.searchsorted(f, 500)
    f, mag = f[:cut], mag[:cut, :]
    peak_freq = f[np.argmax(mag, axis=0)]

    # CAN
    can_df = pd.read_csv(can_csv)
    if can_df.empty:
        can_t = np.array([0.0])
        rpm_arr = speed_arr = steering_arr = np.array([0.0])
        gear_arr = np.array(["?"])
    else:
        can_df = can_df.sort_values("t").reset_index(drop=True)
        can_t0 = can_df["t"].iloc[0]
        can_t = (can_df["t"] - can_t0).to_numpy()
        rpm_arr = pd.to_numeric(can_df["rpm"], errors="coerce").fillna(0).to_numpy()
        speed_arr = pd.to_numeric(can_df["speed"], errors="coerce").fillna(0).to_numpy()
        if "steering" in can_df.columns:
            steering_arr = pd.to_numeric(can_df["steering"], errors="coerce").fillna(0).to_numpy()
        else:
            steering_arr = np.zeros_like(rpm_arr)
        gear_arr = can_df.get("gear", pd.Series(["?"] * len(can_df))).fillna("?").astype(str).to_numpy()

    # 오디오 → CAN 시간 매핑 후 상관계수
    rpm_at_audio = np.interp(t_audio, can_t, rpm_arr) if len(can_t) > 1 else np.zeros_like(t_audio)
    speed_at_audio = np.interp(t_audio, can_t, speed_arr) if len(can_t) > 1 else np.zeros_like(t_audio)

    # peak_freq는 t_stft 기준이라 t_audio로 interp
    if len(t_stft) > 1:
        peak_at_audio = np.interp(t_audio, t_stft, peak_freq)
    else:
        peak_at_audio = np.zeros_like(t_audio)

    rpm_freq_r = safe_corr(rpm_at_audio, peak_at_audio)
    speed_freq_r = safe_corr(speed_at_audio, peak_at_audio)
    rpm_rms_r = safe_corr(rpm_at_audio, rms)
    speed_rms_r = safe_corr(speed_at_audio, rms)

    # spike 검출 (RMS 상위 1%)
    spikes: list[dict] = []
    if len(rms) > 100:
        thresh = np.percentile(rms, 99)
        spike_idx = np.where(rms > thresh)[0]
        for i in spike_idx[:20]:
            ts = t_audio[i]
            j = np.searchsorted(can_t, ts)
            j = min(j, len(rpm_arr) - 1)
            spikes.append({
                "t": float(ts),
                "rms": float(rms[i]),
                "peak_hz": float(peak_at_audio[i]),
                "rpm": float(rpm_arr[j]),
                "speed": float(speed_arr[j]),
                "steering": float(steering_arr[j]) if j < len(steering_arr) else 0.0,
                "gear": str(gear_arr[j]) if j < len(gear_arr) else "?",
            })

    # 분류
    rpm_locked_bands = find_rpm_locked_bands(spikes)
    for s in spikes:
        s["class"] = classify_spike(
            s, can_t, rpm_arr, speed_arr, steering_arr,
            rpm_freq_r, speed_freq_r, rpm_locked_bands,
        )

    # correlations.csv
    corr_rows = [
        {"metric": "RPM↔peak_freq",  "pearson_r": round(rpm_freq_r, 3),   "interpretation": "엔진 회전성 (회전수와 dominant 주파수의 비례)"},
        {"metric": "speed↔peak_freq","pearson_r": round(speed_freq_r, 3), "interpretation": "노면/타이어성 (속도와 dominant 주파수의 비례)"},
        {"metric": "RPM↔RMS",        "pearson_r": round(rpm_rms_r, 3),    "interpretation": "회전 부하와 음량의 상관"},
        {"metric": "speed↔RMS",      "pearson_r": round(speed_rms_r, 3),  "interpretation": "속도와 음량의 상관"},
    ]
    pd.DataFrame(corr_rows).to_csv(out / "correlations.csv", index=False)

    # overview.png
    fig, axes = plt.subplots(4, 1, figsize=(14, 10), sharex=True)
    fig.patch.set_facecolor("#0f1729")
    for ax in axes:
        ax.set_facecolor("#0f1729")
        ax.tick_params(colors="white")
        for s in ax.spines.values():
            s.set_color("#444")
    axes[0].pcolormesh(t_stft, f, 20 * np.log10(mag + 1e-9), cmap="magma", shading="auto")
    axes[0].set_ylabel("Hz", color="white")
    axes[0].set_title(take_dir.name, color="white")
    axes[1].plot(can_t, rpm_arr, color="#e74c3c"); axes[1].set_ylabel("RPM", color="white")
    axes[2].plot(can_t, speed_arr, color="#3498db"); axes[2].set_ylabel("km/h", color="white")
    axes[3].plot(t_audio, rms, color="#2ecc71"); axes[3].set_ylabel("RMS", color="white")
    axes[3].set_xlabel("s", color="white")
    # spike 마커
    for s in spikes:
        axes[3].axvline(s["t"], color="#fff", alpha=0.3, linewidth=0.5)
    fig.tight_layout()
    fig.savefig(out / "overview.png", dpi=110, facecolor=fig.get_facecolor())
    plt.close(fig)

    # candidate_<n>.png (Top 5만 — 너무 많으면 무거움)
    for idx, s in enumerate(spikes[:5]):
        render_candidate_png(
            s, idx, s["class"],
            f, t_stft, mag,
            can_t, rpm_arr, rms, t_audio,
            out / f"candidate_{idx + 1}.png",
        )

    # report.md
    lines = [f"# Take: {take_dir.name}", ""]
    lines.append(f"- 길이: {len(y) / sr:.1f}s, RPM 범위 {rpm_arr.min():.0f}~{rpm_arr.max():.0f}")
    lines.append(f"- 의심 구간: {len(spikes)}건 (확대 PNG: 상위 {min(5, len(spikes))}건)")
    if rpm_locked_bands:
        lines.append(f"- 검출된 RPM 락 대역: {', '.join(f'{b:.0f}±{RPM_LOCK_BAND:.0f}rpm' for b in rpm_locked_bands)}")
    lines.append("")
    lines.append("## 상관 분석")
    lines.append("")
    lines.append("| 지표 | Pearson r | 해석 |")
    lines.append("|---|---|---|")
    for r in corr_rows:
        lines.append(f"| {r['metric']} | {r['pearson_r']} | {r['interpretation']} |")
    lines.append("")
    if spikes:
        lines.append("## 의심 구간 표")
        lines.append("")
        lines.append("| # | 시각(s) | 분류 | 피크(Hz) | RPM | 속도 | 조향각 | 기어 |")
        lines.append("|---|---|---|---|---|---|---|---|")
        for i, s in enumerate(spikes):
            lines.append(
                f"| {i + 1} | {s['t']:.2f} | **{s['class']}** | {s['peak_hz']:.0f} | "
                f"{s['rpm']:.0f} | {s['speed']:.1f} | {s['steering']:.1f}° | {s['gear']} |"
            )
        lines.append("")
        lines.append("**분류 의미**:")
        lines.append("- `engine_order`: 엔진 회전성. 정상 가능성 높음")
        lines.append("- `road`: 노면/타이어성")
        lines.append("- `rpm_locked`: 특정 RPM 대역 공진/부품 결함 의심")
        lines.append("- `shock`: 충격/접촉음 (RPM 변화 작은데 RMS 급증)")
        lines.append("- `steering`: 서스펜션/조향계통 (조향각 변화 시 발생)")
        lines.append("- `unknown`: 위 패턴에 안 맞음 — 사람 검토 필요")
    (out / "report.md").write_text("\n".join(lines), encoding="utf-8")

    return {
        "name": take_dir.name,
        "spikes": spikes,
        "duration": len(y) / sr,
        "rpm_locked_bands": rpm_locked_bands,
    }


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

    overview = ["# 차량 이상음 분석 — 종합 리포트 (v0.2)", ""]
    overview.append("**휴리스틱 분류는 도메인 검증 전 가이드용입니다.** 실차 검증 후에만 부품 진단에 사용하세요.")
    overview.append("")
    for s in summaries:
        if "error" in s:
            overview.append(f"- {s['name']}: ERROR {s['error']}")
            continue
        overview.append(f"## {s['name']} — {s['duration']:.1f}s, 의심 {len(s['spikes'])}건")
        if s.get("rpm_locked_bands"):
            overview.append(f"- RPM 락 대역: {', '.join(f'{b:.0f}rpm' for b in s['rpm_locked_bands'])}")
        # 분류별 카운트
        if s["spikes"]:
            from collections import Counter
            counts = Counter(sp["class"] for sp in s["spikes"])
            overview.append(f"- 분류: {', '.join(f'{k}={v}' for k, v in counts.items())}")
        overview.append(f"![overview]({s['name']}/overview.png)")
        overview.append(f"[자세히]({s['name']}/report.md)")
        overview.append("")
    (args.out / "INDEX.md").write_text("\n".join(overview), encoding="utf-8")
    shutil.rmtree(work, ignore_errors=True)
    print(f"[*] done → {args.out}/INDEX.md", file=sys.stderr)


if __name__ == "__main__":
    main()
