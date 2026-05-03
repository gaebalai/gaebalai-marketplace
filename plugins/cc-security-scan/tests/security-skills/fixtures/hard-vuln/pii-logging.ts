// Fixture (Hard): PII · 인증 정보의 로그 출력
// 로그처럼 보이지만, 실은 기밀 정보를 출력하고 있다

import { InvocationContext } from "@azure/functions";

interface LoginRequest {
  email: string;
  password: string;
  orgId: string;
}

export async function handleLogin(body: LoginRequest, context: InvocationContext) {
  const { email, password, orgId } = body;

  // ❌ 비밀번호를 그대로 로그에 출력
  context.log(`Login attempt: email=${email}, password=${password}, orgId=${orgId}`);

  const user = await authenticate(email, password);

  if (!user) {
    // ❌ 실패 시에도 인증 정보를 포함해서 로그 출력
    context.error(`Authentication failed for email=${email} password=${password}`);
    return { status: 401 };
  }

  // ❌ JWT 토큰을 로그에 출력
  const token = generateToken(user);
  context.log(`Token issued: ${token}`);

  return { status: 200, token };
}

async function authenticate(email: string, password: string) {
  // 생략
  return null;
}

function generateToken(user: any) {
  return "dummy-token";
}
