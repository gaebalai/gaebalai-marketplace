#!/usr/bin/env bash
# Phase 1: 회의 mp4에서 16kHz mono WAV 음성 추출
#
# 사용법:
#   bash 10_extract_audio.sh
#
# 입력:  meeting_rec/rec/_latest/_links/meeting.mp4 (Phase 0 산출)
# 출력:  meeting_rec/transcribe/audio.wav (16kHz mono PCM)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LATEST="${REPO_ROOT}/meeting_rec/rec/_latest"
INPUT_MP4="${LATEST}/_links/meeting.mp4"
TRANSCRIBE_DIR="${REPO_ROOT}/meeting_rec/transcribe"
OUTPUT_WAV="${TRANSCRIBE_DIR}/audio.wav"

log()  { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; }

# 사전 점검
command -v ffmpeg >/dev/null || { err "ffmpeg가 없습니다. brew install ffmpeg"; exit 1; }
[[ -e "${INPUT_MP4}" ]] || { err "입력 mp4가 없습니다: ${INPUT_MP4}"; err "Phase 0(00_setup_symlinks.sh)을 먼저 실행하세요"; exit 1; }

mkdir -p "${TRANSCRIBE_DIR}"

# 캐시 판정: 입력보다 출력이 새것이고 비어있지 않으면 건너뜀
if [[ "${FORCE:-0}" != "1" ]] && [[ -s "${OUTPUT_WAV}" ]] && [[ "${OUTPUT_WAV}" -nt "${INPUT_MP4}" ]]; then
    log "캐시 사용: ${OUTPUT_WAV}"
    log "재추출하려면 FORCE=1 bash 10_extract_audio.sh"
    exit 0
fi

log "입력: $(realpath "${INPUT_MP4}")"
log "추출 시작 (16kHz mono PCM)..."

ffmpeg -hide_banner -loglevel warning -y \
    -i "${INPUT_MP4}" \
    -vn \
    -ac 1 \
    -ar 16000 \
    -c:a pcm_s16le \
    "${OUTPUT_WAV}"

# 결과 검증
if [[ ! -s "${OUTPUT_WAV}" ]]; then
    err "음성 추출 실패. 출력 파일이 비어있음"
    exit 1
fi

duration_sec="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${OUTPUT_WAV}")"
size_mb="$(du -m "${OUTPUT_WAV}" | cut -f1)"
log "Phase 1 완료. 길이: ${duration_sec}초, 크기: ${size_mb}MB"
log "다음 단계: source meeting_rec/.venv/bin/activate && python meeting_rec/scripts/20_transcribe.py"
