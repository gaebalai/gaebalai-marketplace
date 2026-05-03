# cc-security-scan

Claude Code 용 보안 스킬 3종과, 그것을 평가하는 테스트 하니스 세트입니다.

## 설치

### 방식 A: gaebalai 마켓플레이스 (권장)

```
/plugin marketplace add gaebalai/gaebalai-marketplace
/plugin install cc-security-scan@gaebalai-marketplace
```

플러그인 시스템이 `commands/` / `hooks/` / `templates/` / `rules/` 를 자동 인식합니다. 재시작 불필요.

### 방식 B: gh-cc-skill 직접 설치 (단독 사용)

```bash
gh extension install gaebalai/gh-cc-skill
gh cc-skill install gaebalai/cc-security-scan
```

> 공식 `gh skill` (preview) 명령과 충돌하지 않도록 확장명을 `gh-cc-skill` (Claude Code skill) 로 사용합니다.

`~/.claude/commands/` 에 3개의 스킬 파일이 배치됩니다. Claude Code 를 재시작한 후 사용해 주세요.

---

## 스킬의 역할 분담

| 타이밍 | 스킬 | 대상 |
|-----------|--------|------|
| PR 생성 시 | `/security-review` | git diff 만 · 정적 분석 |
| 릴리스 전 | `/full-scan` | 전체 소스 파일 + 의존성 CVE |
| 배포 후 | `/security-scan` | 런타임 거동 · HTTP 동적 테스트 |

3개 스킬을 조합함으로써, 개발 사이클 전체를 커버합니다.

---

## 스킬 개요

### `/security-review` — 차분 기반 정적 분석

PR · 브랜치의 `git diff` 를 대상으로, 변경된 코드만을 보안 분석합니다.

**검출 대상:**
- 인젝션 (SQL / NoSQL / 명령 / 템플릿)
- 인증 · 인가의 결함 (JWT 잘못된 구현 · 인가 우회)
- 하드코딩된 인증 정보 · API 키
- 위험한 메서드에 의한 XSS (`dangerouslySetInnerHTML` 등)
- PII · 토큰의 로그 출력

**특징:** 거짓 양성 필터링 (신뢰도 0.8 이상만 보고), 기존 보안 패턴과의 비교 분석

---

### `/full-scan` — 전체 파일 정적 분석 (언어 · 프레임워크 비의존)

프로젝트 구조를 자동 검출하고, 전체 소스 파일의 정적 분석과 의존성 CVE 스캔을 병렬 실행합니다.

**특징:**
- 모노레포 대응 (모듈마다 서브 에이전트를 병렬 실행)
- `npm audit` / `pip-audit` / `cargo audit` 등 의존성 스캔
- `gitleaks` 에 의한 시크릿 유출 체크
- 컨텍스트 상한 도달 시에는 PARTIAL SCAN 으로 명시

---

### `/security-scan` — 런타임 검증

스테이징 환경에 배포 완료된 서버에 대해 HTTP 동적 테스트를 실행합니다.

**검증 내용:**
- HTTP 보안 헤더 (HSTS · CSP · X-Frame-Options 등)
- OWASP Top 10 (A01~A10)
- JWT 알고리즘 혼동 공격 · Cookie 속성
- SQL / NoSQL / 명령 인젝션
- 프롬프트 인젝션 (AI 기능이 있는 경우)

**전제:** `security-agent.config.yml` 과 `STAGING_URL` 환경 변수가 필요

```bash
cp security-agent.config.template.yml ./your-project/security-agent.config.yml
# 편집 후:
export STAGING_URL=https://staging.your-app.com
/security-scan
```

자세한 내용은 [templates/security-skills-setup.md](templates/security-skills-setup.md) 을 참조해 주세요.

---

## 커버리지

### 3개 스킬 합산

| 영역 | 커버리지 |
|------|----------|
| OWASP Top 10 베이스 | 약 65~70% |
| 코드 패턴 계열 (injection, XSS, hardcoded key) | 약 90% |
| 의존성 CVE | 약 85% |
| HTTP 설정 실수 | 약 75% |
| 비즈니스 로직 · 인프라 설정 | 침투 테스트 (수작업) 가 필요 |

---

## 테스트 하니스

`tests/security-skills/` 에 픽스처와 채점 기준 (`expected.json`) 이 포함됩니다.

### 픽스처의 구성

| 디렉터리 | 내용 |
|------------|------|
| `fixtures/vuln/` | Easy: 기본적인 취약성 패턴 |
| `fixtures/safe/` | Easy: 안전한 패턴 (거짓 양성 테스트) |
| `fixtures/hard-vuln/` | Hard: 언뜻 안전해 보이는 취약성 |
| `fixtures/hard-safe/` | Hard: 언뜻 위험해 보이는 안전한 패턴 |
| `fixtures/attacker/` | Attacker: 실제 공격자 수준의 패턴 |
| `fixtures/attacker-safe/` | Attacker: 어려운 안전 패턴 |
| `fixtures/no-comment-vuln/` | No-Comment: 주석 없는 취약 코드 |
| `fixtures/no-comment-safe/` | No-Comment: 주석 없는 안전 코드 |
| `fixtures/deep-chain/` | 6 파일 깊은 연쇄 (JWT 서명 검증 없음) |
| `fixtures/framework-bypass/` | Next.js middleware + rewrite 우회 |
| `fixtures/infra-combo/` | CSP 설정 + XSS 조합 |

### 실측 스코어 (`/full-scan` 에 의한 평가)

| 난이도 | Recall | FP Rate |
|--------|--------|---------|
| Easy | 100% | 0% |
| Hard | 100% | 0% |
| Attacker-level | 100% | 0% |
| No-Comment | 100% | 0% |
| 깊은 연쇄 (6 파일) | 100% | 0% |
| 프레임워크 거동 의존 | 100% | 0% |
| 인프라 설정 조합 | 100% | 0% |

### 테스트 실행 방법

Claude Code 에서 다음을 실행합니다:

```
/full-scan tests/security-skills/fixtures
```

`tests/security-skills/expected.json` 의 채점 기준과 대조하여, 검출 누락 · 거짓 양성을 확인해 주세요.

---

## ⚠️ 보안에 관한 중요 사항

이 스킬은 다음 명령을 당신의 머신 상에서 실행합니다. 설치 전에 반드시 확인해 주세요.

| 명령 | 목적 | 조건 |
|---------|------|------|
| `npm audit` / `yarn audit` | 의존성 스캔 | `package.json` 이 있는 경우 |
| `curl -I` | HTTP 헤더 취득 | 항상 |
| `gitleaks` / `trufflehog` | 시크릿 유출 검출 | 도구가 설치되어 있는 경우 |

- **스테이징 환경 전용**입니다. 프로덕션 URL 에 대한 실행은 거부됩니다
- **허가를 받지 않은 시스템에 대한 진단 실행은 불법입니다**. 본인이 관리 권한을 가진 시스템에만 사용해 주세요
- 자동화 커버리지는 대략 70~80% 입니다. 비즈니스 로직의 결함은 수작업 리뷰가 필요합니다

---

## 파일 구성

```
cc-security-scan/
├── commands/
│   ├── security-review.md        # /security-review 스킬 본체
│   ├── full-scan.md              # /full-scan 스킬 본체
│   └── security-scan.md         # /security-scan 스킬 본체
├── templates/
│   ├── security-agent.config.template.yml  # /security-scan 설정 템플릿
│   └── security-skills-setup.md           # 신규 프로젝트 도입 절차
├── rules/
│   └── security.md               # Claude Code 글로벌 보안 룰
├── hooks/
│   └── security-filter.sh        # 출력 필터링 훅
└── tests/
    └── security-skills/
        ├── expected.json          # 채점 기준 (모범 답안)
        └── fixtures/              # 테스트용 코드 픽스처
```

## 라이선스

MIT
