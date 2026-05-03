import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const orgs = client.database("app").container("organizations");

export async function POST(req: Request) {
  const userId = req.headers.get("X-MS-CLIENT-PRINCIPAL-ID")!;
  const { orgId, url, events } = await req.json();

  const { resource: org } = await orgs.item(orgId, orgId).read();
  if (!org) return Response.json({ error: "not found" }, { status: 404 });

  await orgs.items.upsert({ ...org, webhook: { url, events } });

  const testRes = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ type: "ping", orgId }),
  });

  return Response.json({ ok: true, status: testRes.status });
}
