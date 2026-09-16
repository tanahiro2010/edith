"""E.D.I.T.H ローカル STT サービス（faster-whisper, CPU）。

LLM はクラウド(deniai)、文字起こしはローカル、という E.D.I.T.H の方針を体現する
軽量サービス。Voice Agent がこの `/transcribe` を HTTP で呼ぶ。
"""

import os
import tempfile
from contextlib import asynccontextmanager

from faster_whisper import WhisperModel
from fastapi import FastAPI, File, Form, HTTPException, UploadFile

# tiny / base / small / medium / large-v3。日本語は small 以上が無難。
MODEL_SIZE = os.getenv("STT_MODEL", "small")
# GPU 無し前提。int8 で CPU 実行（省メモリ・十分高速）。
COMPUTE_TYPE = os.getenv("STT_COMPUTE_TYPE", "int8")

_model: WhisperModel | None = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global _model
    # 起動時に一度だけモデルをロード（初回はダウンロード）。
    _model = WhisperModel(MODEL_SIZE, device="cpu", compute_type=COMPUTE_TYPE)
    yield


app = FastAPI(title="E.D.I.T.H STT Service", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"ok": True, "model": MODEL_SIZE, "compute_type": COMPUTE_TYPE}


@app.post("/transcribe")
async def transcribe(
    audio: UploadFile = File(...),
    language: str | None = Form(None),  # 例: "ja"。未指定なら自動判定。
):
    if _model is None:
        raise HTTPException(status_code=503, detail="model not loaded")

    data = await audio.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty audio")

    # faster-whisper(PyAV) がデコードできるよう一時ファイルに保存して渡す。
    suffix = os.path.splitext(audio.filename or "")[1] or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        tmp.write(data)
        tmp.flush()
        segments, info = _model.transcribe(tmp.name, language=language, vad_filter=True)
        text = "".join(seg.text for seg in segments).strip()

    return {
        "text": text,
        "language": info.language,
        "language_probability": info.language_probability,
        "duration": info.duration,
    }
