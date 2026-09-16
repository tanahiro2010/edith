// PRD §23: STT は Provider Adapter として抽象化する。
// interface SpeechToTextProvider { transcribe(audio): Promise<Transcript> }

export interface Transcript {
  text: string;
  language?: string;
  durationSec?: number;
}

export interface SpeechToTextProvider {
  transcribe(audio: {
    bytes: ArrayBuffer;
    filename: string;
    mimeType: string;
    language?: string;
  }): Promise<Transcript>;
}
