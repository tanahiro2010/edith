import {
  doublePrecision,
  index,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uuid,
} from "drizzle-orm/pg-core";

// PRD §10: Agent Session（ユーザー ↔ E.D.I.T.H の対話セッション）と
// Conversation Session（ユーザー ↔ 第三者の現実の会話）は別概念として扱う。

export const conversationStatus = pgEnum("conversation_status", [
  "recording",
  "completed",
]);

export const participantRole = pgEnum("participant_role", [
  "user",
  "person",
  "unknown",
]);

export const agentActionStatus = pgEnum("agent_action_status", [
  "pending",
  "completed",
  "failed",
]);

/** PRD §11: AgentSession — ユーザーと E.D.I.T.H 間の対話セッション。 */
export const agentSessions = pgTable("agent_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

/** PRD §11: Conversation — ユーザーと第三者の現実の会話ログ。 */
export const conversations = pgTable(
  "conversations",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull(),
    status: conversationStatus("status").notNull().default("recording"),
    // 会話後処理（PRD §16）で LLM が生成する要約・トピック。MVP では summary のみでも可。
    summary: text("summary"),
    topics: jsonb("topics").$type<string[]>().notNull().default([]),
    startedAt: timestamp("started_at", { withTimezone: true }).notNull().defaultNow(),
    endedAt: timestamp("ended_at", { withTimezone: true }),
  },
  (table) => [index("conversations_user_started_idx").on(table.userId, table.startedAt)],
);

/**
 * PRD §11: ConversationParticipant。personId は face_api 側の Person を指すが、
 * 別サービス・別DBのため外部キー制約は張らない（疎結合を保つ）。
 */
export const conversationParticipants = pgTable("conversation_participants", {
  id: uuid("id").primaryKey().defaultRandom(),
  conversationId: uuid("conversation_id")
    .notNull()
    .references(() => conversations.id, { onDelete: "cascade" }),
  personId: uuid("person_id"),
  // 参加登録時点で判明していれば名前を保持しておく（検索・表示用のスナップショット）。
  displayName: text("display_name"),
  role: participantRole("role").notNull().default("unknown"),
});

/** PRD §11: Utterance — 発話単位のログ。 */
export const utterances = pgTable(
  "utterances",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    conversationId: uuid("conversation_id")
      .notNull()
      .references(() => conversations.id, { onDelete: "cascade" }),
    // "user" / "unknown" / person_id 文字列など（MVP では自由文字列で許容）。
    speakerId: text("speaker_id"),
    text: text("text").notNull(),
    confidence: doublePrecision("confidence"),
    startedAt: timestamp("started_at", { withTimezone: true }).notNull().defaultNow(),
    endedAt: timestamp("ended_at", { withTimezone: true }),
  },
  (table) => [index("utterances_conversation_idx").on(table.conversationId, table.startedAt)],
);

/**
 * PRD §11 / §20: AgentAction — Agent がクライアント（グラス等）へ返す
 * デバイス操作要求（capture_face など）。requestId として id をそのまま使う。
 */
export const agentActions = pgTable("agent_actions", {
  id: uuid("id").primaryKey().defaultRandom(),
  sessionId: uuid("session_id")
    .notNull()
    .references(() => agentSessions.id, { onDelete: "cascade" }),
  type: text("type").notNull(),
  status: agentActionStatus("status").notNull().default("pending"),
  payload: jsonb("payload").$type<Record<string, unknown>>().notNull().default({}),
  // クライアントが Action 実行後に返す結果（/v1/agent/actions/:id/result）。
  result: jsonb("result").$type<Record<string, unknown>>(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
