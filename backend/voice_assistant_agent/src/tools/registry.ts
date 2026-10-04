import type OpenAI from "openai";

import { assignFaceTool } from "./person/assign-face.js";
import { getPersonTool } from "./person/get-person.js";
import { registerPersonTool } from "./person/register-person.js";
import { searchConversationsTool } from "./conversation/search-conversations.js";
import { startConversationTool } from "./conversation/start-conversation.js";
import { stopConversationTool } from "./conversation/stop-conversation.js";
import type { AgentTool } from "./types.js";

// PRD §7: MVP で実装する Tool 一式。
export const tools: AgentTool[] = [
  registerPersonTool,
  assignFaceTool,
  getPersonTool,
  startConversationTool,
  stopConversationTool,
  searchConversationsTool,
];

const toolByName = new Map(tools.map((t) => [t.name, t]));

export function getTool(name: string): AgentTool | undefined {
  return toolByName.get(name);
}

/** OpenAI chat.completions の tools パラメータ形式へ変換する。 */
export function toOpenAiTools(): OpenAI.Chat.Completions.ChatCompletionTool[] {
  return tools.map((t) => ({
    type: "function",
    function: { name: t.name, description: t.description, parameters: t.parameters },
  }));
}
