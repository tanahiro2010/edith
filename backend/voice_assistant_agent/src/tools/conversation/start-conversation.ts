import { conversationRepo, type ParticipantInput } from "../../domain/conversation/repository.js";
import type { AgentTool } from "../types.js";

// PRD §7 start_conversation: 現実の会話ログ(Conversation Session)を開始する。
export const startConversationTool: AgentTool = {
  name: "start_conversation",
  description:
    "ユーザーが会話の記録開始を指示したときに使う（例: 「会話を記録して」「ログ開始」）。新しい Conversation を作成し recording 状態にする。",
  parameters: {
    type: "object",
    properties: {
      participants: {
        type: "array",
        description: "分かっている参加者。personId か name を指定できる。",
        items: {
          type: "object",
          properties: {
            personId: { type: "string" },
            name: { type: "string" },
          },
          additionalProperties: false,
        },
      },
    },
    additionalProperties: false,
  },
  async execute(args, ctx) {
    const rawParticipants = Array.isArray(args.participants) ? args.participants : [];
    const participants: ParticipantInput[] = rawParticipants.map((p) => {
      const obj = (p ?? {}) as Record<string, unknown>;
      return {
        personId: obj.personId ? String(obj.personId) : null,
        displayName: obj.name ? String(obj.name) : null,
        role: "person" as const,
      };
    });

    const conversation = await conversationRepo.create(ctx.userId, participants);
    return {
      result: {
        ok: true,
        conversationId: conversation.id,
        status: conversation.status,
        message: "会話の記録を開始しました。",
      },
    };
  },
};
