#!/usr/bin/env bash
# empirical-prompt-tuning 로컬 설치 스크립트 (마켓플레이스 미사용 시)
#
# 권장 경로는 Claude Code 플러그인 마켓플레이스입니다:
#   /plugin marketplace add gaebalai/gaebalai-marketplace
#   /plugin install empirical-prompt-tuning@gaebalai-marketplace
#
# 이 스크립트는 마켓플레이스를 거치지 않고 SKILL 자원을
# ~/.claude/skills/empirical-prompt-tuning 으로 직접 연결합니다 (개발 편의용).
#
# 사용:
#   bash install.sh           # 심볼릭 링크 (개발용, 기본)
#   bash install.sh --copy    # 파일 복사 (배포용, 변경 격리)
#   bash install.sh --uninstall

set -euo pipefail

SKILL_NAME="empirical-prompt-tuning"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${REPO_ROOT}/plugins/${SKILL_NAME}/skills/${SKILL_NAME}"
DEST_BASE="${HOME}/.claude/skills"
DEST_DIR="${DEST_BASE}/${SKILL_NAME}"

mode="${1:-link}"

log()  { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; }

# 사전 점검
if [[ ! -f "${SRC_DIR}/SKILL.md" ]]; then
    err "SKILL.md를 찾을 수 없습니다: ${SRC_DIR}/SKILL.md"
    err "리포지터리 구조가 plugins/${SKILL_NAME}/skills/${SKILL_NAME}/ 형태인지 확인하세요"
    exit 1
fi

mkdir -p "${DEST_BASE}"

case "${mode}" in
    --uninstall)
        if [[ -L "${DEST_DIR}" || -d "${DEST_DIR}" ]]; then
            rm -rf "${DEST_DIR}"
            log "제거 완료: ${DEST_DIR}"
        else
            warn "설치되어 있지 않음: ${DEST_DIR}"
        fi
        ;;

    --copy)
        if [[ -e "${DEST_DIR}" ]]; then
            warn "기존 설치 발견: ${DEST_DIR}"
            read -r -p "  덮어쓰시겠습니까? [y/N] " ans
            [[ "${ans}" == "y" || "${ans}" == "Y" ]] || { warn "취소"; exit 0; }
            rm -rf "${DEST_DIR}"
        fi
        mkdir -p "${DEST_DIR}"
        cp -R "${SRC_DIR}/SKILL.md"     "${DEST_DIR}/"
        cp -R "${SRC_DIR}/references"   "${DEST_DIR}/"
        cp -R "${SRC_DIR}/assets"       "${DEST_DIR}/"
        log "복사 설치 완료: ${DEST_DIR} (소스: ${SRC_DIR})"
        ;;

    link|*)
        if [[ -e "${DEST_DIR}" || -L "${DEST_DIR}" ]]; then
            warn "기존 설치 발견: ${DEST_DIR}"
            read -r -p "  심볼릭 링크로 교체하시겠습니까? [y/N] " ans
            [[ "${ans}" == "y" || "${ans}" == "Y" ]] || { warn "취소"; exit 0; }
            rm -rf "${DEST_DIR}"
        fi
        ln -s "${SRC_DIR}" "${DEST_DIR}"
        log "심볼릭 링크 생성: ${DEST_DIR} → ${SRC_DIR}"
        log "이 디렉터리에서 수정한 SKILL.md / references / assets 가 즉시 반영됩니다"
        ;;
esac

# 평가 결과 저장 디렉터리 사전 생성 (워크플로우 중 자동 생성을 기대하지만,
# 권한 문제로 첫 dispatch가 실패하는 사례가 있어 사전 보장)
EVAL_LOGS="${HOME}/.claude/eval-logs"
if [[ ! -d "${EVAL_LOGS}" ]]; then
    mkdir -p "${EVAL_LOGS}"
    log "평가 로그 디렉터리 생성: ${EVAL_LOGS}"
fi

# 설치 검증
if [[ -f "${DEST_DIR}/SKILL.md" ]]; then
    log "검증 OK: SKILL.md 접근 가능"
else
    err "검증 실패: SKILL.md를 읽을 수 없습니다"
    exit 1
fi

cat <<EOF

설치 완료.

다음 단계:
  1. 새 Claude Code 세션을 엽니다
  2. "empirical-prompt-tuning 스킬 보여줘" 또는
     "내 SKILL.md 평가해줘" 같은 표현으로 트리거합니다

제거하려면:
  bash install.sh --uninstall

참고 — 마켓플레이스 경로 (권장):
  /plugin marketplace add gaebalai/gaebalai-marketplace
  /plugin install empirical-prompt-tuning@gaebalai-marketplace

EOF
