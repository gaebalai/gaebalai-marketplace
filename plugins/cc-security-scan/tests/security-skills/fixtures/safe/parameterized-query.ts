// Fixture: Safe - 파라미터화 쿼리 (거짓 양성 테스트용)

import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

export async function getOrganization(orgId: string) {
  // ✅ 파라미터화 쿼리 (안전)
  const query = {
    query: "SELECT * FROM c WHERE c.orgId = @orgId AND c.type = 'organization'",
    parameters: [{ name: "@orgId", value: orgId }],
  };

  const { resources } = await client
    .database("analytics")
    .container("organizations")
    .items.query(query)
    .fetchAll();

  return resources;
}
