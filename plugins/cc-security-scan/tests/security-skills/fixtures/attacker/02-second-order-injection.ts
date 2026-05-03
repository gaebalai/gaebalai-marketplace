// Fixture (Attacker): 2 차 인젝션 (Second-Order Injection)
// 저장 시는 새니타이즈하지만, 꺼내서 사용할 때 재새니타이즈하지 않는다
// 공격자는 페이로드를 한 번 「안전하게」 저장시켜, 나중에 발화시킨다

import { CosmosClient } from "@azure/cosmos";
const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const tags = client.database("analytics").container("tags");
const reports = client.database("analytics").container("reports");

// Step 1: 태그를 저장 (언뜻 새니타이즈 완료)
export async function createTag(req: Request) {
  const { name } = await req.json();

  // XSS 대책으로서 < > 만 제거 (불완전한 새니타이즈)
  const safeName = name.replace(/[<>]/g, "");

  // ✅ 저장 시점에서는 SQL 인젝션은 일어나지 않는다 (파라미터화)
  await tags.items.create({ name: safeName, createdAt: Date.now() });
  return Response.json({ success: true });
}

// Step 2: 저장된 태그명을 사용해서 리포트를 검색 (여기가 취약)
export async function getReportByTagName(tagId: string) {
  // DB 에서 취득한 값은 「안전」 이라고 단정 짓고 있다
  const { resource: tag } = await tags.item(tagId, tagId).read();

  // ❌ DB 에서 취득한 값을 재새니타이즈 없이 쿼리에 임베드
  // 공격자가 name = "normal') OR ('1'='1" 이라는 태그명을 저장해 두었던 경우,
  // 여기서 모든 리포트를 가져갈 수 있다
  const query = `SELECT * FROM c WHERE c.tag = '${tag.name}' AND c.type = 'report'`;

  const { resources } = await reports.items.query(query).fetchAll();
  return resources;
}
