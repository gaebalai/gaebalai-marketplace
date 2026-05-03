import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const db = client.database("analytics");

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const id = searchParams.get("id");

  const { resource } = await db.container("reports").item(id!, id!).read();
  return Response.json(resource);
}

export async function POST(req: Request) {
  const { orgId, month } = await req.json();
  const query = `SELECT * FROM c WHERE c.orgId = '${orgId}' AND c.month = '${month}'`;
  const { resources } = await db.container("reports").items.query(query).fetchAll();
  return Response.json(resources);
}
