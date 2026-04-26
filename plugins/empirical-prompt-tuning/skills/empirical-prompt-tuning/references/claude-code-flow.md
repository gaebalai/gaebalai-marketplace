# Claude Code 환경에서의 dispatch 절차

Task tool을 통해 서브에이전트를 병렬 기동하는 흐름.

## 전제

- Claude Code CLI v1.x 이상 (`npm i -g @anthropic-ai/claude-code`, Node.js 24+)
- `claude --version`으로 확인
- Task tool은 기본 활성. 비활성화되어 있다면 `~/.claude/settings.json` 점검

## 기본 dispatch 의뢰 패턴

사용자가 Claude Code 세션에서 이 스킬을 발동시킨 경우, Claude는 다음과 같이 Task tool 호출을 명시적으로 지시받아야 한다:

```
~/.claude/skills/<target-skill>/SKILL.md 을 시나리오 A/B/C로
서브에이전트 3병렬 평가해줘.
- 각 서브에이전트에 시나리오 1개씩 할당
- 불명확점 / 재량 보완 / 요건 달성 ○× / 재시도 횟수 / tool_uses / duration_ms를
  보고서로 만들어줘
- Task tool을 사용해서 별도 컨텍스트로 기동시켜줘 (현재 세션에서 자기가 답하지 말 것)
```

`Task tool을 사용해서`를 명시하지 않으면 본문만 읽고 자기가 답해 버리는 패턴이 발생한다.

## Task tool 호출 형태

```
Task(
  description="<시나리오 라벨, 예: median-ts-library>",
  prompt="<dispatch-prompt-template.md 채워넣은 본체>",
  subagent_type="general-purpose"
)
```

각 서브에이전트는 부모 컨텍스트와 분리되어 백지 상태로 시작한다.

## 병렬도 가이드

- 권장: 3병렬 (median + edge + hold-out)
- 부모 컨텍스트가 무거우면 (>50% 사용) 직렬로 전환
- 각 병렬 호출은 부모 컨텍스트를 30k 토큰 정도 먹는다고 가정

## usage 메타 추출

Task tool 응답 말미에 다음 형태가 붙는다:

```
<usage>
total_tokens: 12345
tool_uses: 3
duration_ms: 45000
</usage>
```

이를 추출하여 정량 메트릭으로 활용. 추출되지 않으면 dispatch 프롬프트에 "종료 시 산출물·요건 달성·불명확점·재량 보완·재시도를 포함하여 응답해 주세요"를 강제해야 한다.

## 자주 발생하는 실패와 대처

| 증상 | 원인 | 대처 |
|---|---|---|
| Task tool dispatch 안 됨 | 의뢰 프롬프트가 모호 | "Task tool을 사용해서 서브에이전트 기동" 명시 |
| `<usage>` 안 나옴 | 보고 구조 미강제 | dispatch 프롬프트에 보고 구조 강제 문구 추가 |
| 529 / overloaded | 레이트 리밋 | 병렬 3→1, 30초 대기 후 재시도 |
| 부모 context 고갈 | 평가 누적 | 새 세션 띄워 평가 전용 분리 (skill 평가는 대화 이력 비의존) |
| 서브에이전트가 description만 읽고 통과 | frontmatter-본문 정렬 안 됨 | [1] 단계 정적 체크 강화 |

## 한국 사내망 환경 메모

- 일부 회사망에서 Anthropic API 직접 호출이 차단된 경우 사내 게이트웨이 경유 설정 필요
- 프록시 환경에서는 `HTTPS_PROXY` 환경변수 설정 후 `claude` 기동
- Node.js 글로벌 패키지 설치 권한 없으면 `~/.npm-global` prefix 사용

## 결과 저장 위치

각 반복의 결과는 `~/.claude/eval-logs/<skill-name>/iter-<N>.json`에 저장 권장:

```json
{
  "iteration": 3,
  "scenarios": {
    "median": {"score": "100%", "tool_uses": 3, "duration_ms": 42000, ...},
    "edge": {"score": "85%", "tool_uses": 8, "duration_ms": 67000, ...},
    "hold_out": {"score": "—", "skipped": true}
  },
  "applied_fix": "publish workflow 동일/별도 비교표 추가",
  "next_target": "bump-patch-for-minor-pre-major 기재 누락"
}
```

이걸로 반복 간 추이를 그릴 수 있다.
