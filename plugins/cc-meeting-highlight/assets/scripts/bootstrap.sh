#!/usr/bin/env bash
# cc-meeting-highlight: 사용자 프로젝트에 자산(스크립트 + Remotion 템플릿) 부트스트랩
#
# 사용법 (사용자 프로젝트 루트에서):
#   bash <플러그인 경로>/assets/scripts/bootstrap.sh
#
# /meeting-highlight 슬래시 명령어가 자동으로 실행하는 단계입니다.
# 수동 실행도 가능합니다.

set -euo pipefail

# 자산 루트 (이 스크립트가 있는 디렉터리의 부모)
ASSETS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${PWD}"
TARGET="${PROJECT_ROOT}/meeting_rec"

log()  { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; }

mkdir -p "${TARGET}/scripts" "${TARGET}/rec" "${TARGET}/transcribe" "${TARGET}/out"

# 스크립트 복사 (bootstrap.sh 자체는 복사 대상에서 제외)
for f in 00_setup_symlinks.sh 10_extract_audio.sh 20_transcribe.py 50_cut_clips.sh; do
    src="${ASSETS_ROOT}/scripts/${f}"
    dst="${TARGET}/scripts/${f}"
    if [[ -e "${dst}" ]]; then
        warn "이미 존재: scripts/${f} (덮어쓰지 않음)"
    else
        cp "${src}" "${dst}"
        chmod +x "${dst}"
        log "복사: scripts/${f}"
    fi
done

# Remotion 프로젝트 복사
if [[ -d "${TARGET}/remotion" ]]; then
    warn "이미 존재: remotion/ (덮어쓰지 않음)"
else
    cp -R "${ASSETS_ROOT}/remotion" "${TARGET}/remotion"
    log "복사: remotion/"
fi

# Schemas
mkdir -p "${TARGET}/schemas"
for f in highlights.schema.json topics.schema.json; do
    src="${ASSETS_ROOT}/schemas/${f}"
    dst="${TARGET}/schemas/${f}"
    if [[ ! -e "${dst}" ]]; then
        cp "${src}" "${dst}"
        log "복사: schemas/${f}"
    fi
done

# Python venv 점검
if [[ ! -f "${TARGET}/.venv/bin/python" ]]; then
    if command -v uv >/dev/null; then
        log "Python 3.11 venv 생성: ${TARGET}/.venv"
        uv venv --python 3.11 "${TARGET}/.venv"
        # shellcheck disable=SC1091
        source "${TARGET}/.venv/bin/activate"
        uv pip install mlx-whisper
    else
        warn "uv가 없습니다. 'brew install uv' 후 다음을 수동 실행:"
        warn "  uv venv --python 3.11 ${TARGET}/.venv"
        warn "  source ${TARGET}/.venv/bin/activate"
        warn "  uv pip install mlx-whisper"
    fi
fi

# Remotion npm install — 기본은 안내만, INSTALL_NPM=1로 활성화
if command -v npm >/dev/null; then
    if [[ ! -d "${TARGET}/remotion/node_modules" ]]; then
        if [[ "${INSTALL_NPM:-0}" == "1" ]]; then
            log "npm install 실행 (meeting_rec/remotion) — INSTALL_NPM=1"
            ( cd "${TARGET}/remotion" && npm install )
        else
            warn "Remotion 의존성을 설치하려면 다음 중 하나를 실행하세요:"
            warn "  INSTALL_NPM=1 bash bootstrap.sh   # 이 스크립트로 자동 설치"
            warn "  cd ${TARGET}/remotion && npm install   # 수동 설치"
        fi
    fi
else
    warn "Node.js가 없습니다. 'brew install node' 후 다음을 수동 실행:"
    warn "  cd ${TARGET}/remotion && npm install"
fi

cat <<EOF

부트스트랩 완료.

다음 단계:
  1. 회의 소재를 ${TARGET}/rec/<날짜>/ 아래에 배치
     - *.mp4
     - 회의요약.txt
  2. /meeting-highlight 슬래시 명령어 실행 또는 단계별 수동 실행:
       bash meeting_rec/scripts/00_setup_symlinks.sh
       bash meeting_rec/scripts/10_extract_audio.sh
       source meeting_rec/.venv/bin/activate && python meeting_rec/scripts/20_transcribe.py
       (Phase 3·4: Claude Code에서 topics-extractor / highlights-selector 스킬 호출)
       bash meeting_rec/scripts/50_cut_clips.sh
       cd meeting_rec/remotion && npx remotion render Highlight60 ../out/highlight_60s.mp4 --props=../transcribe/highlights.json

EOF
