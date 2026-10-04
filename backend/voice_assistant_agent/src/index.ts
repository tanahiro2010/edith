import { serve } from "@hono/node-server";
import { serveStatic } from "@hono/node-server/serve-static";
import { Hono } from "hono";

import { config } from "./config.js";
import { runMigrations } from "./infrastructure/database/migrate.js";
import { api } from "./presentation/http/routes.js";

// 起動時に DB 接続確認＋マイグレーション。
// DB が落ちている/テーブル未作成のまま起動して「無言の 500」を返すのを防ぎ、
// 原因を明確にして即座に終了する（よくある: podman/コンテナ停止）。
try {
  await runMigrations();
  console.log("✅ DB ready (migrations up to date)");
} catch (err) {
  console.error(
    "❌ DB に接続/マイグレーションできませんでした。DB コンテナが起動しているか確認してください:\n" +
      "   podman machine start && podman start edith-agent-db\n",
    err,
  );
  process.exit(1);
}

const app = new Hono();

app.route("/", api);

// 簡易テストUI（テキストで Agent を叩ける）。
app.use("/ui/*", serveStatic({ root: "./static", rewriteRequestPath: (p) => p.replace(/^\/ui/, "") }));
app.get("/", (c) => c.redirect("/ui/"));

serve({ fetch: app.fetch, port: config.port }, (info) => {
  console.log(`🧠 E.D.I.T.H Voice Agent listening on http://localhost:${info.port}`);
  console.log(`   Test UI:  http://localhost:${info.port}/ui/`);
  console.log(`   LLM:      ${config.llm.model} @ ${config.llm.baseUrl}`);
  console.log(`   Face API: ${config.faceApiBaseUrl}`);
});
