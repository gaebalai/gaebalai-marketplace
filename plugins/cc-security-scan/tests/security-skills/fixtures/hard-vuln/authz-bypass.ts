// Fixture (Hard): 인가 우회 (횡단 액세스)
// 인증은 되어 있지만, 인가 (자기 데이터인가?) 가 결여되어 있다
// 비즈니스 로직을 모르면 발견하기 어렵다

import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

// 이 함수는 Azure Easy Auth 에 의해 인증된 사용자만이 호출할 수 있다
// 헤더 X-MS-CLIENT-PRINCIPAL-ID 에 userId 가 들어간다
export async function getOrganizationReport(req: Request) {
  const userId = req.headers.get("X-MS-CLIENT-PRINCIPAL-ID"); // 인증 완료 ✅
  const { orgId } = await req.json();

  // ❌ orgId 가 이 userId 에 속해 있는지 체크하지 않는다
  // 공격자는 자신의 userId 로 인증하면서, 타인의 orgId 를 지정할 수 있다
  // 예: 경쟁사의 orgId 를 전수 시도하면 모든 조직의 데이터를 가져갈 수 있다
  const { resources } = await client
    .database("analytics")
    .container("reports")
    .items.query({
      query: "SELECT * FROM c WHERE c.orgId = @orgId",
      parameters: [{ name: "@orgId", value: orgId }],
    })
    .fetchAll();

  return resources;
}
