import type { AgentTool } from "../types.js";

// HUD 上の識別子(A, B, ...)で指し示された「未登録の人」に名前を対応付ける。
// 例: 「Aの人の名前は田中だよ」/「Bの人、すでに登録済みの佐藤さんだよ」。
// Agent 自身は顔登録をせず、クライアントへ capture_labeled_face Action を返す。
// クライアントがその識別子のトラックの顔を切り出し、Face API に登録（新規 or 既存へ
// サンプル追加はサーバ側の upsert が判断）する。
export const assignFaceTool: AgentTool = {
  name: "assign_face",
  description:
    "画面(HUD)上の識別子で指し示された人物に名前を紐付けるときに使う。ユーザーが「Aの人の名前は田中だよ」「Bの人、すでに登録されている佐藤さんだよ」のように、識別子(A/B/1 等)と名前を言った場合。新規登録・既存人物への紐付けのどちらもこのツールでよい（クライアントがその顔を撮影して登録する）。",
  parameters: {
    type: "object",
    properties: {
      marker: { type: "string", description: "画面上の識別子（例: A, B, 1）" },
      name: { type: "string", description: "その人物の名前（例: 田中さん）" },
    },
    required: ["marker", "name"],
    additionalProperties: false,
  },
  async execute(args, ctx) {
    const marker = String(args.marker ?? "").trim();
    const name = String(args.name ?? "").trim();
    if (!marker || !name) {
      return { result: { ok: false, error: "識別子と名前の両方を指定してください。" } };
    }
    const action = await ctx.pushAction("capture_labeled_face", { marker, name });
    return {
      result: {
        ok: true,
        requiresAction: {
          type: "capture_labeled_face",
          requestId: action.id,
          payload: { marker, name },
        },
        message: `識別子「${marker}」の人物を ${name} として登録するよう、クライアントに要求しました。`,
      },
    };
  },
};
