# Changelog

이 프로젝트의 모든 주목할 만한 변경 사항은 이 파일에 기록됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)을 따르며,
버전 관리는 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [Unreleased]

### Planned
- 자기 적용(dogfooding) 결과 `examples/self-eval-iter-1.md` 추가
- 기존 `gaebalai/cc-roundtable` 리포의 `.claude-plugin/marketplace.json` 정리 (마켓플레이스 통합 안내)

## [0.2.0] - 2026-04-26

### Added
- 플러그인 추가: **`cc-roundtable`** (다분야 전문가 토론 스킬)
  - [plugins/cc-roundtable/skills/start/](plugins/cc-roundtable/skills/start/) — SKILL 본체 + references 3개
  - 카테고리: `productivity`, 버전 1.0.0
- 마켓플레이스 매니페스트 형식 정렬 (cc-roundtable 매니페스트와 통일)
  - top-level `$schema`, `version`, `description` 추가
  - `owner.url` 추가, 이메일을 `jaewoo@mdrules.dev`로 통일
  - `plugins[].category`, `plugins[].tags` 추가
- 마켓플레이스 자산 [assets/logo.png](assets/logo.png) 포함

### Changed
- `gaebalai/cc-roundtable` 리포에서 운영하던 마켓플레이스를 본 리포로 이전
  - 사용자가 이미 등록한 마켓플레이스가 있다면 `/plugin marketplace remove gaebalai-marketplace` → `/plugin marketplace add gaebalai/gaebalai-marketplace`로 재등록
- README 수록 플러그인 표를 2개로 확장, 트리거 예시 추가
- `plugins/empirical-prompt-tuning/.claude-plugin/plugin.json` 형식을 cc-roundtable plugin.json과 정렬
  - `author.url`, `license: MIT`, `skills: "./skills/"` 추가

### Migration (기존 사용자용)
사용자가 `gaebalai/cc-roundtable`로 마켓플레이스를 등록 중이면 다음으로 마이그레이션 권장.

```
/plugin marketplace remove gaebalai-marketplace
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-roundtable@gaebalai-marketplace
/plugin install empirical-prompt-tuning@gaebalai-marketplace
```

## [0.1.0] - 2026-04-26

### Added
- `empirical-prompt-tuning` 스킬 본체 ([SKILL.md](plugins/empirical-prompt-tuning/skills/empirical-prompt-tuning/SKILL.md))
  - 6가지 핵심 원칙 (글쓴이/판정자 분리, 시나리오 사전 고정, 매번 신규 dispatch, 양면 측정, 1회 1테마 수정, hold-out 시나리오)
  - 8단계 워크플로우 (대상 식별 → 시나리오 설계 → 요건 체크리스트 → 실행 → 보고 수집 → 1테마 수정 → 재실행 → 종료 판정)
  - 환경별 분기 (Claude Code Task tool / Claude.ai 단일 세션)
- references/
  - `claude-code-flow.md` — Task tool 기반 병렬 dispatch 절차
  - `claude-ai-flow.md` — 단일 세션 직렬 폴백 절차 (전략 A/B/C)
  - `scenario-design.md` — median/edge/hold-out 시나리오 작성 가이드
  - `scoring-rubric.md` — 20점 평가 루브릭 (skill / 일반 프롬프트 / 기술 문서 변형)
- assets/
  - `dispatch-prompt-template.md` — dispatch 프롬프트 본체 템플릿
  - `report-structure.md` — 서브에이전트 보고 구조 강제 템플릿
  - `iteration-log-template.md` — 반복 추이 기록표 템플릿
- 마켓플레이스 매니페스트 ([.claude-plugin/marketplace.json](.claude-plugin/marketplace.json))
  - `name: gaebalai-marketplace`
- 플러그인 매니페스트 ([plugins/empirical-prompt-tuning/.claude-plugin/plugin.json](plugins/empirical-prompt-tuning/.claude-plugin/plugin.json))
- 로컬 설치 스크립트 [install.sh](install.sh) (심볼릭 링크 / 복사 / 제거 모드)
- 정량 메트릭 임곗값 가이드 (정확도 50/80/90, tool_uses 1~3/4~10/15+)
- 종료 판정 기준 (수렴 / 발산 / 종료)

### Notes
- 이 버전은 Claude Code 플러그인 시스템에서의 첫 공개 릴리스입니다 (early access)
- 마켓플레이스 매니페스트 형식은 실제 사용 검증 초기 단계이므로,
  추후 호환성 패치가 필요할 수 있습니다 (0.1.x 시리즈에서 흡수 예정)
- 안정화 후 `1.0.0`으로 메이저 승격 예정

[Unreleased]: https://github.com/gaebalai/gaebalai-marketplace/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.2.0
[0.1.0]: https://github.com/gaebalai/gaebalai-marketplace/releases/tag/v0.1.0
