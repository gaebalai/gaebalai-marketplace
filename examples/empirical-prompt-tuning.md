# empirical-prompt-tuning — 사용 예시

내가 쓴 프롬프트의 재현성을 별도 AI에 백지 dispatch 시켜 객관 측정·정련합니다.

## SKILL.md 평가

```
~/.claude/skills/conventional-changelog/SKILL.md 평가해줘. 서브에이전트 3병렬로.
median 1개 + edge 1개 + hold-out 1개 시나리오 고정해서.
```

스킬이 Phase 1-8을 진행:
1. 대상 식별 (skill 본체 + references + assets)
2. 시나리오 3개 사전 고정
3. 요건 체크리스트 작성
4. 백지 dispatch (Task tool로 서브에이전트 3개 병렬)
5. 정성+정량 보고 수집
6. 1테마 수정안 (가장 큰 결함 1개)
7. 새 dispatch로 재실행
8. 수렴/발산/종료 판정

결과는 `~/.claude/eval-logs/<ts>/`:
- `iteration-0.md` — 초기 dispatch 결과
- `iteration-1.md` — 1테마 수정 후 재dispatch
- ...
- `final.md` — 종료 시점 정리

## SlashCommand 평가

```
~/.claude/commands/babysit-prs.md 다른 AI한테 돌려봐줘.
이 슬래시 명령어가 "여러 PR 트리아주" 같은 모호한 시나리오에서도 결정적으로 동작하는지.
```

## 일반 프롬프트 텍스트

```
이 prompt.md 백지 dispatch로 검증해줘. 회사 사내용 보고서 자동 생성 프롬프트인데, 입력 형식이 들쭉날쭉해도 안정적인지 보고 싶어.
```

## hold-out 시나리오 검증

본문 설명 범위를 벗어난 시나리오에서도 통과하는지가 핵심:

```
지금 만든 SKILL이 "median 시나리오 + edge 시나리오"는 통과했는데, hold-out 시나리오 1개 더 만들어서 과적합 안 됐는지 검증해줘.
```

## 인라인 프롬프트 (paste)

```
다음 프롬프트 본문을 평가해줘 (서브에이전트 1명, 시나리오 1개로 빠르게):

---
당신은 코드 리뷰어입니다. 다음 PR diff를 받아 다음 형식으로 보고합니다:
1. 주요 변경 요약 (3줄 이내)
2. 우려 사항 (없으면 명시)
3. 머지 가능 여부 (yes/no/with-fixes)
---
```

## 종료 판정 시그널

| 시그널 | 의미 | 추천 액션 |
|---|---|---|
| 정확도 90% + tool_uses ≤ 3 | 수렴 | 종료 |
| 반복마다 정확도 진동 | 발산 | 1테마 수정 원칙 위반 점검 |
| 같은 결함이 N번 반복 | 종료 | 본질적 한계 — 프롬프트 자체 재구성 권장 |

## Claude.ai 단일 세션 (Task tool 없음)

Claude Code가 아닌 Claude.ai 환경에서는 Task tool이 없어 동일 흐름 불가. 스킬이 자동 감지하고 [전략 A/B/C](../plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning/references/claude-ai-flow.md)로 폴백:

- **전략 A**: 사용자가 별도 Claude.ai 탭을 열어 직접 dispatch (협력 모드)
- **전략 B**: 메모리 분리 — 시스템 프롬프트로 페르소나 격리 (단일 세션)
- **전략 C**: 사람 시뮬레이션 — 사용자가 단계별 입력 (가장 느림)

## 자주 빠지는 함정

- 같은 AI 재사용 → 이전 지적 학습으로 통과율 가짜 상승
- 사후 시나리오 튜닝 → 본말전도, 절대 금지
- 메트릭만 보기 → 본문이 야위어도 모름. 정성 주, 정량 보조
- 1회에 여러 테마 수정 → 무엇이 효과 있었는지 추적 불가
- 자기 재독으로 평가 대체 → 편향이 가장 큼. 차라리 "평가 안 함"이 정직
