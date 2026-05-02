---
description: "cc-jarvis 가 가장 최근에 만든 작업 요약을 다시 음성으로 재생 (macOS 전용)"
allowed-tools: Bash
---

# /jarvis-replay — 마지막 작업 요약 다시 듣기

cc-jarvis 가 직전 응답을 요약해 `~/Library/Logs/cc-jarvis/` 아래에 저장한 요약 파일 중 **가장 최신 1개**를 찾아 `session_summary.conf` 의 음성·속도로 다시 읽어줍니다.

> macOS 전용. 알림은 다시 띄우지 않습니다 (음성 재생만).

## 실행 방법

다음 한 줄을 Bash 도구로 그대로 실행해 주세요. 출력에는 재생 중인 파일 경로와 요약 본문이 함께 표시됩니다.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/jarvis_replay.sh"
```

## 동작 요약

- `~/Library/Logs/cc-jarvis/summary_*.txt` 중 가장 최신 파일 1개 선택
- 플러그인의 `session_summary.conf` 에서 `VOICE` / `RATE` 로딩 (기본 Yuna, 시스템 기본 rate)
- `say -v $VOICE [-r $RATE] -f <latest>` 로 백그라운드 재생
- 재생할 파일이 없으면 안내 메시지를 출력하고 종료

## 활용

- 음성 알림이 다른 작업과 겹쳐서 못 들었을 때
- 30초짜리 보고를 다른 사람에게 다시 들려줄 때
- 요약 본문을 화면으로 한 번 더 확인하고 싶을 때 (cat 결과가 출력됨)
