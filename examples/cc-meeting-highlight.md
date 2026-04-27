# cc-meeting-highlight — 사용 예시

> macOS Apple Silicon 전용. mlx-whisper로 받아쓰기 → Claude로 토픽/하이라이트 선정 → Remotion으로 자막 합성.

## 첫 셋업

```bash
# 1. 마켓플레이스 + 플러그인
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-meeting-highlight@gaebalai-marketplace

# 2. 사용자 프로젝트에 자산 부트스트랩
cd <your-project>
bash "$(claude plugin path cc-meeting-highlight)/assets/scripts/bootstrap.sh"
```

## 풀 파이프라인

```bash
# 회의 소재 배치
mkdir -p meeting_rec/rec/2025_12_04
cp ~/Downloads/회의녹화_2025-12-04.mp4 meeting_rec/rec/2025_12_04/
cp ~/Downloads/회의요약.txt              meeting_rec/rec/2025_12_04/
```

Claude Code 세션에서:

```
/meeting-highlight
```

또는 자연어로:

```
오늘 1시간짜리 정기 회의 mp4를 60초 하이라이트로 만들어줘. 회의록 요약은 같은 폴더에 회의요약.txt로 있어.
```

## 자막 문구만 수정 (가장 빠른 반복)

```
meeting_rec/transcribe/highlights.json의 caption / subCaption을 수정했어. Phase 6 렌더링만 다시 돌려줘.
```

또는 직접:

```bash
cd meeting_rec/remotion
npx remotion render Highlight60 ../out/highlight_60s.mp4 \
  --props=../transcribe/highlights.json
```

Phase 5(클립 자르기)는 건너뜀 — 자막만 바뀌므로 클립 재인코딩 불필요.

## 30초 버전 / 90초 버전

```
같은 회의에서 30초 버전 highlights.json도 뽑아줘. 클립 2-3개로.
```

highlights-selector 스킬이 길이 인자를 받아 합계를 정확히 30초로 맞춥니다 (caption은 새로 작성).

## 한국 환경 트러블슈팅

| 증상 | 원인 | 대응 |
|---|---|---|
| 받아쓰기가 일본어로 흘러감 | `language` 미지정 | `20_transcribe.py`의 `language="ko"` 확인 (기본 적용됨) |
| 한글 글자 일부 깨짐 | 폰트 fallback | Noto Sans KR 적용 확인 ([Highlight60.tsx](../plugins/cc-meeting-highlight/assets/remotion/src/Highlight60.tsx)) |
| 한글 파일명 ffmpeg 에러 | NFD/NFC 차이 | Phase 0 symlink 레이어가 흡수 (자동) |
| 모델 다운로드 느림 | HF 사내망 | 다른 회선에서 캐시 받은 후 `~/.cache/huggingface` 동기화 |

## 사내 보안 정책

회의록을 외부 LLM에 올리는 게 금지된 환경이라면:

1. Phase 1·2는 로컬에서 끝남 (mlx-whisper, 외부 호출 없음)
2. Phase 3·4 진입 전에 `transcript.json`을 마스킹 처리:
   ```bash
   # 예: 인명/금액/고객사 마스킹
   sed -i.bak -E 's/[가-힣]{2,4} (대표|사장|부장|과장|차장|팀장)/[REDACTED] \1/g' \
     meeting_rec/transcribe/transcript.json
   ```
3. 마스킹 후에도 토픽 추출이 정상 동작하는지 dry-run

또는 Phase 3·4를 사내 LLM 게이트웨이 경유로 우회 (현 플러그인은 미지원, 사용자 직접 구성).
