import { eq } from "drizzle-orm";

import { db, schema } from "../../infrastructure/database/client.js";

const { agentSessions, agentActions } = schema;

export const sessionRepo = {
  async create(userId: string) {
    const [row] = await db.insert(agentSessions).values({ userId }).returning();
    if (!row) throw new Error("failed to create agent session");
    return row;
  },

  async get(sessionId: string) {
    return db.query.agentSessions.findFirst({ where: eq(agentSessions.id, sessionId) });
  },

  /** セッションが存在すれば返し、無ければ新規作成する（MVP は暗黙生成でよい）。 */
  async ensure(sessionId: string | undefined, userId: string) {
    if (sessionId) {
      const existing = await this.get(sessionId);
      if (existing) return existing;
    }
    return this.create(userId);
  },
};

export const actionRepo = {
  async create(sessionId: string, type: string, payload: Record<string, unknown>) {
    const [row] = await db
      .insert(agentActions)
      .values({ sessionId, type, payload })
      .returning();
    if (!row) throw new Error("failed to create agent action");
    return row;
  },

  async get(actionId: string) {
    return db.query.agentActions.findFirst({ where: eq(agentActions.id, actionId) });
  },

  async complete(actionId: string, result: Record<string, unknown>, ok: boolean) {
    const [row] = await db
      .update(agentActions)
      .set({ status: ok ? "completed" : "failed", result })
      .where(eq(agentActions.id, actionId))
      .returning();
    return row;
  },
};
