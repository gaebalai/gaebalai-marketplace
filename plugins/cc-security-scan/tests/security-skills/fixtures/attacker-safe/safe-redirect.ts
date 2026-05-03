// Fixture (Attacker Safe): 화이트리스트에 의한 안전한 리다이렉트
// open redirect 처럼 보이지만, allowlist 로 완전히 제어되어 있다

import { NextResponse } from "next/server";

const ALLOWED_REDIRECT_PATHS = ["/dashboard", "/analytics", "/settings", "/"];

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const returnTo = searchParams.get("returnTo") || "/";

  // ✅ URL 을 파싱해서 동일 오리진이면서 allowlist 내의 패스만 허가
  let safePath = "/";
  try {
    const parsed = new URL(returnTo, "http://localhost"); // 상대 패스를 해석하기 위한 더미 베이스
    // 외부 도메인에 대한 리다이렉트를 거부 (pathname 만 사용)
    const pathname = parsed.pathname;
    if (ALLOWED_REDIRECT_PATHS.some((allowed) => pathname.startsWith(allowed))) {
      safePath = pathname;
    }
  } catch {
    safePath = "/";
  }

  return NextResponse.redirect(new URL(safePath, req.url));
}
