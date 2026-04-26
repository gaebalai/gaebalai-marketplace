# empirical-prompt-tuning

> 내가 쓴 프롬프트는, 내가 평가할 수 없다.
> 다른 AI에 백지 dispatch 시키고, 막힌 곳을 보고받아 단계적으로 다듬는 루프 스킬.

`gaebalai-marketplace`에서 배포되는 Claude Code 플러그인입니다. Skill 본체와 references / assets 자원만 포함합니다.

## 설치

```
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install empirical-prompt-tuning@gaebalai-marketplace
```

## 트리거 예시

```
이 SKILL.md 평가해줘 (서브에이전트 3병렬로)
~/.claude/skills/conventional-changelog/SKILL.md 다른 AI한테 돌려봐줘
내가 쓴 /release-notes 슬래시 커맨드 재현성 검증해줘
이 프롬프트에서 암묵지 빼줘
```

## 무엇이 다른가

자기 재독·단순 윤문이 아니라 **별도 컨텍스트에 백지 dispatch** 시켜 막힌 지점을 보고받는 양면 평가 루프입니다. 6가지 핵심 원칙이 어느 하나라도 빠지면 의미를 잃습니다.

1. 글쓴이와 판정자 분리
2. 시나리오 사전 고정 (사후 수정 절대 금지)
3. 매번 신규 dispatch (같은 세션 재사용 금지)
4. 양면 측정 — 정성(불명확점·재량 보완·재시도) + 정량(tool_uses·duration_ms)
5. 1회 반복 1테마 수정
6. hold-out 시나리오로 과적합 검사

## 워크플로우

```
[1] 대상 식별        → SKILL.md / SlashCommand / 프롬프트 파일 확보
[2] 시나리오 설계    → median 1 + edge 1~2 + hold-out 1
[3] 요건 체크리스트  → [critical] 태그 최소 1개 강제
[4] 실행 (환경별)    → Code: Task tool 병렬 / .ai: 신규 세션 직렬
[5] 보고 수집        → 정성 + 정량
[6] 1테마 수정       → 가장 큰 불명확점 1개만 본문 반영
[7] 재실행           → 새 dispatch로 [4] 반복
[8] 종료 판정        → 수렴 / 발산 / 종료
```

## 종료 판정

| 상태 | 조건 |
|---|---|
| **수렴** | 연속 2회 신규 불명확점 0, 정확도 ±3pt 이내, hold-out -15pt 미만 |
| **발산** | 3회 이상 반복해도 불명확점 줄지 않음 → 본문 구조 재설계 |
| **종료** | 80~90점 도달, 남은 항목은 사용 빈도 낮은 디테일 |

## 적용하지 않는 케이스

- 일회성 프롬프트
- 글쓴이의 주관적 취향 반영이 목적
- 단순 맞춤법·번역투 윤문 → `humanize-korean`
- 다분야 전문가 토론 형식 리뷰 → `cc-roundtable:start`

## 디렉터리 구조

```
plugins/empirical-prompt-tuning/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── empirical-prompt-tuning/
        ├── SKILL.md                    # 스킬 본체 + frontmatter
        ├── references/
        │   ├── claude-code-flow.md     # Task tool 병렬 dispatch 절차
        │   ├── claude-ai-flow.md       # 단일 세션 직렬 폴백
        │   ├── scenario-design.md      # 시나리오 작성 가이드
        │   └── scoring-rubric.md       # 20점 평가 루브릭
        └── assets/
            ├── dispatch-prompt-template.md
            ├── report-structure.md
            └── iteration-log-template.md
```

## 자세한 내용

자세한 워크플로우·정량 임곗값·자주 빠지는 함정은 [SKILL.md](skills/empirical-prompt-tuning/SKILL.md) 참고.

전체 마켓플레이스 가이드는 [상위 README](../../README.md) 참고.
