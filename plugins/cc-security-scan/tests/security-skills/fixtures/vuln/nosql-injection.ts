// Fixture: NoSQL Injection (CosmosDB)
// 의도적으로 취약한 코드 - 테스트용

import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

export async function getOrganization(req: Request) {
  const { orgId } = await req.json();

  // ❌ 사용자 입력을 그대로 쿼리에 임베드한다
  const query = `SELECT * FROM c WHERE c.orgId = '${orgId}' AND c.type = 'organization'`;

  const { resources } = await client
    .database("analytics")
    .container("organizations")
    .items.query(query)
    .fetchAll();

  return resources;
}
