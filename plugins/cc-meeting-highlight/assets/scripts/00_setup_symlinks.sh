#!/usr/bin/env bash
# Phase 0: 한글·일본어 파일명을 ASCII symlink로 통일
#
# 사용법:
#   bash 00_setup_symlinks.sh                  # rec/ 아래 가장 최신 폴더 자동 선택
#   DATE=2025_12_04 bash 00_setup_symlinks.sh  # 특정 날짜 폴더 지정
#   bash 00_setup_symlinks.sh --date 2025_12_04
#
# 출력:
#   meeting_rec/rec/<date>/_links/
#     ├── meeting.mp4   → 원본 mp4
#     ├── summary.txt   → 회의요약.txt 또는 geminiまとめ.txt
#     └── chat.sbv      → Meeting Chat.sbv (있는 경우)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REC_BASE="${REPO_ROOT}/meeting_rec/rec"

log()  { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; }

# 인자 파싱
date_arg=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --date) date_arg="$2"; shift 2 ;;
        --date=*) date_arg="${1#*=}"; shift ;;
        *) err "알 수 없는 인자: $1"; exit 2 ;;
    esac
done

# DATE 환경변수 우선
if [[ -z "${date_arg}" ]]; then
    date_arg="${DATE:-}"
fi

if [[ ! -d "${REC_BASE}" ]]; then
    err "rec 디렉터리가 없습니다: ${REC_BASE}"
    err "회의 소재를 meeting_rec/rec/<date>/ 아래에 배치하세요"
    exit 1
fi

# 날짜 폴더 결정
if [[ -n "${date_arg}" ]]; then
    target_dir="${REC_BASE}/${date_arg}"
    [[ -d "${target_dir}" ]] || { err "지정한 날짜 폴더가 없습니다: ${target_dir}"; exit 1; }
else
    # rec/ 아래 디렉터리 중 이름 정렬상 가장 마지막(최신 날짜로 가정)
    target_dir="$(find "${REC_BASE}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
    [[ -n "${target_dir}" && -d "${target_dir}" ]] || { err "rec/ 아래에 날짜 폴더가 없습니다"; exit 1; }
fi

log "대상 폴더: ${target_dir}"

LINKS_DIR="${target_dir}/_links"
mkdir -p "${LINKS_DIR}"

# mp4 한 개 찾기 (NFD/NFC 무관하게 매칭)
shopt -s nullglob
mp4_files=( "${target_dir}"/*.mp4 "${target_dir}"/*.MP4 )
shopt -u nullglob

if [[ ${#mp4_files[@]} -eq 0 ]]; then
    err "mp4 파일이 없습니다: ${target_dir}"
    exit 1
elif [[ ${#mp4_files[@]} -gt 1 ]]; then
    warn "mp4 파일이 여러 개 있습니다. 첫 번째만 사용합니다:"
    for f in "${mp4_files[@]}"; do warn "  - $(basename "$f")"; done
fi

mp4_src="${mp4_files[0]}"
mp4_link="${LINKS_DIR}/meeting.mp4"
ln -sfn "${mp4_src}" "${mp4_link}"
log "meeting.mp4 → $(basename "${mp4_src}")"

# 회의요약 텍스트 (한국어/일본어/영문 후보 순서대로 탐색)
summary_src=""
for cand in "${target_dir}/회의요약.txt" \
            "${target_dir}/회의록.txt" \
            "${target_dir}/geminiまとめ.txt" \
            "${target_dir}/Gemini요약.txt" \
            "${target_dir}/summary.txt"; do
    if [[ -f "${cand}" ]]; then summary_src="${cand}"; break; fi
done

# 위 후보가 없으면 *.txt 중 첫 번째
if [[ -z "${summary_src}" ]]; then
    shopt -s nullglob
    txt_files=( "${target_dir}"/*.txt )
    shopt -u nullglob
    if [[ ${#txt_files[@]} -gt 0 ]]; then
        summary_src="${txt_files[0]}"
        warn "표준 이름의 회의요약을 못 찾아 첫 .txt를 사용합니다: $(basename "${summary_src}")"
    fi
fi

if [[ -z "${summary_src}" ]]; then
    err "회의요약 텍스트가 없습니다. 회의요약.txt 또는 *.txt를 ${target_dir}에 배치하세요"
    exit 1
fi

ln -sfn "${summary_src}" "${LINKS_DIR}/summary.txt"
log "summary.txt → $(basename "${summary_src}")"

# Meeting Chat (선택)
shopt -s nullglob
sbv_files=( "${target_dir}"/*.sbv "${target_dir}"/Meeting\ Chat*.sbv )
shopt -u nullglob

if [[ ${#sbv_files[@]} -gt 0 ]]; then
    ln -sfn "${sbv_files[0]}" "${LINKS_DIR}/chat.sbv"
    log "chat.sbv → $(basename "${sbv_files[0]}")"
else
    warn "Meeting Chat.sbv 없음 (선택 사항이라 계속 진행)"
fi

# transcribe 디렉터리 사전 생성
mkdir -p "${REPO_ROOT}/meeting_rec/transcribe"

# 현재 활성 날짜를 latest 심볼릭으로 마킹 (다른 페이즈가 자동 선택)
ln -sfn "${target_dir}" "${REC_BASE}/_latest"
log "rec/_latest → $(basename "${target_dir}")"

log "Phase 0 완료. 다음 단계: bash 10_extract_audio.sh"
