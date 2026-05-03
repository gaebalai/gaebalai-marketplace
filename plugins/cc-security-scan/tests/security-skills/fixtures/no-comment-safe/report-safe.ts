import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const db = client.database("analytics");

export async function POST(req: Request) {
  const { orgId, month } = await req.json();

  const { resources } = await db
    .container("reports")
    .items.query({
      query: "SELECT * FROM c WHERE c.orgId = @orgId AND c.month = @month",
      parameters: [
        { name: "@orgId", value: orgId },
        { name: "@month", value: month },
      ],
    })
    .fetchAll();

  return Response.json(resources);
}
