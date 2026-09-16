import { serve } from "@hono/node-server";
import { serveStatic } from "@hono/node-server/serve-static";
import { Hono } from "hono";

import { config } from "./config.js";
import { api } from "./presentation/http/routes.js";

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
