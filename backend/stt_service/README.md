# E.D.I.T.H STT Service

ローカルで動作する音声文字起こし(Speech-to-Text)サービス。[faster-whisper](https://github.com/SYSTRAN/faster-whisper)（CTranslate2, CPU 実行）を使い、GPU 無しでも日本語を文字起こしする。

E.D.I.T.H の方針として **LLM はクラウド(deniai)、文字起こしはローカル**。この分離を体現する軽量サービス。

- `POST /transcribe` — multipart の `audio` を受け取り `{ "text": "...", "language": "ja" }` を返す。
- Voice Agent(`../voice_assistant_agent`) の `SpeechToTextProvider` がこのサービスを HTTP で呼ぶ。

## 起動

```bash
cd backend/stt_service
uv sync
# モデルサイズは STT_MODEL で変更（tiny/base/small/medium）。初回はモデルをDL。
STT_MODEL=small ./.venv/bin/uvicorn app:app --port 8020
```
