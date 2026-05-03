import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const users = client.database("app").container("users");

export async function PATCH(req: Request) {
  const userId = req.headers.get("X-MS-CLIENT-PRINCIPAL-ID")!;
  const body = await req.json();

  if (!body.displayName) {
    return Response.json({ error: "displayName is required" }, { status: 400 });
  }

  const { resource: current } = await users.item(userId, userId).read();

  await users.items.upsert({ ...current, ...body, id: userId });

  return Response.json({ ok: true });
}
