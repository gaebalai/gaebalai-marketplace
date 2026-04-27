---
name: car-noise-report
description: PWA가 내보낸 ZIP(audio.webm/wav + can.csv + metadata.json)을 입력받아 이상음 후보 구간을 자동 탐지하고 RPM·속도와의 상관관계를 분석한 리포트(MD + PNG 패널)를 생성한다. 음향 에너지 급증 구간, 특정 RPM에서만 나타나는 피크 주파수, 노면/속도와 무관한 정상 회전성 노이즈 분리 등을 다룬다. 사용자가 "이상음 분석해줘", "녹음 ZIP 분석", "주행 노이즈 리포트", "특정 RPM에서 나는 소리 찾아줘", "car-noise-report" 같은 요청에서 호출한다.
---

# car-noise-report

`car-noise-pwa-builder`로 만든 PWA의 ZIP을 받아, 사람이 정비소에 들고 갈 수 있는 한 페이지 리포트를 만든다.

## 입력

ZIP 또는 풀어둔 디렉토리 하나당 take 한 개:

```
take_001_<ts>/
├── audio.webm  (또는 audio.wav)
├── can.csv     # t,rpm,speed,steering,gear
└── metadata.json
```

여러 take는 일괄 처리.

## 의존성

```bash
pip install numpy scipy pandas matplotlib soundfile librosa
# audio.webm → wav 변환에 ffmpeg 필요
sudo apt install ffmpeg   # 또는 brew install ffmpeg
```

## 분석 파이프라인

### STEP 1. 오디오 → wav 변환 + 동기화

`webm` → `wav` (16kHz 모노) 변환:
```bash
ffmpeg -i audio.webm -ac 1 -ar 16000 audio.wav
```

오디오 시작 시각과 CAN 첫 프레임 시각이 다를 수 있음 → `metadata.json`의 `ts`를 기준으로 정렬. CAN의 `t`는 epoch 초.

### STEP 2. 음향 특성 추출

- **RMS 에너지** (10ms 프레임) — 급증 구간이 이상음 후보
- **STFT 스펙트로그램** — 0~500Hz 강조 (차량 저음 구간)
- **주파수 피크 추적** — 시간별 dominant frequency
- **하모닉 추적** — 엔진 회전 차수(2nd/4th order)와 일치 여부

### STEP 3. CAN 신호와 동기화

오디오 프레임마다 가장 가까운 시각의 RPM/속도/기어를 매핑한다 (`np.searchsorted`).

### STEP 4. 이상음 후보 탐지 (현재 v0.1 구현)

현재 버전은 **단순 spike 탐지** 수준입니다. RMS 에너지 상위 1% 시점을 추출해 그 시점의 RPM/속도/기어/dominant 주파수를 메타데이터로 표기합니다. 사람이 표를 보고 다음 패턴을 직접 판정해야 합니다.

| 패턴 | 의미 |
|---|---|
| RPM↑에 따라 피크주파수 비례 증가 | 엔진 회전성(차수성) — 정상 가능성 |
| 속도↑에 따라 피크주파수 비례 증가 | 노면/타이어성 |
| 특정 RPM 대역에서만 피크 | 공진 / 부품 결함 의심 |
| RMS 급증 + RPM 무관 | 충격 / 접촉음 의심 |
| 조향각 변화 시 발생 | 서스펜션 / 조향 계통 의심 |

> **v0.2 계획**: 위 5종 패턴의 자동 분류, RPM-주파수 / 속도-주파수 상관계수 산출, 의심 구간 확대 PNG. 도메인 전문가의 실차 검증 데이터가 누적되면 휴리스틱을 코드화 예정.

### STEP 5. 리포트 출력

```
report_<ts>/
├── INDEX.md                # 여러 take 일괄 처리 시 종합 인덱스
└── <take_name>/
    ├── report.md           # take별 의심 구간 표 (시각/peak Hz/RPM/속도/기어)
    └── overview.png        # 4단 패널 (스펙트로그램 0~500Hz / RPM / 속도 / RMS)
```

## 리포트 예시 구조

```markdown
# 차량 이상음 분석 리포트
- 분석 take: 3건, 총 주행 시간 12분 47초
- 의심 구간: 5건

## 의심 구간 #1 — 17:18:04 ~ 17:18:07
- 패턴: 1650 rpm 부근에서만 94Hz 피크 발생
- 주행상황: 2단, 28 km/h, 직진
- 가능성: 엔진 마운트 공진 / 보조벨트 텐셔너 (후보)
- 권장 점검: 엔진 마운트 상태, 풀리·벨트
![candidate_1](candidate_1.png)
```

## 한계와 주의

- 노이즈 캔슬링 마이크는 100Hz 이하 저음을 깎아냄 — 본문 글의 한계와 동일
- 고체 전도음(서스펜션 부싱 등)은 공기음 마이크로 거의 못 잡음 → **컨택트 마이크** 권장
- 결과는 **점검 후보 가이드**일 뿐, 진단 확정 도구가 아님

## 참고 스크립트

- `scripts/noise_report.py` — 메인 분석기
