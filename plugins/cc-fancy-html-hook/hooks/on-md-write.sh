#!/bin/bash
# Claude Code Hook: .md 파일이 작성되었을 때, .html/ 디렉터리에 HTML 변환본을 저장
# PostToolUse (Write, Edit)에서 호출됨
# 사용자의 선택에 따라 "팬시 HTML"도 생성 가능

INPUT=$(cat)

# tool_input.file_path 추출
FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('file_path', ''))
" 2>/dev/null)

# .md 파일이 아니면 아무것도 하지 않음
if [[ ! "$FILE_PATH" == *.md ]]; then
    exit 0
fi

# 파일이 존재하지 않으면 아무것도 하지 않음
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# 제외: 특정 파일명, 특정 디렉터리 하위
BASENAME_CHECK=$(basename "$FILE_PATH")
case "$BASENAME_CHECK" in
    CHANGELOG.md|CLAUDE.md|MEMORY.md) exit 0 ;;
esac
case "$FILE_PATH" in
    */node_modules/*|*/.html/*|*/.claude/*|*/.git/*|*/.kiro/*) exit 0 ;;
esac

# MD→HTML 변환 여부를 다이얼로그로 확인
DO_CONVERT=$(osascript -e "
set theFile to \"$(basename "$FILE_PATH")\"
set theResult to button returned of (display dialog \"Markdown 파일이 업데이트되었습니다:\" & return & return & theFile & return & return & \"HTML 변환을 수행할까요?\" buttons {\"건너뛰기\", \"HTML 생성\"} default button 2 with title \"MD → HTML Hook\" giving up after 20)
return theResult
" 2>/dev/null)

# "건너뛰기" 또는 gave up (타임아웃)인 경우 아무것도 하지 않음
if [[ "$DO_CONVERT" != "HTML 생성" ]]; then
    exit 0
fi

# 출력 디렉터리와 파일명 결정
DIR=$(dirname "$FILE_PATH")
BASENAME=$(basename "$FILE_PATH")
HTML_DIR="${DIR}/.html"
HTML_FILE="${HTML_DIR}/${BASENAME}.html"
BEAUTIFUL_FILE="${HTML_DIR}/${BASENAME}.beautiful.html"

# .html/ 디렉터리 생성
mkdir -p "$HTML_DIR"

# python-markdown으로 일반 변환
python3 -c "
import markdown, sys, pathlib

src = pathlib.Path(sys.argv[1])
text = src.read_text(encoding='utf-8')
html_body = markdown.markdown(text, extensions=['tables', 'fenced_code', 'toc', 'nl2br'])

html_doc = f'''<!DOCTYPE html>
<html lang=\"ko\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<title>{src.stem}</title>
<style>
  body {{ font-family: 'AppleGothic', 'Apple SD Gothic Neo', -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 2em auto; padding: 0 1em; line-height: 1.6; color: #333; }}
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
</html>'''

pathlib.Path(sys.argv[2]).write_text(html_doc, encoding='utf-8')
" "$FILE_PATH" "$HTML_FILE" 2>/dev/null

# 팬시 HTML 변환 여부를 다이얼로그로 확인
CHOICE=$(osascript -e "
set theFile to \"$BASENAME\"
set theResult to button returned of (display dialog \"Markdown 파일이 생성되었습니다:\" & return & return & theFile & return & return & \"팬시 HTML(인포그래픽)도 생성할까요?\" buttons {\"No (일반 HTML만)\", \"Yes (팬시 생성)\"} default button 1 with title \"MD → HTML Hook\" giving up after 15)
return theResult
" 2>/dev/null)

if [[ "$CHOICE" == "Yes (팬시 생성)" ]]; then
    # 백그라운드에서 claude -p로 팬시 HTML 생성
    # - Markdown 본문은 stdin으로 전달 (ARG_MAX 초과 / ps 노출 회피)
    # - 출력에 ```html ... ``` 펜스가 섞여 나오는 경우가 많아 awk로 후처리
    (
        claude -p --tools "" --output-format text "당신은 Markdown을 인포그래픽 스타일 HTML로 변환하는 전문가입니다.
다음 규칙을 반드시 준수하세요:
- 출력은 <!DOCTYPE html>로 시작하는 완전한 HTML 문서만
- 설명문, 주석, 마크다운 코드 펜스(\`\`\`)는 일절 포함하지 않음
- draw.io 스타일의 도형, SVG 아이콘, CSS 애니메이션, 그라데이션을 적극 활용
- 정보를 유려하게 시각화한 인포그래픽 스타일 디자인
- 단일 HTML 파일로 완결(외부 리소스 참조 없음)

입력 Markdown은 표준 입력(stdin)으로 전달됩니다. 그 내용을 변환하세요." \
            < "$FILE_PATH" \
            | awk '
                { lines[++n] = $0 }
                END {
                    s = 1; e = n
                    if (n >= 1 && lines[1] ~ /^[[:space:]]*```[[:alnum:]]*[[:space:]]*$/) s = 2
                    if (n >= s && lines[n] ~ /^[[:space:]]*```[[:space:]]*$/)         e = n - 1
                    for (i = s; i <= e; i++) print lines[i]
                }
            ' > "$BEAUTIFUL_FILE"

        # 완료 알림 및 브라우저로 열기
        if [[ -s "$BEAUTIFUL_FILE" ]]; then
            open "$BEAUTIFUL_FILE" 2>/dev/null
            osascript -e "display notification \"팬시 HTML 생성 완료: $BASENAME.beautiful.html\" with title \"MD → HTML Hook\"" 2>/dev/null
        else
            osascript -e "display notification \"팬시 HTML 생성에 실패했습니다\" with title \"MD → HTML Hook\"" 2>/dev/null
        fi
    ) &

    # 일반 HTML도 브라우저로 열기
    open "$HTML_FILE" 2>/dev/null &
else
    # 일반 HTML만 브라우저로 열기
    open "$HTML_FILE" 2>/dev/null &
fi

exit 0
