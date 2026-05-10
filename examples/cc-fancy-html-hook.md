# cc-fancy-html-hook — 사용 예시

> macOS / Windows 모두 지원. 설치 후 별도 트리거 없음 — Claude Code가 `.md` 파일을 Write/Edit 할 때마다 다이얼로그가 떠서 일반 HTML과 팬시 HTML(인포그래픽 스타일) 생성을 묻습니다.

## 첫 셋업

```bash
# 1. 마켓플레이스 등록 (1회)
/plugin marketplace add gaebalai/gaebalai-marketplace

# 2. 플러그인 설치
/plugin install cc-fancy-html-hook@gaebalai-marketplace
```

설치 시 [hooks/hooks.json](../plugins/cc-fancy-html-hook/hooks/hooks.json)이 Claude Code의 PostToolUse(Write/Edit/MultiEdit) 이벤트에 자동 연결됩니다. `~/.claude/settings.json` 수동 편집 불필요.

### 사용자 환경 사전 요건

```bash
# 공통: Python 3 + markdown 패키지
pip3 install --user markdown

# 공통: claude CLI (claude -p 서브 프로세스 호출용)
which claude

# macOS: osascript / open / awk
which osascript open awk

# Windows: pwsh 7+ 권장
pwsh -v
```

> PEP 668(`externally-managed-environment`)에 걸리면 hook 전용 venv를 권장합니다.
>
> ```bash
> python3 -m venv ~/.claude/venv
> ~/.claude/venv/bin/pip install markdown
> # 그리고 hooks/on-md-write.sh의 python3 경로를 ~/.claude/venv/bin/python으로 바꿔주세요.
> ```

## 동작 예시 1: 플랜 파일을 만들었을 때

Claude Code 세션에서 `PLAN.md`를 새로 작성하면 다이얼로그가 뜹니다.

```
┌─────────────────────────────────────────────┐
│  Markdown 파일이 업데이트되었습니다:         │
│                                             │
│       PLAN.md                               │
│                                             │
│  HTML 변환을 수행할까요?                    │
│                                             │
│         [건너뛰기]   [HTML 생성]            │
└─────────────────────────────────────────────┘
```

**HTML 생성** 선택 → `./.html/PLAN.md.html` 자동 생성. 다음 다이얼로그가 이어집니다.

```
┌─────────────────────────────────────────────┐
│  Markdown 파일이 생성되었습니다:             │
│                                             │
│       PLAN.md                               │
│                                             │
│  팬시 HTML(인포그래픽)도 생성할까요?         │
│                                             │
│  [No (일반 HTML만)]   [Yes (팬시 생성)]     │
└─────────────────────────────────────────────┘
```

- **No** → 일반 HTML만 브라우저로 즉시 오픈
- **Yes** → 일반 HTML 즉시 오픈 + 백그라운드에서 `claude -p`가 `./.html/PLAN.md.beautiful.html` 생성 (수십 초~수 분, 완료 시 알림 표시)

## 동작 예시 2: 변환 건너뛰기

다이얼로그에서 **건너뛰기** 또는 20초 무응답 → hook이 즉시 종료, 아무 파일도 생성하지 않음. Claude Code 세션은 영향 없음.

## 동작 예시 3: 자동 제외 대상

다음 경우는 hook이 다이얼로그조차 띄우지 않고 즉시 통과합니다.

- `.md`가 아닌 파일
- `CHANGELOG.md`, `CLAUDE.md`, `MEMORY.md` (자주 수정되어 흐름을 깨므로)
- `node_modules/`, `.html/`, `.claude/`, `.git/`, `.kiro/` 하위

수정하려면 [plugins/cc-fancy-html-hook/hooks/on-md-write.sh](../plugins/cc-fancy-html-hook/hooks/on-md-write.sh)의 `BASENAME_CHECK` / `case "$FILE_PATH"` 블록을 편집.

## 산출물 구조

```
PLAN.md
.html/
├── PLAN.md.html              # python-markdown 일반 변환
└── PLAN.md.beautiful.html    # claude -p 팬시 인포그래픽 (Yes 선택 시)
```

## 끄기 / 다시 켜기

특정 세션에서만 일시적으로 끄려면 다이얼로그에서 계속 **건너뛰기**를 선택하세요. 영구히 비활성화하려면 `/plugin disable cc-fancy-html-hook`.

## 트러블슈팅 빠른 점검

```bash
# 1. python-markdown 단독 동작
echo "# test" | python3 -c "import markdown,sys; print(markdown.markdown(sys.stdin.read()))"

# 2. osascript 다이얼로그 단독 동작 (macOS)
osascript -e 'display dialog "test" buttons {"OK"} default button 1'

# 3. claude -p 단독 동작 (팬시 HTML 생성기)
echo "# Hello" | claude -p --tools "" --output-format text "이 Markdown을 HTML로 바꿔줘"

# 4. 백그라운드 claude -p 프로세스 확인
ps aux | grep "claude -p" | grep -v grep
```

## 주의사항

- **API 토큰 사용량.** 자식 `claude -p` 프로세스도 별도로 토큰을 소비합니다. Claude Pro / Max 정액 구독의 weekly limit에도 합산되므로, `.md`를 자주 만드는 워크플로우에서는 누적 비용을 미리 점검하세요.
- **Markdown을 자주 저장하는 작업에는 부적합.** 블로그 작성처럼 `.md`를 수십 번 저장하는 흐름이라면 매번 다이얼로그가 떠서 흐름이 끊깁니다. "문서/플랜 파일을 만들고 사람이 리뷰" 같은 저빈도 생성 워크플로우에 어울립니다.
- **백그라운드 실행.** Claude Code의 hook은 동기 실행이므로, 팬시 HTML 생성은 macOS Bash `&` / Windows `Start-Job`으로 분리해 부모 Claude Code가 멈추지 않게 합니다.

자세한 내부 동작·코드 펜스 후처리·WSL2 대체 명령은 [plugins/cc-fancy-html-hook/README.md](../plugins/cc-fancy-html-hook/README.md) 참고.
