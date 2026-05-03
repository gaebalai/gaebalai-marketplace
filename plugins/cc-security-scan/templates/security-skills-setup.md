# 신규 프로젝트 도입 절차

## 1. 스킬 파일을 설치

```bash
cp commands/*.md ~/.claude/commands/
```

Claude Code 를 재시작하면 `/security-review`, `/full-scan`, `/security-scan` 을 사용할 수 있게 됩니다.

## 2. `/security-scan` 의 설정 (런타임 검증을 사용하는 경우)

`security-agent.config.template.yml` 을 프로젝트 루트에 복사해서 편집합니다.

```bash
cp templates/security-agent.config.template.yml ./security-agent.config.yml
```

편집 포인트:

| 필드 | 설명 |
|-----------|------|
| `target.base_url` | 스테이징 환경의 URL. 환경 변수 `STAGING_URL` 로 덮어쓰기 가능 |
| `scope.include` | 스캔 대상 엔드포인트 |
| `scope.exclude` | 스킵할 엔드포인트 (바이너리 응답 등) |
| `agents` | 활성화할 테스트 에이전트 |
| `severity_gate` | CI 판정의 임계값 (`high` 권장) |

## 3. `.gitignore` 에 스캔 결과를 추가

스캔 결과 파일에는 실제 엔드포인트 정보 · 취약성 내용이 포함되므로, 리포지터리에 커밋하지 않을 것을 권장합니다.

```gitignore
security-reports/
security-report.md
coverage-report.yml
security-agent.config.yml  # 프로젝트 고유 엔드포인트를 포함하는 경우
```

## 4. 사용 예

```bash
# PR 생성 전: 변경 차분만 체크
/security-review

# 릴리스 전: 전체 파일 + 의존성을 스캔
/full-scan

# 스테이징 배포 후: 런타임 검증
STAGING_URL=https://staging.example.com /security-scan
```

## 스킬의 역할 분담

| 타이밍 | 스킬 | 대상 |
|-----------|--------|------|
| PR 생성 시 | `/security-review` | git diff 만 · 정적 분석 |
| 릴리스 전 | `/full-scan` | 전체 소스 파일 + 의존성 CVE |
| 배포 후 | `/security-scan` | 런타임 거동 · HTTP 동적 테스트 |
