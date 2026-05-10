#!/usr/bin/env pwsh
# Claude Code Hook (Windows PowerShell):
# .md 파일이 작성되었을 때, 같은 디렉터리의 .html\ 폴더에 HTML 변환본을 저장.
# PostToolUse (Write, Edit, MultiEdit)에서 호출됨.
# 사용자의 선택에 따라 "팬시 HTML"도 생성 가능.
#
# 권장 환경: PowerShell 7+ (`pwsh`).
# Windows PowerShell 5.1에서도 동작하지만, 한국어 메시지가 깨질 수 있으므로
# 가능하면 PowerShell 7+ 사용을 권장합니다.

$ErrorActionPreference = 'Continue'

# UTF-8 출력 보장 (PowerShell 5.1 한글 출력 대응)
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
} catch { }

# 1) stdin에서 hook JSON 읽기
$rawInput = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($rawInput)) { exit 0 }

try {
    $payload = $rawInput | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

$filePath = $null
if ($payload.PSObject.Properties.Name -contains 'tool_input' -and $payload.tool_input) {
    $filePath = $payload.tool_input.file_path
}
if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

# 2) .md 파일이 아니거나 존재하지 않으면 종료
if ($filePath -notmatch '\.md$') { exit 0 }
if (-not (Test-Path -LiteralPath $filePath)) { exit 0 }

# 3) 제외: 특정 파일명, 특정 디렉터리 하위
$baseName = Split-Path -Leaf $filePath
if ($baseName -in @('CHANGELOG.md', 'CLAUDE.md', 'MEMORY.md')) { exit 0 }

# Windows 백슬래시 / WSL 슬래시 경로 모두 대응
$normalizedPath = $filePath -replace '\\', '/'
$excludeDirs = @('node_modules', '.html', '.claude', '.git', '.kiro')
foreach ($d in $excludeDirs) {
    if ($normalizedPath -like "*/$d/*") { exit 0 }
}

# 4) Windows Forms 다이얼로그 준비
Add-Type -AssemblyName System.Windows.Forms | Out-Null

$msg1 = "Markdown 파일이 업데이트되었습니다:`r`n`r`n$baseName`r`n`r`nHTML 변환을 수행할까요?"
$convert = [System.Windows.Forms.MessageBox]::Show(
    $msg1,
    'MD → HTML Hook',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button1
)
if ($convert -ne [System.Windows.Forms.DialogResult]::Yes) { exit 0 }

# 5) 출력 경로 결정
$dir = Split-Path -Parent $filePath
$htmlDir = Join-Path $dir '.html'
$htmlFile = Join-Path $htmlDir "$baseName.html"
$beautifulFile = Join-Path $htmlDir "$baseName.beautiful.html"

New-Item -ItemType Directory -Force -Path $htmlDir | Out-Null

# 6) python-markdown으로 일반 HTML 생성
$pyExe = Get-Command python -ErrorAction SilentlyContinue
if (-not $pyExe) { $pyExe = Get-Command py -ErrorAction SilentlyContinue }
if (-not $pyExe) {
    [System.Windows.Forms.MessageBox]::Show(
        "Python을 찾을 수 없습니다.`r`n`r`npython 또는 py 런처가 PATH에 있어야 합니다.",
        'MD → HTML Hook',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$pyScript = @'
import markdown, sys, pathlib

src = pathlib.Path(sys.argv[1])
text = src.read_text(encoding="utf-8")
html_body = markdown.markdown(text, extensions=["tables", "fenced_code", "toc", "nl2br"])

html_doc = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{src.stem}</title>
<style>
  body {{ font-family: 'Malgun Gothic', '맑은 고딕', 'Segoe UI', Tahoma, sans-serif; max-width: 800px; margin: 2em auto; padding: 0 1em; line-height: 1.6; color: #333; }}
  pre {{ background: #f4f4f4; padding: 1em; overflow-x: auto; border-radius: 4px; }}
  code {{ background: #f4f4f4; padding: 0.2em 0.4em; border-radius: 3px; font-size: 0.9em; }}
  pre code {{ background: none; padding: 0; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ border: 1px solid #ddd; padding: 0.5em; text-align: left; }}
  th {{ background: #f4f4f4; }}
  blockquote {{ border-left: 4px solid #ddd; margin: 0; padding-left: 1em; color: #666; }}
  h1, h2, h3 {{ border-bottom: 1px solid #eee; padding-bottom: 0.3em; }}
</style>
</head>
<body>
{html_body}
</body>
</html>"""

pathlib.Path(sys.argv[2]).write_text(html_doc, encoding="utf-8")
'@

& $pyExe.Source -c $pyScript $filePath $htmlFile 2>$null

# 7) 팬시 HTML 변환 여부 확인
$msg2 = "Markdown 파일이 생성되었습니다:`r`n`r`n$baseName`r`n`r`n팬시 HTML(인포그래픽)도 생성할까요?"
$fancy = [System.Windows.Forms.MessageBox]::Show(
    $msg2,
    'MD → HTML Hook',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2
)

if ($fancy -eq [System.Windows.Forms.DialogResult]::Yes) {
    # 백그라운드 Job으로 claude -p 실행
    # - Markdown 본문은 stdin으로 전달 (긴 파일도 안전)
    # - 출력의 ```html ... ``` 코드 펜스는 후처리로 제거
    Start-Job -ScriptBlock {
        param($srcPath, $outPath)

        $prompt = @'
당신은 Markdown을 인포그래픽 스타일 HTML로 변환하는 전문가입니다.
다음 규칙을 반드시 준수하세요:
- 출력은 <!DOCTYPE html>로 시작하는 완전한 HTML 문서만
- 설명문, 주석, 마크다운 코드 펜스(```)는 일절 포함하지 않음
- draw.io 스타일의 도형, SVG 아이콘, CSS 애니메이션, 그라데이션을 적극 활용
- 정보를 유려하게 시각화한 인포그래픽 스타일 디자인
- 단일 HTML 파일로 완결(외부 리소스 참조 없음)

입력 Markdown은 표준 입력(stdin)으로 전달됩니다. 그 내용을 변환하세요.
'@

        try {
            $mdText = Get-Content -LiteralPath $srcPath -Raw -Encoding UTF8
            $rawHtml = $mdText | claude -p --tools '' --output-format text $prompt | Out-String

            # 첫 줄/마지막 줄에 코드 펜스가 있으면 제거
            $lines = $rawHtml -split "`r?`n"
            $start = 0
            $end = $lines.Length - 1
            if ($lines.Length -gt 0 -and $lines[0] -match '^\s*```[A-Za-z0-9]*\s*$') { $start = 1 }
            if ($end -ge $start -and $lines[$end] -match '^\s*```\s*$') { $end-- }

            if ($end -ge $start) {
                $cleaned = ($lines[$start..$end] -join "`n")
                Set-Content -LiteralPath $outPath -Value $cleaned -Encoding UTF8
            }

            if ((Test-Path -LiteralPath $outPath) -and (Get-Item -LiteralPath $outPath).Length -gt 0) {
                Start-Process $outPath
            }
        } catch {
            # Job 내부 오류는 부모로 전달되지 않음. 디버그가 필요하면 Receive-Job 활용.
        }
    } -ArgumentList $filePath, $beautifulFile | Out-Null

    # 일반 HTML도 즉시 브라우저로 열기
    Start-Process $htmlFile
} else {
    Start-Process $htmlFile
}

exit 0
