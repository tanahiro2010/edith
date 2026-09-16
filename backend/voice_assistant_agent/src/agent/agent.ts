import type OpenAI from "openai";

import { matchCommand, normalize } from "../commands/matcher.js";
import { conversationRepo } from "../domain/conversation/repository.js";
import { actionRepo } from "../domain/agent/session-repository.js";
import { faceApi } from "../infrastructure/face/face-api-client.js";
import { LLM_MODEL, llm } from "../infrastructure/llm/client.js";
import { getTool, toOpenAiTools, tools } from "../tools/registry.js";
import type { ClientAction, ToolContext } from "../tools/types.js";
import { buildSystemPrompt } from "./prompt.js";

const MAX_TOOL_ROUNDS = 5;

export interface AgentRunInput {
  userId: string;
  sessionId: string;
  content: string;
}

export interface AgentToolTrace {
  name: string;
  args: Record<string, unknown>;
  result: Record<string, unknown>;
}

export interface AgentResult {
  message: string;
  actions: ClientAction[];
  toolCalls: AgentToolTrace[];
}

/** PRD §19 Agent Pipeline: Normalize → Command Matcher →（一致: Tool / 不一致: LLM）。 */
export async function runAgent(input: AgentRunInput): Promise<AgentResult> {
  const now = new Date();
  const active = await conversationRepo.findActive(input.userId);

  const actions: ClientAction[] = [];
  const ctx: ToolContext = {
    userId: input.userId,
    sessionId: input.sessionId,
    faceApi,
    activeConversationId: active?.id,
    pushAction: async (type, payload) => {
      const row = await actionRepo.create(input.sessionId, type, payload);
      const action: ClientAction = { id: row.id, type, payload };
      actions.push(action);
      return action;
    },
  };

  // 1) 明確な Command は決定的に処理（LLM を介さない）。
  const matched = matchCommand(input.content);
  if (matched) {
    const tool = getTool(matched.tool);
    if (tool) {
      const outcome = await tool.execute(matched.args, ctx);
      return {
        message: buildCommandMessage(matched.tool, outcome.result),
        actions,
        toolCalls: [{ name: tool.name, args: matched.args, result: outcome.result }],
      };
    }
  }

  // 2) それ以外は LLM に委ね、Tool Calling ループを回す。
  const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
    { role: "system", content: buildSystemPrompt(now) },
    { role: "user", content: normalize(input.content) },
  ];
  const toolCalls: AgentToolTrace[] = [];

  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    const completion = await llm.chat.completions.create({
      model: LLM_MODEL,
      messages,
      tools: toOpenAiTools(),
      tool_choice: "auto",
    });

    const choice = completion.choices[0]?.message;
    if (!choice) break;

    if (!choice.tool_calls || choice.tool_calls.length === 0) {
      return { message: choice.content ?? "", actions, toolCalls };
    }

    // アシスタントの tool_calls を履歴へ追加してから各 Tool を実行する。
    messages.push({
      role: "assistant",
      content: choice.content ?? "",
      tool_calls: choice.tool_calls,
    });

    for (const call of choice.tool_calls) {
      if (call.type !== "function") continue;
      const result = await executeToolCall(call, ctx, toolCalls);
      messages.push({
        role: "tool",
        tool_call_id: call.id,
        content: JSON.stringify(result),
      });
    }
  }

  // ラウンド上限に達した場合のフォールバック。
  return {
    message: "処理が完了しませんでした。もう一度指示してください。",
    actions,
    toolCalls,
  };
}

async function executeToolCall(
  call: OpenAI.Chat.Completions.ChatCompletionMessageToolCall,
  ctx: ToolContext,
  trace: AgentToolTrace[],
): Promise<Record<string, unknown>> {
  if (call.type !== "function") return { ok: false, error: "unsupported tool call" };
  const tool = getTool(call.function.name);
  let args: Record<string, unknown> = {};
  try {
    args = call.function.arguments ? JSON.parse(call.function.arguments) : {};
  } catch {
    // 引数が壊れていても Tool 側でバリデーションできるよう空で続行。
  }
  if (!tool) {
    const result = { ok: false, error: `unknown tool: ${call.function.name}` };
    trace.push({ name: call.function.name, args, result });
    return result;
  }
  try {
    const outcome = await tool.execute(args, ctx);
    trace.push({ name: tool.name, args, result: outcome.result });
    return outcome.result;
  } catch (err) {
    const result = { ok: false, error: err instanceof Error ? err.message : String(err) };
    trace.push({ name: tool.name, args, result });
    return result;
  }
}

/** Command 一致時の定型応答（PRD §18 の低レイテンシ経路）。 */
function buildCommandMessage(toolName: string, result: Record<string, unknown>): string {
  if (result.ok === false) {
    return String(result.error ?? "処理に失敗しました。");
  }
  if (toolName === "stop_conversation" && typeof result.summary === "string") {
    return `会話を保存しました。\n要約: ${result.summary}`;
  }
  return String(result.message ?? "完了しました。");
}

export const registeredToolNames = tools.map((t) => t.name);
