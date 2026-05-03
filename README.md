# gaebalai-marketplace

[![Latest release](https://img.shields.io/github/v/release/gaebalai/gaebalai-marketplace?label=release)](https://github.com/gaebalai/gaebalai-marketplace/releases/latest)
[![Plugins](https://img.shields.io/badge/plugins-6-blue)](#수록-플러그인)
[![License](https://img.shields.io/github/license/gaebalai/gaebalai-marketplace)](LICENSE)
[![CI](https://github.com/gaebalai/gaebalai-marketplace/actions/workflows/static-checks.yml/badge.svg)](https://github.com/gaebalai/gaebalai-marketplace/actions/workflows/static-checks.yml)

> Claude Code 플러그인 마켓플레이스. 현재 `car-can-checker`, `cc-jarvis`, `cc-meeting-highlight`, `cc-roundtable`, `cc-security-scan`, `empirical-prompt-tuning` 여섯 플러그인을 호스팅합니다.

이 리포지터리는 Claude Code의 [플러그인 시스템](https://docs.claude.com/en/docs/claude-code/plugins)에서 곧바로 추가할 수 있는 **마켓플레이스** 형태로 구성되어 있습니다.

---

## 빠른 시작 (사용자)

Claude Code 세션에서 마켓플레이스를 한 번 추가한 뒤, 원하는 플러그인을 설치합니다.

```
# 1. 마켓플레이스 등록 (1회)
/plugin marketplace add gaebalai/gaebalai-marketplace

# 2. 플러그인 설치 (필요한 것만, 또는 전부)
/plugin install car-can-checker@gaebalai-marketplace
/plugin install cc-jarvis@gaebalai-marketplace              # macOS 전용
/plugin install cc-meeting-highlight@gaebalai-marketplace   # macOS Apple Silicon 전용
/plugin install cc-roundtable@gaebalai-marketplace
/plugin install cc-security-scan@gaebalai-marketplace
/plugin install empirical-prompt-tuning@gaebalai-marketplace
```

설치 후 자연어 또는 슬래시 명령어로 트리거됩니다.

```
# car-can-checker
차 한번 굴리고 받은 데이터 분석해줘
이 candump 로그에서 RPM ID 찾아줘
차량 진단 PWA 만들어줘

# cc-jarvis (macOS 전용 — 설치만 하면 자동 동작, 별도 트리거 없음)
# 매 응답이 끝날 때마다 데스크톱 알림 + Yuna 한국어 음성으로 작업 결과 보고

# cc-meeting-highlight (macOS 전용)
/meeting-highlight
이 회의 녹화 60초 하이라이트로 만들어줘

# cc-roundtable
이 결정을 다분야 전문가들과 토론으로 평가해줘
이 사이트를 원탁회의 형식으로 리뷰해줘

# cc-security-scan (수동 호출 전용 — disable-model-invocation)
/security-review                           # PR · 차분(git diff) 정적 분석
/full-scan                                 # 릴리스 전 전체 파일 + 의존성 CVE
/security-scan                             # 스테이징 환경 런타임·HTTP 검증

# empirical-prompt-tuning
이 SKILL.md 평가해줘 (서브에이전트 3병렬로)
~/.claude/skills/conventional-changelog/SKILL.md 다른 AI한테 돌려봐줘
```

> 로컬 개발 중인 마켓플레이스를 그대로 가리키려면 `/plugin marketplace add /Users/gaebalai/cc-workspace/gaebalai-marketplace` 처럼 절대 경로로도 추가할 수 있습니다.

---

## 수록 플러그인

| 플러그인 | 플랫폼 | 카테고리 | 설명 | 버전 | 예시 |
|---|---|---|---|---|---|
| [`car-can-checker`](plugins/car-can-checker/) | 모든 플랫폼 + Raspberry Pi | automotive | 자동차 OBD2/CAN 진단 풀스택 — Pi 부트스트랩 → 신호 역엔지니어링(+DBC 자동) → 마이크 + CAN PWA → 5종 휴리스틱 이상음 리포트 | 0.2.0 | [예시](examples/car-can-checker.md) |
| [`cc-jarvis`](plugins/cc-jarvis/) | macOS | productivity | Claude Code 응답 종료 시 직전 트랜스크립트를 Haiku 4.5로 요약 → 데스크톱 알림 + 한국어 음성(Yuna) 보고 (Stop hook) | 0.1.0 | [예시](examples/cc-jarvis.md) |
| [`cc-meeting-highlight`](plugins/cc-meeting-highlight/) | macOS Apple Silicon | productivity | 회의 녹화 mp4 → 60초 하이라이트 영상 자동 생성 (mlx-whisper × Claude × Remotion) | 0.1.1 | [예시](examples/cc-meeting-highlight.md) |
| [`cc-roundtable`](plugins/cc-roundtable/) | 모든 플랫폼 | productivity | 다분야 전문가를 동적으로 선정해 구조화된 토론으로 다각적 평가·제언을 정리 | 1.0.0 | [예시](examples/cc-roundtable.md) |
| [`cc-security-scan`](plugins/cc-security-scan/) | 모든 플랫폼 | security | 보안 슬래시 명령어 3종 — `/security-review` (PR 차분), `/full-scan` (전체 + CVE), `/security-scan` (스테이징 런타임). 출력 필터 hook + 40개 픽스처 테스트 동봉 | 1.0.0 | [예시](examples/cc-security-scan.md) |
| [`empirical-prompt-tuning`](plugins/empirical-prompt-tuning/) | 모든 플랫폼 | productivity | 자기가 쓴 프롬프트의 재현성을 별도 AI에 백지 dispatch 시켜 객관 측정·정련하는 메타-스킬 | 0.1.0 | [예시](examples/empirical-prompt-tuning.md) |

> 더 많은 트리거 예시는 [examples/](examples/README.md)를 참고.

---

## car-can-checker 요점

> 자동차 OBD2/CAN 진단을 처음부터 끝까지 자동화. **읽기 전용** 파이프라인 (ECU 쓰기 차단).

**구성**: 4개 스킬 + 1개 오케스트레이터 에이전트.

```
STEP A  raspi-can-bootstrap     → Pi에 Node 18 + Claude Code + python-can + udev 규칙 설치
STEP B  can-signal-hunter       → CAN 로그(.asc/.log/.blf/.csv)에서 RPM·차속·조향각·기어 ID/바이트 자동 추정
                                  + 4단 검증 패널 PNG + DBC 초안
STEP C  car-noise-pwa-builder   → 마이크 FFT 스펙트로그램 + WebSocket CAN 시각화 PWA 자동 스캐폴딩
                                  (HTTPS via mkcert, Service Worker, IndexedDB, JSZip)
STEP D  car-noise-report        → PWA가 만든 ZIP에서 RMS 급증·RPM 공진 피크·노면 무관 노이즈 자동 분리 리포트

car-can-orchestrator (agent)    → 사용자가 가진 자산을 보고 STEP A~D 중 어디부터 시작할지 자동 분기
```

**보안 원칙**: ECU 쓰기 명령 미구현 / 차량 연결 Pi의 인터넷 노출 금지 / mkcert·sudo·신호 매핑 확정은 사용자 승인 필수 / 신뢰도 95% 미만 신호는 PWA에 자동 반영 안 함.

자세한 실행 흐름·결과물 구조·하드웨어 가이드는 [plugins/car-can-checker/README.md](plugins/car-can-checker/README.md)를 참고.

---

## cc-jarvis 요점

> Claude Code의 응답 종료(Stop) 이벤트를 가로채, 직전 트랜스크립트 30라인을 Haiku 4.5로 요약 → macOS 데스크톱 알림 + 한국어 음성(Yuna)으로 자비스(JARVIS)처럼 보고.

**구성**: 단일 Stop hook (스킬·슬래시 명령어·에이전트 없음 — 설치만 하면 자동 동작).

```
Claude Code 응답 종료
    ↓
hooks/hooks.json → ${CLAUDE_PLUGIN_ROOT}/hooks/session_summary.sh 실행
    ↓
ENABLED 체크 → transcript_path 끝 30 라인 → Haiku 4.5로 보고용 한국어 요약
    ↓
osascript display notification + say -v Yuna "$SUMMARY" &
```

**보강 사항** — 단순 음성 출력에서 그치지 않고 다음 3가지를 적용했다.

- **재귀 차단**: hook이 부르는 자식 `claude -p`가 다시 Stop hook을 발화하지 않도록 `CLAUDE_SUMMARY_HOOK_RUNNING=1` 환경 변수 전파
- **osascript 인용 안전화**: 요약 결과 안의 `"` / `\` / `$` 를 `sed`로 escape 후 `display notification` 호출
- **한국어 음성 명시**: 시스템 기본 음성이 영어인 경우를 가정해 `say -v Yuna` 고정

**사전 요건**: macOS, `osascript` / `say`, `jq`, `claude` CLI, Yuna 한국어 음성 설치(`시스템 설정 → 손쉬운 사용 → 음성 콘텐츠`).

**ON / OFF 토글**: 플러그인의 `hooks/session_summary.conf` 의 `ENABLED=true|false`. `ENABLED=false` 면 즉시 종료 — LLM·알림·음성 호출 모두 건너뜀.

자세한 설치·트러블슈팅은 [plugins/cc-jarvis/README.md](plugins/cc-jarvis/README.md)를 참고.

---

## cc-meeting-highlight 요점

> "녹화 안 보는 문제"를 자동화로 해결 — 1시간 회의 mp4를 60초 자막 영상으로 압축.

**파이프라인**: 7-Phase, 첫 실행 10-15분 / 두 번째부터 2-5분 (M3 Mac 24GB 기준).

```
Phase 0  symlink (한글·일본어 파일명 ASCII화)              [scripts/00]
Phase 1  음성 추출 (16kHz mono WAV)                        [scripts/10]
Phase 2  받아쓰기 (mlx-whisper, word-level timestamps)     [scripts/20]
Phase 3  토픽 추출 + 시각 매칭 (LLM)                       [skills/topics-extractor]
Phase 4  60초 하이라이트 선정 + 자막 작성 (LLM)             [skills/highlights-selector]
Phase 5  클립 잘라내기 (CFR 30fps 재인코딩)                 [scripts/50]
Phase 6  Remotion 4.x 렌더링 (Noto Sans KR 한글 자막)      [assets/remotion/]
```

**한국 환경 기본 설정** (이 플러그인이 자동 적용):

- mlx-whisper `language="ko"` 명시 (자동 감지가 일본어로 흘러가는 문제 회피)
- INITIAL_PROMPT에 한국 회사 자주 쓰는 용어 (OKR, KPI, MAU, PM, CTO 등)
- NFD/NFC 정규화 차이를 symlink 레이어로 흡수 (한글 파일명 안전)
- Remotion에서 Noto Sans KR + `wordBreak: keep-all` 적용
- 자막 한국어 길이 가이드 (caption 18자, subCaption 35자)

**사전 요건**: macOS 14+, Apple Silicon, 16GB+ RAM, Python 3.11(필수, 3.14는 mlx-whisper ImportError), Node 18+, `brew install ffmpeg jq uv node`.

자세한 절차·트러블슈팅·자산 부트스트랩 방법은 [plugins/cc-meeting-highlight/README.md](plugins/cc-meeting-highlight/README.md)를 참고.

---

## cc-roundtable 요점

> 한 명의 시점으로는 보이지 않는 사각지대를, 다분야 전문가 패널의 구조화된 토론으로 메우는 스킬.

**핵심 설계** — 그룹 사고와 의견 수렴 실패를 회피하기 위해 학술적 지견에 근거해 설계됨.

1. **독립 분석 먼저** — 각 전문가가 다른 의견을 보지 않고 병렬로 분석 (Nominal Group Technique)
2. **반대 의견을 구조적으로 보장** — Devil's Advocate를 패널과 별도로 1명 항상 포함
3. **반복은 최대 2라운드** — MAD 연구 기준, 3라운드 이상은 사고 퇴화
4. **소수 의견 보호** — 통합 단계에서 명시적으로 체크
5. **전문가 패널은 Phase 0에서 확정** — 토론 중간에 추가·교체 금지

**파이프라인**

```
Phase 0: 의제 분석·전문가 동적 선정 (오케스트레이터)
   ↓
Phase 1: 독립 분석 (전문가 병렬, 상호 비공개)
   ↓
Phase 2: 구조화된 토론 (대립점 중심, 최대 2라운드)
   ↓
Phase 3: 통합·평결 (소수 의견 체크)
   ↓
Phase 4: 사용자 보고
```

- **패널 크기**는 의제의 도메인 수에 따라 **3–7명 + DA**로 동적 결정.
- **토론 심도**는 리스크/대립 가능성에 따라 **Quick / Standard / Deep**.
- 웹사이트, 코드, 사업 전략, 디자인, 조직 설계 등 도메인 무관.

자세한 설계 원칙·전문가 선정 로직·페르소나 템플릿은 [plugins/cc-roundtable/skills/start/SKILL.md](plugins/cc-roundtable/skills/start/SKILL.md)를 참고.

---

## cc-security-scan 요점

> Claude Code 용 보안 슬래시 명령어 3종을 개발 사이클의 다른 타이밍에 분리 배치 — PR 리뷰 / 릴리스 전 / 배포 후. 모두 **`disable-model-invocation: true`** 라 모델이 자의로 발동하지 않고, 사용자가 명시적으로 `/명령어`를 쳐야 동작.

| 타이밍 | 슬래시 | 대상 |
| --- | --- | --- |
| PR 생성 시 | `/security-review` | git diff 만 · 정적 분석 · 신뢰도 0.8↑만 보고(거짓 양성 필터링) |
| 릴리스 전 | `/full-scan` | 전체 소스 + `npm audit`/`pip-audit`/`cargo audit`/`gitleaks` 병렬, 모노레포 대응 |
| 배포 후 | `/security-scan` | 스테이징 서버에 HTTP 동적 테스트 (헤더, OWASP Top 10, JWT 혼동, 인젝션 등) |

**보안 원칙**

- `/security-scan` 은 **스테이징 환경 전용** — 프로덕션 URL (`prod`, `production`, `app.` 등) 은 `security-agent.config.yml` 에서 명시 허가가 없으면 거부
- Critical 이상 발견은 즉시 보고하고 사람 승인 없이 자동 수정하지 않음
- 결과에 PII / 인증 토큰이 섞이면 마스킹 후 기록
- 출력은 `hooks/security-filter.sh` 로 Critical/High만 추려 8KB 캡

**테스트 하니스** — `tests/security-skills/fixtures/` 에 40+ 픽스처(`vuln/safe/hard/attacker/no-comment/deep-chain/framework-bypass/infra-combo`) + 채점 기준(`expected.json`). `/full-scan tests/security-skills/fixtures` 로 자체 평가 가능.

**커버리지** (3개 명령어 합산):

| 영역 | 커버리지 |
| --- | --- |
| OWASP Top 10 베이스 | 약 65~70% |
| 코드 패턴 (injection, XSS, hardcoded key) | 약 90% |
| 의존성 CVE | 약 85% |
| HTTP 설정 실수 | 약 75% |
| 비즈니스 로직 · 인프라 | 침투 테스트 (수작업) 필요 |

자세한 사전 요건·도입 절차·실행 정책은 [plugins/cc-security-scan/README.md](plugins/cc-security-scan/README.md) 와 [plugins/cc-security-scan/templates/security-skills-setup.md](plugins/cc-security-scan/templates/security-skills-setup.md) 를 참고.

---

## empirical-prompt-tuning 요점

> 내가 쓴 프롬프트는, 내가 평가할 수 없다.
> 다른 AI에게 백지 상태로 돌려보고, 막힌 곳을 보고받아 단계적으로 다듬는 루프 스킬.

**6가지 핵심 원칙** — 어느 하나라도 빠지면 의미 없음.

1. 글쓴이와 판정자 분리
2. 시나리오 사전 고정 (사후 수정 절대 금지)
3. 매번 신규 dispatch (같은 세션 재사용 금지)
4. 양면 측정 (정성 + 정량)
5. 1회 반복 1테마 수정
6. hold-out 시나리오로 과적합 검사

**한 줄 흐름**

```
대상 식별 → 시나리오 3개 고정 → 요건 체크리스트
   ↓
백지 dispatch → 정성+정량 수집 → 1테마 수정
   ↓
새 dispatch로 재실행 → 수렴/발산/종료 판정
```

자세한 워크플로우·종료 판정 기준·평가 루브릭은 [plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning/SKILL.md](plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning/SKILL.md)를 참고.

---

## 디렉터리 구조

```
gaebalai-marketplace/                          # 이 리포지터리
├── .claude-plugin/
│   └── marketplace.json                       # 마켓플레이스 매니페스트
├── plugins/
│   ├── car-can-checker/                       # 자동차 OBD2/CAN 진단 풀스택
│   │   ├── .claude-plugin/plugin.json
│   │   ├── README.md
│   │   ├── agents/car-can-orchestrator.md     # 4개 스킬 오케스트레이터
│   │   └── skills/
│   │       ├── raspi-can-bootstrap/           # STEP A
│   │       ├── can-signal-hunter/             # STEP B
│   │       ├── car-noise-pwa-builder/         # STEP C
│   │       └── car-noise-report/              # STEP D
│   ├── cc-jarvis/                             # macOS 전용 Stop hook
│   │   ├── .claude-plugin/plugin.json
│   │   ├── README.md
│   │   ├── commands/jarvis-replay.md          # /jarvis-replay 슬래시 명령어
│   │   └── hooks/
│   │       ├── hooks.json                     # Stop hook 등록
│   │       ├── session_summary.sh             # JSONL 파싱 + 토큰 마스킹 + Haiku 요약 + osascript + say
│   │       ├── session_summary_prompt.txt     # 자비스 캐릭터 프롬프트
│   │       ├── session_summary.conf           # ENABLED·VOICE·MODEL·CAPS 설정
│   │       ├── jarvis_replay.sh               # /jarvis-replay 헬퍼
│   │       ├── install.sh                     # 수동 설치(플러그인 미사용 시)
│   │       └── gs-config                      # ON/OFF 토글
│   ├── cc-meeting-highlight/                  # macOS Apple Silicon 전용
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/meeting-highlight.md      # /meeting-highlight 슬래시 명령어
│   │   ├── skills/
│   │   │   ├── topics-extractor/SKILL.md      # Phase 3
│   │   │   └── highlights-selector/SKILL.md   # Phase 4
│   │   └── assets/
│   │       ├── scripts/                       # Phase 0·1·2·5 + bootstrap.sh
│   │       ├── remotion/                      # Phase 6 Remotion 4.x 템플릿
│   │       └── schemas/                       # topics / highlights JSON Schema
│   ├── cc-roundtable/
│   │   ├── .claude-plugin/plugin.json
│   │   └── skills/
│   │       └── start/
│   │           ├── SKILL.md
│   │           └── references/                # 토론 규칙·전문가 아키타입·출력 포맷
│   ├── cc-security-scan/                      # 보안 슬래시 명령어 3종
│   │   ├── .claude-plugin/plugin.json
│   │   ├── README.md
│   │   ├── commands/
│   │   │   ├── security-review.md             # /security-review (PR 차분)
│   │   │   ├── full-scan.md                   # /full-scan (전체 + CVE)
│   │   │   └── security-scan.md               # /security-scan (스테이징 런타임)
│   │   ├── hooks/security-filter.sh           # 출력 파이프 필터 (Critical/High, 8KB 캡)
│   │   ├── rules/security.md                  # 글로벌 보안 룰
│   │   ├── templates/                         # security-agent.config 템플릿 + 도입 가이드
│   │   ├── docs/design.md
│   │   └── tests/security-skills/             # 40+ 픽스처 + expected.json
│   └── empirical-prompt-tuning/
│       ├── .claude-plugin/plugin.json
│       └── skills/
│           └── empirical-prompt-tuning/
│               ├── SKILL.md
│               ├── references/
│               │   ├── claude-code-flow.md
│               │   ├── claude-ai-flow.md
│               │   ├── scenario-design.md
│               │   └── scoring-rubric.md
│               └── assets/
│                   ├── dispatch-prompt-template.md
│                   ├── report-structure.md
│                   └── iteration-log-template.md
├── install.sh                                 # 로컬 개발용 (empirical-prompt-tuning 전용)
└── README.md
```

---

## 마켓플레이스 운영자용

### 새 플러그인 추가하기

1. `plugins/<plugin-name>/` 디렉터리 생성
2. `plugins/<plugin-name>/.claude-plugin/plugin.json` 작성 (필수: `name`, `description`, `version`)
3. 같은 디렉터리에 `skills/`, `commands/`, `agents/`, `hooks/` 등 표준 Claude Code 자원 배치
4. 루트 `.claude-plugin/marketplace.json`의 `plugins` 배열에 항목 추가
5. `.release-please-manifest.json`에 `"plugins/<plugin-name>": "0.1.0"` 추가, `.release-please-config.json`의 `packages`에 항목 추가
6. **Conventional Commits**로 커밋 (`feat:` / `fix:` / `docs:` 등) 후 푸시 — release-please가 자동으로 PR을 생성합니다

### 자동 릴리즈 (release-please)

[.github/workflows/release-please.yml](.github/workflows/release-please.yml)이 main 브랜치 push마다 다음을 자동 처리합니다.

- conventional-commits 분석 → semver bump 결정
- CHANGELOG.md 자동 갱신 (per-plugin 섹션 분리)
- `.claude-plugin/marketplace.json` + 각 plugin.json의 `version` 필드 자동 갱신
- 릴리즈 PR 생성. PR을 머지하면 git tag + GitHub release가 자동으로 만들어짐

수동 `gh release create`는 더 이상 필요 없습니다 (PR 머지 한 번으로 끝).

### GitHub 리포지터리 이름

`/plugin marketplace add gaebalai/gaebalai-marketplace` 형식으로 사용하려면 GitHub 리포 이름이 **반드시 `gaebalai-marketplace`** 여야 합니다. 다른 이름이라면 `/plugin marketplace add owner/<actual-name>`을 안내해야 합니다.

### Third-party 라이선스

플러그인이 사용하는 외부 의존성(Remotion, python-can, mlx-whisper, 폰트 등)의 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참고. 회사 환경 도입 시 특히 **Remotion**(cc-meeting-highlight)과 **python-can LGPL**(car-can-checker)에 주의.

---

## 로컬 개발 (마켓플레이스 미사용)

플러그인 시스템 없이 SKILL만 직접 시험하고 싶다면.

### empirical-prompt-tuning

```bash
# 심볼릭 링크 (개발용, 실시간 반영)
bash install.sh

# 또는 복사
bash install.sh --copy

# 제거
bash install.sh --uninstall
```

`install.sh`는 `plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning`을 `~/.claude/skills/empirical-prompt-tuning`으로 링크합니다.

### cc-roundtable

전용 install 스크립트는 아직 제공하지 않습니다. 직접 링크하려면.

```bash
ln -s "$(pwd)/plugins/cc-roundtable/skills/start" ~/.claude/skills/cc-roundtable
```

### cc-meeting-highlight

macOS Apple Silicon 전용. 사용자 프로젝트 루트에서 부트스트랩 스크립트를 실행하면 `meeting_rec/` 트리, Python 3.11 venv, Remotion 의존성까지 한 번에 셋업됩니다.

```bash
cd <your-project>
bash <repo>/plugins/cc-meeting-highlight/assets/scripts/bootstrap.sh
```

> 마켓플레이스 경유 설치(`/plugin install <name>@gaebalai-marketplace`)를 사용하면 SKILL/Command는 자동 관리됩니다. cc-meeting-highlight의 경우 `/meeting-highlight` 슬래시 명령어가 부트스트랩까지 안내합니다.

---

## 평가 대상 종류별 사용법 (empirical-prompt-tuning)

이 스킬은 SKILL뿐 아니라 다음에도 적용됩니다.

| 평가 대상 | 트리거 예시 |
|---|---|
| Claude Code Skill 본체 | `~/.claude/skills/<name>/SKILL.md 평가해줘` |
| 사용자 SlashCommand | `~/.claude/commands/<name>.md 다른 AI한테 돌려봐줘` |
| 일반 프롬프트 텍스트 파일 | `이 prompt.md 백지 dispatch로 검증해줘` |
| 인라인 프롬프트 | `다음 프롬프트 본문을 평가해줘 (paste)` |

스킬은 환경(Claude Code / Claude.ai)을 자동 감지하고 적절한 dispatch 방식을 선택합니다.

---

## 마켓플레이스 갱신·제거

```
# 마켓플레이스 정의가 바뀌면 (소유자가 새 플러그인을 추가했거나 plugin.json을 갱신했을 때)
/plugin marketplace update gaebalai-marketplace

# 플러그인 개별 제거 (마켓플레이스는 유지)
/plugin uninstall car-can-checker@gaebalai-marketplace
/plugin uninstall cc-jarvis@gaebalai-marketplace
/plugin uninstall cc-meeting-highlight@gaebalai-marketplace
/plugin uninstall cc-roundtable@gaebalai-marketplace
/plugin uninstall cc-security-scan@gaebalai-marketplace
/plugin uninstall empirical-prompt-tuning@gaebalai-marketplace

# 마켓플레이스 자체 제거
/plugin marketplace remove gaebalai-marketplace
```

설치된 플러그인 목록은 `/plugin` 메뉴에서 확인할 수 있습니다.

---

## 트러블슈팅 (empirical-prompt-tuning)

| 증상 | 원인 | 대처 |
|---|---|---|
| 트리거해도 스킬이 발동 안 함 | description이 다른 스킬과 경합 | `~/.claude/skills/empirical-prompt-tuning/SKILL.md` 명시적 경로 지정 |
| `Task tool dispatch 안 됨` | 의뢰 프롬프트 모호 | "Task tool을 사용해서 서브에이전트 기동" 명시 |
| `<usage>` 태그가 응답에 없음 | dispatch 프롬프트의 보고 구조 미강제 | `assets/dispatch-prompt-template.md`의 보고 구조 부분 추가 |
| `529 / overloaded` | API 레이트 리밋 | 병렬 3 → 1로 줄이고 30초 대기 후 재시도 |
| 부모 컨텍스트 고갈 | 평가 누적 | 새 Claude Code 세션 띄워 평가 전용으로 분리 |
| 서브에이전트가 description만 읽고 통과 | frontmatter-본문 정렬 안 됨 | [1] 단계 정적 체크 강화 |
| 한국 사내망에서 API 차단 | 회사 방화벽 | 사내 게이트웨이 경유, `HTTPS_PROXY` 환경변수 설정 |
| `Claude.ai 환경에서 dispatch 불가` | Task tool 부재 | references/claude-ai-flow.md의 전략 A (사용자 협력 외부 세션) 사용 |

---

## 자주 빠지는 함정 (empirical-prompt-tuning)

- **시나리오가 본문 설명 범위만 따라간다** → 가짜 100% 통과. median + edge + hold-out 강제.
- **같은 AI 재사용** → 이전 지적 학습으로 통과율이 가짜로 오름. 매번 신규 dispatch.
- **메트릭만 본다** → 본문이 야위어도 모름. 정성이 주, 정량이 보조.
- **1회에 여러 수정** → 무엇이 효과 있었는지 추적 불가. 1테마/회.
- **사후 시나리오 튜닝** → 본말전도. 절대 금지.
- **자기 재독으로 대체** → 편향이 가장 크다. 평가 자체를 건너뛰고 명시 보고하는 편이 낫다.

---

## 라이선스 / 기여

본 마켓플레이스 / 플러그인 자체도 `empirical-prompt-tuning`의 평가 대상이 될 수 있습니다 (자기 적용, dogfooding). 발견한 불명확점·재량 보완 사례는 이슈로 환영.
