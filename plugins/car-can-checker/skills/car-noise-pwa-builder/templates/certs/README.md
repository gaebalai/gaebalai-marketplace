# pi/certs — mkcert로 로컬 HTTPS 인증서 발급하기

PWA의 `getUserMedia`(마이크) API는 HTTPS 컨텍스트가 아니면 동작하지 않습니다. 라즈베리파이에서 자기 LAN 호스트명/IP로 발급받은 로컬 인증서를 사용해 HTTPS를 구성합니다.

## 1. mkcert 설치

`raspi-can-bootstrap` 스킬이 자동 설치합니다 (Go 소스 빌드). 수동 설치는:

```bash
# Pi (Bookworm)
sudo apt install -y golang-go libnss3-tools
go install filippo.io/mkcert@latest
export PATH="$PATH:$HOME/go/bin"

# macOS / Linux 호스트
brew install mkcert       # macOS
sudo apt install mkcert    # Debian/Ubuntu
```

## 2. 로컬 CA 신뢰 등록 (1회)

```bash
mkcert -install
```

> 시스템 신뢰 저장소를 변경합니다. 운영 PC가 아닌 진단용 라즈베리파이에서만 실행하세요.

## 3. 인증서 발급

PWA에 접속할 때 사용할 호스트명/IP를 인자로 넣습니다. 여러 개 등록 가능.

```bash
# 단일 호스트
mkcert pi-car.local

# 호스트명 + IP + 와일드카드
mkcert pi-car.local 192.168.1.42 *.pi-car.local
```

발급된 두 파일을 본 디렉터리에 `cert.pem` / `key.pem`으로 배치합니다.

```bash
mv pi-car.local+2.pem      cert.pem
mv pi-car.local+2-key.pem  key.pem
```

`pi_server.py`는 이 경로(`./certs/cert.pem`, `./certs/key.pem`)를 자동으로 읽습니다.

## 4. 스마트폰에서의 신뢰

mkcert로 만든 인증서는 **발급한 머신의 신뢰 저장소**에서만 자동 신뢰됩니다. 스마트폰은 별도 설정이 필요합니다.

### 옵션 A — rootCA 임포트 (권장)

```bash
mkcert -CAROOT
# 위 명령이 출력하는 디렉터리에서 rootCA.pem을 스마트폰으로 전송
```

iOS: 프로파일로 설치 → 설정 → 일반 → VPN 및 기기 관리 → 프로파일 신뢰
Android: 설정 → 보안 → 신뢰할 수 있는 자격 증명 → CA 인증서 설치

### 옵션 B — 브라우저 경고 우회

처음 접속 시 "안전하지 않음" 경고가 뜨면 "고급 → 계속 진행". `getUserMedia`는 이 상태에서도 권한만 허용하면 동작합니다(차량 안 자기 폰만 쓰는 단일 사용자 시나리오 한정).

## 보안 주의

- mkcert 인증서는 **로컬 개발용**. 인터넷에 공개 노출 금지.
- `pi/certs/key.pem`은 비공개 키이므로 git에 절대 커밋하지 마세요.
- `pi_server.py`의 기본 바인딩은 `PI_HOST`(LAN IP). `0.0.0.0`은 `HOST=0.0.0.0` 환경변수를 명시해야 활성화되며, 이 경우 사내망/방화벽 분리를 직접 책임져야 합니다.
