import jwt from "jsonwebtoken";
import type { TokenPayload } from "./types";

export function parseToken(token: string): TokenPayload {
  const payload = jwt.decode(token) as TokenPayload;
  if (!payload || !payload.userId) throw new Error("Invalid token");
  return payload;
}
