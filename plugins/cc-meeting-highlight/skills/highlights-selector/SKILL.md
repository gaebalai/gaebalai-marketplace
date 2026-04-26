---
name: highlights-selector
description: >
  topics.json에서 중요도 상위 토픽을 선정해 60초 하이라이트 영상용 highlights.json을
  생성합니다. 각 클립의 자막(caption/subCaption), 시작·종료 시각, src 경로를 결정하고
  합계 60초를 정확히 맞춥니다. "60초 하이라이트 만들어줘", "highlights.json 만들어줘"
  같은 표현에서 발동됩니다. cc-meeting-highlight 파이프라인의 Phase 4.
argument-hint: "[topics.json 경로] [총 길이 초, 기본 60]"
---

# highlights-selector — 60초 하이라이트 선정

## 사명

topics.json에서 상위 3-4개 토픽을 골라 합계 60초의 하이라이트 영상을 위한 `highlights.json`을 만듭니다. 각 클립의 자막 문구와 시각 구간이 핵심 산출물입니다.

## 입력

| 파일 | 역할 |
|---|---|
| `topics.json` | topics-extractor가 만든 토픽 목록 (`importance`, `startSec`, `endSec`, `summary` 포함) |
| 총 길이 (선택) | 기본 60초. 사용자가 30초·90초·3분 등을 지정할 수 있음 |

## 처리 절차

### 1. 클립 수 결정

| 총 길이 | 권장 클립 수 | 클립당 평균 길이 |
|---|---|---|
| 30초 | 2-3개 | 10-15초 |
| 60초 | 3-4개 | 15-20초 |
| 90초 | 4-5개 | 18-22초 |
| 3분 | 6-8개 | 22-30초 |

너무 잘게 쪼개면 영상이 정신없고, 너무 길게 잡으면 회의의 다양성이 안 보임. **3-4개 / 60초**가 가장 시청 경험이 좋다.

### 2. 토픽 선정

다음 우선순위로 선정합니다.

1. `importance`가 0.7 이상인 토픽 (의사결정·예산·일정 변경 등)
2. 의견 대립이 명시적으로 있는 토픽 (`anchorTexts`에 반대 발언이 있는지)
3. 액션 아이템이 도출된 토픽
4. 다양성 — 같은 주제 영역의 토픽 2개를 연속으로 넣지 않음

**제외 기준:**
- `endSec - startSec`이 너무 짧음 (15초 미만)
- `anchorTexts`가 비어있거나 토픽 요지를 못 담음
- 잡담·휴식 시간

### 3. 클립 구간 결정

각 선정 토픽에서 **가장 임팩트 있는 15-20초**를 잘라냅니다.

**구간 결정 원리:**
- 토픽의 핵심 발언이 transcript에 있는 시점 ±5초를 중심으로
- 문장 경계에서 시작/종료 (mlx-whisper의 segments 경계 활용)
- 도입부 빈 시간이나 침묵 구간은 피함
- `sourceStartSec`/`sourceEndSec`은 0.1초 단위까지 정확히

### 4. 자막(caption/subCaption) 작성

각 클립에 **2단 자막**을 답니다.

**caption (메인, 큰 글자, 최대 1줄)**
- 토픽의 결론·핵심 메시지
- 18자 이내 권장 (한국어 자막 가독성)
- 명사형 또는 동사형 한 문장

**subCaption (보조, 작은 글자, 1줄)**
- 발언자, 컨텍스트, 또는 액션 아이템
- 35자 이내
- "PM 김OO", "결정", "12/22까지" 같은 짧은 부연

**예시:**

| 토픽 | caption | subCaption |
|---|---|---|
| QA 마감 12/22로 변경 | "QA 마감, 12/22로 4일 연장" | "PM·엔지니어 합의 · 출시일 영향 없음" |
| 신규 채용 1명 승인 | "백엔드 1명 추가 채용 확정" | "1Q 안에 입사 목표 · 김OO이 채용 리드" |
| 마케팅 예산 30% 삭감 | "마케팅 예산 30% 삭감" | "이번 분기 한정 · 내년 1월 재논의" |

### 5. 길이 맞추기 (60초)

선정한 클립들의 `durationSec` 합이 정확히 60초가 되도록 조정합니다.

**조정 알고리즘:**

```
1. 각 클립을 18초로 일단 설정 → 4클립이면 72초, 3클립이면 54초
2. 4클립 시: 각 클립을 15초로 줄여 60초 (4 × 15)
3. 3클립 시: 평균 20초 (20 + 20 + 20) 또는 (18 + 22 + 20)으로 분배
4. 미세 조정: 핵심 발언 길이에 맞춰 ±2초씩 분배
5. 최종 합계가 정확히 60.0초가 되도록 마지막 클립의 endSec을 조정
```

총 길이 오차는 ±0.1초 이내로.

### 6. 출력 작성

```json
{
  "title": "12월 4일 정기 회의 하이라이트",
  "meeting_date": "2025_12_04",
  "totalDurationSec": 60,
  "fps": 30,
  "clips": [
    {
      "id": 1,
      "src": "clips/clip_1.mp4",
      "topic": "QA 마감 일정 변경",
      "caption": "QA 마감, 12/22로 4일 연장",
      "subCaption": "PM·엔지니어 합의 · 출시일 영향 없음",
      "sourceStartSec": 248.5,
      "sourceEndSec": 263.5,
      "durationSec": 15.0,
      "speakers": ["PM", "엔지니어 A"]
    },
    {
      "id": 2,
      "src": "clips/clip_2.mp4",
      "topic": "백엔드 채용",
      "caption": "백엔드 1명 추가 채용 확정",
      "subCaption": "1Q 입사 목표 · 채용 리드 김OO",
      "sourceStartSec": 1245.2,
      "sourceEndSec": 1260.2,
      "durationSec": 15.0,
      "speakers": ["CTO"]
    },
    {
      "id": 3,
      "src": "clips/clip_3.mp4",
      "topic": "마케팅 예산",
      "caption": "마케팅 예산 30% 삭감",
      "subCaption": "이번 분기 한정 · 1월 재논의",
      "sourceStartSec": 2103.0,
      "sourceEndSec": 2118.0,
      "durationSec": 15.0,
      "speakers": ["CFO"]
    },
    {
      "id": 4,
      "src": "clips/clip_4.mp4",
      "topic": "다음 회의 안건",
      "caption": "다음 회의: OKR 점검",
      "subCaption": "12/11 · 부서장 전원",
      "sourceStartSec": 3280.0,
      "sourceEndSec": 3295.0,
      "durationSec": 15.0,
      "speakers": ["PM"]
    }
  ]
}
```

**필드 설명:**

- `src`: Remotion 프로젝트의 `public/` 기준 상대경로. **`clips/clip_<id>.mp4` 패턴 고정** (Phase 5 cut_clips 스크립트가 이 패턴으로 출력)
- `sourceStartSec` / `sourceEndSec`: 원본 mp4 기준
- `durationSec`: `sourceEndSec - sourceStartSec`. 합계 = `totalDurationSec`
- `fps`: Phase 6 Remotion 렌더링 시 사용. 기본 30
- `speakers`: 자막 표시에 활용할 수 있음 (선택)

### 7. 검증

출력 직전 자체 점검:

- [ ] `clips[].durationSec`의 합 = `totalDurationSec` (오차 ≤ 0.1초)
- [ ] 모든 `src`가 `clips/clip_<id>.mp4` 패턴
- [ ] `id`가 1부터 연속
- [ ] 각 `caption`이 18자 이하, `subCaption`이 35자 이하
- [ ] 각 `sourceStartSec` < `sourceEndSec`
- [ ] 클립 시간 순서로 정렬되지 **않아도 됨** (영상에서는 id 순)

검증 실패 시 출력 직전에 자동 보정 또는 사용자에게 보고.

## 출력 위치

기본: `meeting_rec/transcribe/highlights.json`

## 자막 작성 가이드

- **결론을 먼저** — "QA 일정 변경 논의" (X) → "QA 마감 12/22로 연장" (O)
- **숫자 살리기** — 날짜, 금액, %, 인원수는 그대로 노출
- **호칭은 직책으로** — "김철수 PM"보다 "PM 김OO" (영상이 외부 공유될 수 있음)
- **부정형 자제** — "예산 안 깎기로 했음"보다 "예산 유지 결정"
- **물음표·느낌표 절제** — 공식 회의록 톤 유지

## 다음 단계

`highlights.json` 작성이 끝나면 Phase 5 (cut_clips.sh) → Phase 6 (Remotion 렌더링) 순서로 진행합니다.
