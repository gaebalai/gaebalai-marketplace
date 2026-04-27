---
name: car-noise-pwa-builder
description: 자동차 이상 소음 진단용 PWA를 자동으로 스캐폴딩한다. 마이크 입력 FFT 스펙트로그램 + 라즈베리파이로부터 WebSocket으로 받은 CAN 데이터(RPM·속도·조향각·기어) 동시 시각화 + 녹음 정지 시 WAV+CSV ZIP 저장 + Service Worker 오프라인 동작까지 한 번에 만든다. 사용자가 "차량 진단 PWA 만들어줘", "OBD2 시각화 앱", "FFT 스펙트로그램 PWA", "마이크 + CAN 동시 기록 앱", "car-noise-pwa-builder" 같은 요청을 할 때 호출한다.
---

# car-noise-pwa-builder

원문 글의 PWA 구조를 그대로 재현하는 풀 스택 스캐폴드. 스마트폰 브라우저 ↔ 라즈베리파이 4 ↔ OBD2 USB-CAN 흐름을 가정한다.

## 산출 구조

```
<project_name>/
├── pwa/
│   ├── index.html
│   ├── app.js              # 마이크 FFT + WebSocket + IndexedDB + ZIP
│   ├── sw.js               # Service Worker
│   ├── manifest.webmanifest
│   └── icon-192.png        # 자리표시자
├── pi/
│   ├── server.py           # aiohttp HTTPS + WebSocket + python-can 디코더
│   ├── requirements.txt
│   └── certs/
│       └── README.md       # mkcert 가이드
└── README.md
```

## 워크플로우

### STEP 1. 사용자 입력 수집

- `project_name` (예: `my-car-diag`)
- `pi_host` (Wi-Fi 상에서 접근 가능한 라즈베리파이 IP, 예: `192.168.1.42`)
- 신호 매핑 JSON (`can-signal-hunter` 결과물 또는 사용자 직접 입력)
  ```json
  {
    "rpm":      {"id": "0x202", "byte": 0, "width": 16, "endian": "big",        "scale": 0.25, "offset": 0},
    "speed":    {"id": "0x202", "byte": 2, "width": 16, "endian": "big",        "scale": 0.01, "offset": 0},
    "steering": {"id": "0x082", "byte": 0, "width": 16, "endian": "big_signed", "scale": 0.1,  "offset": 0},
    "gear":     {"id": "0x228", "byte": 0, "width": 8,  "endian": "uint",       "scale": 1,    "offset": 0}
  }
  ```

### STEP 2. 템플릿 복사

`templates/` 디렉토리의 5개 파일을 사용자 프로젝트로 복사하면서 다음 토큰 치환:

| 토큰 | 치환값 |
|---|---|
| `{{PROJECT_NAME}}` | 프로젝트명 |
| `{{PI_HOST}}` | 라즈베리파이 호스트 |
| `{{SIGNAL_MAPPING_JSON}}` | 신호 매핑 JSON 문자열 |

### STEP 3. PWA 의존성 설치 안내

PWA는 정적 파일이라 빌드 도구 없음. 라즈베리파이 쪽만:

```bash
cd pi
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### STEP 4. HTTPS 인증서 생성 안내

브라우저 `getUserMedia`는 HTTPS 필수. mkcert로 로컬 CA 발급 가이드를 README에 포함.

```bash
brew install mkcert  # 또는 apt install libnss3-tools && go install
mkcert -install
mkcert {{PI_HOST}}
mv {{PI_HOST}}.pem        pi/certs/cert.pem
mv {{PI_HOST}}-key.pem    pi/certs/key.pem
```

### STEP 5. 실행

라즈베리파이:
```bash
cd pi && python server.py
```

스마트폰 브라우저에서 `https://{{PI_HOST}}:8443/` 접속 → "홈 화면에 추가"로 PWA 설치.

## 기술 스택 (글 본문과 동일)

- 마이크: `navigator.mediaDevices.getUserMedia({ audio: true })`
- FFT: `AudioContext` + `AnalyserNode` (FFT 사이즈 16384)
- 스펙트로그램: Canvas 2D 시간×주파수 히트맵
- 음성 저장: IndexedDB Blob
- 오프라인: Service Worker
- ZIP 묶기: JSZip (CDN)
- CAN 수신: WebSocket (`wss://{{PI_HOST}}:8443/ws`)

## 보안 주의

- mkcert로 만든 인증서는 **로컬 개발용**. 차량 안에서 자기 폰만 쓰는 시나리오 한정
- Pi 서버는 LAN 노출만 가정 — 인터넷에 직접 노출 금지
- WebSocket 메시지는 읽기 전용. ECU 쓰기는 절대 구현하지 말 것

## 참고 템플릿 (templates/)

- `index.html` — 단일 페이지 UI
- `app.js` — 모든 클라이언트 로직
- `sw.js` — Service Worker 캐시 전략
- `manifest.webmanifest` — PWA 매니페스트
- `pi_server.py` — aiohttp + python-can 서버
