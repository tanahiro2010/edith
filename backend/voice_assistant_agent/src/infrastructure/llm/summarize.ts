import { LLM_MODEL, llm } from "./client.js";

export interface ConversationSummary {
  summary: string;
  topics: string[];
}

// PRD §16: Conversation 終了後、LLM で summary / topics を生成する。
// MVP では summary のみでも可だが、topics も併せて抽出しておく。
export async function summarizeConversation(
  utterances: { speakerId: string | null; text: string }[],
): Promise<ConversationSummary> {
  if (utterances.length === 0) {
    return { summary: "（発話が記録されていません）", topics: [] };
  }

  const transcript = utterances.map((u) => `${u.speakerId ?? "unknown"}: ${u.text}`).join("\n");

  const completion = await llm.chat.completions.create({
    model: LLM_MODEL,
    messages: [
      {
        role: "system",
        content:
          "あなたは会話ログを要約するアシスタントです。与えられた会話の Transcript から、" +
          "日本語で簡潔な要約(summary)と主要なトピック(topics)を JSON で出力してください。" +
          '出力は必ず {"summary": string, "topics": string[]} 形式の JSON のみ。',
      },
      { role: "user", content: `以下の会話を要約してください:\n\n${transcript}` },
    ],
    response_format: { type: "json_object" },
  });

  const raw = completion.choices[0]?.message?.content ?? "{}";
  try {
    const parsed = JSON.parse(raw) as Partial<ConversationSummary>;
    return {
      summary: parsed.summary ?? "（要約を生成できませんでした）",
      topics: Array.isArray(parsed.topics) ? parsed.topics : [],
    };
  } catch {
    return { summary: raw.slice(0, 500), topics: [] };
  }
}
