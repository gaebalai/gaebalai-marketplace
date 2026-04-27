---
name: raspi-can-bootstrap
description: 라즈베리파이 4(Raspberry Pi OS Bookworm)에 OBD2/CAN 진단 환경을 한 번에 깔아주는 스킬. Node.js 18 LTS, Claude Code, python-can, socketcan, USB-CAN 어댑터(slcan/canable) udev 규칙, aiohttp 의존성, 스왑 확장(4GB 미만 모델용)까지 부트스트랩 스크립트로 자동화한다. 사용자가 "라즈베리파이에 Claude Code 깔아줘", "Pi에 CAN 환경 세팅", "OBD2 raspi 부트스트랩", "raspi-can-bootstrap" 같은 요청을 할 때 호출한다.
---

# raspi-can-bootstrap

새 라즈베리파이 4 / 5 / Zero 2W에 차량 진단 PWA를 돌리는 데 필요한 모든 것을 설치한다.

## 전제

- Raspberry Pi OS (Bookworm 이상, 64-bit 권장)
- 인터넷 연결
- USB-CAN 어댑터(예: CANable, Lawicel, USB2CAN 호환) 또는 MCP2515 SPI 모듈

## 사용법

사용자에게 다음을 묻는다:

1. Pi에 SSH 접속할 수 있는가? → 가능하면 SSH로 직접 실행, 아니면 스크립트만 전달
2. CAN 어댑터 종류 — `slcan`(serial CAN, USB 시리얼) / `socketcan`(MCP2515) / `auto`
3. CAN 비트레이트 — 기본 `500000` (대부분 승용차)

스크립트를 실행하려면:

```bash
# 로컬(Pi)에서
bash scripts/bootstrap.sh                    # 기본 비트레이트 500kbps
bash scripts/bootstrap.sh --bitrate 250000   # CAN-C(250kbps) 차량
```

> **현재 v0.1은 USB-CAN(slcan) 어댑터만 자동 셋업합니다.** MCP2515 SPI 모듈을 쓰는 경우 SPI overlay 활성화와 `dtoverlay=mcp2515-can0` 설정이 추가로 필요합니다(스크립트가 처리하지 않음).

## 무엇을 설치하는가

| 영역 | 내용 |
|---|---|
| 시스템 패키지 | `git`, `build-essential`, `python3-venv`, `python3-pip`, `can-utils`, `libnss3-tools`, `mkcert`(소스 빌드) |
| Node.js | NodeSource를 통한 LTS 18.x — Claude Code 요구사항 |
| Claude Code | `npm i -g @anthropic-ai/claude-code` |
| Python | venv + `python-can`, `cantools`, `aiohttp`, `numpy`, `pandas`, `matplotlib` |
| 커널 모듈 | `can`, `can-raw`, `slcan` 자동 로드 (`/etc/modules-load.d/can.conf`) |
| 시스템 서비스 | `slcan-attach.service` — 부팅 시 USB-CAN 자동 연결 (`can0`) |
| udev 규칙 | CANable/Lawicel를 `/dev/canable`로 안정 매핑 |
| 스왑 | RAM 2GB 미만이면 자동으로 zram 1GB 추가 |

## 설치 후 검증

스크립트 마지막에 자동으로:

```bash
ip -s link show can0    # can0 인터페이스 표시 확인
cansend can0 7DF#02010D # OBD2 PID 0x0D(차속) 요청 (시동 켜진 차량 연결 시)
candump can0 -n 50      # 50프레임 들어오는지 확인
node --version          # v18.x
claude --version        # Claude Code 버전
```

## 차량 연결 가이드

스크립트는 SW 환경만 만든다. 하드웨어 연결은 사람이:

1. OBD2 케이블 (DB9 ↔ OBD2) → USB-CAN 어댑터 → Pi USB 포트
2. 차량 시동 ON (엔진 ON 권장 — ACC만으로는 일부 ECU가 잠자고 있음)
3. `cansend`/`candump`로 통신 확인
4. `candump -L can0 > drive.log` 로 드라이빙 로그 수집 → `can-signal-hunter` 스킬에 전달

## 실패할 수 있는 지점과 대응

| 증상 | 원인 | 대응 |
|---|---|---|
| `can0` 안 뜸 | 어댑터 미인식 | `dmesg | tail`, `lsusb` 확인 |
| 비트레이트 불일치 | 차량 CAN-C(125kbps)/CAN-FD | `--bitrate` 변경 후 재실행 |
| `getUserMedia` 실패 | HTTPS 미사용 | `car-noise-pwa-builder`의 mkcert 가이드 참조 |
| Claude Code 설치 OOM | 1GB 모델 | 스왑 확장 (스크립트가 자동 처리) |

## 보안/안전 주의

- 차량과 연결된 Pi에 외부 인터넷 노출 금지 (LAN 또는 핫스팟만)
- ECU 쓰기 명령(diagnostic write, UDS write) 금지 — 본 스킬은 읽기 전용 환경만 구성
- Pi에서 차량 전원 직결 시 점화 OFF에서도 배터리 방전 가능 → ACC 라인 또는 별도 스위치 권장

## 참고 스크립트

- `scripts/bootstrap.sh` — 메인 부트스트랩
