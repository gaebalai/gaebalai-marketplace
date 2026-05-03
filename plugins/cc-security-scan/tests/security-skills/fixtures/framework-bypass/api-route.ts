import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);

export async function GET(req: Request) {
  const userId = req.headers.get("X-User-Id");
  if (!userId) return Response.json({ error: "Unauthorized" }, { status: 401 });

  const { resources } = await client
    .database("analytics")
    .container("reports")
    .items.query({
      query: "SELECT * FROM c WHERE c.userId = @userId",
      parameters: [{ name: "@userId", value: userId }],
    })
    .fetchAll();

  return Response.json({ data: resources });
}
