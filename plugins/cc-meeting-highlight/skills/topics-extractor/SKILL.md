---
name: topics-extractor
description: >
  회의 받아쓰기(transcript.json)와 회의록 요약 텍스트(예: Gemini Meet 요약, Teams 요약, 네이버 웍스 요약)를
  입력으로 받아, 회의에서 다뤄진 주요 토픽을 추출해 transcript의 word-level 타임스탬프와 매칭한
  topics.json을 생성합니다. "회의 토픽 뽑아줘", "topics.json 만들어줘", "회의 요약과 받아쓰기 매칭해줘"
  같은 표현에서 발동됩니다. cc-meeting-highlight 파이프라인의 Phase 3.
argument-hint: "[transcript.json 경로] [회의요약.txt 경로]"
---

# topics-extractor — 회의 토픽 × 시각 매칭

## 사명

회의 받아쓰기(transcript)와 회의록 요약(summary)을 결합해, 토픽별 시작/종료 타임스탬프를 가진 `topics.json`을 만듭니다. 이후 highlights-selector 스킬이 이 결과에서 60초 분량을 선정합니다.

## 입력

| 파일 | 역할 |
|---|---|
| `transcript.json` | mlx-whisper word-level 받아쓰기. `segments[].words[]`에 `word`, `start`, `end`. |
| `회의요약.txt` (또는 `geminiまとめ.txt`) | 회의록 요약. 토픽 단위로 줄/단락 구분된 텍스트. 어떤 도구가 만든 것이든 무관 (Gemini Meet, Teams, 네이버 웍스, 카카오워크, 수기 메모도 가능). |
| `Meeting Chat.sbv` (선택) | Google Meet 채팅 로그. 시각 앵커 보조. |

## 처리 절차

### 1. 입력 로드

```
transcript.json → segments[].text를 시간 순서로 이어 붙인 "full transcript" 생성
회의요약.txt → 토픽 단위 단락으로 분할 (보통 빈 줄, 들여쓰기, 또는 헤딩으로 구분됨)
```

### 2. 토픽 분할 (요약 기반)

회의요약 텍스트에서 다음 단서로 토픽을 분리합니다.

- 명시적 헤딩 (`##`, `■`, `▶`, `1.`, `[토픽1]` 등)
- 빈 줄로 구분된 단락
- 명사형 키워드 출현 빈도 변화

**최대 토픽 수**: 7개. 그보다 많으면 중요도가 낮은 것을 합치거나 제외.

### 3. 시각 매칭 (transcript 기반)

각 토픽에 대해 transcript에서 매칭되는 구간을 찾습니다.

**매칭 원리** (키워드 매칭이 아닌 의미적 매칭):

- 요약 단락의 핵심 명사·동사·고유명사를 추출
- transcript에서 해당 키워드들이 **밀집해서 등장하는 구간**을 찾음
- 시작 시각: 핵심 키워드가 처음 등장한 word의 `start`
- 종료 시각: 같은 토픽 키워드 클러스터가 끝나는 마지막 word의 `end`
- 토픽 간 시각이 겹쳐도 됨 (실제 회의에서는 흔함)

**시각 보조 단서**:
- Meeting Chat.sbv가 있다면 채팅의 키워드/시각을 앵커로 사용
- 회의요약이 시간 순서를 따른다고 가정 (대부분의 자동 요약은 그러함)

### 4. 출력 작성

```json
{
  "meeting_date": "2025_12_04",
  "totalDurationSec": 3612.5,
  "topics": [
    {
      "id": 1,
      "title": "12월 출시 일정 확정",
      "summary": "QA 마감일을 12/18 → 12/22로 조정. PM/엔지니어 합의.",
      "startSec": 245.3,
      "endSec": 412.8,
      "anchorTexts": [
        "그래서 QA 마감을 12월 22일로 미루는 게 어떻겠냐는...",
        "엔지니어 입장에서 12/18은 너무 빠듯해서..."
      ],
      "speakers": ["PM", "엔지니어 A"],
      "importance": 0.9
    }
  ]
}
```

**필드 설명:**

- `id`: 1부터 시작하는 정수
- `title`: 1줄 토픽명 (자막에 그대로 쓸 수 있게)
- `summary`: 1-2문장 요약
- `startSec` / `endSec`: transcript의 word-level 타임스탬프 기준
- `anchorTexts`: transcript에서 이 토픽을 대표하는 발언 1-3개 (디버깅/검증용)
- `speakers`: 발언자가 식별 가능하면 배열, 아니면 빈 배열 또는 `["미상"]`
- `importance`: 0.0~1.0. 회의 결과에 미치는 영향, 후속 액션 동반 여부, 의견 대립의 정도로 판단

### 5. 검증

출력 직전에 다음을 자체 점검합니다.

- [ ] 모든 `startSec` < `endSec`
- [ ] `endSec` <= `totalDurationSec`
- [ ] 토픽 수가 7개 이하
- [ ] 각 토픽의 `endSec - startSec`이 30초 이상 (그보다 짧으면 의미 있는 클립이 안 나옴)
- [ ] `anchorTexts`가 transcript에 실제 존재하는 표현인지 (LLM 환각 방지)

검증 실패 항목은 출력 후 사용자에게 명시적으로 보고합니다.

## 출력 위치

기본: `meeting_rec/transcribe/topics.json`

호출자가 명시적 경로를 지정한 경우 그쪽을 우선합니다.

## 주의사항

- **transcript는 진실, 요약은 가이드**: 시각은 반드시 transcript에서 찾습니다. 요약 텍스트는 토픽 분할의 단서일 뿐 시각 출처가 아닙니다.
- **요약에 없는 토픽도 포함 가능**: 요약이 누락한 중요 발언(예: 의외의 결정, 예산 변경)을 transcript에서 발견하면 별도 토픽으로 추가하고 `summary` 끝에 `(요약에 없음)`을 표기.
- **고유명사 신뢰도**: mlx-whisper는 고유명사 받아쓰기 오류가 잦습니다. 회의요약에 명시된 고유명사가 transcript에 비슷한 음으로 잘못 적혀 있다면(예: "아키텍처" → "아키택처"), `anchorTexts`에는 transcript의 원문 그대로 적되 `title`/`summary`는 요약 기준으로 정정합니다.
- **한국어 회의 가정**: 입력은 기본적으로 한국어. 일본어/영어 혼용 회의도 처리하지만 출력의 `title`/`summary`는 회의의 주 언어를 따릅니다.

## 자주 빠지는 함정

- 요약 텍스트의 단락 수만큼 토픽을 만들려는 강박 — 일부 단락은 다른 토픽의 부연 설명일 수 있음. 합칠지 판단.
- transcript의 time gap을 토픽 경계로 오인 — 침묵 구간은 토픽 변경이 아닐 수 있음 (잠시 자료 확인 등).
- 시작 시각을 토픽 도입부 발언이 아닌 첫 키워드 등장 시점에 두는 실수 — 도입부("그래서 다음 주제는…") 5-10초를 포함하는 편이 자막 영상에서 자연스럽다.

## 다음 단계

`topics.json` 작성이 끝나면 highlights-selector 스킬을 호출해 60초 분량의 `highlights.json`을 만듭니다.
