#!/usr/bin/env bash
# E.D.I.T.H ローカル開発の下ごしらえ：podman マシンと DB コンテナを確実に起動する。
# これを実行してから各サービス（face_api / voice_assistant_agent / stt_service）を起動する。
# 「Agent が 500」の多くは DB コンテナ停止が原因。まずこれを実行。
set -euo pipefail

echo "▶ podman マシン確認…"
if ! podman info >/dev/null 2>&1; then
  echo "  マシンを起動します"
  podman machine start
fi

echo "▶ DB コンテナ起動…（restart=always 設定済みなので通常は自動起動）"
podman start edith-agent-db edith-face-db >/dev/null 2>&1 || {
  echo "  コンテナが無い場合は README の手順で作成してください（初回のみ）"
}

echo "▶ Agent DB(5433) 準備待ち…"
for _ in $(seq 1 40); do
  if podman exec edith-agent-db pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done

podman ps --filter name=edith --format '  {{.Names}} {{.Status}} {{.Ports}}'

cat <<'EOF'

✅ DB 準備完了（agent:5433 / face:5434）
次に各サービスを起動:
  Face API : cd backend/face_api && DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5434/face_auth ./.venv/bin/uvicorn src.main:app --port 8000
  Voice Agent : cd backend/voice_assistant_agent && npm run dev   # 起動時に自動マイグレーション
  STT      : cd backend/stt_service && STT_MODEL=small ./.venv/bin/uvicorn app:app --port 8020
  Native   : cd native/edith_glass && flutter run -d chrome
EOF
