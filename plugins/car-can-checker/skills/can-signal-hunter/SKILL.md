---
name: can-signal-hunter
description: 차량 OBD2/CAN 로그(.asc, .log, .blf, .csv)에서 RPM·차속·조향각·기어 같은 신호의 ID와 바이트 위치, 스케일·오프셋을 자동 추정하고 검증 그래프(PNG)와 DBC 초안을 생성한다. 사용자가 "CAN 로그 분석", "RPM ID 찾아줘", "0x202가 무슨 신호야", "조향각 ID 매핑", "DBC 만들어줘" 같은 요청을 할 때 호출한다. 제조사 비공개 신호를 빠르게 역엔지니어링할 때 쓰는 스킬.
---

# can-signal-hunter

대용량 CAN 로그를 받아 후보 신호를 자동 식별하고, 사람이 한눈에 검증할 수 있는 그래프와 DBC 초안을 만들어낸다.

## 언제 쓰나

- `.asc`(Vector), `.log`(candump), `.blf`, 또는 `timestamp,id,data` 형식 CSV CAN 로그가 있다
- 사용자가 "RPM/속도/조향각/기어가 어느 ID 어느 바이트에 있는지" 알고 싶다
- 제조사 DBC가 없거나 신뢰할 수 없는 인터넷 정보뿐이다

## 입력

다음 중 하나를 사용자에게 받는다:

1. CAN 로그 파일 경로 (필수)
2. 알고 있는 라벨 시드(선택) — 예: "주행 시작 30~80초 구간은 가속, 100~120초는 우회전"
3. 차종/연식(선택) — 결과 캐시용

## 워크플로우

### STEP 1. 로그 파싱

`python-can` 우선, 없으면 텍스트 파서로 폴백:

```bash
pip install python-can numpy pandas matplotlib
```

```python
import can
import pandas as pd

# .asc / .log / .blf 자동 감지
reader = can.LogReader(log_path)
rows = [(m.timestamp, m.arbitration_id, bytes(m.data)) for m in reader]
df = pd.DataFrame(rows, columns=["t", "id", "data"])
```

candump 텍스트 로그(`(timestamp) can0 ID#DATA`)는 `scripts/parse_candump.py` 사용.

### STEP 2. ID별 통계 산출

각 CAN ID마다:

- 프레임 주기(Hz) — 100Hz 근처는 RPM/속도/엑셀 후보, 50~64Hz는 조향/기어 후보
- 바이트별 분산·해상도(고유값 수)
- 16비트 빅엔디안/리틀엔디안 워드 단위 분산

`scripts/hunt_can_signals.py`가 모든 ID×바이트조합을 표로 뽑아준다.

### STEP 3. 신호 후보 분류 휴리스틱

| 신호 | 단서 |
|---|---|
| RPM | 100Hz, 16비트 BE, 정지 시 ~800rpm(=값 3200, ÷4), 가속 시 단조 증가 |
| 차속 | 100Hz, 16비트 BE, 정지 시 0, 후진 시 부호 전환 또는 별도 비트 |
| 조향각 | 50~64Hz, 부호 있는 16비트, 직진 시 0 근처, 좌우 대칭 |
| 기어 | 50Hz 이하, 1바이트, 이산값(P/R/N/D/숫자), 정차 중 변화 |
| 엑셀ON | 1비트, 시동 직후 토글 빈번 |

후보가 여러 개면 Top-3을 상관계수와 함께 제시.

### STEP 4. 검증 그래프 생성

원본 글의 `car-can-data2.jpeg`와 동일한 4단 패널(RPM, Speed, Steering, Gear) PNG를 `scripts/plot_signals.py`로 출력한다. 사용자가 눈으로 즉시 검증.

### STEP 5. DBC 초안 작성

`cantools` 사용:

```python
import cantools
from cantools.database.can import Database, Message, Signal

db = Database()
db.messages.append(Message(
    frame_id=0x202, name="EngineStatus", length=8,
    signals=[
        Signal("RPM", start_bit=7, length=16, byte_order="big_endian",
               scale=0.25, offset=0, unit="rpm"),
        Signal("Speed", start_bit=23, length=16, byte_order="big_endian",
               scale=0.01, offset=0, unit="km/h"),
    ],
))
db.dump_file("guess.dbc")
```

## 출력물

- `can_analysis_<timestamp>/`
  - `summary.md` — ID별 후보 신호 표 + 신뢰도
  - `signals.png` — 4단 검증 패널
  - `guess.dbc` — 초안
  - `id_stats.csv` — 전체 ID 통계 (사람이 추가 탐색용)

## 주의사항

- 후보는 **추정**이다. 차량 매뉴얼·실차 검증 없이 ECU 쓰기 명령에 절대 사용 금지
- ID/바이트 위치는 같은 차종이라도 트림·연식별로 다를 수 있음
- 신뢰도 95% 이상만 자동 채택, 그 미만은 사람 확인 후 채택

## 참고 스크립트

- `scripts/hunt_can_signals.py` — 메인 분석기
- `scripts/parse_candump.py` — candump 텍스트 로그 파서
- `scripts/plot_signals.py` — 4단 검증 패널 그리기
