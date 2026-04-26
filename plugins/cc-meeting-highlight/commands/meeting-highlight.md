---
description: "회의 녹화 mp4 → 60초 하이라이트 영상 자동 생성 (macOS Apple Silicon 전용)"
argument-hint: "[--date YYYY_MM_DD] [--duration 60] [--meeting-rec-dir <path>]"
---

# /meeting-highlight — 회의 하이라이트 파이프라인

회의 녹화 mp4와 회의록 요약 텍스트를 입력으로 받아 60초 하이라이트 영상을 생성합니다.
**macOS Apple Silicon 전용**입니다 (mlx-whisper 의존).

## 인자

- `--date YYYY_MM_DD` (선택): 처리할 날짜 폴더. 미지정 시 `meeting_rec/rec/` 아래 가장 최신 폴더 자동 선택.
- `--duration <초>` (선택): 출력 영상 길이. 기본 60.
- `--meeting-rec-dir <path>` (선택): meeting_rec 디렉터리 경로. 기본 `./meeting_rec`.

## 사전 조건 검증

명령어 실행 시 다음을 순서대로 점검합니다.

### 1. 환경 점검

```bash
uname -m         # arm64 여야 함 (Apple Silicon)
sw_vers -productVersion  # 14 이상
which ffmpeg jq uv node  # 모두 설치돼 있어야 함
node --version   # v18 이상
```

미설치 항목이 있다면 사용자에게 다음을 안내:

```bash
brew install ffmpeg jq uv
brew install node
```

### 2. 프로젝트 구조 점검

`<meeting-rec-dir>` 아래에 다음이 있어야 합니다 (없으면 플러그인의 `assets/`에서 복사하도록 안내).

```
meeting_rec/
├── .venv/                   # Python 3.11 venv (없으면 생성 안내)
├── rec/<date>/              # 회의 소재
│   ├── *.mp4
│   └── 회의요약.txt 또는 geminiまとめ.txt
├── scripts/
│   ├── 00_setup_symlinks.sh
│   ├── 10_extract_audio.sh
│   ├── 20_transcribe.py
│   └── 50_cut_clips.sh
├── transcribe/              # 자동 생성됨
└── remotion/                # Remotion 4.x 프로젝트
    ├── package.json
    ├── src/
    └── public/
```

`scripts/`와 `remotion/`이 없으면 플러그인의 `${CLAUDE_PLUGIN_ROOT}/assets/scripts/`와 `${CLAUDE_PLUGIN_ROOT}/assets/remotion/`을 사용자 프로젝트로 복사하도록 안내합니다.

### 3. Python venv 점검

```bash
[ -f meeting_rec/.venv/bin/python ] || {
  uv venv --python 3.11 meeting_rec/.venv
  source meeting_rec/.venv/bin/activate
  uv pip install mlx-whisper
}
```

Python 3.14 venv가 있으면 **반드시 삭제 후 3.11로 재생성**(mlx-whisper의 ImportError 회피).

## 실행 절차

### Phase 0: symlink 레이어

```bash
bash meeting_rec/scripts/00_setup_symlinks.sh ${DATE:+--date $DATE}
```

한글·일본어 파일명을 ASCII로 symlink. `meeting_rec/rec/<date>/_links/`에 `meeting.mp4`, `summary.txt`, `chat.sbv`로 통일.

### Phase 1: 음성 추출

```bash
bash meeting_rec/scripts/10_extract_audio.sh
```

16kHz mono WAV 추출. 출력: `meeting_rec/transcribe/audio.wav`.

### Phase 2: 받아쓰기 (mlx-whisper)

```bash
source meeting_rec/.venv/bin/activate
python meeting_rec/scripts/20_transcribe.py
```

- 모델: `mlx-community/whisper-large-v3-turbo`
- `language="ko"` 명시
- `condition_on_previous_text=False` (반복 루프 방지)
- 출력: `meeting_rec/transcribe/transcript.json`

첫 실행은 모델 다운로드 1.5GB로 1-5분 추가.

### Phase 3: 토픽 추출 (LLM)

이 단계는 **topics-extractor 스킬**을 호출합니다.

```
Phase 3에서 topics-extractor 스킬을 발동하세요.
입력:
  transcript = meeting_rec/transcribe/transcript.json
  summary    = meeting_rec/rec/<date>/_links/summary.txt
출력: meeting_rec/transcribe/topics.json
```

### Phase 4: 60초 하이라이트 선정 (LLM)

이 단계는 **highlights-selector 스킬**을 호출합니다.

```
Phase 4에서 highlights-selector 스킬을 발동하세요.
입력:
  topics = meeting_rec/transcribe/topics.json
  duration = ${DURATION:-60}
출력: meeting_rec/transcribe/highlights.json
```

### Phase 5: 클립 잘라내기

```bash
bash meeting_rec/scripts/50_cut_clips.sh
```

- 입력: `meeting_rec/transcribe/highlights.json`
- ffmpeg로 각 클립 잘라내기 (CFR 30fps 재인코딩, libx264 + aac)
- 출력: `meeting_rec/remotion/public/clips/clip_<id>.mp4` (Remotion staticFile에서 참조 가능한 위치)
- 캐시: `highlights.json`의 해당 클립 정보가 변하지 않으면 재인코딩 건너뜀

### Phase 6: Remotion 렌더링

```bash
cd meeting_rec/remotion
npx remotion render Highlight60 ../out/highlight_60s.mp4 \
  --props=../transcribe/highlights.json \
  --concurrency=4
```

Chromium Headless Shell이 첫 실행 시 자동 다운로드(약 90MB).

완료 후 `open meeting_rec/out/highlight_60s.mp4`로 결과 확인.

## 부분 실행 / 재실행 패턴

### 자막 문구만 수정

```bash
# highlights.json의 caption/subCaption 편집 후
cd meeting_rec/remotion
npx remotion render Highlight60 ../out/highlight_60s.mp4 \
  --props=../transcribe/highlights.json
```

Phase 5는 건너뜀 (클립 자체는 그대로).

### 클립 구간만 변경

```bash
# highlights.json의 sourceStartSec/sourceEndSec 편집 후
bash meeting_rec/scripts/50_cut_clips.sh   # 변경된 클립만 재인코딩
cd meeting_rec/remotion
npx remotion render Highlight60 ../out/highlight_60s.mp4 \
  --props=../transcribe/highlights.json
```

### Remotion Studio (실시간 미리보기)

```bash
cd meeting_rec/remotion
npx remotion studio
```

`http://localhost:3000`에서 자막·레이아웃 미세 조정.

## 보안 / 사내 정책 주의

회의 녹화·회의록은 사내 정보보호 정책상 외부 클라우드 반출이 제한될 수 있습니다.

- **Phase 2 받아쓰기는 로컬에서 끝남** (mlx-whisper, 외부 API 호출 없음)
- **Phase 3·4는 Claude API에 transcript와 회의록을 전송** (Claude Code 경유)
- 사내 데이터 분류 기준에 따라 **마스킹**(이름·계약 금액·고객사명) 후 호출 권장
- 회사가 Claude API 사용을 승인했는지 사전 확인

## 트러블슈팅

| 증상 | 원인 | 대처 |
|---|---|---|
| `ImportError: cannot import name 'X' from 'mlx_whisper'` | Python 3.14 venv | venv 삭제 후 3.11로 재생성 |
| 받아쓰기 후반부가 같은 문장으로 도배 | `condition_on_previous_text=True` | `CONDITION_PREV=0 FORCE=1 python scripts/20_transcribe.py` |
| 자동 감지가 일본어로 흘러감 | `language` 미지정 | `20_transcribe.py`의 `language="ko"` 확인 |
| Remotion `loadFont` 에러 | 패키지 버전 충돌 | `loadFont()` 인수 없이 호출 |
| 한글 자막에 일부 글자 깨짐 | 일본어 폰트 fallback | `assets/remotion/src/fonts.ts`의 `noto-sans-kr` 서브셋 확인 |
| 한글 파일명 ffmpeg 에러 | NFD/NFC 정규화 차이 | Phase 0의 symlink 레이어 사용 (이미 적용됨) |
| HF 모델 다운로드 실패 | 사내망 차단 | 다른 회선에서 캐시 받은 후 `~/.cache/huggingface` 동기화 |

## 결과물

```
meeting_rec/
├── transcribe/
│   ├── transcript.json    # Phase 2
│   ├── topics.json        # Phase 3
│   └── highlights.json    # Phase 4
├── remotion/public/clips/
│   ├── clip_1.mp4         # Phase 5
│   └── ...
└── out/
    └── highlight_60s.mp4  # Phase 6 (최종)
```
