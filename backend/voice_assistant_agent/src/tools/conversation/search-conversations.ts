import { conversationRepo } from "../../domain/conversation/repository.js";
import type { AgentTool } from "../types.js";

// PRD §7 search_conversations: 過去の Conversation を検索する。
// 相対日付("昨日"等)は system prompt に現在日時を注入し、LLM が from/to(ISO8601)へ
// 変換してから渡す前提。ここでは受け取った条件で DB を絞り込む。
export const searchConversationsTool: AgentTool = {
  name: "search_conversations",
  description:
    "過去の会話を検索する（例: 「昨日田中さんと何話した？」）。相手の名前(name)や期間(from/to)で絞り込み、要約と発話を返す。相対的な日付はあらかじめ ISO8601 の from/to に変換して渡すこと。",
  parameters: {
    type: "object",
    properties: {
      query: { type: "string", description: "検索の意図（任意のメモ）" },
      name: { type: "string", description: "会話相手の名前" },
      personId: { type: "string", description: "会話相手の人物ID" },
      from: { type: "string", description: "検索開始日時（ISO8601, 例: 2026-09-15T00:00:00+09:00）" },
      to: { type: "string", description: "検索終了日時（ISO8601）" },
    },
    additionalProperties: false,
  },
  async execute(args, ctx) {
    const from = args.from ? new Date(String(args.from)) : undefined;
    const to = args.to ? new Date(String(args.to)) : undefined;

    const conversations = await conversationRepo.search({
      userId: ctx.userId,
      name: args.name ? String(args.name) : undefined,
      personId: args.personId ? String(args.personId) : undefined,
      from: from && !isNaN(from.getTime()) ? from : undefined,
      to: to && !isNaN(to.getTime()) ? to : undefined,
    });

    if (conversations.length === 0) {
      return { result: { count: 0, conversations: [], message: "該当する会話は見つかりませんでした。" } };
    }

    // 各会話に発話も添える（要約が未生成＝recording 中の会話にも対応するため）。
    const enriched = await Promise.all(
      conversations.map(async (c) => {
        const utterances = await conversationRepo.listUtterances(c.id);
        return {
          id: c.id,
          status: c.status,
          startedAt: c.startedAt,
          endedAt: c.endedAt,
          summary: c.summary,
          topics: c.topics,
          utterances: utterances.map((u) => ({ speaker: u.speakerId, text: u.text })),
        };
      }),
    );

    return { result: { count: enriched.length, conversations: enriched } };
  },
};
