// Fixture (Attacker Safe): Origin 화이트리스트에 의한 안전한 CORS 설정
// Origin 을 동적으로 처리하고 있지만, 화이트리스트 검증 완료이기 때문에 안전

const ALLOWED_ORIGINS = [
  "https://app.example.com",
  "https://staging.example.com",
  "http://localhost:3000",
];

function getAllowedOrigin(requestOrigin: string | null): string {
  // ✅ 화이트리스트에 포함되는 경우에만 그 오리진을 반환
  // 포함되지 않는 경우에는 최초의 허가 오리진을 반환 (또는 리젝트)
  if (requestOrigin && ALLOWED_ORIGINS.includes(requestOrigin)) {
    return requestOrigin;
  }
  return ALLOWED_ORIGINS[0];
}

export async function OPTIONS(req: Request) {
  const origin = getAllowedOrigin(req.headers.get("Origin"));

  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": origin,      // ✅ 화이트리스트 검증 완료
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    },
  });
}
