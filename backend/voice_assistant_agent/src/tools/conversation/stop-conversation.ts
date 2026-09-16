import { conversationRepo } from "../../domain/conversation/repository.js";
import { summarizeConversation } from "../../infrastructure/llm/summarize.js";
import type { AgentTool } from "../types.js";

// PRD §7 stop_conversation + §16 会話後処理: 会話を終了し、要約を生成して保存する。
export const stopConversationTool: AgentTool = {
  name: "stop_conversation",
  description:
    "ユーザーが会話の記録終了を指示したときに使う（例: 「記録終了」「もうログ止めて」）。指定した Conversation を completed にし、要約を生成する。conversationId を省略した場合は現在アクティブな会話を終了する。",
  parameters: {
    type: "object",
    properties: {
      conversationId: { type: "string", description: "終了する会話ID（省略時はアクティブな会話）" },
    },
    additionalProperties: false,
  },
  async execute(args, ctx) {
    const conversationId = args.conversationId
      ? String(args.conversationId)
      : ctx.activeConversationId;
    if (!conversationId) {
      return { result: { ok: false, error: "終了対象の会話が特定できませんでした。" } };
    }

    const conversation = await conversationRepo.get(conversationId);
    if (!conversation) {
      return { result: { ok: false, error: "指定された会話が見つかりませんでした。" } };
    }
    if (conversation.status === "completed") {
      return {
        result: { ok: true, conversationId, summary: conversation.summary, message: "この会話は既に終了しています。" },
      };
    }

    const utterances = await conversationRepo.listUtterances(conversationId);
    const { summary, topics } = await summarizeConversation(utterances);
    await conversationRepo.complete(conversationId, summary, topics, new Date());

    return {
      result: { ok: true, conversationId, summary, topics, message: "会話を保存しました。" },
    };
  },
};
