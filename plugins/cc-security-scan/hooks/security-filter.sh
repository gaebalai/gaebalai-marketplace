#!/bin/bash
# security-filter.sh
# 스캔 결과의 원본 출력을 받아서, 8,000자 이내로 필터해서 반환
# 사용 방법: <스캔 명령> | bash ~/.claude/hooks/security-filter.sh

INPUT=$(cat)

# JSON 형식의 경우: Critical/High 만 추출해서 심각도 내림차순으로 정렬
FILTERED=$(echo "$INPUT" \
  | jq '[.[] | select(.severity == "critical" or .severity == "high" or .severity == "HIGH" or .severity == "CRITICAL")]
        | sort_by(.severity)
        | reverse' 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$FILTERED" ] && [ "$FILTERED" != "[]" ]; then
  echo "$FILTERED" | head -c 8000
else
  # JSON 이 아닌 경우: CRITICAL / HIGH / ERROR 행만 추출
  echo "$INPUT" | grep -E "CRITICAL|HIGH|ERROR|critical|high|error" | head -c 8000
fi
