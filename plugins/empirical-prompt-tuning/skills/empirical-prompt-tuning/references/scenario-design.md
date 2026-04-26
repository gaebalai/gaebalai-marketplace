# 시나리오 설계 가이드

평가의 재현성은 시나리오 품질에 좌우된다. **시나리오가 본문 설명 범위를 따라가기만 하면 가짜 통과**가 나온다.

## 최저 구성 (3개)

| 시나리오 | 역할 | 특성 |
|---|---|---|
| **median** | 가장 전형적인 사용 케이스 | 본문이 명시적으로 다루는 상황 |
| **edge** | 본문 설명 범위에서 살짝 벗어남 | 변형/특수/조합 케이스 |
| **hold-out** | 조정에 쓰지 않고 끝까지 보존 | 과적합 검사용 |

`median` 1개 + `edge` 1~2개 + `hold-out` 1개 = 총 3~4개. 더 늘려도 좋지만 dispatch 비용 증가.

## median 시나리오 작성법

대상 프롬프트가 가장 자주 적용될 상황을 1단락으로 기술. 너무 일반적이면 본문 그대로 따라가서 의미 없고, 너무 특수하면 edge가 된다.

**예시 (conventional-changelog skill 평가 시)**:
```
당신은 TypeScript로 작성된 npm 라이브러리(foo-utils)를 처음으로
release-please 워크플로우에 도입하려 합니다. 현재 v0.0.0 상태이며,
단일 패키지 구조이고, GitHub Actions를 사용합니다. 첫 v0.1.0을
끊는 것이 목표입니다.
```

## edge 시나리오 작성법

본문 설명이 부족할 가능성이 높은 변형. 자주 만드는 변형 패턴:

- **규모 변형**: 단일 패키지 → 모노레포, 1인 → 다인 협업
- **언어/스택 변형**: TypeScript → Rust, Python → Go
- **제약 변형**: 신규 도입 → 기존 ad-hoc 마이그레이션, 표준 도구 → 사내 커스텀
- **문화 변형**: OSS 공개 → 사내 비공개, 영어 commit → 한국어 commit
- **부분 적용**: 모든 기능 → 일부만 적용

**예시 (conventional-changelog skill, edge)**:
```
pnpm 모노레포에서 packages/ 하위에 5개 패키지가 있고, 그중 일부는
workspace:* 의존성을 가집니다. 각 패키지를 독립 버전 관리하면서
release-please를 도입하려 합니다.
```

## hold-out 시나리오 작성법

**조정 도중에는 절대 사용하지 않는다.** 과적합 검사 전용.

3회차 또는 종료 직전에 처음 투입하여, 직전 평균 정확도 대비 **-15pt 이상 떨어지지 않으면 과적합 없음**으로 판정.

hold-out은 median/edge와 충분히 다른 영역에서 고른다:

**예시 (conventional-changelog skill, hold-out)**:
```
Rust crate 프로젝트에서 git-cliff와 cargo-release 조합으로
CHANGELOG를 관리합니다. release-please는 사용하지 않습니다.
이 환경에서 Conventional Commits 규약을 도입하려 합니다.
```

## 시나리오 검증 체크리스트

작성한 시나리오를 사용자에게 보여주기 전 self-check:

- [ ] median이 본문 설명 1차 범위 내에 있는가
- [ ] edge가 본문 설명 범위에서 살짝 벗어나는가 (완전히 벗어나면 발산 시나리오)
- [ ] hold-out이 median/edge와 영역이 충분히 다른가
- [ ] 각 시나리오가 1단락(3~6줄)으로 명확한가
- [ ] 시나리오 간 산출물 형태가 비교 가능한가

## 절대 하지 않는 것

- **사후 시나리오 수정** — 결과 보고 후 시나리오를 손보면 불명확점이 메워진 것처럼 위장 가능. 본말전도.
- **본문 베껴쓰기** — "skill 본문에 나온 그대로의 케이스"를 시나리오로 만들면 100% 통과가 보장되지만 의미 없다.
- **시나리오 수만 늘리기** — 5개를 모두 median 변형으로 만들면 edge 검사가 사라진다. 다양성 우선.

## 시나리오와 요건 체크리스트의 관계

각 시나리오마다 **별도의 요건 체크리스트**를 만든다. 시나리오마다 산출물이 다르므로 평가 기준도 달라진다.

```
시나리오 A (median - TS 라이브러리 신규 도입):
  요건:
  1. [critical] commit 구문 예시 3건 이상
  2. [critical] config + manifest + workflow 3종 세트
  3. [critical] v0.1.0 컷팅 가능한 manifest 초기값
  4. fix→patch / feat→minor / BREAKING→major 매핑
  5. CHANGELOG 자동 생성 설정

시나리오 B (edge - pnpm monorepo):
  요건:
  1. [critical] 패키지별 독립 버전 관리 가능
  2. [critical] workspace:* 의존성 처리 명시
  3. monorepo 모드 전환 절차
  ...
```

요건도 시나리오와 함께 사전에 고정한다.
