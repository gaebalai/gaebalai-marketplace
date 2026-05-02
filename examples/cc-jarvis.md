# cc-jarvis — 사용 예시

> macOS 전용. 설치 후 별도 트리거 없음 — Claude Code 가 응답을 끝낼 때마다 자동으로 자비스(JARVIS)처럼 보고합니다.

## 첫 셋업

```bash
# 1. 마켓플레이스 등록 (1회)
/plugin marketplace add gaebalai/gaebalai-marketplace

# 2. 플러그인 설치
/plugin install cc-jarvis@gaebalai-marketplace
```

설치 시 [hooks/hooks.json](../plugins/cc-jarvis/hooks/hooks.json)이 Claude Code 의 Stop 이벤트에 자동 연결됩니다. `~/.claude/settings.json` 수동 편집 불필요.

### 사용자 환경 사전 요건

```bash
# Yuna(한국어 여성) 음성 설치 확인
say -v "?" | grep ko_KR
# Yuna ko_KR  안녕하세요. 제 이름은 유나입니다.

# 없으면: 시스템 설정 → 손쉬운 사용 → 음성 콘텐츠 → 시스템 음성 → Yuna 다운로드

# 의존성
which jq claude osascript say
```

## 동작 예시 1: 정상 응답 종료

Claude Code 세션에서 코드 변경을 마치고 보스에게 보고가 자동으로 들립니다.

```
보스, 마켓플레이스 매니페스트와 플러그인 매니페스트, 릴리즈 설정에 cc-jarvis 항목을 추가했습니다.
요청대로 모든 검증이 통과했고, 이제 마켓플레이스에서 직접 설치할 수 있습니다.
```

- macOS 알림 센터에 240자 이내로 잘린 요약 표시
- 백그라운드에서 `say -v Yuna` 가 600자 이내로 음성 재생
- `~/Library/Logs/cc-jarvis/summary_<repo>_<ts>.txt` 에 전체 요약 저장

## 동작 예시 2: 사용자가 ESC로 중단

`stop_reason=interrupted` 분기 — 짧은 알림만 띄우고 음성·LLM 호출 생략.

```
🤖 Claude 작업 완료
사용자 중단으로 작업이 멈췄습니다.
```

## 동작 예시 3: 마지막 보고 다시 듣기

```
/jarvis-replay
```

`~/Library/Logs/cc-jarvis/` 의 가장 최신 `summary_*.txt` 를 찾아 conf 의 음성·속도로 재생합니다. 요약 본문도 함께 출력됩니다.

```
[jarvis-replay] 재생: /Users/you/Library/Logs/cc-jarvis/summary_my-project_20260502_223045.txt
[jarvis-replay] voice: Yuna, rate: 220

보스, …
```

## 자주 쓰는 conf 튜닝

플러그인 설치 위치의 `hooks/session_summary.conf` 또는 수동 설치 시 `~/.claude/hooks/session_summary.conf` 편집.

```bash
# 한국어를 빠르게
RATE=230

# 더 짧게 보고받기 (음성 25초 → 15초)
SUMMARY_MAX_CHARS=400

# 야간엔 끄기
ENABLED=false

# 다른 음성으로
VOICE="Mia"   # say -v "?" | grep ko_KR 에서 선택
```

## 임시로 끄기 / 다시 켜기

```bash
# OFF
sed -i "" 's/^ENABLED=true/ENABLED=false/' \
  ~/.claude/plugins/<install-root>/cc-jarvis/hooks/session_summary.conf

# ON
sed -i "" 's/^ENABLED=false/ENABLED=true/' \
  ~/.claude/plugins/<install-root>/cc-jarvis/hooks/session_summary.conf
```

플러그인 설치 경로는 Claude Code 의 `/plugin` 메뉴에서 확인할 수 있습니다.

## 트러블슈팅 빠른 점검

```bash
# 1. 음성 단독 동작
say -v Yuna "테스트입니다"

# 2. 알림 단독 동작
osascript -e 'display notification "test" with title "🤖 Claude"'

# 3. claude -p 단독 동작
claude -p --model claude-haiku-4-5 "한 문장으로 안녕"

# 4. 마지막 hook 입력 / 에러 확인
ls -lt ~/Library/Logs/cc-jarvis/
cat ~/Library/Logs/cc-jarvis/last_error.log
```

자세한 보강 사항·내부 동작은 [plugins/cc-jarvis/README.md](../plugins/cc-jarvis/README.md) 참고.
