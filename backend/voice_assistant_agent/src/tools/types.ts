import type { FaceApiClient } from "../infrastructure/face/face-api-client.js";

/** Agent がクライアント（グラス等）へ返すデバイス操作要求（PRD §20）。 */
export interface ClientAction {
  id: string;
  type: string;
  payload: Record<string, unknown>;
}

/** Tool 実行時に渡す文脈。DB や外部サービスへのアクセスはここ経由に限定する。 */
export interface ToolContext {
  userId: string;
  sessionId: string;
  faceApi: FaceApiClient;
  /** 現在のアクティブな会話（recording 中）の ID。無ければ undefined。 */
  activeConversationId?: string;
  /** クライアントへ返す Action をキューに積む。 */
  pushAction: (type: string, payload: Record<string, unknown>) => Promise<ClientAction>;
}

/** Tool 実行結果。result は LLM に返す JSON。 */
export interface ToolOutcome {
  result: Record<string, unknown>;
}

export interface AgentTool {
  name: string;
  description: string;
  /** OpenAI function-calling 形式の JSON Schema。 */
  parameters: Record<string, unknown>;
  execute: (args: Record<string, unknown>, ctx: ToolContext) => Promise<ToolOutcome>;
}
