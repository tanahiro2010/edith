// 環境変数を一箇所に集約する。tsx は .env を自動ロードしないため、
// Node 21+ の process.loadEnvFile() で .env を読み込む（依存追加なし）。
try {
  process.loadEnvFile();
} catch {
  // .env が無い場合（本番で環境変数を直接注入するケース等）は無視する。
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`環境変数 ${name} が設定されていません（.env を確認してください）`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 8010),
  databaseUrl: required("DATABASE_URL"),
  llm: {
    baseUrl: process.env.LLM_BASE_URL ?? "https://api.deniai.app/v1",
    apiKey: required("LLM_API_KEY"),
    model: process.env.LLM_MODEL ?? "openai/gpt-5.2",
  },
  faceApiBaseUrl: process.env.FACE_API_BASE_URL ?? "https://face.unischool.jp",
  // ローカル STT サービス（faster-whisper, backend/stt_service）。
  sttBaseUrl: process.env.STT_BASE_URL ?? "http://localhost:8020",
  // MVP: 認証未実装。全リクエストをこの固定ユーザーに紐付ける（PRD §22 は将来対応）。
  defaultUserId: process.env.DEFAULT_USER_ID ?? "00000000-0000-0000-0000-000000000001",
} as const;
