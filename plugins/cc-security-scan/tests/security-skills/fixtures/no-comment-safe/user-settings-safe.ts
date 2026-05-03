import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const users = client.database("app").container("users");

const ALLOWED_UPDATE_FIELDS = ["displayName", "avatarUrl", "timezone"] as const;
type AllowedField = (typeof ALLOWED_UPDATE_FIELDS)[number];

export async function PATCH(req: Request) {
  const userId = req.headers.get("X-MS-CLIENT-PRINCIPAL-ID")!;
  const body = await req.json();

  if (!body.displayName) {
    return Response.json({ error: "displayName is required" }, { status: 400 });
  }

  const patch: Partial<Record<AllowedField, unknown>> = {};
  for (const field of ALLOWED_UPDATE_FIELDS) {
    if (field in body) patch[field] = body[field];
  }

  const { resource: current } = await users.item(userId, userId).read();
  await users.items.upsert({ ...current, ...patch, id: userId });

  return Response.json({ ok: true });
}
