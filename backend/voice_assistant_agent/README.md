# E.D.I.T.H Voice Agent

E.D.I.T.H の思考・操作インターフェース。ユーザーの音声・テキスト指示を理解し、
Tool Calling で E.D.I.T.H の各機能（人物登録・会話ログ・過去会話検索）を実行し、
結果を自然な日本語で返す Agent API です。

デバイス（カメラ・マイク・HUD）は直接操作せず、必要な場合はクライアント（グラス等）へ
`capture_face` などの **Action** を返す設計（PRD §6.1 / §20）。クライアントを Mac →
スマホ → スマートグラス(Halo) へ差し替えても Agent 本体は変更不要です。

> ✅ **Phase 1（Text Agent）** + **Phase 2 の音声入力(STT)** まで実装済み。
> 音声はローカル STT サービス（[`../stt_service`](../stt_service)、faster-whisper）で文字起こしし、
> `POST /v1/agent/audio`（Push-to-Talk）で Agent に流します。**LLM はクラウド(deniai)、文字起こしはローカル**。
> 音声応答(TTS)・WebSocket は今後。詳細は `PRD.md` を参照。

## 技術スタック

- **TypeScript + Hono**（Agent API）
- **PostgreSQL + Drizzle ORM**（Conversation / Utterance / AgentSession / AgentAction）
- **LLM**: [deniai.app](https://api.deniai.app/v1)（OpenAI 互換, 既定 `openai/gpt-5.2`）を
  `openai` SDK 経由で利用。Provider 依存は `src/infrastructure/llm/client.ts` に隔離。
- **Face API 連携**: 既存の `../face_api`（Python/FastAPI）を HTTP で呼ぶ（顔認証は Agent の責務外）。

## セットアップ

### 1. データベース（PostgreSQL）を起動

face_api の PostgreSQL(5432) と衝突しないよう **5433** で公開します。

```bash
# podman で直接起動（推奨）
podman run -d --name edith-agent-db \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=edith_agent \
  -p 5433:5432 -v edith_agent_db_data:/var/lib/postgresql/data \
  docker.io/library/postgres:16
```

（`docker compose up -d db` / `podman compose up -d db` でも起動できます。`docker-compose.yml` 同梱）

### 2. 環境変数

```bash
cp .env.example .env
# .env の LLM_API_KEY を自分の deniai API キーに設定する
```

| 変数 | 説明 | 既定 |
| --- | --- | --- |
| `PORT` | サーバのポート | `8010` |
| `DATABASE_URL` | PostgreSQL 接続文字列 | `postgres://postgres:postgres@localhost:5433/edith_agent` |
| `LLM_BASE_URL` | LLM の Base URL（OpenAI 互換） | `https://api.deniai.app/v1` |
| `LLM_API_KEY` | LLM の API キー | （必須） |
| `LLM_MODEL` | 使用モデル | `openai/gpt-5.2` |
| `FACE_API_BASE_URL` | 既存 Face API の URL | `http://localhost:8000` |
| `STT_BASE_URL` | ローカル STT サービスの URL | `http://localhost:8020` |
| `DEFAULT_USER_ID` | MVP 用の固定ユーザー ID | `00000000-...-0001` |

### 3. 依存インストール & マイグレーション & 起動

```bash
npm install
npm run db:migrate      # drizzle/ の SQL を適用
npm run dev             # tsx watch で起動（本番相当は npm start）
```

起動後:

- Agent API: `http://localhost:8010`
- テスト UI（テキストで Agent を試せる）: `http://localhost:8010/ui/`

## API

| メソッド / パス | 説明 |
| --- | --- |
| `POST /v1/agent/input` | テキスト指示を送り、Agent の応答・Action を得る（PRD §8.1） |
| `POST /v1/agent/audio` | 音声(multipart `audio`)を送り、ローカル STT で文字起こし→Agent 応答（Push-to-Talk, PRD §8/§12） |
| `POST /v1/agent/actions/:requestId/result` | クライアントが実行した Action の結果を返す |
| `POST /v1/conversations` | Conversation を作成 |
| `POST /v1/conversations/:id/utterances` | 発話を追加 |
| `POST /v1/conversations/:id/end` | Conversation を終了し要約を生成 |
| `GET /v1/conversations` | Conversation を検索（`name` / `personId` / `from` / `to`） |
| `GET /health` | ヘルスチェック |

### 例: Agent にテキストを送る

```bash
curl -X POST http://localhost:8010/v1/agent/input \
  -H 'Content-Type: application/json' \
  -d '{"type":"text","content":"この人を田中さんとして覚えて"}'
```

```json
{
  "sessionId": "…",
  "message": "田中さんとして覚えるため、顔撮影を開始してください。",
  "actions": [{ "id": "…", "type": "capture_face", "payload": { "name": "田中さん" } }],
  "toolCalls": [{ "name": "register_person", "args": { "name": "田中さん" }, "result": { … } }]
}
```

## Agent Tool（MVP, PRD §7）

| Tool | 説明 |
| --- | --- |
| `register_person` | 人物登録を要求（`capture_face` Action をクライアントへ返す） |
| `get_person` | 登録済み人物情報を Face API から取得 |
| `start_conversation` | 会話ログ（Conversation）を開始 |
| `stop_conversation` | 会話を終了し、LLM で要約・トピックを生成 |
| `search_conversations` | 過去会話を検索し自然言語で回答 |

「会話記録開始」「記録終了」などの明確な指示は、LLM を介さずコマンドマッチャ
（`src/commands/matcher.ts`）で決定的に処理し、レイテンシ・コストを抑えます（PRD §18）。

## ディレクトリ構成

```
src/
  agent/            Agent コア（Pipeline / prompt）
  commands/         決定的コマンドマッチャ
  tools/            Tool 定義と registry（person/ conversation/）
  domain/           Conversation / AgentSession の repository
  infrastructure/
    database/       Drizzle schema / client / migrate
    llm/            deniai(OpenAI互換) クライアント・要約
    face/           Face API クライアント
  presentation/http Hono ルート
  config.ts         環境変数
static/             テスト UI
drizzle/            生成されたマイグレーション
```

## メモ

- **認証は未実装（MVP）**。全リクエストは `DEFAULT_USER_ID` に紐付きます。将来 `Authorization: Bearer` を導入予定（PRD §22）。
- `get_person` / `register_person` の登録実処理は Face API 側に依存します（`FACE_API_BASE_URL` を起動しておく）。
- **音声入力を使うには** ローカル STT サービスを起動しておく（[`../stt_service`](../stt_service): `uv sync && STT_MODEL=small ./.venv/bin/uvicorn app:app --port 8020`）。テスト UI の 🎤 ボタン（押している間だけ録音）で Push-to-Talk を試せる。
- LLM 呼び出し（deniai）はクラウド、**文字起こしはローカル(whisper)**、という構成。TTS(音声応答)・WebSocket は今後の Phase。
