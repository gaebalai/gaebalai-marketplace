#!/usr/bin/env bash
# raspi-can-bootstrap — Pi 4/5/Zero 2W에 OBD2/CAN 진단 환경 + Claude Code 설치
set -euo pipefail

ADAPTER="auto"
BITRATE="500000"
CAN_DEV="/dev/serial/by-id/usb-CANable*"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --adapter)  ADAPTER="$2"; shift 2;;
    --bitrate)  BITRATE="$2"; shift 2;;
    --can-dev)  CAN_DEV="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

log() { printf '\033[36m[bootstrap]\033[0m %s\n' "$*"; }
need_sudo() { [[ $EUID -ne 0 ]] && SUDO=sudo || SUDO=; }
need_sudo

# ---------- 1. 시스템 패키지 ----------
log "apt update + 기본 패키지 설치"
$SUDO apt-get update -y
$SUDO apt-get install -y \
    git curl ca-certificates build-essential \
    python3 python3-venv python3-pip python3-dev \
    can-utils libnss3-tools \
    iproute2

# ---------- 2. Node.js 18 LTS ----------
if ! command -v node >/dev/null || [[ "$(node -v 2>/dev/null | cut -c2-3)" -lt 18 ]]; then
  log "Node.js 18 LTS 설치 (NodeSource)"
  curl -fsSL https://deb.nodesource.com/setup_18.x | $SUDO -E bash -
  $SUDO apt-get install -y nodejs
fi
log "node $(node -v)  /  npm $(npm -v)"

# ---------- 3. Claude Code ----------
if ! command -v claude >/dev/null; then
  log "Claude Code 설치 (전역 npm)"
  $SUDO npm install -g @anthropic-ai/claude-code
fi
log "claude $(claude --version 2>/dev/null || echo '미확인')"

# ---------- 4. 스왑 확장 (RAM<2GB) ----------
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [[ "$RAM_MB" -lt 2048 ]]; then
  log "RAM ${RAM_MB}MB → zram 1GB 추가"
  $SUDO apt-get install -y zram-tools
  echo -e "ALGO=zstd\nPERCENT=100\nSIZE=1024" | $SUDO tee /etc/default/zramswap >/dev/null
  $SUDO systemctl enable --now zramswap.service || true
fi

# ---------- 5. CAN 커널 모듈 ----------
log "can/slcan 커널 모듈 자동 로드 등록"
echo -e "can\ncan_raw\nslcan\nvcan" | $SUDO tee /etc/modules-load.d/can.conf >/dev/null
$SUDO modprobe can || true
$SUDO modprobe can_raw || true
$SUDO modprobe slcan || true

# ---------- 6. udev 규칙 (CANable 안정 경로) ----------
log "CANable udev 규칙 작성 → /dev/canable"
$SUDO tee /etc/udev/rules.d/60-canable.rules >/dev/null <<'EOF'
SUBSYSTEM=="tty", ATTRS{idVendor}=="ad50", ATTRS{idProduct}=="60c4", SYMLINK+="canable"
SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", SYMLINK+="canable"
EOF
$SUDO udevadm control --reload && $SUDO udevadm trigger || true

# ---------- 7. slcan 자동 부착 서비스 ----------
log "slcan-attach.service 등록 (bitrate=$BITRATE)"
$SUDO tee /etc/systemd/system/slcan-attach.service >/dev/null <<EOF
[Unit]
Description=Attach USB CANable as can0
After=local-fs.target
Wants=local-fs.target
ConditionPathExists=/dev/canable

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/slcand -o -c -s$(case "$BITRATE" in 1000000) echo 8;; 800000) echo 7;; 500000) echo 6;; 250000) echo 5;; 125000) echo 4;; *) echo 6;; esac) -S$BITRATE /dev/canable can0
ExecStart=/sbin/ip link set up can0
ExecStop=/sbin/ip link set down can0
ExecStopPost=/usr/bin/pkill -f "slcand .* can0" || true

[Install]
WantedBy=multi-user.target
EOF
$SUDO systemctl daemon-reload
$SUDO systemctl enable slcan-attach.service || true

# ---------- 8. Python venv + 진단 라이브러리 ----------
VENV="$HOME/.venvs/cancar"
if [[ ! -d "$VENV" ]]; then
  log "Python venv 생성 → $VENV"
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install python-can cantools aiohttp numpy pandas matplotlib

# ---------- 9. 검증 ----------
log "검증 — can0 인터페이스 상태"
ip -s link show can0 || log "can0 미생성 — 차량/어댑터 연결 후 'sudo systemctl start slcan-attach.service'"

cat <<'TIP'

====================================================
다음 단계
1) USB-CAN 어댑터를 OBD2 케이블에 연결 → Pi USB 포트
2) 차량 시동 ON
3) 첫 번째 통신 확인:
     candump can0 -n 50
4) 드라이브 로그 수집 (반나절 분량):
     candump -L can0 > drive.log
5) 로그를 PC로 가져와서 'can-signal-hunter' 스킬로 분석
6) 매핑 결과를 'car-noise-pwa-builder' 스킬에 넣어 PWA 생성
====================================================
TIP
