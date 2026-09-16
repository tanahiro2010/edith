// PRD §18/§19: 明確な Command は LLM を介さず決定的に処理し、レイテンシ・コスト・
// 誤動作を減らす。ここでは会話の開始/終了のみを対象とする（顔登録や検索は文脈依存の
// 引数が要るため LLM に任せる）。

export interface MatchedCommand {
  tool: "start_conversation" | "stop_conversation";
  args: Record<string, unknown>;
}

const START_PATTERNS = [
  /会話.*記録.*開始/,
  /記録.*開始/,
  /ログ.*開始/,
  /会話.*開始/,
  /この会話.*(覚え|記録)/,
  /会話.*記録して/,
];

const STOP_PATTERNS = [
  /記録.*終了/,
  /記録.*終わ/,
  /ログ.*(止め|停止|終了)/,
  /会話.*記録.*終わ/,
  /記録.*やめ/,
];

/** 入力を正規化する（前後空白除去・全角空白潰し）。 */
export function normalize(input: string): string {
  return input.trim().replace(/　/g, " ").replace(/\s+/g, " ");
}

export function matchCommand(input: string): MatchedCommand | null {
  const text = normalize(input);
  if (START_PATTERNS.some((re) => re.test(text))) {
    return { tool: "start_conversation", args: {} };
  }
  if (STOP_PATTERNS.some((re) => re.test(text))) {
    return { tool: "stop_conversation", args: {} };
  }
  return null;
}
