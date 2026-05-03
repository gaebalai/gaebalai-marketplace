// Fixture (Attacker): CORS + Credentials 의 조합에 의한 횡단적 데이터 탈취
// 단독으로는 문제없이 보이지만, 2 개의 설정의 조합이 위험
//
// 공격 절차:
// 1. 공격자가 evil.com 을 준비하고, 피해자를 유도한다
// 2. evil.com 에서 fetch("https://app.example.com/api/analytics", { credentials: "include" })
// 3. ACAO 가 요청 출처의 Origin 을 반사 → evil.com 이 허가된다
// 4. ACAC: true → Cookie (세션) 가 붙은 요청이 통한다
// 5. 피해자의 인증된 세션으로 모든 데이터가 취득된다

export async function OPTIONS(req: Request) {
  const origin = req.headers.get("Origin") ?? "*";

  // ❌ 요청 출처의 Origin 을 그대로 반사 (화이트리스트 없음)
  // ❌ Allow-Credentials: true 와 조합함으로써 임의 사이트로부터의
  //    인증된 크로스 오리진 요청을 허가해 버린다
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}

export async function POST(req: Request) {
  const origin = req.headers.get("Origin") ?? "*";

  // GET/POST 에도 같은 CORS 헤더를 부여
  const res = await handleAnalytics(req);
  res.headers.set("Access-Control-Allow-Origin", origin);     // ❌
  res.headers.set("Access-Control-Allow-Credentials", "true"); // ❌
  return res;
}

async function handleAnalytics(req: Request) {
  return Response.json({ data: [] });
}
