export interface TokenPayload {
  userId: string;
  orgIds: string[];
  role: "admin" | "member" | "viewer";
  exp: number;
}

export interface UserContext {
  userId: string;
  orgIds: string[];
  role: string;
}

export interface AnalyticsQuery {
  orgId: string;
  startDate: string;
  endDate: string;
  metrics: string[];
}
