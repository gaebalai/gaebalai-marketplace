# car-can-checker — 사용 예시

## 풀 파이프라인 (오케스트레이터 자동 분기)

```
오늘 차 한번 굴리고 받은 candump 로그랑 ZIP 가지고 있어. 분석부터 영상 리포트까지 한번에 돌려줘.
```

오케스트레이터가 사용자 자산을 보고 STEP B(can-signal-hunter)부터 시작 → C → D 순으로 진행. 매 단계 결과를 `./car-can-out/`에 누적.

## 단계별 호출

### STEP A — 새 라즈베리파이 부트스트랩

```
방금 받은 라즈베리파이 5에 OBD2/CAN 진단 환경 깔아줘. SSH 접속 가능해 (pi@192.168.1.42).
```

### STEP B — CAN 로그만 분석

```
~/Downloads/drive_2025_12_04.log 에서 RPM/속도/조향각/기어 ID 찾아줘.
출력은 ./can_analysis_out/ 에 summary.md, candidates.csv, id_stats.csv, guess.dbc 모두.
```

candidate Top-3을 리뷰한 뒤 매핑 JSON을 확정:

```json
{
  "rpm":      {"id": "0x202", "byte": 0, "width": 16, "endian": "big",        "scale": 0.25, "offset": 0},
  "speed":    {"id": "0x202", "byte": 2, "width": 16, "endian": "big",        "scale": 0.01, "offset": 0},
  "steering": {"id": "0x082", "byte": 0, "width": 16, "endian": "big_signed", "scale": 0.1,  "offset": 0},
  "gear":     {"id": "0x228", "byte": 0, "width": 8,  "endian": "uint",       "scale": 1,    "offset": 0}
}
```

### STEP C — PWA만 빌드

```
위 매핑 JSON으로 차량 진단 PWA 만들어줘. 프로젝트명 my-car-diag, Pi 호스트는 pi-car.local.
mkcert 가이드는 사용자 (나)가 직접 따라할 거니까 안내만 하고 발급은 자동화하지 마.
```

### STEP D — 녹음 ZIP만 분석

```
./recordings/car-noise-takes-1733299200000.zip 에서 이상음 후보 뽑아줘.
의심 구간 상위 5건은 확대 PNG로, 분류는 5종 휴리스틱(engine_order/road/rpm_locked/shock/steering) 적용.
```

## 환경변수 (pi_server.py)

```bash
# 기본 — LAN IP만 바인딩
python pi_server.py

# 모든 인터페이스 (방화벽 직접 책임 — 권장 X)
HOST=0.0.0.0 python pi_server.py

# Origin 화이트리스트 추가
ALLOWED_ORIGIN=https://my-pi.local:8443 python pi_server.py
```

## 보안 체크리스트

- [ ] `pi/certs/key.pem`을 git에 커밋하지 않았다
- [ ] Pi의 `0.0.0.0` 바인딩을 활성화했다면 사내망 분리 / iptables 규칙을 직접 설정했다
- [ ] CAN 신호 매핑은 4단 검증 패널(`signals.png`)을 본 뒤 확정했다
- [ ] ECU 쓰기 명령은 절대 보내지 않는다 (이 플러그인은 코드 차원에서 미지원)

## 문제 해결

| 증상 | 원인 | 대응 |
|---|---|---|
| `mkcert: command not found` | `~/go/bin`이 PATH에 없음 | 새 셸 열기, 또는 `export PATH="$PATH:$HOME/go/bin"` |
| `can0` 인터페이스 안 뜸 | USB-CAN 미인식 | `dmesg | tail`, `lsusb`, udev 규칙 확인 |
| WS 403 (Origin not allowed) | mkcert 호스트와 `PI_HOST` 토큰 불일치 | `ALLOWED_ORIGIN` 환경변수로 보정 |
| `cantools` ImportError | venv 미활성 | `source ~/.venvs/cancar/bin/activate && pip install cantools` |
