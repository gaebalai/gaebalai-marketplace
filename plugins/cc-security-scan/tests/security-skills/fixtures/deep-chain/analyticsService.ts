import { CosmosClient } from "@azure/cosmos";
import { assertOrgAccess } from "./permissionService";
import type { UserContext, AnalyticsQuery } from "./types";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

export async function runQuery(ctx: UserContext, query: AnalyticsQuery) {
  assertOrgAccess(ctx, query.orgId);

  const { resources } = await client
    .database("analytics")
    .container("reports")
    .items.query({
      query: "SELECT * FROM c WHERE c.orgId = @orgId AND c.date BETWEEN @start AND @end",
      parameters: [
        { name: "@orgId", value: query.orgId },
        { name: "@start", value: query.startDate },
        { name: "@end", value: query.endDate },
      ],
    })
    .fetchAll();

  return resources;
}
