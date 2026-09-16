import type { AgentTool } from "../types.js";

// PRD §7 register_person: Agent 自身は顔認証を実行しない（PRD §6.1）。
// 代わりに capture_face Action をクライアントへ返し、クライアントがカメラ画像を
// 取得して Face API に登録する。ここでは Action を積むだけ。
export const registerPersonTool: AgentTool = {
  name: "register_person",
  description:
    "ユーザーが目の前の人物を特定の名前で覚えるよう指示したときに使う。実際の顔登録はクライアントがカメラ画像を撮影して Face API に対して行うため、このツールはクライアントに顔撮影(capture_face)を要求するだけで、登録完了そのものは行わない。",
  parameters: {
    type: "object",
    properties: {
      name: { type: "string", description: "登録する人物の名前（例: 田中さん）" },
    },
    required: ["name"],
    additionalProperties: false,
  },
  async execute(args, ctx) {
    const name = String(args.name ?? "").trim();
    if (!name) {
      return { result: { ok: false, error: "name が空です。人物の名前を確認してください。" } };
    }
    const action = await ctx.pushAction("capture_face", { name });
    return {
      result: {
        ok: true,
        requiresAction: { type: "capture_face", requestId: action.id, payload: { name } },
        message: `${name} を登録するため、クライアントに顔撮影を要求しました。`,
      },
    };
  },
};
