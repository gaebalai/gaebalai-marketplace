# cc-fancy-html-hook

Claude Code가 Markdown을 작성하는 순간,

1. **일반 HTML**(플레인 스타일 — macOS는 AppleGothic, Windows는 맑은 고딕을 우선 폰트로 사용)
2. **팬시 HTML**(`claude -p`를 서브 프로세스로 실행하여 생성하는 인포그래픽 스타일 HTML)

을 자동으로 `.html/` 디렉터리에 출력하고, 브라우저로 열어 주는 hook 스크립트입니다.
**macOS**(Bash + AppleScript)와 **Windows**(PowerShell + WinForms) 양쪽을 지원합니다.

매번 다이얼로그로 "HTML을 생성할까요?", "팬시도 만들까요?"를 물어보는 대화형 방식입니다.

## 설치 (권장: gaebalai-marketplace)

이 플러그인은 [gaebalai/gaebalai-marketplace](https://github.com/gaebalai/gaebalai-marketplace)에 등록되어 있어, Claude Code의 플러그인 시스템으로 한 줄에 설치할 수 있습니다. 별도의 `~/.claude/settings.json` 편집 / 스크립트 복사 / `chmod +x` 불필요.

```
# 1. 마켓플레이스 등록 (1회)
/plugin marketplace add gaebalai/gaebalai-marketplace

# 2. 플러그인 설치
/plugin install cc-fancy-html-hook@gaebalai-marketplace
```

설치하면 [hooks/hooks.json](hooks/hooks.json)이 Claude Code의 `PostToolUse` (Write/Edit/MultiEdit)에 자동 연결되며, macOS에서는 `on-md-write.sh`, Windows에서는 `on-md-write.ps1`이 각각 호출됩니다.

> Python `markdown` 패키지 설치는 별도로 필요합니다. 아래 [필요한 것](#필요한-것) 섹션을 참고하세요.

## 동작 개요

```
Claude Code가 *.md를 Write/Edit
        ↓ PostToolUse hook (JSON over stdin)
on-md-write.sh  (macOS)        |  on-md-write.ps1  (Windows)
   ├─ 확인 다이얼로그           |     ├─ 확인 다이얼로그
   │   (osascript display dialog)|     │   (System.Windows.Forms.MessageBox)
   ├─ python-markdown 으로       |     ├─ python-markdown 으로
   │   일반 HTML 생성            |     │   일반 HTML 생성
   ├─ (선택) claude -p 를         |     ├─ (선택) claude -p 를
   │   백그라운드(`&`)로 실행해   |     │   Start-Job 백그라운드로 실행해
   │   팬시 HTML 생성            |     │   팬시 HTML 생성
   ├─ 출력의 ```html``` 펜스 제거  |     ├─ 출력의 ```html``` 펜스 제거
   └─ open 으로 브라우저 표시    |     └─ Start-Process 로 브라우저 표시
```

## 필요한 것

### 공통
- [Claude Code](https://docs.claude.com/claude-code) CLI(`claude -p`를 서브 프로세스로 호출)
- Python 3 + `markdown` 패키지

### macOS
- macOS(`osascript` / `display dialog` / `open`을 사용)
- Bash, `awk`(BSD awk 호환)

### Windows
- Windows 10/11
- **PowerShell 7+ (`pwsh`) 권장.** Windows PowerShell 5.1에서도 동작하지만, 한국어 메시지 인코딩이 깨질 수 있습니다.
- `python` 또는 `py` 런처가 PATH에 등록되어 있을 것

### Python 패키지 설치

```bash
# macOS / Linux
pip3 install --user markdown

# Windows
pip install --user markdown
# 또는
py -m pip install --user markdown
```

> **PEP 668 (`externally-managed-environment`) 회피**
> 최신 macOS / 일부 Linux 배포판은 시스템 Python에 대한 `pip install`을 막아둡니다. 다음 중 하나를 사용하세요.
>
> ```bash
> # 옵션 1: 사용자 영역에 설치 (가장 간단)
> pip3 install --user markdown
>
> # 옵션 2: hook 전용 venv (실무에서 가장 깔끔)
> python3 -m venv ~/.claude/venv
> ~/.claude/venv/bin/pip install markdown
> # 그리고 스크립트의 `python3` 호출부를 ~/.claude/venv/bin/python으로 바꿔주세요.
> ```

## 수동 설치 (마켓플레이스를 쓰지 않는 경우)

마켓플레이스를 쓰지 않고 hook을 직접 `~/.claude/`에 꽂고 싶을 때만 아래를 따르세요. 위의 [설치 (권장: gaebalai-marketplace)](#설치-권장-gaebalai-marketplace) 흐름이 더 단순하고 업데이트도 `/plugin update`로 자동입니다.

### macOS

```bash
# 1. 저장소 clone (또는 gaebalai-marketplace clone 후 plugins/cc-fancy-html-hook으로 이동)
git clone https://github.com/gaebalai/gaebalai-marketplace.git
cd gaebalai-marketplace/plugins/cc-fancy-html-hook

# 2. hook 스크립트를 ~/.claude/hooks/에 배치
mkdir -p ~/.claude/hooks
cp hooks/on-md-write.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/on-md-write.sh

# 3. ~/.claude/settings.json에 PostToolUse hook 등록
#    settings.example.json을 참고해 병합하세요
```

`settings.example.json` (macOS):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/on-md-write.sh" }
        ]
      }
    ]
  }
}
```

### Windows (PowerShell)

```powershell
# 1. 저장소 clone
git clone https://github.com/gaebalai/gaebalai-marketplace.git
cd gaebalai-marketplace\plugins\cc-fancy-html-hook

# 2. hook 스크립트를 %USERPROFILE%\.claude\hooks\에 배치
$hookDir = Join-Path $env:USERPROFILE '.claude\hooks'
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
Copy-Item .\hooks\on-md-write.ps1 $hookDir

# 3. (선택) 현재 사용자에 한해 스크립트 실행 정책 허용
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 4. %USERPROFILE%\.claude\settings.json 에 PostToolUse hook 등록
#    settings.example.windows.json을 참고해 병합하세요
```

`settings.example.windows.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\hooks\\on-md-write.ps1\""
          }
        ]
      }
    ]
  }
}
```

> Windows PowerShell 5.1만 사용 가능한 환경(예: 사내 PC)이라면 `pwsh`를 `powershell`로 바꿔도 동작합니다. 다만 한국어 다이얼로그 메시지가 깨질 수 있으니 가능하면 [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) 설치를 권장합니다.
>
> 회사 보안 정책으로 PowerShell 스크립트 실행이 막혀 있을 수 있습니다. 사내 PC 적용 전에 IT 정책을 확인하세요.

### WSL2 (Ubuntu)

WSL2에서는 macOS용 `on-md-write.sh`를 그대로 쓰되, 다이얼로그/브라우저 열기 부분을 다음과 같이 치환해야 합니다.

| macOS                       | WSL2 대체                                          |
| --------------------------- | -------------------------------------------------- |
| `osascript display dialog`  | `zenity --question` (apt: `sudo apt install zenity`) |
| `osascript display notification` | `notify-send` (apt: `libnotify-bin`)           |
| `open <file>`               | `wslview <file>` 또는 `cmd.exe /c start "" <wsl경로의 windows 형식>` |

`wslview`는 `wslu` 패키지로 설치합니다(`sudo apt install wslu`).

## 디렉터리 구성

```
.
├── .claude-plugin/
│   └── plugin.json                # 마켓플레이스 매니페스트 (이름·버전·hooks 경로)
├── README.md
├── LICENSE                        # MIT
├── hooks/
│   ├── hooks.json                 # PostToolUse 자동 등록 정의 (sh + ps1 모두)
│   ├── on-md-write.sh             # macOS / Linux용 본체 스크립트
│   └── on-md-write.ps1            # Windows PowerShell용 본체 스크립트
├── settings.example.json           # macOS용 수동 hook 등록 예시
└── settings.example.windows.json   # Windows용 수동 hook 등록 예시
```

## 보완 사항 / 주의점

- **기본 폰트는 OS별로 분기.** 일반 HTML의 `<style>` 블록은 macOS에서 `AppleGothic, 'Apple SD Gothic Neo', -apple-system, BlinkMacSystemFont, sans-serif` 순으로, Windows에서 `'Malgun Gothic', '맑은 고딕', 'Segoe UI', Tahoma, sans-serif` 순으로 폴백을 잡습니다. 다른 폰트로 바꾸고 싶으면 [hooks/on-md-write.sh:72](hooks/on-md-write.sh#L72) (macOS) 또는 [hooks/on-md-write.ps1:98](hooks/on-md-write.ps1#L98) (Windows)의 `font-family` 한 줄만 수정하세요. 팬시 HTML은 `claude -p`가 자유롭게 디자인하므로 이 설정의 영향을 받지 않습니다.
- **코드 펜스 자동 제거.** `claude -p`의 출력은 종종 ```` ```html ... ``` ```` 펜스로 감싸져 나옵니다. 이 hook은 awk(macOS) / PowerShell(Windows)에서 첫 줄과 마지막 줄의 펜스를 후처리로 떼어냅니다. 그래도 가운데에 펜스가 박혀 나오는 경우가 있다면 프롬프트를 추가로 강화하세요.
- **Markdown 본문은 stdin 전달.** `claude -p`의 인자에 본문을 끼워 넣으면 `ARG_MAX`를 넘기거나 `ps`로 본문이 노출될 위험이 있습니다. 두 스크립트 모두 stdin으로 전달합니다.
- **백그라운드 실행 필수.** Claude Code의 hook은 동기 실행입니다. 팬시 HTML 생성은 수십 초 ~ 수 분 걸리므로, macOS는 Bash `&`, Windows는 `Start-Job`으로 분리해 부모 Claude Code가 멈추지 않게 합니다.
- **API 토큰 사용량.** 자식 `claude -p` 프로세스도 별도로 토큰을 소비합니다. Claude Pro / Max 정액 구독의 weekly limit에도 합산되니 `.md`를 자주 만드는 워크플로우에서는 비용이 누적될 수 있습니다. 회사 단위로 Claude API를 쓰는 환경이라면 hook을 켜기 전에 팀의 토큰 예산 정책을 확인하세요.
- **Markdown을 자주 저장하는 작업에는 부적합.** 블로그 작성처럼 `.md`를 수십 번 저장하는 작업이라면 매번 다이얼로그가 떠서 흐름이 끊깁니다. "문서/플랜 파일을 만들고 사람이 리뷰" 같은 저빈도 생성 워크플로우에 어울립니다.

## 라이선스

MIT
