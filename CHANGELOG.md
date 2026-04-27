# Changelog

이 프로젝트의 모든 주목할 만한 변경 사항은 이 파일에 기록됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)을 따르며,
버전 관리는 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [Unreleased]

### Planned
- 자기 적용(dogfooding) 결과 `examples/self-eval-iter-1.md` 추가
- 기존 `gaebalai/cc-roundtable` 리포의 `.claude-plugin/marketplace.json` 정리 (마켓플레이스 통합 안내)
- cc-meeting-highlight 실사용 회의 1건으로 dogfooding (mlx-whisper 모델 변형, 자막 길이 가이드 검증)
- car-can-checker 실차량 1건으로 dogfooding (CAN 신호 후보 정확도, PWA 마이크 ZIP 워크플로우, 이상음 휴리스틱 검증)
- car-noise-report v0.2: 5종 휴리스틱 분류 (회전성/노면성/공진/충격/조향계통), RPM-주파수·속도-주파수 상관 산출, 의심 구간 확대 PNG

## [0.4.1] - 2026-04-27

내부 코드 리뷰로 발견된 SKILL.md 약속과 실제 코드의 미스매치를 동기화. 보안 약속을 코드 레벨에서 강화.

### Added
- **`can-signal-hunter`**: cantools 기반 `guess.dbc` 자동 생성 — RPM/SPEED/STEERING/GEAR 카테고리별 top-score 후보를 빅엔디안 DBC Signal로 변환 ([hunt_can_signals.py:write_dbc](plugins/car-can-checker/skills/can-signal-hunter/scripts/hunt_can_signals.py))
- **`car-noise-pwa-builder`**: [`templates/certs/README.md`](plugins/car-can-checker/skills/car-noise-pwa-builder/templates/certs/README.md) — mkcert 발급 가이드 (Pi 빌드, 로컬 CA, 스마트폰 신뢰, 보안 주의)
- **`raspi-can-bootstrap`**: bootstrap.sh에 mkcert Go 소스 빌드 추가 (`golang-go` apt 설치 + `go install filippo.io/mkcert@latest`)

### Changed
- **`pi_server.py` 보안 강화**:
  - 기본 바인딩 `0.0.0.0` → `PI_HOST` (LAN IP) — `HOST` 환경변수로 덮어쓰기 가능
  - WebSocket Origin 화이트리스트 (기본 `https://{PI_HOST}:8443`) — `ALLOWED_ORIGIN` 환경변수
  - SSL 컨텍스트 `Purpose.CLIENT_AUTH` → `PROTOCOL_TLS_SERVER` (의도 명확화)
  - 인증서 누락 시 명시적 SystemExit + mkcert 가이드 안내
  - `asyncio.get_event_loop()` deprecation 제거, `can.Notifier(loop=)` 인자 제거
- **`car-noise-report` SKILL.md**: 5종 휴리스틱 분류 약속을 v0.2 계획으로 이동, 현재 v0.1은 "RMS 상위 1% spike 탐지 + 메타데이터 표"로 정직하게 표기. `candidate_<n>.png` / `correlations.csv` 출력 명세 삭제 (v0.2 예정)
- **`car-noise-pwa-builder` SKILL.md**:
  - 산출 구조에서 `pi/server.py` → `pi_server.py`로 정정 (실제 파일명과 일치)
  - `icon-192.png` 자리표시자 항목 삭제 — 사용자가 별도 추가하도록 안내
  - STEP 5 실행 예시에 `HOST` / `PORT` / `ALLOWED_ORIGIN` 환경변수 사용법 추가
- **`raspi-can-bootstrap` SKILL.md**: 미사용 `--adapter` / `--can-dev` 인자 삭제, MCP2515 SPI 모듈은 별도 처리 필요함을 명시
- **`bootstrap.sh`**: 무시되던 `ADAPTER` / `CAN_DEV` 변수 + 옵션 제거. `--bitrate`만 유지
- **플러그인 README**: "신뢰도 95% 미만 자동 반영 안 함" 문구 삭제 — 실제 구현은 분산 임계값 기반이고 95% 게이트는 코드에 없음. "사람 검증 후 채택" 약속으로 정정
- **`manifest.webmanifest`**: 존재하지 않는 `icon-192.png` 참조 삭제

### Fixed
- 정적 검증 (`bash -n`, `py_compile`, `jq empty`) 모두 통과
- 토큰 치환 후 pi_server.py 컴파일 통과

## [0.4.0] - 2026-04-27

### Added
- 플러그인 추가: **`car-can-checker`** (자동차 OBD2/CAN 진단 풀스택, 카테고리: `automotive`)
  - 에이전트 [`car-can-orchestrator`](plugins/car-can-checker/agents/car-can-orchestrator.md) — STEP A~D 풀 파이프라인 자동 분기
  - 스킬 [`raspi-can-bootstrap`](plugins/car-can-checker/skills/raspi-can-bootstrap/SKILL.md) — Pi 4/5/Zero 2W에 Node 18 + Claude Code + python-can + USB-CAN udev 규칙 부트스트랩
  - 스킬 [`can-signal-hunter`](plugins/car-can-checker/skills/can-signal-hunter/SKILL.md) — `.asc/.log/.blf/.csv` CAN 로그에서 RPM/차속/조향각/기어 자동 추정 + 4단 검증 패널 PNG + DBC 초안
  - 스킬 [`car-noise-pwa-builder`](plugins/car-can-checker/skills/car-noise-pwa-builder/SKILL.md) — 마이크 FFT + CAN WebSocket PWA 자동 스캐폴딩 (HTTPS, IndexedDB, Service Worker, JSZip)
  - 스킬 [`car-noise-report`](plugins/car-can-checker/skills/car-noise-report/SKILL.md) — PWA의 녹음 ZIP을 받아 RMS 급증·RPM 공진 피크·노면 무관 노이즈 분리 리포트(MD + PNG)
  - 플러그인 매니페스트 [plugin.json](plugins/car-can-checker/.claude-plugin/plugin.json), 플러그인 README
- 보안 설계: ECU 쓰기 명령 미구현/차단, 차량 연결 Pi의 인터넷 노출 금지, mkcert·sudo·신호 매핑 확정에 사용자 승인 필수, 신뢰도 95% 미만 신호 PWA 자동 반영 차단

### Changed
- 마켓플레이스 버전 0.3.0 → **0.4.0**
- 수록 플러그인 3개 → **4개**
- 마켓플레이스 카테고리에 `automotive` 신설 (기존 `productivity` 외)

## [0.3.0] - 2026-04-27

### Added
- 플러그인 추가: **`cc-meeting-highlight`** (회의 녹화 → 60초 하이라이트 자동 생성, macOS Apple Silicon 전용)
  - 슬래시 명령어 [`/meeting-highlight`](plugins/cc-meeting-highlight/commands/meeting-highlight.md) — 7-Phase 파이프라인 오케스트레이터
  - 스킬 [`topics-extractor`](plugins/cc-meeting-highlight/skills/topics-extractor/SKILL.md) — Phase 3 (transcript+요약 → topics.json)
  - 스킬 [`highlights-selector`](plugins/cc-meeting-highlight/skills/highlights-selector/SKILL.md) — Phase 4 (topics → 60초 highlights.json)
  - 자산 [assets/scripts/](plugins/cc-meeting-highlight/assets/scripts/) — Phase 0·1·2·5 스크립트 (00 symlink, 10 ffmpeg 음성 추출, 20 mlx-whisper 받아쓰기, 50 클립 잘라내기) + bootstrap.sh
  - 자산 [assets/remotion/](plugins/cc-meeting-highlight/assets/remotion/) — Remotion 4.x Highlight60 템플릿 (React 19 + TypeScript + Noto Sans KR + calculateMetadata 동적 길이)
  - 자산 [assets/schemas/](plugins/cc-meeting-highlight/assets/schemas/) — topics / highlights JSON Schema
  - 카테고리: `productivity`, 버전 0.1.0
  - 한국어 회의 환경 기본 설정: `language="ko"` 명시, 한국 회사 용어 INITIAL_PROMPT, NFD/NFC 흡수 symlink, Noto Sans KR + `wordBreak: keep-all`, 자막 한국어 길이 가이드(caption 18자, subCaption 35자)

### Changed
- 마켓플레이스 버전 0.2.0 → **0.3.0**
- 수록 플러그인 2개 → **3개**

## [0.2.0] - 2026-04-26

### Added
- 플러그인 추가: **`cc-roundtable`** (다분야 전문가 토론 스킬)
  - [plugins/cc-roundtable/skills/start/](plugins/cc-roundtable/skills/start/) — SKILL 본체 + references 3개
  - 카테고리: `productivity`, 버전 1.0.0
- 마켓플레이스 매니페스트 형식 정렬 (cc-roundtable 매니페스트와 통일)
  - top-level `$schema`, `version`, `description` 추가
  - `owner.url` 추가, 이메일을 `jaewoo@mdrules.dev`로 통일
  - `plugins[].category`, `plugins[].tags` 추가
- 마켓플레이스 자산 [assets/logo.png](assets/logo.png) 포함

### Changed
- `gaebalai/cc-roundtable` 리포에서 운영하던 마켓플레이스를 본 리포로 이전
  - 사용자가 이미 등록한 마켓플레이스가 있다면 `/plugin marketplace remove gaebalai-marketplace` → `/plugin marketplace add gaebalai/gaebalai-marketplace`로 재등록
- README 수록 플러그인 표를 2개로 확장, 트리거 예시 추가
- `plugins/empirical-prompt-tuning/.claude-plugin/plugin.json` 형식을 cc-roundtable plugin.json과 정렬
  - `author.url`, `license: MIT`, `skills: "./skills/"` 추가

### Migration (기존 사용자용)
사용자가 `gaebalai/cc-roundtable`로 마켓플레이스를 등록 중이면 다음으로 마이그레이션 권장.

```
/plugin marketplace remove gaebalai-marketplace
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-roundtable@gaebalai-marketplace
/plugin install empirical-prompt-tuning@gaebalai-marketplace
```

## [0.1.0] - 2026-04-26

### Added
- `empirical-prompt-tuning` 스킬 본체 ([SKILL.md](plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning/SKILL.md))
  - 6가지 핵심 원칙 (글쓴이/판정자 분리, 시나리오 사전 고정, 매번 신규 dispatch, 양면 측정, 1회 1테마 수정, hold-out 시나리오)
  - 8단계 워크플로우 (대상 식별 → 시나리오 설계 → 요건 체크리스트 → 실행 → 보고 수집 → 1테마 수정 → 재실행 → 종료 판정)
  - 환경별 분기 (Claude Code Task tool / Claude.ai 단일 세션)
- references/
  - `claude-code-flow.md` — Task tool 기반 병렬 dispatch 절차
  - `claude-ai-flow.md` — 단일 세션 직렬 폴백 절차 (전략 A/B/C)
  - `scenario-design.md` — median/edge/hold-out 시나리오 작성 가이드
  - `scoring-rubric.md` — 20점 평가 루브릭 (skill / 일반 프롬프트 / 기술 문서 변형)
- assets/
  - `dispatch-prompt-template.md` — dispatch 프롬프트 본체 템플릿
  - `report-structure.md` — 서브에이전트 보고 구조 강제 템플릿
  - `iteration-log-template.md` — 반복 추이 기록표 템플릿
- 마켓플레이스 매니페스트 ([.claude-plugin/marketplace.json](.claude-plugin/marketplace.json))
  - `name: gaebalai-marketplace`
- 플러그인 매니페스트 ([plugins/empirical-prompt-tuning/.claude-plugin/plugin.json](plugins/empirical-prompt-tuning/.claude-plugin/plugin.json))
- 로컬 설치 스크립트 [install.sh](install.sh) (심볼릭 링크 / 복사 / 제거 모드)
- 정량 메트릭 임곗값 가이드 (정확도 50/80/90, tool_uses 1~3/4~10/15+)
- 종료 판정 기준 (수렴 / 발산 / 종료)

### Notes
- 이 버전은 Claude Code 플러그인 시스템에서의 첫 공개 릴리스입니다 (early access)
- 마켓플레이스 매니페스트 형식은 실제 사용 검증 초기 단계이므로,
  추후 호환성 패치가 필요할 수 있습니다 (0.1.x 시리즈에서 흡수 예정)
- 안정화 후 `1.0.0`으로 메이저 승격 예정

[Unreleased]: https://github.com/gaebalai/gaebalai-marketplace/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.4.1
[0.4.0]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.4.0
[0.3.0]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.3.0
[0.2.0]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.2.0
[0.1.0]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.1.0
