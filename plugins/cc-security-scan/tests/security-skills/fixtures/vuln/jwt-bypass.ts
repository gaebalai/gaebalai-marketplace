// Fixture: JWT Verification Bypass
// 의도적으로 취약한 코드 - 테스트용

import jwt from "jsonwebtoken";

// ❌ verify 가 아니라 decode (서명을 검증하지 않는다)
export function getUser(token: string) {
  const decoded = jwt.decode(token);  // 서명 검증 없음! 누구든 위조할 수 있다
  return decoded as { userId: string; role: string };
}

// ❌ alg: none 을 허가
export function verifyToken(token: string) {
  return jwt.verify(token, "", { algorithms: ["none", "HS256"] });
}
