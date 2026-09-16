import { and, asc, desc, eq, gte, inArray, lte } from "drizzle-orm";

import { db, schema } from "../../infrastructure/database/client.js";

const { conversations, conversationParticipants, utterances } = schema;

export interface ParticipantInput {
  personId?: string | null;
  displayName?: string | null;
  role?: "user" | "person" | "unknown";
}

export interface ConversationSearchFilter {
  userId: string;
  personId?: string;
  name?: string;
  from?: Date;
  to?: Date;
  limit?: number;
}

export const conversationRepo = {
  async create(userId: string, participants: ParticipantInput[] = []) {
    const [conversation] = await db
      .insert(conversations)
      .values({ userId })
      .returning();
    if (!conversation) throw new Error("failed to create conversation");

    if (participants.length > 0) {
      await db.insert(conversationParticipants).values(
        participants.map((p) => ({
          conversationId: conversation.id,
          personId: p.personId ?? null,
          displayName: p.displayName ?? null,
          role: p.role ?? "unknown",
        })),
      );
    }
    return conversation;
  },

  async get(conversationId: string) {
    return db.query.conversations.findFirst({
      where: eq(conversations.id, conversationId),
    });
  },

  /** ユーザーの現在 recording 中の会話（最新の1件）を返す。無ければ undefined。 */
  async findActive(userId: string) {
    return db.query.conversations.findFirst({
      where: and(eq(conversations.userId, userId), eq(conversations.status, "recording")),
      orderBy: desc(conversations.startedAt),
    });
  },

  async addUtterance(input: {
    conversationId: string;
    text: string;
    speakerId?: string | null;
    confidence?: number | null;
  }) {
    const [row] = await db
      .insert(utterances)
      .values({
        conversationId: input.conversationId,
        text: input.text,
        speakerId: input.speakerId ?? "unknown",
        confidence: input.confidence ?? null,
      })
      .returning();
    return row;
  },

  async listUtterances(conversationId: string) {
    return db
      .select()
      .from(utterances)
      .where(eq(utterances.conversationId, conversationId))
      .orderBy(asc(utterances.startedAt));
  },

  async complete(conversationId: string, summary: string, topics: string[], endedAt: Date) {
    const [row] = await db
      .update(conversations)
      .set({ status: "completed", summary, topics, endedAt })
      .where(eq(conversations.id, conversationId))
      .returning();
    return row;
  },

  /** PRD §7 search_conversations: 参加者(名前/personId)・期間で会話を絞り込む。 */
  async search(filter: ConversationSearchFilter) {
    const conditions = [eq(conversations.userId, filter.userId)];
    if (filter.from) conditions.push(gte(conversations.startedAt, filter.from));
    if (filter.to) conditions.push(lte(conversations.startedAt, filter.to));

    // 参加者フィルタ: 該当する conversation_id を先に集める。
    if (filter.personId || filter.name) {
      const partConditions = [];
      if (filter.personId)
        partConditions.push(eq(conversationParticipants.personId, filter.personId));
      const matchedParticipants = await db
        .select({ conversationId: conversationParticipants.conversationId, displayName: conversationParticipants.displayName })
        .from(conversationParticipants)
        .where(partConditions.length ? and(...partConditions) : undefined);

      let ids = matchedParticipants.map((m) => m.conversationId);
      if (filter.name) {
        const needle = filter.name;
        ids = matchedParticipants
          .filter((m) => (m.displayName ?? "").includes(needle))
          .map((m) => m.conversationId);
      }
      if (ids.length === 0) return [];
      conditions.push(inArray(conversations.id, ids));
    }

    return db
      .select()
      .from(conversations)
      .where(and(...conditions))
      .orderBy(desc(conversations.startedAt))
      .limit(filter.limit ?? 10);
  },
};
