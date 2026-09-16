# E.D.I.T.H

顔・名前・過去の会話を覚えるのが苦手なユーザーを補助する **AIスマートグラス向け「社会的記憶」補助システム**。
一度会った人物を認識し（Recognize）、前回何を話したか思い出し（Remember）、いまの会話を補助する（Assist）体験を目指す。

対象デバイスは [brilliant.xyz **Halo**](https://brilliant.xyz/)。グラスは薄い表示・センシングクライアントとし、
知能部分（顔認識・音声理解・記憶）を独立したバックエンドサービスとして**先行開発**する方針。

> プロダクト全体の詳細は [`smart_glasses_social_memory.md`](./smart_glasses_social_memory.md)（プロダクトPRD）を参照。
> 当面の目標は **Lv.1（顔認識 → 名前を HUD 表示）** の達成。

## アーキテクチャ（マイクロサービス）

```
┌─────────────────────────────┐
│ Client (native/)            │  Halo 公式 Flutter SDK で実装予定
│ Camera / Mic / HUD / Speaker│  Agent が返す Action(capture_face 等)を実行
└──────────────┬──────────────┘
               │ HTTP / (将来 WebSocket)
        ┌──────┴───────┐
        ▼              ▼
┌───────────────┐  ┌──────────────────────────┐
│ face_api      │  │ voice_assistant_agent    │
│ Python/FastAPI│◀─│ TypeScript/Hono          │
│ 顔登録・識別   │  │ 音声/テキスト指示 → Tool   │
│ insightface   │  │ Calling → 各機能を実行     │
│ +pgvector     │  │ LLM: deniai(gpt-5.2)      │
└──────┬────────┘  └───────────┬──────────────┘
       ▼                       ▼
  PostgreSQL(pgvector)    PostgreSQL
```

| サービス | ディレクトリ | 技術 | 役割 | 状態 |
| --- | --- | --- | --- | --- |
| **Face API** | [`backend/face_api`](./backend/face_api) | Python / FastAPI / insightface / pgvector | 顔画像から人物を登録・識別（Face Embedding） | ✅ 実装済み |
| **Voice Agent** | [`backend/voice_assistant_agent`](./backend/voice_assistant_agent) | TypeScript / Hono / Drizzle / PostgreSQL | 指示理解・Tool Calling・会話ログ・記憶 | ✅ Phase 1(Text)+Phase 2(音声入力) |
| **STT Service** | [`backend/stt_service`](./backend/stt_service) | Python / faster-whisper (CPU) | ローカル音声文字起こし | ✅ 実装済み |
| **Native Client** | [`native/edith_glass`](./native/edith_glass) | Flutter (Halo) | グラスHUD(SFレティクル)・カメラ識別・音声/指示 | ✅ プレビュー実装（実機待ち） |

## ローカルで動かす

前提: `podman`（DBコンテナ用）, `node`(>=20), `uv`（Python 環境）。DB は 3 サービスでポートを分けています。

### 1. Face API（顔認識） — ポート 8000 / DB 5432(既定)

```bash
cd backend/face_api
cp .env.example .env
# pgvector を podman で起動（例では 5434。DATABASE_URL を合わせること）
podman run -d --name edith-face-db \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=face_auth \
  -p 5434:5432 -v edith_face_db_data:/var/lib/postgresql/data docker.io/pgvector/pgvector:pg16
export DATABASE_URL="postgresql+psycopg://postgres:postgres@localhost:5434/face_auth"
uv sync
./.venv/bin/alembic upgrade head
./.venv/bin/uvicorn src.main:app --port 8000   # 初回は顔モデルをDL
```

詳細・API は [`backend/face_api/README.md`](./backend/face_api/README.md)。

### 2. Voice Agent（指示理解・記憶） — ポート 8010 / DB 5433

```bash
cd backend/voice_assistant_agent
cp .env.example .env          # .env の LLM_API_KEY を deniai のキーに設定
podman run -d --name edith-agent-db \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=edith_agent \
  -p 5433:5432 -v edith_agent_db_data:/var/lib/postgresql/data docker.io/library/postgres:16
npm install
npm run db:migrate
npm run dev                   # http://localhost:8010/ui/ でテスト可
```

詳細・API・Tool 一覧は [`backend/voice_assistant_agent/README.md`](./backend/voice_assistant_agent/README.md)。

### 3. STT Service（ローカル文字起こし・任意） — ポート 8020

音声入力（`POST /v1/agent/audio` / テスト UI の 🎤）を使う場合のみ起動。GPU 不要。

```bash
cd backend/stt_service
uv sync
STT_MODEL=small ./.venv/bin/uvicorn app:app --port 8020   # 初回は whisper モデルをDL
```

## ドキュメント

- [`smart_glasses_social_memory.md`](./smart_glasses_social_memory.md) — プロダクト全体の PRD（Goals / User Stories / Risks）
- [`backend/voice_assistant_agent/PRD.md`](./backend/voice_assistant_agent/PRD.md) — Voice Agent の詳細 PRD（API / データモデル / フェーズ計画）
