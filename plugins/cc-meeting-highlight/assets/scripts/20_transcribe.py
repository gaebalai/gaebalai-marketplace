#!/usr/bin/env python3
"""
Phase 2: mlx-whisper로 한국어 회의 음성을 word-level 받아쓰기

사용법:
    python 20_transcribe.py
    CONDITION_PREV=0 FORCE=1 python 20_transcribe.py    # 반복 루프 발생 시 강제 재생성

입력:  meeting_rec/transcribe/audio.wav (Phase 1 산출)
출력:  meeting_rec/transcribe/transcript.json

환경 요건:
    Python 3.11 (3.14는 mlx-whisper ImportError 발생)
    mlx-whisper (uv pip install mlx-whisper)

INITIAL_PROMPT:
    회의에서 자주 등장하는 사내 용어·고유명사를 콤마 구분으로 적어두면
    받아쓰기 정확도가 올라갑니다. 환경변수 INITIAL_PROMPT로도 덮어쓸 수 있습니다.
"""

import json
import os
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
TRANSCRIBE_DIR = REPO_ROOT / "meeting_rec" / "transcribe"
INPUT_WAV = TRANSCRIBE_DIR / "audio.wav"
OUTPUT_JSON = TRANSCRIBE_DIR / "transcript.json"

# 모델 (Apple Silicon 최적화)
MODEL = os.environ.get("WHISPER_MODEL", "mlx-community/whisper-large-v3-turbo")

# INITIAL_PROMPT — 회의별로 자주 등장하는 용어를 추가하세요
INITIAL_PROMPT = os.environ.get(
    "INITIAL_PROMPT",
    "회의, 안건, OKR, KPI, MAU, DAU, 출시, 마감, QA, PM, CTO, CFO, 백엔드, 프론트엔드, "
    "스프린트, 마일스톤, 액션 아이템, 결재, 승인, 리뷰",
)

LANGUAGE = os.environ.get("LANGUAGE", "ko")
CONDITION_PREV = os.environ.get("CONDITION_PREV", "0") == "1"
FORCE = os.environ.get("FORCE", "0") == "1"


def log(msg: str) -> None:
    print(f"  \033[32m✓\033[0m {msg}")


def warn(msg: str) -> None:
    print(f"  \033[33m!\033[0m {msg}")


def err(msg: str) -> None:
    print(f"  \033[31m✗\033[0m {msg}", file=sys.stderr)


def main() -> int:
    if sys.version_info[:2] != (3, 11):
        warn(
            f"Python {sys.version_info.major}.{sys.version_info.minor} 사용 중. "
            "권장 버전은 3.11입니다 (3.14에서는 mlx-whisper ImportError 발생). "
            "uv venv --python 3.11 meeting_rec/.venv 로 재생성하세요"
        )

    if not INPUT_WAV.exists():
        err(f"입력 WAV가 없습니다: {INPUT_WAV}")
        err("Phase 1(10_extract_audio.sh)을 먼저 실행하세요")
        return 1

    if (
        not FORCE
        and OUTPUT_JSON.exists()
        and OUTPUT_JSON.stat().st_size > 0
        and OUTPUT_JSON.stat().st_mtime > INPUT_WAV.stat().st_mtime
    ):
        log(f"캐시 사용: {OUTPUT_JSON}")
        log("재생성하려면 FORCE=1 python 20_transcribe.py")
        return 0

    try:
        import mlx_whisper
    except ImportError as e:
        err(f"mlx-whisper import 실패: {e}")
        err("Python 3.11 venv에서 'uv pip install mlx-whisper' 실행하세요")
        return 1

    log(f"모델: {MODEL}")
    log(f"언어: {LANGUAGE}")
    log(f"INITIAL_PROMPT: {INITIAL_PROMPT[:80]}{'...' if len(INITIAL_PROMPT) > 80 else ''}")
    log(f"condition_on_previous_text: {CONDITION_PREV}")
    log("받아쓰기 시작 (1시간 회의 기준 1-3분 소요)...")

    result: dict[str, Any] = mlx_whisper.transcribe(
        str(INPUT_WAV),
        path_or_hf_repo=MODEL,
        language=LANGUAGE,
        initial_prompt=INITIAL_PROMPT,
        condition_on_previous_text=CONDITION_PREV,
        word_timestamps=True,
        verbose=False,
    )

    # 결과 정규화 (mlx-whisper 버전별 키 차이 흡수)
    segments = result.get("segments", [])
    text = result.get("text", "")

    # word-level 타임스탬프 보존 검증
    has_words = any("words" in seg and seg["words"] for seg in segments)
    if not has_words:
        warn("word-level 타임스탬프가 비어있습니다. 토픽 매칭 정확도가 떨어질 수 있음")

    output = {
        "language": result.get("language", LANGUAGE),
        "model": MODEL,
        "text": text,
        "segments": segments,
    }

    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")

    seg_count = len(segments)
    word_count = sum(len(seg.get("words", [])) for seg in segments)
    log(f"Phase 2 완료. segments: {seg_count}, words: {word_count}")
    log(f"출력: {OUTPUT_JSON}")
    log("다음 단계: Claude Code에서 topics-extractor 스킬 호출")
    return 0


if __name__ == "__main__":
    sys.exit(main())
