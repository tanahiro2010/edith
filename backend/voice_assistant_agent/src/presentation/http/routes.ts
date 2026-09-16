import { Hono } from "hono";

import { runAgent } from "../../agent/agent.js";
import { config } from "../../config.js";
import { conversationRepo } from "../../domain/conversation/repository.js";
import { actionRepo, sessionRepo } from "../../domain/agent/session-repository.js";
import { summarizeConversation } from "../../infrastructure/llm/summarize.js";
import { stt } from "../../infrastructure/stt/http-whisper-provider.js";

export const api = new Hono();

// MVP: 認証は未実装（PRD §22 は将来対応）。全リクエストを既定ユーザーに紐付ける。
const userId = () => config.defaultUserId;

api.get("/health", (c) => c.json({ ok: true, service: "edith-voice-agent" }));

// --- Agent ---

// PRD §8.1 Agent Input（テキスト）。音声(§8 Audio Input)は Phase 2 で追加。
api.post("/v1/agent/input", async (c) => {
  const body = await c.req.json<{ sessionId?: string; type?: string; content?: string }>();
  if (!body.content || typeof body.content !== "string") {
    return c.json({ error: "content(text) is required" }, 400);
  }

  const session = await sessionRepo.ensure(body.sessionId, userId());
  const result = await runAgent({
    userId: userId(),
    sessionId: session.id,
    content: body.content,
  });

  return c.json({
    sessionId: session.id,
    message: result.message,
    actions: result.actions,
    toolCalls: result.toolCalls,
  });
});

// PRD §8 Audio Input / §12 音声処理(Phase 2, Push-to-Talk):
// 音声を受け取り、ローカル STT で文字起こししてから Agent に流す。
// MVP初期は multipart/form-data（将来 WebSocket へ移行）。
api.post("/v1/agent/audio", async (c) => {
  const body = await c.req.parseBody();
  const file = body.audio;
  if (!(file instanceof File)) {
    return c.json({ error: "audio(file) is required (multipart/form-data)" }, 400);
  }
  const sessionIdField = typeof body.sessionId === "string" ? body.sessionId : undefined;

  // 1) ローカル STT で文字起こし（日本語想定。language 未指定なら自動判定）。
  let transcript;
  try {
    transcript = await stt.transcribe({
      bytes: await file.arrayBuffer(),
      filename: file.name || "audio.wav",
      mimeType: file.type || "application/octet-stream",
      language: typeof body.language === "string" ? body.language : "ja",
    });
  } catch (err) {
    return c.json({ error: `transcription failed: ${err instanceof Error ? err.message : err}` }, 502);
  }

  if (!transcript.text) {
    return c.json({ transcript: "", message: "音声を認識できませんでした。", actions: [], toolCalls: [] });
  }

  // 2) 文字起こし結果をテキスト指示として Agent に投入。
  const session = await sessionRepo.ensure(sessionIdField, userId());
  const result = await runAgent({ userId: userId(), sessionId: session.id, content: transcript.text });

  return c.json({
    sessionId: session.id,
    transcript: transcript.text,
    message: result.message,
    actions: result.actions,
    toolCalls: result.toolCalls,
  });
});

// PRD §8 Action Result: クライアントが実行した Action の結果を返す。
api.post("/v1/agent/actions/:requestId/result", async (c) => {
  const requestId = c.req.param("requestId");
  const action = await actionRepo.get(requestId);
  if (!action) return c.json({ error: "action not found" }, 404);

  const body = await c.req.json<Record<string, unknown>>().catch(() => ({}) as Record<string, unknown>);
  const ok = body.success !== false;
  const updated = await actionRepo.complete(requestId, body, ok);
  return c.json({ ok: true, action: updated });
});

// --- Conversation（現実の会話ログ。クライアントが直接叩く用。PRD §8） ---

api.post("/v1/conversations", async (c) => {
  const body = await c.req
    .json<{ participants?: { personId?: string; name?: string }[] }>()
    .catch(() => ({ participants: [] }));
  const participants = (body.participants ?? []).map((p) => ({
    personId: p.personId ?? null,
    displayName: p.name ?? null,
    role: "person" as const,
  }));
  const conversation = await conversationRepo.create(userId(), participants);
  return c.json(conversation, 201);
});

// PRD §8 発話登録。会話ログ中に文字起こし結果を積む。
api.post("/v1/conversations/:id/utterances", async (c) => {
  const conversationId = c.req.param("id");
  const conversation = await conversationRepo.get(conversationId);
  if (!conversation) return c.json({ error: "conversation not found" }, 404);

  const body = await c.req.json<{ text?: string; speakerId?: string; confidence?: number }>();
  if (!body.text) return c.json({ error: "text is required" }, 400);

  const utterance = await conversationRepo.addUtterance({
    conversationId,
    text: body.text,
    speakerId: body.speakerId ?? "unknown",
    confidence: body.confidence ?? null,
  });
  return c.json(utterance, 201);
});

// PRD §8 Conversation 終了 + §16 会話後処理（要約生成）。
api.post("/v1/conversations/:id/end", async (c) => {
  const conversationId = c.req.param("id");
  const conversation = await conversationRepo.get(conversationId);
  if (!conversation) return c.json({ error: "conversation not found" }, 404);
  if (conversation.status === "completed") {
    return c.json(conversation);
  }

  const utterances = await conversationRepo.listUtterances(conversationId);
  const { summary, topics } = await summarizeConversation(utterances);
  const updated = await conversationRepo.complete(conversationId, summary, topics, new Date());
  return c.json(updated);
});

// PRD §8 Conversation 検索。name / personId / from / to で絞り込み。
api.get("/v1/conversations", async (c) => {
  const q = c.req.query();
  const from = q.from ? new Date(q.from) : undefined;
  const to = q.to ? new Date(q.to) : undefined;
  const results = await conversationRepo.search({
    userId: userId(),
    name: q.name,
    personId: q.personId,
    from: from && !isNaN(from.getTime()) ? from : undefined,
    to: to && !isNaN(to.getTime()) ? to : undefined,
  });
  return c.json({ count: results.length, conversations: results });
});
