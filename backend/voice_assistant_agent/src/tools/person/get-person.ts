import type { AgentTool } from "../types.js";

// PRD §7 get_person: 登録済み人物情報を Face API から取得する。
export const getPersonTool: AgentTool = {
  name: "get_person",
  description:
    "登録済みの人物情報（名前・付随情報）を取得する。personId か name のどちらかを指定する。",
  parameters: {
    type: "object",
    properties: {
      personId: { type: "string", description: "人物ID（分かっている場合）" },
      name: { type: "string", description: "人物の名前（例: 田中さん）" },
    },
    additionalProperties: false,
  },
  async execute(args, ctx) {
    const personId = args.personId ? String(args.personId) : undefined;
    const name = args.name ? String(args.name) : undefined;

    if (personId) {
      const person = await ctx.faceApi.getPerson(personId);
      if (!person) return { result: { found: false, message: "該当する人物が見つかりませんでした。" } };
      return { result: { found: true, person } };
    }

    if (name) {
      const matches = await ctx.faceApi.findByName(name);
      if (matches.length === 0)
        return { result: { found: false, message: `${name} は登録されていません。` } };
      return { result: { found: true, people: matches } };
    }

    return { result: { found: false, error: "personId か name のいずれかを指定してください。" } };
  },
};
