import { config } from "../../config.js";
import type { SpeechToTextProvider, Transcript } from "./provider.js";

// ローカルの STT サービス（faster-whisper, ../stt_service）を HTTP で呼ぶ実装。
// E.D.I.T.H の方針: LLM はクラウド(deniai)、文字起こしはローカル。
export class HttpWhisperProvider implements SpeechToTextProvider {
  constructor(private readonly baseUrl: string = config.sttBaseUrl) {}

  async transcribe(audio: {
    bytes: ArrayBuffer;
    filename: string;
    mimeType: string;
    language?: string;
  }): Promise<Transcript> {
    const form = new FormData();
    form.append("audio", new Blob([audio.bytes], { type: audio.mimeType }), audio.filename);
    if (audio.language) form.append("language", audio.language);

    const res = await fetch(`${this.baseUrl}/transcribe`, { method: "POST", body: form });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`STT service failed: ${res.status} ${detail}`);
    }
    const data = (await res.json()) as {
      text: string;
      language?: string;
      duration?: number;
    };
    return { text: data.text, language: data.language, durationSec: data.duration };
  }
}

export const stt: SpeechToTextProvider = new HttpWhisperProvider();
