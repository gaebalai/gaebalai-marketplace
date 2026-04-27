# Third-Party Notices

이 마켓플레이스의 플러그인은 다음 외부 라이브러리·자원을 런타임 의존성으로 사용합니다. 각각의 라이선스는 해당 프로젝트에서 확인하세요. 본 마켓플레이스 저장소에는 이들 자산을 직접 포함하지 않으며, 사용자가 설치/실행 시점에 정상 채널로 가져옵니다.

## cc-meeting-highlight

### Python (Phase 2 받아쓰기)
- [`mlx-whisper`](https://github.com/ml-explore/mlx-examples) — MIT (Apple)
- [`mlx`](https://github.com/ml-explore/mlx) — MIT (Apple)

### JavaScript / TypeScript (Phase 6 Remotion 렌더링)
- [`remotion`](https://github.com/remotion-dev/remotion) — Remotion License (개인/비영리 무료, 회사 사용 시 라이선스 필요. 자세한 사항은 https://remotion.pro/license 참조)
- [`@remotion/cli`](https://www.npmjs.com/package/@remotion/cli) — 동일 Remotion License
- [`@remotion/google-fonts`](https://www.npmjs.com/package/@remotion/google-fonts) — Apache-2.0
- [`@remotion/media-parser`](https://www.npmjs.com/package/@remotion/media-parser) — 동일 Remotion License
- [`react`](https://github.com/facebook/react) — MIT
- [`react-dom`](https://github.com/facebook/react) — MIT
- [Noto Sans KR (Google Fonts)](https://fonts.google.com/noto/specimen/Noto+Sans+KR) — SIL Open Font License 1.1

### 외부 도구
- `ffmpeg` — LGPL/GPL (Homebrew 배포본 기준)
- `jq` — MIT
- `uv` — Apache-2.0 OR MIT (Astral)

> **Remotion 라이선스 주의**: 회사(법인) 환경에서 cc-meeting-highlight를 사용하려는 경우 Remotion 상용 라이선스가 별도로 필요할 수 있습니다. 개인 사용·연구·오픈소스 기여는 무료. 본 플러그인은 Remotion 라이선스 조건 변경에 책임지지 않습니다.

## car-can-checker

### Python (Phase 2/4/5)
- [`python-can`](https://github.com/hardbyte/python-can) — LGPL-3.0
- [`cantools`](https://github.com/cantools/cantools) — MIT
- [`aiohttp`](https://github.com/aio-libs/aiohttp) — Apache-2.0
- [`numpy`](https://numpy.org/) — BSD-3-Clause
- [`pandas`](https://github.com/pandas-dev/pandas) — BSD-3-Clause
- [`matplotlib`](https://github.com/matplotlib/matplotlib) — Matplotlib License (BSD-style)
- [`scipy`](https://github.com/scipy/scipy) — BSD-3-Clause
- [`soundfile`](https://github.com/bastibe/python-soundfile) — BSD-3-Clause

### JavaScript (PWA 클라이언트)
- [`JSZip`](https://github.com/Stuk/jszip) — MIT or GPL-3.0 (CDN 로드)

### 외부 도구
- `ffmpeg` — LGPL/GPL
- `jq` — MIT
- `mkcert` — BSD-3-Clause (Filippo Valsorda)
- Go 컴파일러 (`golang-go`) — BSD-3-Clause + Patents

## cc-roundtable
외부 런타임 의존성 없음. 텍스트 자산만으로 동작.

## empirical-prompt-tuning
Claude Code Task tool / Claude API 외 추가 외부 의존성 없음.

---

## 본 저장소의 라이선스

마켓플레이스 자체 + 모든 플러그인 코드는 [MIT 라이선스](LICENSE)로 배포됩니다. 다만 사용자가 플러그인을 실행하려면 위 third-party 의존성을 각자의 라이선스 조건에 맞춰 설치·사용해야 합니다.

특히 **Remotion**(cc-meeting-highlight)과 **python-can LGPL**(car-can-checker)은 사용 환경에 따라 추가 검토가 필요합니다. 회사 환경에서 도입한다면 사내 법무·OSS 컴플라이언스 검토를 권장합니다.
