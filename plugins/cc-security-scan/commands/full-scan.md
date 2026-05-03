---
description: 릴리스 전 전체 파일 정적 분석 스킬. 프로젝트 구조를 자동 검출하고, 소스 모듈마다 서브 에이전트와 의존성 스캔을 병렬 실행해서 코드 베이스 전체의 취약성을 검출한다. 수동 호출 전용: /full-scan
disable-model-invocation: true
---

# full-scan

**역할**: 릴리스 전 · 전체 파일 정적 분석 스킬 (언어 · 프레임워크 비의존)

프로젝트 구조를 자동 검출하고, 다음을 병렬 실행한다:
- **소스 모듈 서브 에이전트** (검출된 모듈마다 1 개): 전체 소스 파일의 정적 분석
- **패키지 서브 에이전트**: 의존성의 기지(旣知) CVE 스캔 + 시크릿 유출 체크

> **컨텍스트 상한에 대한 주의**: 리포지터리가 대규모인 경우, 전체 파일이 컨텍스트 윈도우에 들어가지 않을 가능성이 있다. **스킵이 발생한 경우에는 사일런트하게 무시하지 말고, 반드시 스킵한 파일 일람과 함께 PARTIAL 스캔으로서 보고한다.**

---

## 인수

| 인수 | 필수 | 설명 |
|------|------|------|
| `대상 패스` | 임의 | 명시적으로 스캔하고 싶은 디렉터리 (생략 시는 자동 검출) |

---

## 절차

### Step 1: 프로젝트 구조의 자동 검출

이하의 순서로 구조를 파악한다:

1. **소스 디렉터리 특정**
   - `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `Gemfile` / `pom.xml` / `build.gradle` 을 `node_modules/` / `.git/` / `dist/` / `build/` 를 제외하고 검색한다
   - 각 매니페스트 파일의 위치로부터 소스 디렉터리를 추정한다 (예: `package.json` 이 있는 위치의 `src/` / `lib/` / `app/` 등)
   - 인수에서 패스가 지정된 경우에는 그것을 우선한다

2. **언어 · 프레임워크의 검출**
   - 매니페스트 파일의 내용 (dependencies / devDependencies 등) 으로부터 프레임워크를 특정한다
   - 예: `next` → Next.js, `express` → Express, `fastapi` → FastAPI, `rails` → Rails 등

3. **모듈 분할 결정**
   - 소스 디렉터리가 복수 있는 경우 (모노레포 등): 모듈마다 서브 에이전트를 할당한다
   - 소스 디렉터리가 1 개인 경우: 서브 에이전트 1 개로 전체를 커버한다
   - 모듈이 4 개 이상인 경우: 관련된 모듈을 그룹화한다 (컨텍스트 비용 절감)

4. **스캔 전에 파일 일람을 확정한다 (필수)**:
   - 각 모듈의 소스 파일을 `find` 명령으로 열거하고, **총 파일 수를 기록한다**
   - 이 시점에서 확정된 총 파일 수가, 커버리지 계산의 분모가 된다
   - 「이 스캔은 이하의 모듈을 대상으로 합니다: [모듈 일람] / 총 파일 수: [N] 건」 이라고 명시한다

### Step 2: 서브 에이전트를 병렬 실행

이하를 **동시에** 기동한다 (병렬 실행):

---

#### 소스 모듈 서브 에이전트 (모듈마다)

검출된 각 소스 모듈의 파일을 정적 분석한다.

**분석 절차 (필수):**

1. **분석 시작 전에 전체 파일을 열거한다**: `find <src_dir> -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" 등 \)` 으로 대상 파일의 완전한 리스트를 취득하고, **총수 N 을 기록한다**
2. **전체 파일을 순서대로 읽고 분석한다**: 이하의 우선도 순으로 읽어 나간다
3. **컨텍스트 상한에 도달한 경우**: 분석을 즉시 정지하고, 「읽지 못한 파일 일람」 을 기록한다. **미분석 파일을 스킵한 채로 스캔 완료라고 보고해서는 안 된다**

**읽기 우선도 (컨텍스트 상한 시에만 의미를 가진다):**

| 우선도 | 파일 종별 | 범용 패턴 예 |
|--------|------------|--------------|
| 1 | HTTP 엔트리 포인트 · 라우터 | `routes/`, `controllers/`, `api/`, `handlers/`, `endpoints/` |
| 2 | 미들웨어 · 필터 | `middleware/`, `filters/`, `interceptors/` |
| 3 | 인증 · 인가 | `auth/`, `security/`, `permissions/`, `guards/` |
| 4 | 외부 입력을 받는 층 | 요청 보디를 직접 다루는 파일 |
| 5 | 데이터 액세스 층 | `repository/`, `infra/`, `models/`, `db/`, `store/` |
| 6 | 외부 서비스 연계 | `clients/`, `adapters/`, `services/`, `integrations/` |
| 7 | 유틸리티 · 헬퍼 | `utils/`, `lib/`, `helpers/`, `shared/` |

**보고 의무 (필수):**
- 분석 완료 후에 반드시 `FILES_ANALYZED: <분석 완료 수> of <총수>` 를 보고한다
- 미분석 파일이 있는 경우에는 **파일 패스를 전건 열거한다**
- `분석 완료 수 < 총수` 의 경우, 결과를 **PARTIAL SCAN** 으로 명시한다

**검출 대상 (신뢰도 8/10 이상만 보고):**
- **인젝션**: SQL / NoSQL / 명령 / 템플릿 인젝션, 패스 트래버설
- **인증 · 인가의 결함**: 세션 관리 · JWT 잘못된 구현 · 인가 우회 · 권한 상승
- **하드코딩된 인증 정보 · API 키**: 시크릿 · 접속 문자열의 평문 임베드
- **위험한 메서드에 의한 XSS**: `dangerouslySetInnerHTML` / `innerHTML` / `bypassSecurityTrustHtml` / `eval` / `document.write` 등
- **PII · 토큰 · 비밀번호의 로그 출력**
- **SSRF**: 호스트 · 프로토콜을 사용자 입력으로 제어할 수 있는 경우만

**제외 룰 (보고하지 않음):**
- DoS · 리소스 고갈 · 레이트 제한
- React / Angular 통상 컴포넌트의 XSS (위험한 메서드 미사용의 경우)
- 클라이언트 사이드의 인증 체크 결여 (서버 사이드가 책임을 진다)
- AI 시스템 프롬프트에 대한 사용자 입력 혼입
- 환경 변수 · CLI 플래그 경유의 공격 (신뢰됨)
- Markdown · 문서 파일
- 로그 스푸핑
- 패스만 제어할 수 있는 SSRF
- UUID 는 추측 불가능하다고 가정

**거짓 양성 필터링:**
- 구체적인 공격 경로가 있는가 (이론상이 아니라 실제로 악용 가능한가)
- 기존의 프레임워크 · 라이브러리가 안전하게 처리하고 있는 경우에는 제외한다
- 로그에 대한 비 PII 데이터 출력은 취약성으로 하지 않는다

---

#### 패키지 서브 에이전트

**의존성 스캔:**

검출된 매니페스트 파일에 따라 대응하는 명령을 실행한다:

| 매니페스트 | 명령 | 추출 대상 |
|------------|---------|---------|
| `package.json` | `npm audit --json` 또는 `yarn audit --json` | High / Critical |
| `requirements.txt` / `Pipfile` | `pip-audit` 또는 `safety check` | High / Critical |
| `Gemfile` | `bundle audit check` | High / Critical |
| `go.mod` | `govulncheck ./...` | High / Critical |
| `Cargo.toml` | `cargo audit` | High / Critical |
| `pom.xml` / `build.gradle` | `dependency-check` | High / Critical |

도구가 존재하지 않는 경우에는 스킵하고 기록한다.
`--force` 나 파괴적 변경이 필요한 수정은 별도로 명시한다.

**시크릿 유출 체크:**
- `gitleaks detect --source . --report-format json` 을 실행한다
- `trufflehog filesystem .` 를 대체로서 시도한다
- 어느 쪽도 없으면 스킵하고 기록한다

---

### Step 3: 결과의 통합 · 중복 제거

1. 동일한 취약성이 복수 서브 에이전트로부터 보고된 경우에는 1 건으로 정리한다
2. 심각도별로 정렬한다 (Critical → High → Medium → Low)
3. 프레임워크 고유의 수정 방법을 구체적으로 기재한다

**Critical 을 발견하면**: 즉시 보고하고, 나머지 처리를 계속하면서도 즉시 대응을 촉구한다.

### Step 4: 커버리지 집계

```yaml
scan_date: <ISO8601>
scan_type: full_static

project:
  detected_modules: <검출된 모듈명 리스트>
  languages: <검출된 언어 리스트>
  frameworks: <검출된 프레임워크 리스트>

coverage:
  modules:
    - name: <모듈명>
      files_total: <총 파일 수>
      files_analyzed: <분석 완료 수>
      context_limit_reached: <true/false>
  skipped_files:
    - path: <스킵한 파일>
      reason: <이유 (컨텍스트 상한 · 바이너리 등)>

packages:
  scanned: <스캔 완료 매니페스트 수>
  tools_unavailable: <이용 불가했던 도구 리스트>
  vulns_high_critical: <건수>

findings:
  critical: <건수>
  high: <건수>
  medium: <건수>
  low: <건수>

not_covered_by_this_scan:
  - 배포 후의 런타임 거동 → /security-scan 을 사용
  - PR 차분의 즉시 리뷰 → /security-review 를 사용
  - 비즈니스 로직의 결함 → 침투 테스트 (수작업) 가 필요
  - 인프라 · 클라우드 설정 → 인프라 담당자 리뷰가 필요
  - 제로데이 취약성 → CVE 데이터베이스 외이기 때문에 검출 불가
  - 멀티 스텝 공격 체인 → 침투 테스트가 필요

# coverage_score = files_analyzed / files_total × 100 (전체 모듈 합산)
# files_analyzed < files_total 의 경우에는 scan_status: PARTIAL
coverage_score: <files_analyzed 합계 / files_total 합계 × 100>%
scan_status: <COMPLETE | PARTIAL>
ci_result: <pass/fail>
```

### Step 5: 보고서 생성 · 이력 인덱스 업데이트

1. **날짜가 들어간 파일명으로 보고서를 저장한다**
   - 보고서: `./security-reports/YYYY-MM-DD-full-scan-report.md`
   - 커버리지: `./security-reports/YYYY-MM-DD-full-scan-coverage.yml`
   - 날짜는 실행 시의 ISO 8601 형식 (예: `2026-05-01`)
   - 디렉터리가 존재하지 않는 경우에는 작성한다

2. 심각도별 정렬 · 수정 우선순위 · 구체적인 수정 명령을 포함시킨다

3. **`./security-reports/index.md` 에 1 행 추가 기록한다**
   - 파일이 존재하지 않는 경우에는 헤더부터 작성한다
   - 추가 기록 포맷:
   ```
   | YYYY-MM-DD | full-scan | 전체 소스 (<총 파일 수>files / <scan_status>) | <Critical 건수> | <High 건수> | <Medium 건수> | <CI 결과> | [보고서](YYYY-MM-DD-full-scan-report.md) |
   ```
   - CI 결과: High 이상의 발견이 0 건이면 `✅ pass`, 1 건 이상이면 `❌ fail`

4. High 이상의 발견이 있는 경우, 종료 코드 1 을 보고한다

---

## 3 개 스킬의 역할 분담

| 타이밍 | 스킬 | 대상 |
|-----------|--------|------|
| 개발 중 · PR 단위 | `/security-review` | git diff 만 · 정적 분석 |
| 릴리스 전 | `/full-scan` | 전체 소스 파일 + 의존성 (언어 비의존) |
| 스테이징 배포 후 | `/security-scan` | 런타임 거동 · HTTP 동적 테스트 |

---

## 이 스킬로 커버할 수 없는 영역

| 영역 | 권장 수단 |
|------|---------|
| 배포 후의 HTTP 헤더 · 동적 거동 | `/security-scan` |
| 비즈니스 로직의 결함 (사양 지식이 필요) | 침투 테스트 |
| 인프라 · 클라우드 설정 (IAM · 네트워크 ACL) | 인프라 담당자 리뷰 |
| 제로데이 취약성 | CVE 데이터베이스 외이기 때문에 검출 불가 |
| 멀티 스텝 공격 체인 | 침투 테스트 |

---

## 완료 조건

- [ ] `./security-reports/YYYY-MM-DD-full-scan-report.md` 가 생성되어 있다
- [ ] `./security-reports/YYYY-MM-DD-full-scan-coverage.yml` 가 생성되어 있다 (`scan_type: full_static` 명기)
- [ ] 검출된 모듈 · 언어 · 프레임워크가 명시되어 있다
- [ ] 분석 완료 파일 수와 스킵한 파일이 명시되어 있다
- [ ] 커버할 수 없는 영역이 명시되어 있다
- [ ] `severity_gate` 기준에 의한 CI 결과 (pass / fail) 가 명시되어 있다
- [ ] `./security-reports/index.md` 에 1 행 추가 기록되어 있다
