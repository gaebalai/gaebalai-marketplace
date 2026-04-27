# car-can-checker

> 자동차 OBD2/CAN 진단 풀스택 파이프라인. 라즈베리파이 부트스트랩 → CAN 신호 역엔지니어링 → 마이크 FFT + CAN 동시 기록 PWA → 이상음 후보 자동 리포트까지.

차량 진단 환경을 처음부터 끝까지 자동화하는 4개 스킬과 이를 묶어주는 1개 오케스트레이터 에이전트로 구성됩니다. **읽기 전용** 파이프라인입니다 — ECU 쓰기는 설계상 차단합니다.

---

## 무엇이 들어 있나

### 에이전트
- [`car-can-orchestrator`](agents/car-can-orchestrator.md) — 4개 스킬을 사용자 입력에 맞춰 적절한 순서(STEP A~D)로 호출하는 풀 파이프라인 오케스트레이터. TodoWrite로 단계 진행 추적.

### 스킬

| 스킬 | 단계 | 역할 |
|---|---|---|
| [`raspi-can-bootstrap`](skills/raspi-can-bootstrap/SKILL.md) | STEP A | 라즈베리파이 4/5/Zero 2W에 Node 18 + Claude Code + python-can + socketcan + USB-CAN udev 규칙까지 한 번에 설치 |
| [`can-signal-hunter`](skills/can-signal-hunter/SKILL.md) | STEP B | `.asc/.log/.blf/.csv` CAN 로그에서 RPM·차속·조향각·기어 신호의 ID/바이트 위치/스케일 자동 추정, 검증 그래프 PNG, DBC 초안 생성 |
| [`car-noise-pwa-builder`](skills/car-noise-pwa-builder/SKILL.md) | STEP C | 마이크 FFT 스펙트로그램 + WebSocket CAN 데이터 동시 시각화 + WAV/CSV ZIP 저장 + Service Worker 오프라인 동작 PWA 자동 스캐폴딩 |
| [`car-noise-report`](skills/car-noise-report/SKILL.md) | STEP D | PWA가 만든 ZIP을 받아 RMS 에너지 급증, 특정 RPM 공진 피크, 노면/속도 무관 노이즈 분리 등 이상음 후보 탐지 리포트 (MD + PNG) |

---

## 빠른 시작

```
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install car-can-checker@gaebalai-marketplace
```

설치 후 자연어 트리거.

```
# 풀 파이프라인 (오케스트레이터)
차 한번 굴리고 받은 데이터 분석해줘
ZIP에 있는 녹음과 CAN 같이 분석해줘
CAN 로그부터 PWA까지 한번에 처리해줘

# 단계별 호출
라즈베리파이에 CAN 환경 세팅해줘    → raspi-can-bootstrap
이 candump 로그에서 RPM ID 찾아줘  → can-signal-hunter
차량 진단 PWA 만들어줘             → car-noise-pwa-builder
이 녹음 ZIP에서 이상음 분석해줘     → car-noise-report
```

---

## 전형적인 흐름 (STEP A→D)

```
새 라즈베리파이                    1. raspi-can-bootstrap
        ↓
candump CAN 로그 수집              2. can-signal-hunter
        ↓
RPM/속도/조향각/기어 신호 매핑 확정
        ↓
PWA 스캐폴딩 + mkcert HTTPS         3. car-noise-pwa-builder
        ↓
스마트폰에서 PWA 설치, 차에 장착
        ↓
주행하며 마이크 + CAN 동시 기록 → ZIP
        ↓
이상음 자동 분석 리포트            4. car-noise-report
```

오케스트레이터 에이전트가 사용자 입력에서 어느 STEP부터 시작할지 자동 판단합니다 (사용자가 가진 자산이 무엇인지로 분기).

---

## 사전 요건

| 영역 | 요건 |
|---|---|
| 호스트 OS | macOS / Linux (Claude Code 클라이언트) |
| 라즈베리파이 | Pi 4/5/Zero 2W, Raspberry Pi OS Bookworm 64-bit |
| 하드웨어 | OBD2 케이블 + USB-CAN 어댑터 (CANable / Lawicel / USB2CAN) 또는 MCP2515 SPI |
| Python | 3.10+ (Pi와 분석 호스트 양쪽) |
| 추가 도구 | `ffmpeg` (오디오 변환), `mkcert` (HTTPS 로컬 CA) |

---

## 보안 / 안전 원칙

이 플러그인은 다음을 **설계상 보장**합니다.

- **읽기 전용** — ECU 쓰기 명령(UDS write, diagnostic write) 미구현 / 차단
- **LAN 한정** — 차량 연결 Pi를 인터넷에 직접 노출 금지
- **사용자 확인 필수** — mkcert 로컬 CA 신뢰, 패키지 sudo 설치, CAN 신호 매핑 확정은 자동화하지 않음
- **신뢰도 95% 미만 신호는 PWA에 자동 반영 안 함** — 사람 검증 후 채택

리포트 결과는 **점검 후보 가이드**일 뿐 진단 확정 도구가 아닙니다. 차량 매뉴얼·실차 검증 없이 ECU 쓰기 명령에 절대 사용 금지.

---

## 결과물 구조

```
./car-can-out/
├── 01_bootstrap/         # STEP A 로그
├── 02_signals/
│   └── can_analysis_<ts>/
│       ├── summary.md
│       ├── signals.png    # RPM/속도/조향각/기어 4단 검증 패널
│       ├── guess.dbc      # cantools DBC 초안
│       └── id_stats.csv
├── 03_pwa/               # 생성된 PWA 프로젝트
│   ├── pwa/              # 정적 PWA (index.html, app.js, sw.js, manifest)
│   └── pi/               # aiohttp HTTPS + WebSocket + python-can 서버
├── 04_reports/
│   └── report_<ts>/
│       ├── report.md
│       ├── overview.png
│       ├── candidate_*.png
│       └── correlations.csv
└── combined_report_<ts>.md
```

---

## 라이선스

MIT.
