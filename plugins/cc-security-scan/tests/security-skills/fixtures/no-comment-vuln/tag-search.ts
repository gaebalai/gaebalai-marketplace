import { CosmosClient } from "@azure/cosmos";

const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const db = client.database("analytics");

export async function createLabel(req: Request) {
  const { name, color } = await req.json();
  const sanitized = name.replace(/[<>"]/g, "");
  await db.container("labels").items.create({ name: sanitized, color });
  return Response.json({ ok: true });
}

export async function getReportsByLabel(labelId: string) {
  const { resource: label } = await db.container("labels").item(labelId, labelId).read();
  const { resources } = await db
    .container("reports")
    .items.query(`SELECT * FROM c WHERE c.label = '${label.name}'`)
    .fetchAll();
  return resources;
}
