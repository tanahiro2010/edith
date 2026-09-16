import OpenAI from "openai";

import { config } from "../../config.js";

// PRD §17/§23: LLM は Provider 依存を避ける。deniai.app は OpenAI 互換なので
// openai SDK に baseURL を差し替えて利用する。将来ローカル LLM 等へ切り替える場合も
// この 1 ファイルを差し替えるだけで済むよう、外部にはこのモジュールだけを公開する。
const openai = new OpenAI({
  apiKey: config.llm.apiKey,
  baseURL: config.llm.baseUrl,
});

export const llm = openai;
export const LLM_MODEL = config.llm.model;
