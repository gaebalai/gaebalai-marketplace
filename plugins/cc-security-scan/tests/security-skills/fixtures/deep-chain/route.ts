import { buildUserContext } from "./tokenService";
import { runQuery } from "./analyticsService";
import type { AnalyticsQuery } from "./types";

export async function POST(req: Request) {
  const ctx = buildUserContext(req.headers.get("Authorization"));
  const body: AnalyticsQuery = await req.json();
  const data = await runQuery(ctx, body);
  return Response.json({ data });
}
