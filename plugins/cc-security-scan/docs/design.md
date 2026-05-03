# security-scan 스킬 설계서

**버전**: 1.0
**대상**: Claude Code 글로벌 명령 (전체 프로젝트 공통)
**배치 위치**: `~/.claude/commands/security-scan.md`

---

## 1. 목적

프로덕트 비의존 AI 에이전트에 의한 자동 보안 진단을 CI/CD 및 수동 트리거로 실행하고, 발견한 취약성을 티켓 · 보고서로 출력한다.

---

## 2. 설계 원칙

| 원칙 | 내용 |
|------|------|
| **프로덕트 비의존** | 설정 파일 1개로 임의의 스택에 적용할 수 있다 |
| **단계적 진단** | 심각도가 높은 진단부터 순서대로 실행하여, 조기 종료를 가능하게 한다 |
| **토큰 최소화** | Hook 의 출력을 반드시 필터한 후에 반환한다 (상한 8,000자) |
| **인간 승인 전제** | Critical 만 자동 차단, 그 이하는 보고만 |
| **환경 강제** | 스테이징 환경 이외에 대한 실행은 설정 파일에서 명시적으로 거부 |

---

## 3. 디렉터리 구성

```
~/.claude/
  commands/
    security-scan.md          # 스킬 본체 (본 문서에서 생성)
    security-scan-design.md   # 본 설계서
  rules/
    security.md               # 전체 프로젝트 공통 보안 룰
  hooks/
    security-filter.sh        # 스캔 결과 필터 스크립트

각 프로젝트의 리포지터리/
  security-agent.config.yml   # 프로덕트 고유 설정 (필수)
  .github/
    workflows/
      security-scan.yml       # CI/CD 트리거 정의
```

---

## 4. 설정 파일 사양 (security-agent.config.yml)

```yaml
# security-agent.config.yml
# 각 프로젝트의 리포지터리 루트에 배치한다

target:
  type: rest_api              # rest_api / web_app / graphql / grpc / db / auth_service
  base_url: ${STAGING_URL}    # 환경 변수로 주입 (프로덕션 URL 기재 금지)
  auth:
    type: bearer_token        # bearer_token / basic / api_key / none
    token: ${TEST_TOKEN}      # 환경 변수로 주입

scope:
  include:
    - /api/**
  exclude:
    - /api/admin/**           # 관리 계열은 제외
    - /health                 # 헬스 체크는 제외

# 프로덕트의 스택에 맞춰 활성화할 에이전트를 고른다
agents:
  - owasp_top10               # 전체 프로덕트 공통 (필수)
  - auth_bypass               # 인증 기능이 있는 경우
  - injection                 # DB · 외부 명령 실행이 있는 경우
  - prompt_injection          # LLM 기능이 있는 경우
  - multi_tenant              # 멀티 테넌트 구성인 경우
  - file_exposure             # 파일 업로드 · 다운로드가 있는 경우

schedule: weekly              # pr_gate / weekly / release_gate / manual
report:
  format: github_issue        # github_issue / slack / jira / file
  severity_gate: critical     # 이 심각도 이상에서 CI 를 중단 (critical / high / medium)
  output_path: ./security-report.md
```

---

## 5. 에이전트 사양

### 5-1. 공통 에이전트 (전체 프로덕트)

#### owasp_top10
| 진단 항목 | 기법 | 자동화 가능 여부 |
|---------|------|-----------|
| A01 액세스 제어의 결함 | 권한 교체 요청 | AI ◎ |
| A02 암호화의 실패 | HTTPS 체크 · 헤더 검사 | 도구 ○ |
| A03 인젝션 | SQLi/NoSQLi/CMDi 퍼징 | 도구 ◎ |
| A04 안전하지 않은 설계 | 설계 리뷰 | 수작업 ◎ |
| A05 보안 설정 실수 | 헤더 · 설정값 체크 | 도구 ○ |
| A06 취약한 컴포넌트 | 의존성 스캔 | 도구 ◎ |
| A07 인증 · 세션 관리 | 토큰 분석 · 세션 고정 | AI ◎ |
| A08 소프트웨어 무결성 | SBOM 체크 | 도구 ○ |
| A09 로그 · 모니터링의 실패 | 로그 출력 확인 | 수작업 ◎ |
| A10 SSRF | 외부 요청 유도 테스트 | AI ◎ |

### 5-2. 옵션 에이전트

#### auth_bypass
- JWT 알고리즘 혼동 공격 (RS256→HS256)
- 토큰 유효 기간 체크
- OAuth state 파라미터 검증

#### injection
- SQL 인젝션 (시간 기반 블라인드)
- NoSQL 인젝션 ($where, $regex)
- 프롬프트 인젝션 (LLM 경유 명령 실행)

#### prompt_injection (AI 기능 전용)
- Direct Injection: 사용자 입력으로 시스템 프롬프트 덮어쓰기 시도
- Indirect Injection: 외부 데이터 경유 지시 삽입
- Jailbreak: 제약 회피 시도

#### multi_tenant
- 다른 테넌트 ID 에 대한 직접 액세스 시도
- 응답에 다른 테넌트 데이터가 혼입되지 않는지 확인
- 일괄 취득 API 에서의 데이터 경계 확인

#### file_exposure
- 패스 트래버설 (`../../../etc/passwd`)
- 공개 URL 의 추측 (연번 · UUID 패턴)
- 업로드 파일의 실행 가능 여부

---

## 6. 실행 플로우

```
/security-scan [환경명]
        │
        ▼
Step 1: 설정 파일 읽기
  └ security-agent.config.yml 을 검색 · 검증
  └ 환경 변수 (STAGING_URL, TEST_TOKEN) 의 존재 확인
  └ 프로덕션 URL 이 포함되어 있지 않은지 확인 (포함되어 있으면 중단)
        │
        ▼
Step 2: 공격면 매핑
  └ base_url 에 대해 엔드포인트 일람을 수집
  └ OpenAPI 사양이 있으면 읽어들임
  └ scope.include / exclude 를 적용
        │
        ▼
Step 3: 정적 진단 (고속 · 저비용)
  └ 의존성 스캔 (Snyk / npm audit)
  └ 시크릿 유출 체크 (truffleHog / gitleaks)
  └ 헤더 · TLS 설정 체크
        │
        ├── Critical 발견 → 즉시 보고서 생성 · CI 중단
        │
        ▼
Step 4: 동적 진단 (에이전트 실행)
  └ 활성화된 에이전트를 순서대로 실행
  └ 각 에이전트의 출력은 필터 스크립트를 통과시킴 (8,000자 이내)
  └ 중간 결과를 security-report.md 에 그때그때 기록 (중단 대책)
        │
        ▼
Step 5: 커버리지 집계
  └ 테스트 완료 엔드포인트 / 전체 엔드포인트
  └ 진단 완료 OWASP 카테고리 / 전체 카테고리
  └ coverage-report.yml 을 생성
        │
        ▼
Step 6: 보고서 생성 · 알림
  └ 발견한 취약성을 심각도별로 정리
  └ format 설정에 따라 출력 (GitHub Issue / Slack / 파일)
  └ severity_gate 이상이 있으면 CI 종료 코드 1 을 반환
```

---

## 7. Hook 와의 연계

### PostToolUse (파일 편집 후)

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/hooks/security-filter.sh"
      }]
    }]
  }
}
```

### security-filter.sh (출력 필터)

```bash
#!/bin/bash
# 스캔 결과의 원본 출력을 받아서, 8,000자 이내로 필터해서 반환

INPUT=$(cat)

# Critical 만 추출 → High → Medium 순으로 우선
echo "$INPUT" \
  | jq '[.[] | select(.severity == "critical" or .severity == "high")]
        | sort_by(.severity)
        | reverse' 2>/dev/null \
  || echo "$INPUT" | grep -E "CRITICAL|HIGH|ERROR" \
  | head -c 8000
```

---

## 8. 토큰 소비 설계

```
세션 시작 시 (고정)
  └ ~/.claude/CLAUDE.md               ~200 tokens
  └ rules/security.md (paths: 없음)   ~300 tokens
                                      ──────────────
                                      합계 ~500 tokens

/security-scan 호출 시
  └ commands/security-scan.md 전문    ~600 tokens
  └ security-agent.config.yml 읽기    ~200 tokens

진단 단계 (에이전트 수에 비례)
  └ 정적 진단 출력 (필터 후)          ~1,000 tokens
  └ 동적 진단 출력 (필터 후)          ~3,000 tokens × 에이전트 수
  └ 보고서 생성                       ~1,500 tokens

1회 진단 합계 (에이전트 3개의 경우)
  500 + 800 + 1,000 + 9,000 + 1,500 = ~12,800 tokens ≒ $0.05/회
```

---

## 9. 커버리지 보고서 사양 (coverage-report.yml)

```yaml
scan_date: 2026-04-30T10:00:00Z
target: https://staging.example.com

attack_surface:
  endpoints_total: 47
  endpoints_tested: 43           # 91.5%
  endpoints_skipped:
    - path: POST /api/internal/sync
      reason: 인증 토큰 취득 불가
    - path: GET /api/v2/export
      reason: 테스트 데이터 미정비

vuln_classes:
  owasp_top10:
    covered: 8/10
    gaps:
      - A04_insecure_design      # 설계 리뷰가 필요 (자동화 불가)
      - A09_logging_failures     # 모니터링 계열은 CI 대상 외

findings:
  critical: 0
  high: 2
  medium: 5
  low: 12
  info: 8

coverage_score: 74%
ci_result: pass                  # pass / fail (severity_gate 기준)
```

---

## 10. CI/CD 정의 (GitHub Actions)

```yaml
# .github/workflows/security-scan.yml

name: AI Security Scan
on:
  schedule:
    - cron: '0 2 * * 1'         # 매주 월요일 2:00
  workflow_dispatch:             # 수동 트리거

jobs:
  security-scan:
    runs-on: ubuntu-latest
    environment: staging         # 프로덕션 환경에 대한 오실행 방지
    steps:
      - uses: actions/checkout@v4

      - name: Run Security Scan
        env:
          STAGING_URL: ${{ secrets.STAGING_URL }}
          TEST_TOKEN: ${{ secrets.TEST_TOKEN }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          npx @anthropic/claude-code \
            --non-interactive \
            --command "/security-scan staging"

      - name: Upload Coverage Report
        uses: actions/upload-artifact@v4
        with:
          name: security-coverage
          path: coverage-report.yml

      - name: Create Issue on High+ Finding
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            const report = require('fs').readFileSync('security-report.md', 'utf8')
            github.rest.issues.create({
              ...context.repo,
              title: '🚨 보안 진단: 대응 필요한 취약성 검출',
              body: report,
              labels: ['security', 'high-priority']
            })
```

---

## 11. 구현 단계

### Phase 1 (즉시 적용 가능 · 비용 거의 제로)

- [ ] `~/.claude/commands/security-scan.md` 작성 (본 설계서로부터 생성)
- [ ] `~/.claude/rules/security.md` 작성
- [ ] `~/.claude/hooks/security-filter.sh` 작성
- [ ] 각 프로젝트에 `security-agent.config.yml` 을 배치
- [ ] GitHub Actions 워크플로우 추가

**실현 가능한 것**: 의존성 스캔 + 헤더 체크 + LLM 에 의한 보고서 생성

### Phase 2 (2~4 주)

- [ ] OWASP ZAP 와의 연계 (동적 진단 자동화)
- [ ] auth_bypass / injection 에이전트 구현
- [ ] 커버리지 보고서 자동 생성
- [ ] Slack 알림 연계

**실현 가능한 것**: OWASP Top 10 의 80% 를 커버

### Phase 3 (지속적 개선)

- [ ] prompt_injection 에이전트 (AI 기능을 가진 프로덕트용)
- [ ] 진단 결과의 축적 · 트렌드 분석
- [ ] Human-in-the-Loop: Slack 승인 플로우
- [ ] multi_tenant 에이전트 구현

**실현 가능한 것**: AI 기능의 안전성 + 취약성 트렌드의 시각화

---

## 12. 자동화 불가능 영역 (수작업 보완 필요)

| 항목 | 이유 | 권장 대응 |
|------|------|---------|
| 비즈니스 로직의 결함 | 사양을 모르면 판단할 수 없다 | 분기에 1회 수동 리뷰 |
| 안전하지 않은 설계 (A04) | 요건 · 설계서가 필요 | 릴리스 전의 설계 리뷰 |
| 운용 · 인적 리스크 | 코드 스캔으로는 검출 불가 | 보안 교육 · 인시던트 훈련 |

**목표 커버리지**

```
자동화 (CI/CD + AI Agent): 70~80%
  └ 기지(旣知) 취약성 클래스:    90%+
  └ 공격면 (엔드포인트):         85%+
  └ 문맥 의존 테스트:            50% 정도

수작업에 의한 펜테스트 (연 1~2 회): 나머지 20~30% 를 보완
```
