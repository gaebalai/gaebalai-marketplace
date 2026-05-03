// Fixture (Attacker): OAuth 콜백 후의 오픈 리다이렉트
// 인증 플로우 완료 후에 공격자 사이트로 리다이렉트시켜 세션 토큰을 훔친다
//
// 공격 절차:
// 1. 공격자가 /auth/callback?code=xxx&state=https://phishing.com 의 링크를 피해자에게 클릭하게 한다
// 2. 인증은 정상적으로 완료된다
// 3. 피해자가 phishing.com 으로 리다이렉트된다 (URL 바가 바뀌므로 알아채기 어렵다)
// 4. phishing.com 이 리퍼러나 액세스 토큰을 훔친다

import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const code = searchParams.get("code");
  const returnTo = searchParams.get("state") || "/";   // state 에 돌아갈 URL 을 넣는 설계

  if (!code) {
    return NextResponse.redirect("/login");
  }

  // Azure AD 에서 토큰 취득 (정당한 처리)
  const tokenRes = await fetch("https://login.microsoftonline.com/token", {
    method: "POST",
    body: new URLSearchParams({ code, grant_type: "authorization_code" }),
  });
  const { access_token } = await tokenRes.json();

  if (!access_token) {
    return NextResponse.redirect("/login?error=auth_failed");
  }

  // 세션 Cookie 를 설정
  const response = NextResponse.redirect(returnTo);  // ❌ state 의 값을 검증하지 않고 리다이렉트
  response.cookies.set("session", access_token, { httpOnly: true });
  return response;
}
