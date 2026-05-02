#!/bin/bash
# session_summary.sh
# Claude Code Stop 이벤트에서 호출되어 작업 내용을 LLM으로 요약
# 결과를 데스크톱 알림 + macOS say 음성으로 보고

set -u
set -o pipefail

# macOS 외 환경 가드 (osascript / say 의존)
if [ "$(uname)" != "Darwin" ]; then
    echo "[session_summary] macOS 전용 hook 입니다. 건너뜁니다." >&2
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/session_summary.conf" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/session_summary.conf"
fi

# conf 미설정 키 자동 보완 — 기존 사용자 conf 그대로 두고도 신규 동작 적용
ENABLED="${ENABLED:-true}"
VOICE="${VOICE:-Yuna}"
RATE="${RATE:-}"
MODEL="${MODEL:-claude-haiku-4-5}"
SUMMARY_MAX_CHARS="${SUMMARY_MAX_CHARS:-600}"
NOTIFY_MAX_CHARS="${NOTIFY_MAX_CHARS:-240}"
NOTIFY_TITLE="${NOTIFY_TITLE:-🤖 Claude 작업 완료}"

if [ "$ENABLED" != "true" ]; then
    exit 0
fi

# 재귀 방지: 이 hook이 부르는 자식 claude -p 가 다시 Stop hook을 발화하면 무한루프
if [ "${CLAUDE_SUMMARY_HOOK_RUNNING:-}" = "1" ]; then
    exit 0
fi
export CLAUDE_SUMMARY_HOOK_RUNNING=1

# 영구 로그 디렉터리 (재부팅 후에도 보존, Console.app 에서도 열람 가능)
LOG_DIR="${HOME}/Library/Logs/cc-jarvis"
mkdir -p "$LOG_DIR" 2>/dev/null || true

ARGS=$(cat)
echo "$ARGS" > "${LOG_DIR}/last_hook_input.json" 2>/dev/null || true

TRANSCRIPT_PATH=$(echo "$ARGS" | jq -r '.transcript_path // empty' 2>/dev/null)
SESSION_ID=$(echo "$ARGS" | jq -r '.session_id // empty' 2>/dev/null)
STOP_REASON=$(echo "$ARGS" | jq -r '.stop_reason // "end_turn"' 2>/dev/null)

# 사용자가 ESC로 중단한 경우엔 짧은 알림만, 음성·LLM 요약은 생략
if [ "$STOP_REASON" = "interrupted" ]; then
    SAFE_TITLE=$(printf '%s' "$NOTIFY_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "display notification \"사용자 중단으로 작업이 멈췄습니다.\" with title \"$SAFE_TITLE\"" 2>/dev/null || true
    exit 0
fi

# transcript_path 는 .jsonl — 사용자/어시스턴트 텍스트만 추출해 LLM에 깨끗하게 전달
SUMMARY_INPUT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    SUMMARY_INPUT=$(tail -n 30 "$TRANSCRIPT_PATH" | jq -rs '
        [ .[]
          | select(.type=="user" or .type=="assistant")
          | (
              if (.message.content | type) == "array" then
                .message.content[]? | select(.type=="text") | .text
              elif (.message.content | type) == "string" then
                .message.content
              else empty end
            )
        ] | map(select(. != null and . != "")) | join("\n\n---\n\n")
    ' 2>/dev/null || true)
fi

# fallback: jq 추출 실패·transcript 부재 시 raw stdin 일부 사용 (스키마 변경 대비)
if [ -z "$SUMMARY_INPUT" ]; then
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        SUMMARY_INPUT=$(tail -n 30 "$TRANSCRIPT_PATH")
    else
        SUMMARY_INPUT=$(echo "$ARGS" | cut -c 1-2000)
    fi
fi

if [ -z "$SUMMARY_INPUT" ]; then
    echo "[session_summary] 요약 대상 데이터를 찾지 못했습니다. 건너뜁니다." >&2
    exit 0
fi

# 비밀 토큰 마스킹 — LLM 으로 보내기 전에 흔한 키 패턴을 ***REDACTED*** 로 치환
# 알림·음성 출력에도 비밀이 새지 않도록 하는 1차 방어선
SUMMARY_INPUT=$(printf '%s' "$SUMMARY_INPUT" | sed -E '
    s/sk-(ant-)?[A-Za-z0-9_-]{20,}/sk-***REDACTED***/g
    s/sk-proj-[A-Za-z0-9_-]{20,}/sk-proj-***REDACTED***/g
    s/ghp_[A-Za-z0-9]{20,}/ghp_***REDACTED***/g
    s/ghs_[A-Za-z0-9]{20,}/ghs_***REDACTED***/g
    s/gho_[A-Za-z0-9]{20,}/gho_***REDACTED***/g
    s/github_pat_[A-Za-z0-9_]{20,}/github_pat_***REDACTED***/g
    s/AKIA[0-9A-Z]{16}/AKIA***REDACTED***/g
    s/xox[baprs]-[A-Za-z0-9-]{10,}/xox-***REDACTED***/g
    s/AIza[0-9A-Za-z_-]{20,}/AIza***REDACTED***/g
    s/[Bb]earer +[A-Za-z0-9._-]+/Bearer ***REDACTED***/g
')

PROMPT_FILE="${SCRIPT_DIR}/session_summary_prompt.txt"
if [ ! -f "$PROMPT_FILE" ]; then
    echo "[session_summary] 프롬프트 파일이 없습니다: $PROMPT_FILE" >&2
    exit 1
fi
PROMPT_PREFIX=$(cat "$PROMPT_FILE")
FULL_PROMPT="${PROMPT_PREFIX}
${SUMMARY_INPUT}"

echo "[session_summary] 작업 요약 생성 중 (model: ${MODEL}, stop_reason: ${STOP_REASON})..." >&2

SUMMARY_RESULT=$(claude -p --model "$MODEL" "$FULL_PROMPT" 2>"${LOG_DIR}/last_error.log") || true

if [ -z "$SUMMARY_RESULT" ]; then
    echo "[session_summary] LLM 요약 실행에 실패했습니다 (모델: ${MODEL}). 로그: ${LOG_DIR}/last_error.log" >&2
    exit 1
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SUMMARY_FILE="${LOG_DIR}/summary_${REPO_NAME}_${TIMESTAMP}.txt"
echo "$SUMMARY_RESULT" > "$SUMMARY_FILE"
echo "[session_summary] 요약을 저장했습니다: $SUMMARY_FILE" >&2

# 알림 텍스트 (NOTIFY_MAX_CHARS 캡)
NOTIF_TEXT=$(printf '%s' "$SUMMARY_RESULT" | head -c "$NOTIFY_MAX_CHARS")
SAFE_NOTIF=$(printf '%s' "$NOTIF_TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
SAFE_TITLE=$(printf '%s' "$NOTIFY_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
if osascript -e "display notification \"$SAFE_NOTIF\" with title \"$SAFE_TITLE\"" 2>/dev/null; then
    echo "[session_summary] 데스크톱 알림을 표시했습니다" >&2
else
    echo "[session_summary] 데스크톱 알림 표시에 실패했습니다" >&2
fi

# 음성 텍스트 (SUMMARY_MAX_CHARS 캡)
VOICE_TEXT=$(printf '%s' "$SUMMARY_RESULT" | head -c "$SUMMARY_MAX_CHARS")

SAY_ARGS=(-v "$VOICE")
if [ -n "$RATE" ]; then
    SAY_ARGS+=(-r "$RATE")
fi
say "${SAY_ARGS[@]}" "$VOICE_TEXT" &
echo "[session_summary] 음성 읽어주기를 백그라운드에서 시작했습니다 (voice: ${VOICE}${RATE:+, rate: $RATE})" >&2

# 7일 이상 지난 요약 파일 정리 (3% 확률)
if [ $((RANDOM % 100)) -lt 3 ]; then
    find "$LOG_DIR" -name "summary_*.txt" -mtime +7 -delete 2>/dev/null || true
    echo "[session_summary] 7일 이상된 요약 파일을 정리했습니다" >&2
fi

exit 0
