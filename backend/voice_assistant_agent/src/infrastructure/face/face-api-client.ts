import { config } from "../../config.js";

// 既存 Face API(FastAPI, Python) のレスポンス（PersonResponse）に対応する型。
export interface FacePerson {
  id: string;
  name: string;
  info: Record<string, unknown>;
  sample_count: number;
  created_at: string;
  updated_at: string;
}

// PRD §6.3 / §17: Agent は Face API を直接「LLM に」触らせず、この Client 経由で呼ぶ。
// 顔認証・Embedding 生成自体は Face API の責務（PRD §1.2, §4）。
export class FaceApiClient {
  constructor(private readonly baseUrl: string = config.faceApiBaseUrl) {}

  async listPeople(): Promise<FacePerson[]> {
    const res = await fetch(`${this.baseUrl}/faces`);
    if (!res.ok) throw new Error(`Face API list failed: ${res.status}`);
    return (await res.json()) as FacePerson[];
  }

  async getPerson(personId: string): Promise<FacePerson | null> {
    const res = await fetch(`${this.baseUrl}/faces/${personId}`);
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`Face API get failed: ${res.status}`);
    return (await res.json()) as FacePerson;
  }

  /** Face API に名前検索は無いため一覧から前方一致で探す（MVP の割り切り）。 */
  async findByName(name: string): Promise<FacePerson[]> {
    const people = await this.listPeople();
    const needle = name.trim();
    return people.filter(
      (p) => p.name === needle || p.name.includes(needle) || needle.includes(p.name),
    );
  }
}

export const faceApi = new FaceApiClient();
