// Fixture (Attacker): 복수 파일에 걸친 인가 우회 - Part B
// 03a-middleware.ts 와 함께 읽지 않으면 취약성이 보이지 않는다
//
// middleware 는 「인증 완료」 를 보증하지만 orgId 의 소유권은 보증하지 않는다
// 이 라우트는 orgId 를 요청 보디에서 받아, 소유권 체크 없이 사용한다

import { CosmosClient } from "@azure/cosmos";
const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

export async function POST(req: Request) {
  // middleware 가 부여한 userId (진짜)
  const userId = req.headers.get("X-User-Id")!;

  const { orgId, startDate, endDate } = await req.json();

  // ❌ userId 가 orgId 에 소속되어 있는지 확인하고 있지 않다
  // 공격자는 자신의 정규 토큰으로 인증하고,
  // 타사의 orgId 를 body 에 지정해서 경쟁사의 데이터를 취득할 수 있다
  //
  // middleware 에서는 JWT 의 orgIds 를 전송하고 있지 않기 때문에,
  // 여기서는 「누가 정규 사용자인가」 만 알 수 있고,
  // 「그 사용자가 이 orgId 에 액세스해도 좋은가」 를 검증할 수 없다

  const { resources } = await client
    .database("analytics")
    .container("reports")
    .items.query({
      query: `SELECT * FROM c
              WHERE c.orgId = @orgId
              AND c.date >= @start AND c.date <= @end`,
      parameters: [
        { name: "@orgId", value: orgId },
        { name: "@start", value: startDate },
        { name: "@end", value: endDate },
      ],
    })
    .fetchAll();

  return Response.json({ data: resources });
}
