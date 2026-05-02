# cc-jarvis — Claude Code Stop Hook (JARVIS 음성 보고)

Claude Code의 응답이 끝날 때마다 직전 트랜스크립트를 Haiku 4.5로 요약해서, macOS 데스크톱 알림과 한국어 음성(Yuna)으로 작업 결과를 보고받게 하는 Stop hook 플러그인.

> macOS 전용 (`osascript` / `say` 사용)

---

## 설치

### 마켓플레이스 경유 (권장)

```
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-jarvis@gaebalai-marketplace
```

설치하면 [hooks/hooks.json](hooks/hooks.json)이 Claude Code의 Stop 이벤트에 자동 연결됩니다. `~/.claude/settings.json`을 직접 수정할 필요가 없습니다.

### 사전 요구 (사용자 환경에 1회)

- macOS (`osascript` / `say` 필요)
- `jq`, `git`, `claude` (Claude Code) CLI 설치
- 한국어 음성 Yuna 다운로드: `시스템 설정 → 손쉬운 사용 → 음성 콘텐츠 → 시스템 음성`
- 음성 목록 확인: `say -v "?" | grep ko_KR`

### 수동 설치 (플러그인 시스템 미사용 시)

```bash
git clone https://github.com/gaebalai/gaebalai-marketplace.git
cd gaebalai-marketplace
bash plugins/cc-jarvis/hooks/install.sh
```

`install.sh`가 수행하는 일:
- `~/.claude/hooks/` 디렉터리 생성
- `session_summary.sh` / `session_summary_prompt.txt` 복사
- `session_summary.conf` 는 **기존 토글 상태를 보존**하기 위해 없을 때만 복사
- `session_summary.sh` 실행권한 부여
- `~/.claude/settings.json` 에 추가해야 할 hooks 블록 안내 출력

---

## 동작 흐름

```
Claude Code 응답 종료
        │
        ▼
[Stop event] → 플러그인의 hooks/hooks.json 자동 등록 (마켓플레이스 설치 시)
        │
        ▼
hooks/session_summary.sh 실행
  1) macOS 가드 / ENABLED 토글 / 재귀 방지 환경 변수 체크
  2) stdin JSON 수신 (transcript_path / session_id / stop_reason)
  3) stop_reason=interrupted 이면 짧은 알림만 띄우고 종료 (음성·LLM 호출 없음)
  4) transcript_path(.jsonl) 마지막 30라인을 jq 로 user/assistant 텍스트만 추출
  5) claude -p --model $MODEL (기본 claude-haiku-4-5) 로 요약 생성
  6) ~/Library/Logs/cc-jarvis/summary_<repo>_<ts>.txt 에 저장
  7) osascript 로 데스크톱 알림 (NOTIFY_MAX_CHARS 캡, 기본 240자)
  8) say -v $VOICE [-r $RATE] 로 음성 읽기 (SUMMARY_MAX_CHARS 캡, 기본 600자, 백그라운드)
  9) 3% 확률로 7일 이상 지난 요약 파일 정리
```

---

## 폴더 구조

```
cc-jarvis/
├── README.md
├── .claude-plugin/
│   └── plugin.json                         # 플러그인 매니페스트
├── commands/
│   └── jarvis-replay.md                    # /jarvis-replay 슬래시 명령어
└── hooks/
    ├── hooks.json                          # Stop hook 등록 (Claude Code 플러그인 시스템)
    ├── session_summary.sh                  # 본체 (Stop hook entry point)
    ├── session_summary_prompt.txt          # 자비스 캐릭터 프롬프트
    ├── session_summary.conf                # ENABLED·VOICE·MODEL 등 설정
    ├── jarvis_replay.sh                    # /jarvis-replay 가 호출하는 헬퍼
    ├── install.sh                          # 수동 설치용 (~/.claude/hooks/ 로 배치)
    └── gs-config                           # ON/OFF 토글 명령
```

---

## 보강 사항 (원본 명세 대비)

| # | 항목 | 내용 |
| --- | --- | --- |
| B1 | 한국어 음성 + 속도 설정화 | `VOICE` / `RATE` 키로 `say -v $VOICE [-r $RATE]` 가변 |
| B2 | osascript 인용 안전화 | 요약 결과에 `"` / `\` / `$` 가 섞여도 깨지지 않도록 `sed` 로 escape 후 `display notification` 호출 |
| B3 | 재귀 방지 | `CLAUDE_SUMMARY_HOOK_RUNNING=1` 환경 변수 전파로 자식 `claude -p` 호출이 다시 Stop hook을 발화하지 않도록 차단 |
| B4 | JSONL-aware 파싱 | `transcript_path` 마지막 30라인에서 `jq` 로 user/assistant `text` 만 추출 — tool_use·tool_result JSON 래퍼 제거 |
| B5 | 길이 캡 분리 | 음성 `SUMMARY_MAX_CHARS` (기본 600자), 알림 `NOTIFY_MAX_CHARS` (기본 240자) 로 분리해 잡음 방지 |
| B6 | macOS 가드 | `uname` 으로 비-Darwin 환경 즉시 종료 |
| B7 | STOP_REASON 분기 | `interrupted` 면 짧은 알림만, 음성·LLM 호출 생략 |
| B8 | 비밀 토큰 마스킹 | LLM 으로 보내기 전에 `sk-…` / `ghp_…` / `Bearer …` / `AKIA…` / `xox[a-z]-…` / `AIza…` 등 흔한 키 패턴을 `***REDACTED***` 로 치환 |
| B9 | 영구 로그 경로 | `~/Library/Logs/cc-jarvis/` 에 저장 — 재부팅 후에도 보존, Console.app 열람 가능 |

---

## 설정 (session_summary.conf)

`session_summary.conf` 는 단순한 `KEY=VALUE` 쉘 파일입니다. 누락된 키는 `session_summary.sh` 가 기본값으로 자동 보완하므로 **기존 사용자의 conf 를 건드리지 않고도 신규 동작이 적용**됩니다.

| 키 | 기본값 | 설명 |
| --- | --- | --- |
| `ENABLED` | `true` | `false` 면 hook 즉시 종료 — 알림·음성·LLM 호출 없음 |
| `VOICE` | `Yuna` | macOS `say` 음성. `say -v "?" \| grep ko_KR` 로 사용 가능 음성 확인 |
| `RATE` | (빈 값) | 읽기 속도(단어/분). 빈 값이면 시스템 기본 (~175). 한국어 음성은 `200~230` 권장 |
| `MODEL` | `claude-haiku-4-5` | 요약 모델. `claude -p --model` 에 그대로 전달 |
| `SUMMARY_MAX_CHARS` | `600` | 음성으로 읽을 텍스트 최대 길이(약 25~30초). 너무 길게 떠드는 것 방지 |
| `NOTIFY_MAX_CHARS` | `240` | 알림에 노출할 텍스트 최대 길이 (macOS 알림은 ~256자에서 잘림) |
| `NOTIFY_TITLE` | `🤖 Claude 작업 완료` | 데스크톱 알림 타이틀 |

### conf 위치

- **마켓플레이스 설치**: `/plugin` 메뉴에서 확인 가능한 플러그인 설치 경로 아래 `hooks/session_summary.conf`
- **수동 설치**: `~/.claude/hooks/session_summary.conf`

### 자주 쓰는 토글

```bash
# 마켓플레이스 설치 conf 직접 편집
sed -i "" 's/^ENABLED=true/ENABLED=false/' \
  ~/.claude/plugins/<install-root>/cc-jarvis/hooks/session_summary.conf

# 수동 설치 토글 명령 (gs-config)
ln -s "$(pwd)/plugins/cc-jarvis/hooks/gs-config" ~/bin/gs-config
gs-config   # true ↔ false 토글
```

### STOP_REASON 분기

사용자가 ESC로 응답을 중단한 경우(`stop_reason=interrupted`) hook은 **짧은 알림만 표시하고 음성·LLM 호출은 생략**합니다. 잡음을 줄이는 자동 안전망입니다.

### `say` MCP 도구와의 중복 주의

전역 `CLAUDE.md` 에 "답변 마지막에 say 도구로 1~2문장 읽어주기" 같은 규칙이 있으면, 응답 종료 시 **세션 안에서 한 번 + Stop hook 에서 한 번 = 두 번 들리는** 현상이 발생할 수 있습니다. 이 경우:

- 둘 중 하나만 남기는 게 깔끔합니다 (cc-jarvis 만 쓰는 걸 권장 — 프롬프트가 자비스 캐릭터에 맞춰져 있음)
- `CLAUDE.md` 의 say 룰을 제거하거나, cc-jarvis 의 `ENABLED=false` 로 끔

### 로그 경로

- 요약 결과: `~/Library/Logs/cc-jarvis/summary_<repo>_<ts>.txt`
- 마지막 hook stdin: `~/Library/Logs/cc-jarvis/last_hook_input.json`
- LLM 호출 stderr: `~/Library/Logs/cc-jarvis/last_error.log`

> 7일 이상 지난 요약 파일은 hook 실행 시 3% 확률로 자동 정리됩니다. 재부팅 후에도 보존됩니다(과거 `/tmp` 와 달리).

---

## /jarvis-replay — 마지막 보고 다시 듣기

`~/Library/Logs/cc-jarvis/` 에 저장된 가장 최신 요약 파일을 conf 의 음성·속도로 다시 재생합니다.

```
/jarvis-replay
```

- 알림은 다시 띄우지 않고 음성만 재생
- 요약 본문도 화면에 출력
- 재생할 파일이 없으면 안내 메시지

내부적으로 [hooks/jarvis_replay.sh](hooks/jarvis_replay.sh) 를 호출합니다.

---

## 트러블슈팅

| 증상 | 원인 / 대응 |
| --- | --- |
| 알림은 뜨는데 음성이 안 들림 | Yuna 음성 미설치 — `say -v "?" \| grep ko_KR` 로 확인 후 시스템 설정에서 다운로드 |
| 알림도 음성도 없음 | 플러그인이 활성화되어 있는지 (`/plugin` 메뉴), `session_summary.sh` 실행권한, `hooks.json` 인식 여부 확인 |
| LLM 요약이 비어서 실패 | `~/Library/Logs/cc-jarvis/last_error.log` 와 `last_hook_input.json` 확인. `claude -p --model $MODEL` 직접 호출이 되는지부터 검증 |
| hook 무한 재귀 의심 | `CLAUDE_SUMMARY_HOOK_RUNNING=1` 환경 변수 전파로 차단됨. `last_hook_input.json` 이 한 Stop 당 1회만 갱신되는지 확인 |
| Linux/Windows 에서 설치됨 | `uname` 가드로 즉시 exit 0 — hook 실행은 되지만 음성·알림 없음. macOS 전용입니다 |
| 음성이 너무 길게 떠듦 | `SUMMARY_MAX_CHARS` 를 더 작게 (예: `400`). 또는 `RATE` 를 `230` 으로 올려 빠르게 |
| 현재 세션 안에서 단독 실행 시 빈 응답 | 부모 Claude Code 세션의 OAuth 점유 영향. 실제 Stop 이벤트는 부모 응답 종료 시점에 발화하므로 일반 사용에서는 정상 동작 |
