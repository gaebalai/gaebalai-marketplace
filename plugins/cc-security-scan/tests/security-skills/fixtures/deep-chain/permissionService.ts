import type { UserContext } from "./types";

export function assertOrgAccess(ctx: UserContext, orgId: string): void {
  if (!ctx.orgIds.includes(orgId)) {
    throw new Error("Forbidden");
  }
}

export function assertAdminAccess(ctx: UserContext): void {
  if (ctx.role !== "admin") {
    throw new Error("Admin required");
  }
}
