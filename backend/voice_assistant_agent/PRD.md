
# E.D.I.T.H Voice Agent PRD

## 1. 概要

### 1.1 プロダクト名

**E.D.I.T.H Voice Agent**

### 1.2 目的

E.D.I.T.Hにおける音声インターフェースおよびAgent機能を提供する。

スマートグラス本体が未完成の段階でもPC・スマートフォン・Webクライアント等から開発・検証可能とし、将来的には同一のAgent APIをスマートグラスから利用できる設計とする。

本システムは、ユーザーの音声を自然言語として解釈し、登録されたToolを実行することでE.D.I.T.Hの各機能を操作する。

初期MVPでは以下を主要機能とする。

* 音声による人物登録指示
* 会話ログの開始・終了
* 会話内容の文字起こし・保存
* Agentとの音声対話
* 外部Tool/APIの呼び出し
* 過去の会話情報の検索

顔検出・顔認証・顔特徴量生成自体は本システムの責務外とし、既存のFace APIを利用する。

---

# 2. 背景

E.D.I.T.Hは将来的にスマートグラス上で動作し、

* 視界内の人物を認識する
* 人物情報を記憶する
* 会話を記録する
* 過去の会話を参照する
* ユーザーからの自然言語指示を実行する

といったコミュニケーション補助を行うことを目標とする。

しかし、スマートグラス用ハードウェア・クライアントが完成するまでAgent開発を停止する必要はない。

そこで、

> E.D.I.T.Hの知能部分を独立したAPIとして先行開発する

ことを本システムの基本方針とする。

クライアントはE.D.I.T.H Voice Agent APIに対して音声・テキスト・イベントを送信し、Agentは必要に応じてToolを呼び出す。

---

# 3. スコープ

## 3.1 MVP対象

### 音声入力

ユーザーの音声を受信し、STTによってテキストへ変換する。

例:

```text
「EDITH、この人を田中さんとして覚えて」
```

↓

```text
この人を田中さんとして覚えて
```

---

### Agentによる自然言語理解

入力されたテキストからユーザーの意図を解釈する。

例:

```text
この人を田中さんとして覚えて
```

↓

```json
{
  "tool": "register_person",
  "arguments": {
    "name": "田中さん"
  }
}
```

---

### 人物登録指示

Agentは人物登録の指示を理解し、Face APIまたはクライアントへ必要な処理を要求する。

Agent自身は顔認証を実行しない。

想定フロー:

```text
User
 ↓
「この人を田中さんとして覚えて」

Voice Agent
 ↓
register_person

Client
 ↓
現在のカメラフレームを取得

Face API
 ↓
人物登録

Voice Agent
 ↓
「田中さんとして登録しました」
```

---

### 会話ログ開始

以下のような指示を認識する。

```text
「会話を記録して」
「ログ開始」
「この会話覚えておいて」
```

AgentはConversation Sessionを生成する。

---

### 会話ログ終了

以下を認識する。

```text
「記録終了」
「もうログ止めて」
「会話の記録を終わって」
```

Conversation Sessionを終了する。

---

### 会話文字起こし

会話ログ中は音声を継続的にSTTへ送信し、発話単位で保存する。

例:

```json
{
  "conversationId": "conv_xxx",
  "speakerId": "unknown",
  "text": "来週どうする？",
  "timestamp": "2026-09-16T19:20:31+09:00"
}
```

---

### 過去会話検索

自然言語から過去のConversationを検索する。

例:

```text
「昨日佐藤さんと何話した？」
```

↓

```text
search_conversations(
  person = "佐藤さん",
  date = "yesterday"
)
```

検索結果をLLMへ渡し、自然な文章として回答する。

---

### 音声応答

Agentの回答をTTSに渡し、音声としてクライアントに返せるようにする。

MVPではテキストレスポンスも必須とする。

---

# 4. 非スコープ

MVPでは以下を実装対象外とする。

* 顔検出
* 顔認証
* Face Embedding生成
* スマートグラス専用UI
* AR描画
* 自律的な長期タスク実行
* Web検索
* メール操作
* カレンダー操作
* GPSによる位置認識
* 感情認識
* 音声からの本人認証
* 完全なオフライン動作

これらは将来的にToolとして追加可能な設計とする。

---

# 5. システム構成

## 5.1 基本構成

```text
┌──────────────────────────┐
│ Client                   │
│                          │
│ PC / Smartphone / Glass  │
│                          │
│ Microphone               │
│ Camera                   │
│ Speaker                  │
└─────────────┬────────────┘
              │
              │ HTTP / WebSocket
              ▼
┌──────────────────────────┐
│ E.D.I.T.H Voice Agent    │
│                          │
│ API                      │
│ Session Manager          │
│ Agent Core               │
│ Tool Executor            │
│ Conversation Manager     │
│ Memory                   │
└───────┬─────────┬────────┘
        │         │
        ▼         ▼
       LLM       STT/TTS
        │
        ▼
┌──────────────────────────┐
│ External Tools           │
│                          │
│ Face API                 │
│ Person API               │
│ etc...                   │
└──────────────────────────┘
```

---

# 6. 設計思想

## 6.1 Agentとデバイスを分離する

Agentは以下のハードウェアを直接操作しない。

* カメラ
* マイク
* ディスプレイ
* スピーカー

代わりに、

```text
Agent
↓
「camera_frameが必要」
↓
Client
↓
カメラ画像取得
```

のように、クライアントへ要求を返す。

これにより、

```text
MacBook
↓
スマートフォン
↓
スマートグラス
```

へクライアントを変更してもAgent本体を変更する必要がない。

---

## 6.2 Tool Callingベースとする

Agentの機能はToolとして提供する。

LLMは直接DBや外部APIを操作しない。

例:

```ts
registerPerson()
startConversation()
stopConversation()
searchConversations()
getPerson()
```

---

## 6.3 Agent Memoryとデータベースを分離する

LLMのContext Windowを永続ストレージとして使用しない。

人物情報およびConversationはDBに保存する。

必要な情報のみ検索してLLMへ渡す。

---

# 7. Agent Tool

MVPでは以下を実装する。

## register_person

人物の登録を要求する。

### Input

```json
{
  "name": "田中さん"
}
```

### Result

Agent側では直接登録せず、クライアントにActionを返してもよい。

```json
{
  "requiresAction": {
    "type": "capture_face",
    "requestId": "req_xxx",
    "payload": {
      "name": "田中さん"
    }
  }
}
```

---

## start_conversation

会話ログを開始する。

### Input

```json
{
  "participants": []
}
```

### Output

```json
{
  "conversationId": "conv_xxx"
}
```

---

## stop_conversation

会話ログを終了する。

### Input

```json
{
  "conversationId": "conv_xxx"
}
```

---

## search_conversations

過去のConversationを検索する。

### Input

```json
{
  "query": "昨日田中さんと話した内容",
  "personId": "optional",
  "from": "optional",
  "to": "optional"
}
```

---

## get_person

登録済み人物情報を取得する。

### Input

```json
{
  "personId": "person_xxx"
}
```

または

```json
{
  "name": "田中さん"
}
```

---

# 8. API設計

## 8.1 REST API

### Agent Input

```http
POST /v1/agent/input
```

Request:

```json
{
  "sessionId": "session_xxx",
  "type": "text",
  "content": "この人を田中さんとして覚えて"
}
```

Response:

```json
{
  "message": "田中さんとして登録します。",
  "actions": [
    {
      "type": "capture_face",
      "requestId": "req_xxx"
    }
  ]
}
```

---

### Audio Input

```http
POST /v1/agent/audio
```

音声ファイルまたは音声チャンクを送信する。

MVP初期ではmultipart/form-dataでもよい。

将来的にはWebSocketへ移行する。

---

### Action Result

```http
POST /v1/agent/actions/:requestId/result
```

クライアント側で実行したAction結果をAgentへ返す。

例:

```json
{
  "success": true,
  "personId": "person_123"
}
```

---

### Conversation作成

```http
POST /v1/conversations
```

---

### 発話登録

```http
POST /v1/conversations/:id/utterances
```

---

### Conversation終了

```http
POST /v1/conversations/:id/end
```

---

### Conversation検索

```http
GET /v1/conversations
```

---

# 9. リアルタイム通信

MVP後期ではWebSocketを導入する。

```text
WS /v1/realtime
```

扱うイベント例:

```text
audio.chunk
audio.transcript
agent.message
agent.action
agent.action_result
conversation.started
conversation.utterance
conversation.ended
```

イベント例:

```json
{
  "type": "agent.message",
  "data": {
    "text": "田中さんとして登録します"
  }
}
```

---

# 10. 会話セッション

Agentとの対話セッションと、現実世界のConversation Sessionは別概念として扱う。

## Agent Session

E.D.I.T.Hとユーザー間のセッション。

```text
「この人誰？」
「昨日話したこと教えて」
```

など。

---

## Conversation Session

ユーザーと第三者との現実の会話ログ。

```text
User ↔ Person
```

---

両者を混同しない。

例:

```text
AgentSession
  session_xxx

Conversation
  conversation_xxx
```

---

# 11. データモデル

## AgentSession

```ts
interface AgentSession {
  id: string;
  userId: string;

  createdAt: Date;
  updatedAt: Date;
}
```

---

## Conversation

```ts
interface Conversation {
  id: string;

  userId: string;

  startedAt: Date;
  endedAt?: Date;

  status:
    | "recording"
    | "completed";
}
```

---

## ConversationParticipant

```ts
interface ConversationParticipant {
  conversationId: string;

  personId?: string;

  role:
    | "user"
    | "person"
    | "unknown";
}
```

---

## Utterance

```ts
interface Utterance {
  id: string;

  conversationId: string;

  speakerId?: string;

  text: string;

  startedAt: Date;
  endedAt?: Date;

  confidence?: number;
}
```

---

## AgentAction

```ts
interface AgentAction {
  id: string;

  sessionId: string;

  type: string;

  status:
    | "pending"
    | "completed"
    | "failed";

  payload: unknown;

  createdAt: Date;
}
```

---

# 12. 音声処理

## 12.1 MVP

```text
Microphone
↓
Audio Upload
↓
STT
↓
Agent
```

最初はPush-to-Talkでも構わない。

---

## 12.2 将来

```text
Microphone
↓
VAD
↓
Audio Streaming
↓
Realtime STT
↓
Agent
```

---

# 13. VAD

Voice Activity Detectionによって、

```text
無音
↓
発話開始
↓
発話
↓
無音
```

を検出する。

会話ログ中に常時音声ファイルを生成するのではなく、発話単位でSTT処理する。

---

# 14. Wake Word

初期MVPでは必須としない。

Push-to-TalkまたはUI操作でAgentを呼び出してよい。

将来的には、

```text
EDITH
```

をWake Wordとする。

Wake Word検出後のみAgentコマンドとして扱う。

---

# 15. Conversation Logging

会話記録開始後は、

```text
Audio
↓
VAD
↓
STT
↓
Speaker Identification
↓
Utterance保存
```

を繰り返す。

MVP時点でSpeaker Identificationが困難な場合、

```text
user
unknown
```

の2種類でもよい。

将来的にはFace API等との統合によって、

```text
unknown
↓
person_123
```

へ更新可能とする。

---

# 16. 会話の後処理

Conversation終了後、LLMを使用して以下を生成可能とする。

```text
summary
topics
keywords
action items
```

例:

```json
{
  "summary": "OISTでの発表内容について相談した。",
  "topics": [
    "OIST",
    "発表資料"
  ]
}
```

MVPではsummaryのみでもよい。

---

# 17. LLM利用方針

LLMは主に以下へ利用する。

* Intent理解
* Tool選択
* Tool Argument生成
* 会話検索クエリ生成
* 検索結果の要約
* ユーザーへの自然言語応答

---

LLMへ直接、

* SQL
* Face API
* DB Credential

などを操作させない。

---

# 18. 非LLM処理

以下は可能な限り通常のプログラムとして処理する。

```text
「会話開始」
「会話終了」
「停止」
```

のような明確なCommand。

これにより、

* レイテンシ低減
* APIコスト削減
* 誤動作軽減

を行う。

---

# 19. Agent Pipeline

基本Pipeline:

```text
Input
↓
Normalize
↓
Command Matcher
↓
┌───────────────┐
│ Command一致   │
└──────┬────────┘
       │ YES
       ▼
   Tool Execute

       NO
       ↓
      LLM
       ↓
  Tool Calling
       ↓
 Tool Execute
       ↓
   LLM Response
       ↓
     Output
```

---

# 20. クライアントAction

Agentがデバイス機能を必要とする場合、Actionとしてクライアントへ返す。

例:

```json
{
  "type": "client_action",
  "action": {
    "id": "action_xxx",
    "type": "capture_face"
  }
}
```

想定Action:

```text
capture_face
play_audio
show_message
start_microphone
stop_microphone
```

スマートグラス完成後も同一Protocolを利用する。

---

# 21. プライバシー

会話記録を扱うため、プライバシーを重要要件とする。

最低限以下を実装する。

* 会話ログ記録状態の明示
* ログ削除機能
* Conversation単位の削除
* 音声保存有無の設定
* STT後に元音声を破棄できる構造

初期設定では、

> 音声データはSTT処理後に削除し、文字起こしのみ保存

を推奨する。

---

# 22. セキュリティ

APIはユーザー認証を必須とする。

最低限、

```text
Authorization: Bearer <token>
```

形式を利用する。

Tool実行には必ずユーザーIDを紐付ける。

他ユーザーの、

* Person
* Conversation
* Utterance

へアクセスできないようにする。

---

# 23. 推奨技術構成

## Agent API

```text
TypeScript
Hono
```

---

## Database

```text
PostgreSQL
```

ORMについては、

```text
Drizzle ORM
```

を候補とする。

---

## STT

Provider Adapterとして抽象化する。

```ts
interface SpeechToTextProvider {
  transcribe(
    audio: AudioInput
  ): Promise<Transcript>;
}
```

---

## TTS

同様にProvider化する。

```ts
interface TextToSpeechProvider {
  synthesize(
    text: string
  ): Promise<AudioOutput>;
}
```

---

## LLM

LLMについてもProvider依存を避ける。

```ts
interface AgentModel {
  run(
    context: AgentContext
  ): Promise<AgentResponse>;
}
```

---

# 24. ディレクトリ構成案

```text
src/

  agent/
    agent.ts
    context.ts
    prompt.ts

  commands/
    matcher.ts

  tools/
    registry.ts

    person/
      register-person.ts
      get-person.ts

    conversation/
      start-conversation.ts
      stop-conversation.ts
      search-conversations.ts

  conversation/
    service.ts
    repository.ts

  speech/
    stt/
      provider.ts

    tts/
      provider.ts

  realtime/
    websocket.ts

  actions/
    action-manager.ts

  infrastructure/
    database/
    llm/
    stt/
    tts/

  presentation/
    http/
    websocket/

  domain/
    conversation/
    agent/
```

DDDを強く適用する必要はない。

Agent・Conversation・Tool程度の責務分離を行う。

---

# 25. MVPユーザーフロー

## 人物登録

```text
User:
「この人を山田さんとして覚えて」

↓

STT

↓

Agent

↓

register_person
name = 山田さん

↓

Agent:
capture_face Action

↓

Client:
Camera Capture

↓

既存Face API

↓

Face API:
person_id

↓

Agent:
「山田さんとして登録しました」
```

---

## 会話ログ

```text
User:
「会話記録開始」

↓

start_conversation

↓

Conversation:
recording
```

以降、

```text
Microphone
↓
VAD
↓
STT
↓
Utterance
↓
DB
```

終了:

```text
User:
「記録終わって」

↓

stop_conversation

↓

Summary生成

↓

Agent:
「会話を保存しました」
```

---

## 過去会話検索

```text
User:
「昨日山田さんと何話した？」

↓

Agent

↓

search_conversations

↓

DB

↓

Conversation + Utterances

↓

LLM Summary

↓

Agent:
「昨日は主にOISTでの発表について話しています。」
```

---

# 26. MVP開発フェーズ

## Phase 1

Text Agent

実装:

* Agent API
* LLM
* Tool Calling
* PostgreSQL
* Conversation DB
* Person API連携

この段階では音声なし。

---

## Phase 2

Voice Input

追加:

* STT
* 音声アップロード
* Push-to-Talk

---

## Phase 3

Conversation Logging

追加:

* Conversation Session
* VAD
* Utterance保存
* Summary

---

## Phase 4

Realtime

追加:

* WebSocket
* Audio Streaming
* Realtime STT
* Realtime Agent Response

---

## Phase 5

Smart Glass Integration

既存APIをそのまま利用し、

```text
Mac Client
↓
Smart Glass Client
```

へ変更する。

Agent Coreは原則変更しない。

---

# 27. MVP完成条件

以下が動作すればMVP完成とする。

### Agent

* 自然言語入力を受け取れる
* Tool Callingできる

### 人物登録

以下が成立する。

```text
「この人を○○として覚えて」
↓
Face Capture要求
↓
Face API
↓
登録完了
```

### Conversation

以下が成立する。

```text
「記録開始」
↓
会話文字起こし
↓
DB保存
↓
「記録終了」
```

### Memory

以下へ回答できる。

```text
「昨日○○さんと何を話した？」
```

### Device Independence

Mac / Web Clientから利用でき、Agent側がスマートグラス固有APIへ依存していないこと。

---

# 28. 将来的な拡張

将来的にはTool追加だけで以下へ対応できることを目標とする。

```text
「この人誰？」

「前にこの人と何話した？」

「この人とはいつ会った？」

「さっきの話をメモして」

「これTODOに追加して」

「今日の予定教えて」

「この人について覚えていること教えて」
```

さらに、

```text
Vision Context
+
Audio Context
+
Memory
+
LLM
```

を統合することで、

> 現在の状況と過去の記憶を参照しながらユーザーを補助するAgent

へ発展させる。

---

# 29. E.D.I.T.H Voice Agentの責務

最終的に、本Agentの責務を一文で定義すると、

> ユーザーの音声・テキスト指示を理解し、E.D.I.T.Hが持つ各能力をToolとして呼び出し、その結果を自然言語でユーザーへ返す。

とする。

スマートグラスはE.D.I.T.Hの「身体」であり、

Voice AgentはE.D.I.T.Hの「思考・操作インターフェース」とする。
