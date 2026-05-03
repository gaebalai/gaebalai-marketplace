import { parseToken } from "./jwtHelper";
import type { UserContext } from "./types";

export function buildUserContext(authHeader: string | null): UserContext {
  if (!authHeader?.startsWith("Bearer ")) throw new Error("Unauthorized");
  const token = authHeader.slice(7);
  const payload = parseToken(token);
  return {
    userId: payload.userId,
    orgIds: payload.orgIds,
    role: payload.role,
  };
}
