# gaebalai-marketplace

> Claude Code 플러그인 마켓플레이스. 현재는 `empirical-prompt-tuning` 하나를 호스팅합니다.

이 리포지터리는 Claude Code의 [플러그인 시스템](https://docs.claude.com/en/docs/claude-code/plugins)에서 곧바로 추가할 수 있는 **마켓플레이스** 형태로 구성되어 있습니다.

---

## 빠른 시작 (사용자)

Claude Code 세션에서 두 줄.

```
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install empirical-prompt-tuning@gaebalai-marketplace
```

설치 후 자연어로 트리거됩니다.

```
이 SKILL.md 평가해줘 (서브에이전트 3병렬로)
```

```
~/.claude/skills/conventional-changelog/SKILL.md 다른 AI한테 돌려봐줘
```

> 로컬 개발 중인 마켓플레이스를 그대로 가리키려면 `/plugin marketplace add /Users/gaebalai/cc-workspace/empirical-prompt-tuning` 처럼 절대 경로로도 추가할 수 있습니다.

---

## 수록 플러그인

| 플러그인 | 설명 | 버전 |
|---|---|---|
| [`empirical-prompt-tuning`](plugins/empirical-prompt-tuning/) | 자기가 쓴 프롬프트의 재현성을 별도 AI에 백지 dispatch 시켜 객관 측정·정련하는 메타-스킬 | 1.0.0 |

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
│   └── empirical-prompt-tuning/
│       ├── .claude-plugin/
│       │   └── plugin.json                    # 플러그인 매니페스트
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
├── install.sh                                 # 로컬 개발용 (마켓플레이스 미사용 시)
└── README.md
```

---

## 마켓플레이스 운영자용

### 새 플러그인 추가하기

1. `plugins/<plugin-name>/` 디렉터리 생성
2. `plugins/<plugin-name>/.claude-plugin/plugin.json` 작성 (필수: `name`, `description`, `version`)
3. 같은 디렉터리에 `skills/`, `commands/`, `agents/`, `hooks/` 등 표준 Claude Code 자원 배치
4. 루트 `.claude-plugin/marketplace.json`의 `plugins` 배열에 항목 추가
5. 커밋 후 푸시 — 사용자는 `/plugin marketplace update gaebalai-marketplace`로 갱신

### GitHub 리포지터리 이름

`/plugin marketplace add gaebalai/gaebalai-marketplace` 형식으로 사용하려면 GitHub 리포 이름이 **반드시 `gaebalai-marketplace`** 여야 합니다. 다른 이름이라면 `/plugin marketplace add owner/<actual-name>`을 안내해야 합니다.

---

## 로컬 개발 (마켓플레이스 미사용)

플러그인 시스템 없이 SKILL만 직접 시험하고 싶다면.

```bash
# 심볼릭 링크 (개발용, 실시간 반영)
bash install.sh

# 또는 복사
bash install.sh --copy

# 제거
bash install.sh --uninstall
```

`install.sh`는 `plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning`을 `~/.claude/skills/empirical-prompt-tuning`으로 링크합니다. 마켓플레이스로 설치한 경우에는 사용할 필요가 없습니다 (플러그인 시스템이 자동 관리).

---

## 평가 대상 종류별 사용법

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

# 플러그인만 제거 (마켓플레이스는 유지)
/plugin uninstall empirical-prompt-tuning@gaebalai-marketplace

# 마켓플레이스 자체 제거
/plugin marketplace remove gaebalai-marketplace
```

설치된 플러그인 목록은 `/plugin` 메뉴에서 확인할 수 있습니다.

---

## 트러블슈팅

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
