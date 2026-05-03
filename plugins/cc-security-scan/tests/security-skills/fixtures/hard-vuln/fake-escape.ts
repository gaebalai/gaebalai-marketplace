// Fixture (Hard): 가짜 이스케이프 처리
// 이스케이프하고 있는 것처럼 보이지만, 아직 위험

import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

export async function searchOrganizations(req: Request) {
  const { name } = await req.json();

  // 언뜻 이스케이프하고 있는 것처럼 보인다
  const safeName = name.replace(/'/g, "''");

  // ❌ 아직 템플릿 리터럴로 임베드하고 있다
  // CosmosDB SQL 은 LIKE 절에서 와일드카드를 사용할 수 있기 때문에
  // % 나 _ 에 의한 인젝션이 가능하다
  const query = `SELECT * FROM c WHERE CONTAINS(c.name, '${safeName}')`;

  const { resources } = await client
    .database("analytics")
    .container("organizations")
    .items.query(query)
    .fetchAll();

  return resources;
}
