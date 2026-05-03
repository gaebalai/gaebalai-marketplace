// Fixture (Attacker): Mass Assignment (대량 대입 공격)
// 언뜻 밸리데이션하고 있는 것처럼 보이지만,
// 사용자 입력을 전체 필드 spread 함으로써 임의 필드를 덮어쓸 수 있다

import { CosmosClient } from "@azure/cosmos";
const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const users = client.database("analytics").container("users");

export async function updateProfile(req: Request) {
  const userId = req.headers.get("X-MS-CLIENT-PRINCIPAL-ID")!;
  const body = await req.json();

  // 개발자는 여기서 「name 은 필수」 라고 밸리데이션하고 있다
  if (!body.name || typeof body.name !== "string") {
    return Response.json({ error: "name is required" }, { status: 400 });
  }

  const { resource: existing } = await users.item(userId, userId).read();

  // ❌ body 를 전체 필드 spread → 공격자가 role: "admin" 이나 orgId: "타인의 org" 를
  //    body 에 섞으면 기존 도큐먼트의 모든 필드를 덮어쓸 수 있다
  await users.items.upsert({
    ...existing,
    ...body,           // ← 여기가 문제
    id: userId,        // id 만은 덮어써지지 않도록 후치하고 있지만 불충분
  });

  return Response.json({ success: true });
}
