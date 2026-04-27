#!/usr/bin/env bash
# Phase 5: highlights.json을 읽어 ffmpeg로 클립 잘라내기 (CFR 30fps 재인코딩)
#
# 플랫폼: macOS (`stat -f %m` 사용). Linux 이식은 `stat -c %Y` 분기 추가 필요.
#
# 사용법:
#   bash 50_cut_clips.sh
#   FORCE=1 bash 50_cut_clips.sh   # 캐시 무시하고 전체 재생성
#
# 입력:
#   meeting_rec/transcribe/highlights.json  (Phase 4 산출)
#   meeting_rec/rec/_latest/_links/meeting.mp4 (Phase 0 산출)
#
# 출력:
#   meeting_rec/remotion/public/clips/clip_<id>.mp4
#   meeting_rec/transcribe/.cut_cache.json (캐시 키)
#
# 인코딩: H.264 (libx264) + AAC, CFR 30fps, 1920x1080 유지(원본 종횡비)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HIGHLIGHTS_JSON="${REPO_ROOT}/meeting_rec/transcribe/highlights.json"
SOURCE_MP4="${REPO_ROOT}/meeting_rec/rec/_latest/_links/meeting.mp4"
CLIPS_DIR="${REPO_ROOT}/meeting_rec/remotion/public/clips"
CACHE_FILE="${REPO_ROOT}/meeting_rec/transcribe/.cut_cache.json"

log()  { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; }

command -v ffmpeg >/dev/null || { err "ffmpeg가 없습니다. brew install ffmpeg"; exit 1; }
command -v jq     >/dev/null || { err "jq가 없습니다. brew install jq";       exit 1; }

[[ -f "${HIGHLIGHTS_JSON}" ]] || { err "highlights.json이 없습니다: ${HIGHLIGHTS_JSON}"; err "Phase 4(highlights-selector 스킬)를 먼저 실행하세요"; exit 1; }
[[ -e "${SOURCE_MP4}"      ]] || { err "원본 mp4가 없습니다: ${SOURCE_MP4}";              err "Phase 0(00_setup_symlinks.sh)을 먼저 실행하세요";    exit 1; }

mkdir -p "${CLIPS_DIR}"

# highlights.json 검증
clip_count="$(jq '.clips | length' "${HIGHLIGHTS_JSON}")"
[[ "${clip_count}" -gt 0 ]] || { err "highlights.json에 clips가 없습니다"; exit 1; }

total_duration="$(jq '.totalDurationSec // 60' "${HIGHLIGHTS_JSON}")"
sum_duration="$(jq '[.clips[].durationSec] | add' "${HIGHLIGHTS_JSON}")"
log "클립 ${clip_count}개, 합계 ${sum_duration}초 (목표 ${total_duration}초)"

# 캐시 로드
declare -A cache
if [[ -f "${CACHE_FILE}" ]]; then
    while IFS=$'\t' read -r key val; do
        cache[$key]="$val"
    done < <(jq -r 'to_entries | .[] | "\(.key)\t\(.value)"' "${CACHE_FILE}" 2>/dev/null || true)
fi

# 새 캐시 누적
new_cache="{}"

cut_count=0
skip_count=0

for ((i = 0; i < clip_count; i++)); do
    id="$(jq -r ".clips[$i].id" "${HIGHLIGHTS_JSON}")"
    src_path="$(jq -r ".clips[$i].src" "${HIGHLIGHTS_JSON}")"
    start="$(jq -r ".clips[$i].sourceStartSec" "${HIGHLIGHTS_JSON}")"
    end="$(jq -r ".clips[$i].sourceEndSec" "${HIGHLIGHTS_JSON}")"
    duration="$(jq -r ".clips[$i].durationSec" "${HIGHLIGHTS_JSON}")"

    # 경로 결정 (src 명시 우선, 없으면 clip_<id>.mp4 패턴)
    if [[ "${src_path}" == "null" || -z "${src_path}" ]]; then
        out_rel="clips/clip_${id}.mp4"
    else
        out_rel="${src_path}"
    fi
    out_path="${REPO_ROOT}/meeting_rec/remotion/public/${out_rel}"
    mkdir -p "$(dirname "${out_path}")"

    # 캐시 키: id + 시작 + 끝 + 원본 mtime
    src_mtime="$(stat -f %m "$(realpath "${SOURCE_MP4}")" 2>/dev/null || echo 0)"
    cache_key="clip_${id}"
    expected="${start}|${end}|${duration}|${src_mtime}"

    if [[ "${FORCE:-0}" != "1" ]] && [[ -s "${out_path}" ]] && [[ "${cache[$cache_key]:-}" == "${expected}" ]]; then
        log "캐시: ${out_rel}"
        skip_count=$((skip_count + 1))
        new_cache="$(jq --arg k "${cache_key}" --arg v "${expected}" '. + {($k): $v}' <<<"${new_cache}")"
        continue
    fi

    log "잘라내기 [${id}/${clip_count}]: ${start}s → ${end}s (${duration}s)"

    # ffmpeg: -ss 입력 측 + -to 정확 컷, libx264 CFR 30fps, AAC 128k
    # ffmpeg 5.1+에서 -vsync 대신 -fps_mode 사용
    ffmpeg -hide_banner -loglevel warning -y \
        -ss "${start}" \
        -to "${end}" \
        -i "${SOURCE_MP4}" \
        -c:v libx264 \
        -preset medium \
        -crf 20 \
        -r 30 \
        -fps_mode cfr \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 128k \
        -ar 48000 \
        -movflags +faststart \
        "${out_path}"

    if [[ ! -s "${out_path}" ]]; then
        err "클립 출력 실패: ${out_path}"
        exit 1
    fi

    cut_count=$((cut_count + 1))
    new_cache="$(jq --arg k "${cache_key}" --arg v "${expected}" '. + {($k): $v}' <<<"${new_cache}")"
done

# 캐시 저장
echo "${new_cache}" > "${CACHE_FILE}"

log "Phase 5 완료. 새로 자른 클립 ${cut_count}개, 캐시 사용 ${skip_count}개"
log "출력 디렉터리: ${CLIPS_DIR}"
log "다음 단계: cd meeting_rec/remotion && npx remotion render Highlight60 ../out/highlight_60s.mp4 --props=../transcribe/highlights.json"
