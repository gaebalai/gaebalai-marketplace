# cc-meeting-highlight

> 회의 녹화 mp4를 60초 하이라이트 영상으로 자동 압축하는 macOS 전용 파이프라인.
> mlx-whisper로 받아쓰기 → Claude Code LLM으로 토픽·하이라이트 선정 → Remotion으로 자막 합성.

**플랫폼**: macOS Apple Silicon 전용 (mlx-whisper의 MLX 프레임워크 의존).

원작자 takatein 글의 "mlx-whisper × Remotion × Claude Code 파이프라인"을 한국어 회의 환경 기준으로 자산화한 플러그인입니다.

---

## 무엇이 들어 있나

### 슬래시 명령어
- [`/meeting-highlight`](commands/meeting-highlight.md) — 7-Phase 파이프라인 오케스트레이터

### 스킬 (Phase 3·4 LLM 단계)
- [`topics-extractor`](skills/topics-extractor/SKILL.md) — transcript + 회의록 요약 → topics.json
- [`highlights-selector`](skills/highlights-selector/SKILL.md) — topics.json → 60초 highlights.json

### 자산
- [`assets/scripts/`](assets/scripts/) — Phase 0·1·2·5 스크립트 (셸 3개 + Python 1개)
  - `00_setup_symlinks.sh` — 한글·일본어 파일명 ASCII symlink
  - `10_extract_audio.sh` — ffmpeg 16kHz mono WAV 추출
  - `20_transcribe.py` — mlx-whisper word-level 받아쓰기 (한국어 기본)
  - `50_cut_clips.sh` — ffmpeg 클립 잘라내기 (CFR 30fps, 캐시 판정 포함)
  - `bootstrap.sh` — 사용자 프로젝트로 자산 복사 + venv·npm 설치
- [`assets/remotion/`](assets/remotion/) — Remotion 4.x Highlight60 템플릿 (React 19 + Noto Sans KR)
- [`assets/schemas/`](assets/schemas/) — topics.json / highlights.json JSON Schema (검증용)

---

## 7-Phase 파이프라인

```
Phase 0  symlink 레이어 (한글·일본어 파일명 ASCII화)            [scripts/00]
Phase 1  음성 추출 (16kHz mono WAV)                            [scripts/10]
Phase 2  받아쓰기 (mlx-whisper, word-level timestamps)          [scripts/20]
Phase 3  토픽 추출 + 시각 매칭 (LLM)                            [skills/topics-extractor]
Phase 4  60초 하이라이트 선정 + 자막 작성 (LLM)                  [skills/highlights-selector]
Phase 5  클립 잘라내기 (CFR 30fps 재인코딩)                      [scripts/50]
Phase 6  Remotion 렌더링                                        [assets/remotion/]
```

---

## 빠른 시작

```bash
# 1. 마켓플레이스 등록 + 플러그인 설치
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-meeting-highlight@gaebalai-marketplace

# 2. 사용자 프로젝트에 자산 부트스트랩 (한 번만)
cd <your-project>
bash "$(claude plugin path cc-meeting-highlight)/assets/scripts/bootstrap.sh"

# 3. 회의 소재 배치
mkdir -p meeting_rec/rec/2025_12_04
cp ~/Downloads/회의녹화_2025-12-04.mp4 meeting_rec/rec/2025_12_04/
cp ~/Downloads/회의요약.txt           meeting_rec/rec/2025_12_04/

# 4. Claude Code 세션에서:
/meeting-highlight
```

자연어 트리거도 가능합니다:

```
이 회의 녹화 60초 하이라이트로 만들어줘
meeting_rec/rec/2025_12_04 받아쓰기 후 토픽 뽑아줘
```

---

## 사전 요건

| 항목 | 요건 |
|---|---|
| OS | macOS 14+ |
| CPU | Apple Silicon (M1 이상) |
| RAM | 16GB+ (모델 로드 + 영상 인코딩) |
| 디스크 | 10GB+ (Whisper 모델 1.5GB + Remotion 빌드 산출 + 클립) |
| Python | **3.11** (3.14는 mlx-whisper ImportError) |
| Node.js | 18+ |
| 패키지 | `brew install ffmpeg jq uv node` |

---

## 입력 / 출력

**입력**: `meeting_rec/rec/<날짜>/` 아래에
- `*.mp4` (회의 녹화 본체, 1개)
- `회의요약.txt` 또는 `geminiまとめ.txt` (Gemini Meet, Teams, 네이버 웍스, 카카오워크 등 어떤 도구의 요약이든 OK)
- `*.sbv` (선택, Google Meet 채팅 로그)

**출력**: `meeting_rec/out/highlight_60s.mp4` (1920×1080, 30fps, H.264 + AAC, 60초)

중간 산출:
- `meeting_rec/transcribe/transcript.json` — Phase 2
- `meeting_rec/transcribe/topics.json` — Phase 3
- `meeting_rec/transcribe/highlights.json` — Phase 4
- `meeting_rec/remotion/public/clips/clip_<id>.mp4` — Phase 5

---

## 한국 환경 보완 사항

이 플러그인은 다음 한국 환경 조건이 기본값으로 들어가 있습니다.

- **mlx-whisper 호출 시 `language="ko"` 명시** — 자동 감지가 일본어로 흘러가는 문제 회피 ([20_transcribe.py](assets/scripts/20_transcribe.py))
- **INITIAL_PROMPT에 한국 회사 자주 쓰는 용어** (OKR, KPI, MAU, PM, CTO 등) — 받아쓰기 정확도 향상
- **NFD/NFC 정규화 차이를 symlink로 흡수** — `회의녹화.mp4`처럼 한글 파일명도 안전 ([00_setup_symlinks.sh](assets/scripts/00_setup_symlinks.sh))
- **Noto Sans KR 폰트** — `@remotion/google-fonts/NotoSansKR`로 한글 자막 렌더링 ([Highlight60.tsx](assets/remotion/src/Highlight60.tsx))
- **자막 길이 한국어 기준** — caption 18자, subCaption 35자 권장 (모바일 가독성)
- **`wordBreak: keep-all`** — 한국어 어절 단위 줄바꿈

---

## 보안 / 사내 정책 주의

회의 녹화·회의록은 외부 클라우드 반출이 제한될 수 있습니다.

- Phase 2 받아쓰기는 **로컬에서 끝남** (mlx-whisper, 외부 API 호출 없음)
- Phase 3·4는 **Claude API에 transcript 전송** — 사내 데이터 분류 기준에 따라 마스킹(이름·계약 금액·고객사명) 후 호출 권장
- 회사가 Claude API 사용을 승인했는지 사전 확인

---

## 라이선스

MIT. 원문 글의 절차에서 영감을 받았으며 코드는 새로 작성됐습니다.
