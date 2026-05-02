#!/bin/bash
# install.sh
# cc-jarvis/hooks/ 의 원본 파일을 ~/.claude/hooks/ 로 배치하고
# ~/.claude/settings.json 에 Stop hook 등록 여부를 안내한다.

set -eu

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="$HOME/.claude/hooks"

mkdir -p "$DEST_DIR"

cp "$SRC_DIR/session_summary.sh" "$DEST_DIR/session_summary.sh"
cp "$SRC_DIR/session_summary_prompt.txt" "$DEST_DIR/session_summary_prompt.txt"

# conf 는 사용자가 ENABLED 토글 후 덮어쓰지 않도록, 없을 때만 복사
if [ ! -f "$DEST_DIR/session_summary.conf" ]; then
    cp "$SRC_DIR/session_summary.conf" "$DEST_DIR/session_summary.conf"
fi

chmod +x "$DEST_DIR/session_summary.sh"

echo "[install] 파일 배치 완료: $DEST_DIR"
echo
echo "[install] settings.json 에 다음 hooks 블록이 있어야 합니다."
echo "         (이미 등록되어 있으면 건너뛰세요)"
cat <<'JSON'
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/session_summary.sh", "timeout": 60 }
        ]
      }
    ]
  }
JSON
