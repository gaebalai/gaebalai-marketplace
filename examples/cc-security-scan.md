# cc-security-scan — 사용 예시

> 보안 슬래시 명령어 3종을 개발 사이클의 **다른 타이밍에 분리** 배치. 모두 `disable-model-invocation: true` — 모델 자의로는 안 돌고 사용자가 명시적으로 `/명령어`를 쳐야 동작.

## 설치

```
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-security-scan@gaebalai-marketplace
```

## 사용 시나리오

### 1. PR 리뷰 — `/security-review`

PR 작성 후, 변경분만 빠르게 정적 분석.

```
/security-review
```

- 대상: `git diff` (현재 브랜치 vs main)
- 검출: 인젝션(SQL/NoSQL/cmd/template), 인증·인가 결함(JWT 잘못된 구현), 하드코딩 키, 위험 메서드 XSS, PII·토큰 로그
- 거짓 양성 필터링: 신뢰도 0.8 이상만 보고
- 시간: 보통 30초~2분 (변경 파일 수에 따라)

### 2. 릴리스 전 — `/full-scan`

릴리스 브랜치에서 전체 코드 + 의존성 풀 스캔.

```
/full-scan
```

- 프로젝트 구조 자동 검출, 모노레포면 모듈마다 서브 에이전트 병렬
- `npm audit` / `pip-audit` / `cargo audit` (있는 매니페스트에 따라)
- `gitleaks` 시크릿 유출 (설치되어 있으면)
- 컨텍스트 상한 도달 시 `PARTIAL SCAN` 명시
- 시간: 5~20분 (코드량에 따라)

자체 테스트 하니스 평가:

```
/full-scan tests/security-skills/fixtures
```

플러그인의 40개 픽스처(`vuln/safe/hard/attacker/no-comment/deep-chain/framework-bypass/infra-combo`)에 대해 검출 누락·거짓 양성을 `expected.json`과 대조 가능.

### 3. 배포 후 — `/security-scan`

스테이징 환경에 배포된 서버에 HTTP 동적 테스트.

```bash
# 사전 1회: 설정 복사 + 편집
cp "$(claude plugin path cc-security-scan)/templates/security-agent.config.template.yml" \
   ./security-agent.config.yml

# 환경변수
export STAGING_URL=https://staging.your-app.com
```

```
/security-scan staging
```

- HTTP 보안 헤더 (HSTS / CSP / X-Frame-Options 등)
- OWASP Top 10 (A01~A10)
- JWT 알고리즘 혼동 공격, Cookie 속성
- SQL/NoSQL/명령 인젝션
- 프롬프트 인젝션 (AI 기능이 있는 경우)
- **프로덕션 URL 거부** — `prod`, `production`, `app.` 등이 STAGING_URL에 포함되면 실행 차단

## 출력 필터링 (옵션)

스캔 결과가 너무 길면 `hooks/security-filter.sh` 로 Critical/High만 추려 8KB 캡:

```bash
/full-scan | bash "$(claude plugin path cc-security-scan)/hooks/security-filter.sh"
```

JSON 출력이면 jq로 severity 필터링, 텍스트면 grep으로 CRITICAL/HIGH/ERROR 줄만 통과.

## 글로벌 보안 룰 적용 (옵션)

`rules/security.md` 의 룰 (시크릿 하드코딩 금지, SQL 플레이스홀더 강제, eval 금지 등) 을 `~/.claude/CLAUDE.md` 에 import:

```bash
echo '@'"$(claude plugin path cc-security-scan)/rules/security.md" >> ~/.claude/CLAUDE.md
```

## 자주 빠지는 함정

- **`/security-scan`은 스테이징 전용** — 프로덕션 진단은 별도 침투 테스트로 분리. 명시적 허가 없이 프로덕션 URL 입력하면 거부됨
- **3개 합산해도 비즈니스 로직 결함은 못 잡음** — 인가 우회의 룰 자체 결함, 도메인 특수 시나리오는 사람이 봐야 함
- **`/full-scan` 컨텍스트 상한** — 큰 모노레포면 PARTIAL SCAN으로 표시되는 모듈은 별도로 스캔 (하위 폴더로 깊이 이동해서 재실행)

## 트러블슈팅

```bash
# 1. 명령어가 안 보임
ls "$(claude plugin path cc-security-scan)/commands/"

# 2. 의존성 스캔이 비어 있음
which npm pip-audit cargo gitleaks
# 없는 도구는 자동 skip — 설치 후 재실행

# 3. 프로덕션 거부 우회 시도 → 정상 동작
# security-agent.config.yml 의 allow_production_urls: false 가 기본
```

자세한 스킬 본체·검증 정책은 [plugins/cc-security-scan/README.md](../plugins/cc-security-scan/README.md) 와 [plugins/cc-security-scan/templates/security-skills-setup.md](../plugins/cc-security-scan/templates/security-skills-setup.md) 참고.
