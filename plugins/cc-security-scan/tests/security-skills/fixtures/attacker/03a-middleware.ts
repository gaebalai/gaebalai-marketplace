// Fixture (Attacker): 복수 파일에 걸친 인가 우회 - Part A
// 이 파일 단체로는 문제없이 보인다
// middleware 에서 토큰의 「존재」 만 체크하고 있지만, orgId 는 검증하지 않는다

import { NextRequest, NextResponse } from "next/server";
import jwt from "jsonwebtoken";

export function middleware(req: NextRequest) {
  const token = req.headers.get("Authorization")?.replace("Bearer ", "");

  if (!token) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    // 토큰의 서명을 검증 (이것 자체는 올바르다)
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as {
      userId: string;
      orgIds: string[];  // ← 이 사용자가 소속된 org 의 일람
    };

    // userId 를 후속 요청의 헤더에 전송
    const requestHeaders = new Headers(req.headers);
    requestHeaders.set("X-User-Id", decoded.userId);
    // ❌ orgIds 는 헤더에 전송하지 않는다 → 라우트 핸들러가 독자적으로 orgId 를 검증할 수 없다

    return NextResponse.next({ request: { headers: requestHeaders } });
  } catch {
    return NextResponse.json({ error: "Invalid token" }, { status: 401 });
  }
}
