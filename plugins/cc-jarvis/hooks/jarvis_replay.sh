#!/bin/bash
# jarvis_replay.sh
# cc-jarvis 가 가장 최근에 만든 요약 파일을 conf 의 음성·속도로 다시 재생.
# /jarvis-replay 슬래시 명령에서 호출.

set -u
set -o pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "macOS 전용입니다." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/session_summary.conf" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/session_summary.conf"
fi
VOICE="${VOICE:-Yuna}"
RATE="${RATE:-}"

LOG_DIR="${HOME}/Library/Logs/cc-jarvis"
LATEST=$(ls -t "$LOG_DIR"/summary_*.txt 2>/dev/null | head -1)

if [ -z "$LATEST" ] || [ ! -f "$LATEST" ]; then
    echo "재생할 요약이 없습니다."
    echo "cc-jarvis 가 한 번 이상 응답을 요약해야 ${LOG_DIR}/ 아래에 파일이 생깁니다."
    exit 0
fi

echo "[jarvis-replay] 재생: $LATEST"
echo "[jarvis-replay] voice: ${VOICE}${RATE:+, rate: $RATE}"
echo
cat "$LATEST"
echo

SAY_ARGS=(-v "$VOICE")
if [ -n "$RATE" ]; then
    SAY_ARGS+=(-r "$RATE")
fi
say "${SAY_ARGS[@]}" -f "$LATEST" &

exit 0
