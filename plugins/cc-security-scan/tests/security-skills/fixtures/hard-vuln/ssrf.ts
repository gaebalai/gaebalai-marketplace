// Fixture (Hard): SSRF (Server-Side Request Forgery)
// 사용자가 지정한 URL 에 서버에서 요청한다

export async function POST(req: Request) {
  const { webhookUrl, orgId } = await req.json();

  // 언뜻 비즈니스적으로 정당한 기능 (Webhook 등록)
  // ❌ webhookUrl 의 호스트 · 프로토콜을 사용자가 자유롭게 지정할 수 있다
  // 공격자가 http://169.254.169.254/metadata (Azure IMDS) 를 지정하면
  // 클라우드 인증 정보가 유출될 가능성이 있다
  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ event: "test", orgId }),
  });

  const result = await response.json();
  return Response.json({ success: true, result });
}
